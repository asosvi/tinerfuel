import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Errores que la interfaz sabe explicar.
enum AppErrorKind { rateLimited, alreadyReported, notSignedIn, invalidImage, other }

class AppException implements Exception {
  const AppException(this.kind, [this.detail]);
  final AppErrorKind kind;
  final String? detail;

  @override
  String toString() => 'AppException($kind, $detail)';
}

const photoBucket = 'parking-photos';

/// Única puerta a Supabase: la interfaz no llama a `Supabase.instance` directamente.
class Repository {
  Repository(this.db);

  final SupabaseClient db;

  String? get userId => db.auth.currentUser?.id;

  // ------------------------------------------------------------ mapa y listas

  Future<List<MapPoint>> mapPoints({
    required Layer layer,
    required LatLngBounds bounds,
    required int zoom,
    required String fuel,
    required double minKw,
  }) async {
    final rows = await db.rpc(
      'map_points',
      params: {
        'kind': layer.rpcKind,
        'min_lon': bounds.west,
        'min_lat': bounds.south,
        'max_lon': bounds.east,
        'max_lat': bounds.north,
        'zoom': zoom,
        'fuel': fuel,
        'min_kw': minKw,
      },
    );
    return [for (final r in rows as List) MapPoint.fromJson(r as Map<String, dynamic>)];
  }

  Future<List<NearbyFuel>> fuelNear(LatLng at, String fuel, {String orderBy = 'price'}) async {
    final rows = await db.rpc(
      'fuel_near',
      params: {'lat': at.latitude, 'lon': at.longitude, 'fuel': fuel, 'order_by': orderBy},
    );
    return [for (final r in rows as List) NearbyFuel.fromJson(r as Map<String, dynamic>)];
  }

  Future<List<Charger>> chargersNear(LatLng at, double minKw) async {
    final rows = await db.rpc(
      'chargers_near',
      params: {'lat': at.latitude, 'lon': at.longitude, 'min_kw': minKw},
    );
    return [for (final r in rows as List) Charger.fromJson(r as Map<String, dynamic>)];
  }

  /// Fecha de la última importación correcta por fuente ('miteco', 'dgt', 'osm').
  Future<Map<String, DateTime>> freshness() async {
    final rows = await db.rpc('data_freshness');
    return {
      for (final r in rows as List)
        if ((r as Map)['finished_at'] != null)
          r['source'] as String: DateTime.parse(r['finished_at'] as String).toLocal(),
    };
  }

  // ------------------------------------------------------------ fichas

  Future<FuelStation> station(int id) async {
    final row = await db
        .from('fuel_stations')
        .select(
          'id, brand, address, municipality, province, postcode, opening_hours, sale_type, '
          'fuel_prices(fuel, price, updated_at)',
        )
        .eq('id', id)
        .single();
    return FuelStation.fromJson(row);
  }

  Future<Charger> charger(String id) async {
    final row = await db
        .from('chargers')
        .select(
          'id, name, operator, address, municipality, province, opening_hours, '
          'points, max_power_kw, connectors',
        )
        .eq('id', id)
        .single();
    return Charger.fromJson(row);
  }

  Future<Parking> parking(String id) async {
    final row = await db
        .from('parkings')
        .select('id, name, operator, kind, fee, capacity')
        .eq('id', id)
        .single();
    return Parking.fromJson(row);
  }

  // ------------------------------------------------------------ comunidad

  static const _author = 'profiles(display_name)';

  Future<ParkingCommunity> community(String parkingId) async {
    final results = await Future.wait([
      db
          .from('parking_prices')
          .select('id, user_id, kind, amount, note, created_at, $_author')
          .eq('parking_id', parkingId)
          .order('created_at', ascending: false)
          .limit(50),
      db
          .from('parking_reviews')
          .select('id, user_id, rating, comment, created_at, updated_at, $_author')
          .eq('parking_id', parkingId)
          .order('updated_at', ascending: false)
          .limit(100),
      db
          .from('parking_photos')
          .select('id, user_id, storage_path, created_at, $_author')
          .eq('parking_id', parkingId)
          .order('created_at', ascending: false)
          .limit(30),
    ]);
    return ParkingCommunity(
      prices: [for (final r in results[0]) ParkingPrice.fromJson(r)],
      reviews: [for (final r in results[1]) ParkingReview.fromJson(r)],
      photos: [for (final r in results[2]) ParkingPhoto.fromJson(r)],
    );
  }

  String photoUrl(String storagePath) => db.storage.from(photoBucket).getPublicUrl(storagePath);

