import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';

enum Layer {
  fuel('fuel'),
  charger('charger'),
  parking('parking');

  const Layer(this.rpcKind);
  final String rpcKind;
}

/// Combustibles en el orden en que salen en el selector (los más usados primero).
/// Las claves son las de la base de datos (ver supabase/functions/import-fuel/parse.ts).
const fuelKeys = [
  'gasolina_95_e5',
  'gasoleo_a',
  'gasolina_98_e5',
  'gasoleo_premium',
  'glp',
  'gasolina_95_e10',
  'diesel_renovable',
  'gnc',
  'gnl',
  'hidrogeno',
  'gasolina_95_e5_premium',
  'gasolina_98_e10',
  'gasolina_renovable',
  'gasoleo_b',
  'adblue',
];

String fuelName(AppLocalizations l, String key) => switch (key) {
  'gasolina_95_e5' => l.fuel_gasolina_95_e5,
  'gasolina_95_e10' => l.fuel_gasolina_95_e10,
  'gasolina_95_e5_premium' => l.fuel_gasolina_95_e5_premium,
  'gasolina_98_e5' => l.fuel_gasolina_98_e5,
  'gasolina_98_e10' => l.fuel_gasolina_98_e10,
  'gasoleo_a' => l.fuel_gasoleo_a,
  'gasoleo_premium' => l.fuel_gasoleo_premium,
  'gasoleo_b' => l.fuel_gasoleo_b,
  'diesel_renovable' => l.fuel_diesel_renovable,
  'gasolina_renovable' => l.fuel_gasolina_renovable,
  'glp' => l.fuel_glp,
  'gnc' => l.fuel_gnc,
  'gnl' => l.fuel_gnl,
  'hidrogeno' => l.fuel_hidrogeno,
  'adblue' => l.fuel_adblue,
  _ => key,
};

