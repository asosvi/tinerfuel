import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Precio de combustible con 3 decimales: "1,459 €" (es) / "€1.459" (en).
String formatFuelPrice(double price, String locale) =>
    NumberFormat.currency(locale: locale, symbol: '€', decimalDigits: 3).format(price);

/// Precio corto para los marcadores del mapa: "1,459" / "1.459".
String formatShortPrice(double price, String locale) =>
    NumberFormat('0.000', locale).format(price);

/// Importe con 2 decimales: "2,50 €".
String formatMoney(double amount, String locale) =>
    NumberFormat.currency(locale: locale, symbol: '€', decimalDigits: 2).format(amount);

String formatDistance(AppLocalizations l, double meters, String locale) => meters < 1000
    ? l.meters(meters.round())
    : l.km(NumberFormat('0.0', locale).format(meters / 1000));

String formatAgo(AppLocalizations l, DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inHours < 1) return l.agoMinutes(diff.inMinutes);
  if (diff.inDays < 1) return l.agoHours(diff.inHours);
  return l.agoDays(diff.inDays);
}

String formatKw(double kw, String locale) => '${NumberFormat('0.#', locale).format(kw)} kW';
