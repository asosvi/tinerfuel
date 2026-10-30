import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'format.dart';
import 'messages.dart';

typedef OnSelectPoint = void Function(Layer layer, String id, LatLng position);

/// Lista de lo más cercano al centro del mapa (o a mi ubicación):
/// gasolineras ordenadas por precio o cargadores por distancia.
Future<void> showNearbySheet(BuildContext context, LatLng center, {required OnSelectPoint onSelect}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) => _NearbyList(center: center, scroll: scroll, onSelect: onSelect),
    ),
  );
}

class _NearbyList extends ConsumerStatefulWidget {
  const _NearbyList({required this.center, required this.scroll, required this.onSelect});

  final LatLng center;
  final ScrollController scroll;
  final OnSelectPoint onSelect;

  @override
  ConsumerState<_NearbyList> createState() => _NearbyListState();
}

class _NearbyListState extends ConsumerState<_NearbyList> {
  late Future<List<Object>> _future;
  bool _byDistance = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ref.read(repositoryProvider)!;
    final layer = ref.read(layerProvider);
    _future = layer == Layer.fuel
        ? repo.fuelNear(widget.center, ref.read(fuelProvider), orderBy: _byDistance ? 'distance' : 'price')
        : repo.chargersNear(widget.center, ref.read(minKwProvider));
  }

  void _select(Layer layer, String id, LatLng position) {
    Navigator.of(context).pop();
    widget.onSelect(layer, id, position);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final layer = ref.watch(layerProvider);

    return FutureBuilder<List<Object>>(
      future: _future,
      builder: (context, snap) {
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  layer == Layer.fuel
                      ? '${l.cheapestNearby} · ${fuelName(l, ref.watch(fuelProvider))}'
                      : l.chargersNearby,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (layer == Layer.fuel)
                IconButton(
                  tooltip: _byDistance ? l.prices : l.myLocation,
                  icon: Icon(_byDistance ? Icons.euro : Icons.near_me),
                  onPressed: () => setState(() {
                    _byDistance = !_byDistance;
                    _load();
                  }),
                ),
            ],
          ),
        );
        if (snap.hasError) {
          return ListView(
            controller: widget.scroll,
            children: [
              header,
              Padding(padding: const EdgeInsets.all(20), child: Text(errorText(l, snap.error!))),
            ],
          );
        }
        if (!snap.hasData) {
          return ListView(
            controller: widget.scroll,
            children: [header, const Center(child: CircularProgressIndicator())],
          );
        }
        final items = snap.data!;
        return ListView(
          controller: widget.scroll,
          children: [
            header,
            if (items.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(l.noResultsNearby)),
            for (final (i, item) in items.indexed)
              switch (item) {
                NearbyFuel f => ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(f.brand ?? l.layerFuel),
                  subtitle: Text(
                    [
                      if (f.distanceM != null) formatDistance(l, f.distanceM!, locale),
                      ?f.municipality,
                      if (f.priceUpdated != null) formatAgo(l, f.priceUpdated!),
                    ].join(' · '),
                  ),
                  trailing: Text(
                    formatFuelPrice(f.price, locale),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  onTap: () => _select(Layer.fuel, '${f.id}', f.position),
                ),
                Charger c => ListTile(
                  leading: const Icon(Icons.ev_station),
                  title: Text(c.name ?? c.operator ?? l.layerCharger),
                  subtitle: Text(
                    [
                      if (c.distanceM != null) formatDistance(l, c.distanceM!, locale),
                      ?c.operator,
                    ].join(' · '),
                  ),
                  trailing: c.maxPowerKw == null
                      ? null
                      : Text(formatKw(c.maxPowerKw!, locale), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: c.position == null ? null : () => _select(Layer.charger, c.id, c.position!),
                ),
                _ => const SizedBox.shrink(),
              },
          ],
        );
      },
    );
  }
}
