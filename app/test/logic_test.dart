import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tinerfuel/auth/login_page.dart';
import 'package:tinerfuel/community/community_dialogs.dart';
import 'package:tinerfuel/community/photo_processing.dart';
import 'package:tinerfuel/data/models.dart';
import 'package:tinerfuel/data/repository.dart';
import 'package:tinerfuel/l10n/app_localizations_en.dart';
import 'package:tinerfuel/l10n/app_localizations_es.dart';
import 'package:tinerfuel/ui/format.dart';
import 'package:tinerfuel/ui/theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('mapa', () {
    test('la caja se recorta a España (la base de datos rechaza cajas enormes)', () {
      // vista inicial en una pantalla grande: medio Atlántico y media Europa
      final box = clampToSpain(LatLngBounds(const LatLng(20.1, -40.1), const LatLng(48.2, 25.3)))!;
      expect(box.east - box.west, lessThanOrEqualTo(40));
      expect(box.north - box.south, lessThanOrEqualTo(30));
      expect(box.contains(const LatLng(28.46, -16.25)), isTrue); // Tenerife
      expect(box.contains(const LatLng(42.0, 3.2)), isTrue); // Girona
      // una caja dentro de España no cambia
      final madrid = LatLngBounds(const LatLng(40.3, -3.8), const LatLng(40.5, -3.6));
      expect(clampToSpain(madrid)!.south, 40.3);
      // fuera de España: nada que pedir
      expect(clampToSpain(LatLngBounds(const LatLng(50, 10), const LatLng(52, 12))), isNull);
    });
  });

  group('models', () {
    test('MapPoint: punto suelto y grupo', () {
      final p = MapPoint.fromJson({'id': '12', 'lat': 28.4, 'lon': -16.2, 'count': 1, 'price': '1.459'});
      expect(p.isGroup, isFalse);
      expect(p.price, 1.459);
      final g = MapPoint.fromJson({'id': null, 'lat': 40, 'lon': -3, 'count': 37, 'price': 1.3});
      expect(g.isGroup, isTrue);
      expect(g.id, isNull);
    });

    test('FuelStation: precios en el orden del selector y fecha más reciente', () {
      final s = FuelStation.fromJson({
        'id': 5,
        'brand': 'REPSOL',
        'sale_type': 'R',
        'fuel_prices': [
          {'fuel': 'gasoleo_a', 'price': 1.709, 'updated_at': '2026-10-27T10:00:00Z'},
          {'fuel': 'gasolina_95_e5', 'price': '1.559', 'updated_at': '2026-10-27T12:00:00Z'},
          {'fuel': 'desconocido', 'price': 9.9, 'updated_at': '2026-10-01T00:00:00Z'},
        ],
      });
      expect(s.restricted, isTrue);
      expect(s.sortedPrices.map((e) => e.key), ['gasolina_95_e5', 'gasoleo_a']);
      expect(s.pricesUpdated, DateTime.parse('2026-10-27T12:00:00Z').toLocal());
    });

    test('Charger: conectores', () {
      final c = Charger.fromJson({
        'id': 'S1',
        'points': 2,
        'max_power_kw': 150,
        'connectors': [
          {'type': 'ccs2', 'mode': 'mode4DC', 'power_kw': 150.0, 'count': 1},
          {'type': 'type2', 'mode': 'mode3AC3p', 'power_kw': 22, 'count': 2},
        ],
        'lat': 39.5,
        'lon': 2.6,
      });
      expect(c.connectors.first.isDc, isTrue);
      expect(c.connectors.first.displayName, 'CCS2 (Combo)');
      expect(c.position?.latitude, 39.5);
    });

    test('ParkingCommunity: oculta lo de personas bloqueadas', () {
      final c = ParkingCommunity(
        prices: [
          ParkingPrice(id: '1', userId: 'a', kind: 'hour', amount: 2, createdAt: DateTime(2026)),
          ParkingPrice(id: '2', userId: 'b', kind: 'hour', amount: 3, createdAt: DateTime(2026)),
        ],
        reviews: [
          ParkingReview(id: 'r1', userId: 'a', rating: 5, createdAt: DateTime(2026)),
          ParkingReview(id: 'r2', userId: 'b', rating: 1, createdAt: DateTime(2026)),
        ],
      );
      expect(c.averageRating, 3);
      final filtered = c.without({'b'});
      expect(filtered.prices.map((p) => p.id), ['1']);
      expect(filtered.averageRating, 5);
    });

    test('nombres de todos los combustibles traducidos', () {
      for (final l in [AppLocalizationsEs(), AppLocalizationsEn()]) {
        for (final k in fuelKeys) {
          expect(fuelName(l, k), isNot(k), reason: '$k sin traducir');
        }
      }
    });
  });

  group('formato', () {
    test('precios', () {
      expect(formatShortPrice(1.459, 'es'), '1,459');
      expect(formatShortPrice(1.459, 'en'), '1.459');
      expect(formatMoney(2.5, 'es'), contains('2,50'));
    });

    test('hace cuánto', () {
      final l = AppLocalizationsEs();
      final now = DateTime(2026, 10, 27, 12);
      expect(formatAgo(l, now.subtract(const Duration(seconds: 20)), now: now), 'ahora mismo');
      expect(formatAgo(l, now.subtract(const Duration(minutes: 25)), now: now), 'hace 25 min');
      expect(formatAgo(l, now.subtract(const Duration(hours: 3)), now: now), 'hace 3 h');
      expect(formatAgo(l, now.subtract(const Duration(days: 2)), now: now), 'hace 2 días');
    });

    test('distancia', () {
      final l = AppLocalizationsEs();
      expect(formatDistance(l, 350, 'es'), '350 m');
      expect(formatDistance(l, 2450, 'es'), '2,5 km');
    });

    test('color del precio', () {
      expect(priceColor(1.40, 1.40, 1.60), AppColors.cheap);
      expect(priceColor(1.50, 1.40, 1.60), AppColors.mid);
      expect(priceColor(1.60, 1.40, 1.60), AppColors.expensive);
      expect(priceColor(1.50, 1.50, 1.50), AppColors.cheap);
    });
  });

  group('formularios', () {
    test('importe', () {
      expect(parseAmount('2,5'), 2.5);
      expect(parseAmount(' 1.999 '), 2.0);
      expect(parseAmount('-1'), isNull);
      expect(parseAmount('1001'), isNull);
      expect(parseAmount('abc'), isNull);
    });

    test('email', () {
      expect(isValidEmail('nombre@ejemplo.com'), isTrue);
      expect(isValidEmail(' a@b.es '), isTrue);
      expect(isValidEmail('sin-arroba.com'), isFalse);
      expect(isValidEmail('a@b'), isFalse);
      expect(isValidEmail('a b@c.com'), isFalse);
    });

    test('uuid v4', () {
      final id = uuidV4(Random(1));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id),
        isTrue,
      );
      expect(uuidV4(), isNot(uuidV4()));
    });
  });

  group('fotos', () {
    test('reduce, convierte a JPEG y quita el EXIF (GPS)', () {
      final big = img.Image(width: 3000, height: 2000);
      big.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(28, 1);
      big.exif.imageIfd['Model'] = img.IfdValueAscii('Telefono');
      final jpeg = Uint8List.fromList(img.encodeJpg(big));
      expect(img.decodeJpgExif(jpeg)?.isEmpty, isFalse, reason: 'el original sí lleva EXIF');

      final out = preparePhotoSync(jpeg)!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, maxUploadSide);
      expect(decoded.height, 1067);
      final exif = img.decodeJpgExif(out);
      expect(exif == null || exif.isEmpty, isTrue, reason: 'la foto subida no debe llevar EXIF');
    });

    test('rechaza imágenes demasiado grandes sin decodificarlas', () {
      final huge = Uint8List.fromList(img.encodePng(img.Image(width: maxSourceSide + 1, height: 1)));
      expect(preparePhotoSync(huge), isNull);
    });

    test('rechaza lo que no es JPEG/PNG', () {
      expect(preparePhotoSync(Uint8List.fromList(img.encodeGif(img.Image(width: 10, height: 10)))), isNull);
      expect(preparePhotoSync(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });
}
