import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../community/parking_community.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'format.dart';
import 'messages.dart';

/// Abre la ficha de un punto del mapa en una hoja que se arrastra desde abajo.
Future<void> showPointDetails(BuildContext context, Layer layer, String id, LatLng position) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scroll) => switch (layer) {
        Layer.fuel => _FuelDetails(id: int.parse(id), position: position, scroll: scroll),
        Layer.charger => _ChargerDetails(id: id, position: position, scroll: scroll),
        Layer.parking => _ParkingDetails(id: id, position: position, scroll: scroll),
      },
    ),
  );
}

Future<void> openDirections(BuildContext context, LatLng p) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}',
  );
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    showMessage(context, AppLocalizations.of(context).somethingWrong(uri.host), error: true);
  }
}

/// Carga, error o contenido.
class _AsyncBody<T> extends StatelessWidget {
  const _AsyncBody({required this.value, required this.builder, required this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (value) {
      AsyncData(:final value) => builder(value),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(errorText(l, error), textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: Text(l.retry)),
          ],
        ),
      ),
      _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
    };
  }
}

class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.title, this.subtitle, required this.position});

  final String title;
  final String? subtitle;
  final LatLng position;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => openDirections(context, position),
          icon: const Icon(Icons.directions),
          label: Text(l.directions),
        ),
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: SelectableText(value),
    );
  }
}

String? _join(List<String?> parts) {
  final s = parts.where((p) => p != null && p.isNotEmpty).join(', ');
  return s.isEmpty ? null : s;
}

// ------------------------------------------------------------------ gasolinera

class _FuelDetails extends ConsumerWidget {
  const _FuelDetails({required this.id, required this.position, required this.scroll});

  final int id;
  final LatLng position;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final selected = ref.watch(fuelProvider);
    return _AsyncBody(
      value: ref.watch(fuelStationProvider(id)),
      onRetry: () => ref.invalidate(fuelStationProvider(id)),
      builder: (s) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          DetailHeader(
            title: s.brand ?? l.layerFuel,
            subtitle: _join([s.address, s.municipality]),
            position: position,
          ),
          if (s.restricted) ...[
            const SizedBox(height: 12),
            Text(l.restrictedSale, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Text(l.prices, style: Theme.of(context).textTheme.titleMedium),
          if (s.pricesUpdated != null)
            Text(
              l.updatedAgo(formatAgo(l, s.pricesUpdated!)),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          const SizedBox(height: 4),
          if (s.sortedPrices.isEmpty) Text(l.noPrice),
          for (final e in s.sortedPrices)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              selected: e.key == selected,
              title: Text(fuelName(l, e.key)),
              trailing: Text(
                formatFuelPrice(e.value, locale),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          if (s.openingHours != null)
            InfoRow(icon: Icons.schedule, label: l.openingHours, value: s.openingHours!),
          if (_join([s.address, s.postcode, s.municipality, s.province]) case final a?)
            InfoRow(icon: Icons.place_outlined, label: l.address, value: a),
          const SizedBox(height: 8),
          Text(l.dataSources, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ cargador

class _ChargerDetails extends ConsumerWidget {
  const _ChargerDetails({required this.id, required this.position, required this.scroll});

  final String id;
  final LatLng position;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _AsyncBody(
      value: ref.watch(chargerProvider(id)),
      onRetry: () => ref.invalidate(chargerProvider(id)),
      builder: (c) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          DetailHeader(
            title: c.name ?? c.operator ?? l.layerCharger,
            subtitle: _join([
              if (c.maxPowerKw != null) formatKw(c.maxPowerKw!, locale),
              if (c.points > 0) l.chargePoints(c.points),
            ]),
            position: position,
          ),
          const SizedBox(height: 16),
          Text(l.connectors, style: Theme.of(context).textTheme.titleMedium),
          for (final k in c.connectors)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(k.isDc ? Icons.flash_on : Icons.power),
              title: Text('${k.count} × ${k.displayName}'),
              trailing: k.powerKw == null
                  ? null
                  : Text(formatKw(k.powerKw!, locale), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 4),
          Text(l.noChargerStatus, style: Theme.of(context).textTheme.bodySmall),
          if (c.operator != null) InfoRow(icon: Icons.business, label: l.operator, value: c.operator!),
          if (c.openingHours != null)
            InfoRow(icon: Icons.schedule, label: l.openingHours, value: c.openingHours!),
          if (_join([c.address, c.municipality, c.province]) case final a?)
            InfoRow(icon: Icons.place_outlined, label: l.address, value: a),
          const SizedBox(height: 8),
          Text(l.dataSources, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ parking

class _ParkingDetails extends ConsumerWidget {
  const _ParkingDetails({required this.id, required this.position, required this.scroll});

  final String id;
  final LatLng position;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _AsyncBody(
      value: ref.watch(parkingProvider(id)),
      onRetry: () => ref.invalidate(parkingProvider(id)),
      builder: (p) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          DetailHeader(
            title: p.name ?? l.unnamedParking,
            subtitle: _join([
              switch (p.kind) {
                'underground' => l.kindUnderground,
                'multi-storey' => l.kindMultiStorey,
                'surface' => l.kindSurface,
                _ => null,
              },
              switch (p.fee) {
                true => l.paid,
                false => l.free,
                null => null,
              },
              if (p.capacity != null) l.capacity(p.capacity!),
              p.operator,
            ]),
            position: position,
          ),
          const SizedBox(height: 8),
          ParkingCommunitySection(parkingId: id),
          const SizedBox(height: 8),
          Text(l.dataSources, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
