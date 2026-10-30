import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'account_page.dart';
import 'details.dart';
import 'format.dart';
import 'messages.dart';
import 'nearby_sheet.dart';
import 'theme.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _map = MapController();
  Timer? _debounce;
  LatLng? _me;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Avisa de la zona visible 350 ms después de dejar de mover el mapa.
  void _onCameraChanged(MapCamera camera) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(mapViewProvider.notifier).set(MapView(camera.visibleBounds, camera.zoom));
    });
  }

  Future<void> _goToMe() async {
    final l = AppLocalizations.of(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) showMessage(context, l.locationOff, error: true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) showMessage(context, l.locationDenied, error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 15)),
      );
      setState(() => _me = LatLng(pos.latitude, pos.longitude));
      _map.move(_me!, 14);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _openPoint(MapPoint p) {
    if (p.isGroup) {
      _map.move(p.position, math.min(_map.camera.zoom + 2.5, 18));
      return;
    }
    if (p.id == null) return;
    showPointDetails(context, ref.read(layerProvider), p.id!, p.position);
  }

  void _openNearby() {
    final center = _me ?? _map.camera.center;
    showNearbySheet(context, center, onSelect: (layer, id, position) {
      _map.move(position, math.max(_map.camera.zoom, 15));
      showPointDetails(context, layer, id, position);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final layer = ref.watch(layerProvider);
    final points = ref.watch(mapPointsProvider);
    final pointList = points.value ?? const <MapPoint>[];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: spainCenter,
              initialZoom: spainZoom,
              minZoom: 4,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () => _onCameraChanged(_map.camera),
              onPositionChanged: (camera, _) => _onCameraChanged(camera),
            ),
            children: [
              TileLayer(urlTemplate: tileUrl, userAgentPackageName: tileUserAgent),
              MarkerLayer(markers: _markers(layer, pointList)),
              if (_me != null)
                MarkerLayer(
                  markers: [Marker(point: _me!, width: 22, height: 22, child: const _MeDot())],
                ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TopBar(),
                  const SizedBox(height: 8),
                  if (!hasBackend)
                    _Banner(text: l.noBackend)
                  else if (points.hasError)
                    _Banner(
                      text: l.loadError,
                      action: TextButton(
                        onPressed: () => ref.invalidate(mapPointsProvider),
                        child: Text(l.retry),
                      ),
                    ),
                  if (points.isLoading) const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'me',
            tooltip: l.myLocation,
            onPressed: _goToMe,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          if (layer != Layer.parking && hasBackend)
            FloatingActionButton.extended(
              heroTag: 'list',
              onPressed: _openNearby,
              icon: const Icon(Icons.list),
              label: Text(layer == Layer.fuel ? l.cheapestNearby : l.chargersNearby),
            ),
        ],
      ),
    );
  }

  List<Marker> _markers(Layer layer, List<MapPoint> points) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final prices = [for (final p in points) if (!p.isGroup && p.price != null) p.price!];
    final minP = prices.isEmpty ? 0.0 : prices.reduce(math.min);
    final maxP = prices.isEmpty ? 0.0 : prices.reduce(math.max);

    return [
      for (final p in points)
        if (p.isGroup)
          Marker(
            point: p.position,
            width: 44,
            height: 44,
            child: _GroupBubble(count: p.count, onTap: () => _openPoint(p)),
          )
        else
          switch (layer) {
            Layer.fuel => Marker(
              point: p.position,
              width: 64,
              height: 28,
              child: _PricePill(
                text: p.price == null ? '—' : formatShortPrice(p.price!, locale),
                color: p.price == null ? AppColors.parking : priceColor(p.price!, minP, maxP),
                onTap: () => _openPoint(p),
              ),
            ),
            Layer.charger => Marker(
              point: p.position,
              width: 30,
              height: 30,
              child: _IconPin(
                icon: Icons.bolt,
                color: (p.powerKw ?? 0) >= 50 ? AppColors.charger : AppColors.charger.withValues(alpha: 0.65),
                onTap: () => _openPoint(p),
              ),
            ),
            Layer.parking => Marker(
              point: p.position,
              width: 28,
              height: 28,
              child: _IconPin(icon: Icons.local_parking, color: AppColors.parking, onTap: () => _openPoint(p)),
            ),
          },
    ];
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final layer = ref.watch(layerProvider);
    final scheme = Theme.of(context).colorScheme;
    // En pantallas estrechas solo iconos (los textos se cortaban).
    final compact = MediaQuery.sizeOf(context).width < 440;
    Widget? label(String text) => compact ? null : Text(text, overflow: TextOverflow.ellipsis);

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<Layer>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: Layer.fuel,
                        icon: const Icon(Icons.local_gas_station),
                        label: label(l.layerFuel),
                        tooltip: l.layerFuel,
                      ),
                      ButtonSegment(
                        value: Layer.charger,
                        icon: const Icon(Icons.ev_station),
                        label: label(l.layerCharger),
                        tooltip: l.layerCharger,
                      ),
                      ButtonSegment(
                        value: Layer.parking,
                        icon: const Icon(Icons.local_parking),
                        label: label(l.layerParking),
                        tooltip: l.layerParking,
                      ),
                    ],
                    selected: {layer},
                    onSelectionChanged: (s) => ref.read(layerProvider.notifier).set(s.first),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: l.account,
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AccountPage()),
                  ),
                ),
              ],
            ),
            if (layer != Layer.parking) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: layer == Layer.fuel ? const _FuelChips() : const _PowerChips(),
              ),
            ],
            const _Freshness(),
          ],
        ),
      ),
    );
  }
}

class _FuelChips extends ConsumerWidget {
  const _FuelChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fuel = ref.watch(fuelProvider);
    return Row(
      children: [
        for (final key in fuelKeys)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(fuelName(l, key)),
              selected: key == fuel,
              onSelected: (_) => ref.read(fuelProvider.notifier).set(key),
            ),
          ),
      ],
    );
  }
}

class _PowerChips extends ConsumerWidget {
  const _PowerChips();

  static const options = [0.0, 22.0, 50.0, 100.0, 150.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final minKw = ref.watch(minKwProvider);
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(l.minPower, style: Theme.of(context).textTheme.labelMedium),
        ),
        for (final kw in options)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(kw == 0 ? l.anyPower : '≥ ${formatKw(kw, locale)}'),
              selected: kw == minKw,
              onSelected: (_) => ref.read(minKwProvider.notifier).set(kw),
            ),
          ),
      ],
    );
  }
}

/// "Actualizado hace 20 min" de la fuente de la capa elegida.
class _Freshness extends ConsumerWidget {
  const _Freshness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final source = switch (ref.watch(layerProvider)) {
      Layer.fuel => 'miteco',
      Layer.charger => 'dgt',
      Layer.parking => 'osm',
    };
    final when = ref.watch(freshnessProvider).value?[source];
    if (when == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        l.updatedAgo(formatAgo(l, when)),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(text, style: TextStyle(color: scheme.onErrorContainer))),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.text, required this.color, required this.onTap});

  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26, offset: Offset(0, 1))],
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _IconPin extends StatelessWidget {
  const _IconPin({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26, offset: Offset(0, 1))],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  const _GroupBubble({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.groupCount(count),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.group.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            count > 999 ? '${(count / 1000).toStringAsFixed(count > 9999 ? 0 : 1)}k' : '$count',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
      ),
    );
  }
}
