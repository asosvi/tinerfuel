import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/models.dart';
import 'data/repository.dart';

/// Se sobrescribe en main() con la instancia ya cargada.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// null si no hay servidor configurado (falta env.json).
final repositoryProvider = Provider<Repository?>(
  (ref) => hasBackend ? Repository(Supabase.instance.client) : null,
);

/// Usuario con sesión (null = sin cuenta).
final userProvider = StreamProvider<User?>((ref) {
  if (!hasBackend) return Stream.value(null);
  final auth = Supabase.instance.client.auth;
  return auth.onAuthStateChange.map((s) => s.session?.user).distinct((a, b) => a?.id == b?.id);
});

/// Estado simple guardado en el dispositivo.
class _PrefNotifier<T> extends Notifier<T> {
  _PrefNotifier(this.key, this.fallback, this.read, this.write);

  final String key;
  final T fallback;
  final T? Function(SharedPreferences, String) read;
  final Future<void> Function(SharedPreferences, String, T) write;

  @override
  T build() => read(ref.read(prefsProvider), key) ?? fallback;

  void set(T value) {
    state = value;
    unawaited(write(ref.read(prefsProvider), key, value));
  }
}

final layerProvider = NotifierProvider<_PrefNotifier<Layer>, Layer>(
  () => _PrefNotifier(
    'layer',
    Layer.fuel,
    (p, k) => Layer.values.where((l) => l.name == p.getString(k)).firstOrNull,
    (p, k, v) => p.setString(k, v.name),
  ),
);

final fuelProvider = NotifierProvider<_PrefNotifier<String>, String>(
  () => _PrefNotifier(
    'fuel',
    fuelKeys.first,
    (p, k) => fuelKeys.contains(p.getString(k)) ? p.getString(k) : null,
    (p, k, v) => p.setString(k, v),
  ),
);

/// Potencia mínima de los cargadores en kW (0 = cualquiera).
final minKwProvider = NotifierProvider<_PrefNotifier<double>, double>(
  () => _PrefNotifier('min_kw', 0, (p, k) => p.getDouble(k), (p, k, v) => p.setDouble(k, v)),
);

/// Idioma elegido (null = el del sistema).
final localeProvider = NotifierProvider<_PrefNotifier<Locale?>, Locale?>(
  () => _PrefNotifier<Locale?>(
    'locale',
    null,
    (p, k) => switch (p.getString(k)) {
      final String code => Locale(code),
      null => null,
    },
    (p, k, v) => v == null ? p.remove(k) : p.setString(k, v.languageCode),
  ),
);

/// Zona visible del mapa (la pone el mapa, con un pequeño retraso al moverlo).
class MapView {
  const MapView(this.bounds, this.zoom);
  final LatLngBounds bounds;
  final double zoom;

  int get roundedZoom => zoom.floor();

  @override
  bool operator ==(Object other) =>
      other is MapView &&
      other.roundedZoom == roundedZoom &&
      other.bounds.north == bounds.north &&
      other.bounds.south == bounds.south &&
      other.bounds.east == bounds.east &&
      other.bounds.west == bounds.west;

  @override
  int get hashCode => Object.hash(roundedZoom, bounds.north, bounds.south, bounds.east, bounds.west);
}

class MapViewNotifier extends Notifier<MapView?> {
  @override
  MapView? build() => null;

  void set(MapView view) => state = view;
}

final mapViewProvider = NotifierProvider<MapViewNotifier, MapView?>(MapViewNotifier.new);

/// Puntos de la capa elegida en la zona visible.
final mapPointsProvider = FutureProvider<List<MapPoint>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final view = ref.watch(mapViewProvider);
  if (repo == null || view == null) return const [];
  return repo.mapPoints(
    layer: ref.watch(layerProvider),
    bounds: view.bounds,
    zoom: view.roundedZoom,
    fuel: ref.watch(fuelProvider),
    minKw: ref.watch(minKwProvider),
  );
});

/// Última importación correcta de cada fuente.
final freshnessProvider = FutureProvider<Map<String, DateTime>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  if (repo == null) return const {};
  final timer = Timer(const Duration(minutes: 10), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return repo.freshness();
});

/// Personas que he bloqueado (id -> nombre). Se vacía al cerrar sesión.
final blockedUsersProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final user = ref.watch(userProvider).value;
  if (repo == null || user == null) return const {};
  return repo.blockedUsers();
});

final fuelStationProvider = FutureProvider.family<FuelStation, int>(
  (ref, id) => ref.watch(repositoryProvider)!.station(id),
);

final chargerProvider = FutureProvider.family<Charger, String>(
  (ref, id) => ref.watch(repositoryProvider)!.charger(id),
);

final parkingProvider = FutureProvider.family<Parking, String>(
  (ref, id) => ref.watch(repositoryProvider)!.parking(id),
);

final parkingCommunityProvider = FutureProvider.family<ParkingCommunity, String>((ref, id) async {
  final community = await ref.watch(repositoryProvider)!.community(id);
  final blocked = await ref.watch(blockedUsersProvider.future);
  return community.without(blocked.keys.toSet());
});