double? _toDouble(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

DateTime? _toDate(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Un punto del mapa o un grupo de puntos (count > 1) cuando hay poco zoom.
class MapPoint {
  const MapPoint({
    required this.id,
    required this.position,
    required this.count,
    this.label,
    this.price,
    this.powerKw,
  });

  factory MapPoint.fromJson(Map<String, dynamic> j) => MapPoint(
    id: j['id'] as String?,
    position: LatLng(_toDouble(j['lat'])!, _toDouble(j['lon'])!),
    count: (j['count'] as num?)?.toInt() ?? 1,
    label: j['label'] as String?,
    price: _toDouble(j['price']),
    powerKw: _toDouble(j['power_kw']),
  );

  final String? id;
  final LatLng position;
  final int count;
  final String? label;

  /// Precio del combustible elegido (o el mínimo del grupo).
  final double? price;

  /// Potencia máxima del cargador (o la máxima del grupo).
  final double? powerKw;

  bool get isGroup => count > 1;
}

class FuelStation {
  const FuelStation({
    required this.id,
    this.brand,
    this.address,
    this.municipality,
    this.province,
    this.postcode,
    this.openingHours,
    this.saleType,
    this.prices = const {},
    this.pricesUpdated,
  });

  factory FuelStation.fromJson(Map<String, dynamic> j) {
    final prices = <String, double>{};
    DateTime? updated;
    for (final p in (j['fuel_prices'] as List? ?? const [])) {
      final m = p as Map<String, dynamic>;
      final price = _toDouble(m['price']);
      if (price != null) prices[m['fuel'] as String] = price;
      final u = _toDate(m['updated_at']);
      if (u != null && (updated == null || u.isAfter(updated))) updated = u;
    }
    return FuelStation(
      id: (j['id'] as num).toInt(),
      brand: j['brand'] as String?,
      address: j['address'] as String?,
      municipality: j['municipality'] as String?,
      province: j['province'] as String?,
      postcode: j['postcode'] as String?,
      openingHours: j['opening_hours'] as String?,
      saleType: j['sale_type'] as String?,
      prices: prices,
      pricesUpdated: updated,
    );
  }

  final int id;
  final String? brand;
  final String? address;
  final String? municipality;
  final String? province;
  final String? postcode;
  final String? openingHours;
  final String? saleType;
  final Map<String, double> prices;
  final DateTime? pricesUpdated;

  bool get restricted => saleType == 'R';

  /// Precios en el orden del selector de combustibles.
  List<MapEntry<String, double>> get sortedPrices => [
    for (final k in fuelKeys)
      if (prices[k] != null) MapEntry(k, prices[k]!),
  ];
}

class Connector {
  const Connector({required this.type, this.mode, this.powerKw, this.count = 1});

  factory Connector.fromJson(Map<String, dynamic> j) => Connector(
    type: j['type'] as String? ?? 'other',
    mode: j['mode'] as String?,
    powerKw: _toDouble(j['power_kw']),
    count: (j['count'] as num?)?.toInt() ?? 1,
  );

  final String type;
  final String? mode;
  final double? powerKw;
  final int count;

  /// Nombre comercial del conector.
  String get displayName => switch (type) {
    'type2' => 'Tipo 2',
    'ccs2' => 'CCS2 (Combo)',
    'chademo' => 'CHAdeMO',
    'schuko' => 'Schuko',
    'type1' => 'Tipo 1',
    'ccs1' => 'CCS1',
    'cee16' => 'CEE 16 A',
    'cee32' => 'CEE 32 A',
    _ => type,
  };

  bool get isDc => mode == 'mode4DC';
}

class Charger {
  const Charger({
    required this.id,
    this.name,
    this.operator,
    this.address,
    this.municipality,
    this.province,
    this.openingHours,
    this.points = 0,
    this.maxPowerKw,
    this.connectors = const [],
    this.position,
    this.distanceM,
  });

  factory Charger.fromJson(Map<String, dynamic> j) => Charger(
    id: j['id'] as String,
    name: j['name'] as String?,
    operator: j['operator'] as String?,
    address: j['address'] as String?,
    municipality: j['municipality'] as String?,
    province: j['province'] as String?,
    openingHours: j['opening_hours'] as String?,
    points: (j['points'] as num?)?.toInt() ?? 0,
    maxPowerKw: _toDouble(j['max_power_kw']),
    connectors: [
      for (final c in (j['connectors'] as List? ?? const []))
        Connector.fromJson(c as Map<String, dynamic>),
    ],
    position: j['lat'] != null ? LatLng(_toDouble(j['lat'])!, _toDouble(j['lon'])!) : null,
    distanceM: _toDouble(j['distance_m']),
  );

  final String id;
  final String? name;
  final String? operator;
  final String? address;
  final String? municipality;
  final String? province;
  final String? openingHours;
  final int points;
  final double? maxPowerKw;
  final List<Connector> connectors;
  final LatLng? position;
  final double? distanceM;
}

class Parking {
  const Parking({
    required this.id,
    this.name,
    this.operator,
    this.kind,
    this.fee,
    this.capacity,
  });

  factory Parking.fromJson(Map<String, dynamic> j) => Parking(
    id: j['id'] as String,
    name: j['name'] as String?,
    operator: j['operator'] as String?,
    kind: j['kind'] as String?,
    fee: j['fee'] as bool?,
    capacity: (j['capacity'] as num?)?.toInt(),
  );

  final String id;
  final String? name;
  final String? operator;
  final String? kind;
  final bool? fee;
  final int? capacity;
}

/// Gasolinera de la lista "más baratas cerca".
class NearbyFuel {
  const NearbyFuel({
    required this.id,
    required this.position,
    required this.price,
    this.brand,
    this.address,
    this.municipality,
    this.priceUpdated,
    this.distanceM,
  });

  factory NearbyFuel.fromJson(Map<String, dynamic> j) => NearbyFuel(
    id: (j['id'] as num).toInt(),
    position: LatLng(_toDouble(j['lat'])!, _toDouble(j['lon'])!),
    price: _toDouble(j['price'])!,
    brand: j['brand'] as String?,
    address: j['address'] as String?,
    municipality: j['municipality'] as String?,
    priceUpdated: _toDate(j['price_updated']),
    distanceM: _toDouble(j['distance_m']),
  );

  final int id;
  final LatLng position;
  final double price;
  final String? brand;
  final String? address;
  final String? municipality;
  final DateTime? priceUpdated;
  final double? distanceM;
}

String? _authorName(Map<String, dynamic> j) =>
    (j['profiles'] as Map<String, dynamic>?)?['display_name'] as String?;

const parkingPriceKinds = ['hour', 'day', 'month', 'flat', 'free'];

class ParkingPrice {
  const ParkingPrice({
    required this.id,
    required this.userId,
    required this.kind,
    required this.amount,
    required this.createdAt,
    this.note,
    this.authorName,
  });

  factory ParkingPrice.fromJson(Map<String, dynamic> j) => ParkingPrice(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    kind: j['kind'] as String,
    amount: _toDouble(j['amount']) ?? 0,
    createdAt: _toDate(j['created_at']) ?? DateTime.now(),
    note: j['note'] as String?,
    authorName: _authorName(j),
  );

  final String id;
  final String userId;
  final String kind;
  final double amount;
  final DateTime createdAt;
  final String? note;
  final String? authorName;
}

class ParkingReview {
  const ParkingReview({
    required this.id,
    required this.userId,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.authorName,
  });

  factory ParkingReview.fromJson(Map<String, dynamic> j) => ParkingReview(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    rating: (j['rating'] as num).toInt(),
    createdAt: _toDate(j['updated_at']) ?? _toDate(j['created_at']) ?? DateTime.now(),
    comment: j['comment'] as String?,
    authorName: _authorName(j),
  );

  final String id;
  final String userId;
  final int rating;
  final DateTime createdAt;
  final String? comment;
  final String? authorName;
}

class ParkingPhoto {
  const ParkingPhoto({
    required this.id,
    required this.userId,
    required this.storagePath,
    required this.createdAt,
    this.authorName,
  });

  factory ParkingPhoto.fromJson(Map<String, dynamic> j) => ParkingPhoto(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    storagePath: j['storage_path'] as String,
    createdAt: _toDate(j['created_at']) ?? DateTime.now(),
    authorName: _authorName(j),
  );

  final String id;
  final String userId;
  final String storagePath;
  final DateTime createdAt;
  final String? authorName;
}

/// Contenido de la comunidad de un parking.
class ParkingCommunity {
  const ParkingCommunity({this.prices = const [], this.reviews = const [], this.photos = const []});

  final List<ParkingPrice> prices;
  final List<ParkingReview> reviews;
  final List<ParkingPhoto> photos;

  /// Quita lo de las personas bloqueadas.
  ParkingCommunity without(Set<String> blocked) => blocked.isEmpty
      ? this
      : ParkingCommunity(
          prices: prices.where((p) => !blocked.contains(p.userId)).toList(),
          reviews: reviews.where((r) => !blocked.contains(r.userId)).toList(),
          photos: photos.where((p) => !blocked.contains(p.userId)).toList(),
        );

  double? get averageRating => reviews.isEmpty
      ? null
      : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
}