  Future<void> addPrice({
    required String parkingId,
    required String kind,
    required double amount,
    String? note,
  }) => _write(
    () => db.from('parking_prices').insert({
      'parking_id': parkingId,
      'kind': kind,
      'amount': amount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }),
  );

  /// Crea o actualiza mi opinión (una por parking).
  Future<void> saveReview({
    required String parkingId,
    required int rating,
    String? comment,
    String? existingId,
  }) {
    final text = comment?.trim();
    return _write(
      () => existingId == null
          ? db.from('parking_reviews').insert({
              'parking_id': parkingId,
              'rating': rating,
              if (text != null && text.isNotEmpty) 'comment': text,
            })
          : db
                .from('parking_reviews')
                .update({'rating': rating, 'comment': (text?.isEmpty ?? true) ? null : text})
                .eq('id', existingId),
    );
  }

  Future<void> deletePrice(String id) => _write(() => db.from('parking_prices').delete().eq('id', id));

  Future<void> deleteReview(String id) => _write(() => db.from('parking_reviews').delete().eq('id', id));

  /// Sube una foto ya preparada (JPEG sin EXIF, ver photo_processing.dart).
  Future<void> addPhoto({required String parkingId, required Uint8List jpeg}) async {
    final uid = userId;
    if (uid == null) throw const AppException(AppErrorKind.notSignedIn);
    final id = uuidV4();
    final path = '$uid/$id.jpg';
    await db.storage
        .from(photoBucket)
        .uploadBinary(path, jpeg, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    try {
      await _write(
        () => db.from('parking_photos').insert({'id': id, 'parking_id': parkingId, 'storage_path': path}),
      );
    } catch (_) {
      await db.storage.from(photoBucket).remove([path]); // no dejar archivos sueltos
      rethrow;
    }
  }

  Future<void> deletePhoto(ParkingPhoto photo) async {
    await _write(() => db.from('parking_photos').delete().eq('id', photo.id));
    await db.storage.from(photoBucket).remove([photo.storagePath]);
  }

  // ------------------------------------------------------------ moderación

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) => _write(
    () => db.from('reports').insert({
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    }),
  );

  Future<void> block(String otherUserId) =>
      _write(() => db.from('user_blocks').insert({'blocked_id': otherUserId}));

  Future<void> unblock(String otherUserId) => _write(
    () => db.from('user_blocks').delete().eq('blocker_id', userId ?? '').eq('blocked_id', otherUserId),
  );

  /// Personas que he bloqueado: id -> nombre.
  Future<Map<String, String>> blockedUsers() async {
    if (userId == null) return {};
    final rows = await db.from('user_blocks').select('blocked_id').eq('blocker_id', userId!);
    final ids = [for (final r in rows) r['blocked_id'] as String];
    if (ids.isEmpty) return {};
    final profiles = await db.from('profiles').select('id, display_name').inFilter('id', ids);
    final names = {for (final p in profiles) p['id'] as String: p['display_name'] as String};
    return {for (final id in ids) id: names[id] ?? '?'};
  }

  // ------------------------------------------------------------ cuenta

  Future<String?> myDisplayName() async {
    if (userId == null) return null;
    final row = await db.from('profiles').select('display_name').eq('id', userId!).maybeSingle();
    return row?['display_name'] as String?;
  }

  Future<void> setDisplayName(String name) =>
      _write(() => db.from('profiles').update({'display_name': name.trim()}).eq('id', userId ?? ''));

  /// Borra mis fotos de Storage (no se pueden borrar por SQL) y después la cuenta.
  Future<void> deleteAccount() async {
    final uid = userId;
    if (uid == null) throw const AppException(AppErrorKind.notSignedIn);
    final files = await db.storage.from(photoBucket).list(path: uid);
    if (files.isNotEmpty) {
      await db.storage.from(photoBucket).remove([for (final f in files) '$uid/${f.name}']);
    }
    await db.rpc('delete_my_account');
    await db.auth.signOut();
  }

  Future<void> _write(Future<dynamic> Function() op) async {
    if (userId == null) throw const AppException(AppErrorKind.notSignedIn);
    try {
      await op();
    } on PostgrestException catch (e) {
      if (e.message.contains('rate_limited')) throw const AppException(AppErrorKind.rateLimited);
      if (e.code == '23505') throw const AppException(AppErrorKind.alreadyReported);
      rethrow;
    }
  }
}

/// UUID v4 aleatorio (para el nombre de las fotos, sin depender de otro paquete).
String uuidV4([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) =>
      b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
