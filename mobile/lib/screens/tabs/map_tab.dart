// NDVI картасы — сайттағы Leaflet картасының мобильді нұсқасы (flutter_map).
// Қазақстан шекарасымен шектелген (сырты күңгірт), облыс таңдау, 3 маусым, спутник/карта фоны, NDVI мөлдірлігі.
// Дереккөз серверден келеді: NASA GIBS MODIS (кілтсіз) немесе Copernicus Sentinel-2 (сервердегі Instance ID).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../api/api.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/format.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  static final kzBounds = LatLngBounds(const LatLng(40.5, 46.5), const LatLng(55.5, 87.3));
  final _map = MapController();
  int _season = 0;
  bool _satellite = true;
  double _opacity = 0.8;
  String _region = 'kz';
  List<List<LatLng>> _border = [];
  String? _tapInfo;

  Json get _ndvi => (AppState.i.data['ndvi'] as Json?) ?? const {};
  List<Json> get _seasons => ((_ndvi['seasons'] as List?) ?? const []).cast<Json>();
  List<Json> get _regions => ((_ndvi['regions'] as List?) ?? const []).cast<Json>();
  bool get _sentinel => _ndvi['provider'] == 'sentinel';

  @override
  void initState() {
    super.initState();
    _region = _ndvi['region'] as String? ?? 'kz';
    _loadBorder();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _loadBorder() async {
    try {
      final gj = await Api.instance.kazakhstanBorder();
      final geom = ((gj['features'] as List).first as Json)['geometry'] as Json;
      final polys = geom['type'] == 'Polygon' ? [geom['coordinates'] as List] : (geom['coordinates'] as List).cast<List>();
      final rings = [
        for (final poly in polys)
          [for (final c in (poly.first as List)) LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble())],
      ];
      if (mounted) setState(() => _border = rings);
    } catch (_) {
      // шекара жүктелмесе де карта жұмыс істейді
    }
  }

  void _goRegion(String key) {
    setState(() => _region = key);
    if (key == 'kz') {
      _map.fitCamera(CameraFit.bounds(bounds: kzBounds, padding: const EdgeInsets.all(12)));
      return;
    }
    final r = _regions.firstWhere((r) => r['key'] == key, orElse: () => const {});
    final c = r['center'] as List?;
    if (c != null) _map.move(LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()), 7);
  }

  void _onTap(LatLng p) {
    Json? best;
    var bestKm = double.infinity;
    for (final r in _regions) {
      final c = r['center'] as List;
      final km = _km(p, LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()));
      if (km < bestKm) {
        bestKm = km;
        best = r;
      }
    }
    setState(() => _tapInfo =
        '${p.latitude.toStringAsFixed(4)}°, ${p.longitude.toStringAsFixed(4)}° · жақын орталық: ${best?['name'] ?? '—'} (${fmtInt(bestKm)} км)');
  }

  double _km(LatLng a, LatLng b) {
    const r = math.pi / 180;
    final d = math.pow(math.sin((b.latitude - a.latitude) * r / 2), 2) +
        math.cos(a.latitude * r) * math.cos(b.latitude * r) * math.pow(math.sin((b.longitude - a.longitude) * r / 2), 2);
    return 12742 * math.asin(math.sqrt(d));
  }

  Widget _ndviLayer(Json season) {
    final bounds = kzBounds;
    final layer = _sentinel
        ? TileLayer(
            key: ValueKey('s2-${season['key']}'),
            wmsOptions: WMSTileLayerOptions(
              baseUrl: 'https://sh.dataspace.copernicus.eu/ogc/wms/${_ndvi['instance']}?',
              layers: [_ndvi['layer'] as String? ?? 'NDVI'],
              otherParameters: {'time': '${season['from']}/${season['to']}', 'maxcc': '20'},
            ),
            tileBounds: bounds,
            userAgentPackageName: 'kz.dalacarbon.dalacarbon_mobile',
          )
        : TileLayer(
            key: ValueKey('modis-${season['key']}'),
            urlTemplate:
                'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_L3_NDVI_16Day/default/{time}/GoogleMapsCompatible_Level9/{z}/{y}/{x}.png',
            additionalOptions: {'time': season['date'] as String},
            maxNativeZoom: 9,
            tileBounds: bounds,
            userAgentPackageName: 'kz.dalacarbon.dalacarbon_mobile',
          );
    return Opacity(opacity: _opacity, child: layer);
  }

  @override
  Widget build(BuildContext context) {
    if (_seasons.isEmpty) return const Center(child: Text('NDVI баптаулары жүктелмеді'));
    final season = _seasons[_season.clamp(0, _seasons.length - 1)];
    final home = _regions.firstWhere((r) => r['key'] == _ndvi['region'], orElse: () => const {});
    final homeC = home['center'] as List?;
    final world = [const LatLng(85, -179), const LatLng(85, 179), const LatLng(-85, 179), const LatLng(-85, -179)];

    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: homeC != null ? LatLng((homeC[0] as num).toDouble(), (homeC[1] as num).toDouble()) : const LatLng(48.02, 66.92),
          initialZoom: homeC != null ? 6.5 : 4.5,
          minZoom: 4,
          maxZoom: 16,
          backgroundColor: const Color(0xFFB9A99A),
          cameraConstraint: CameraConstraint.containCenter(bounds: kzBounds), // шекарадан сыртқа шығармайды
          onTap: (_, p) => _onTap(p),
        ),
        children: [
          TileLayer(
            key: ValueKey(_satellite),
            urlTemplate: _satellite
                ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            maxNativeZoom: 18,
            userAgentPackageName: 'kz.dalacarbon.dalacarbon_mobile',
          ),
          _ndviLayer(season),
          if (_border.isNotEmpty) ...[
            PolygonLayer(polygons: [
              Polygon(points: world, holePointsList: _border, color: Dc.ink.withValues(alpha: 0.55), borderStrokeWidth: 0),
            ]),
            PolygonLayer(polygons: [
              for (final ring in _border) Polygon(points: ring, borderColor: Dc.cream, borderStrokeWidth: 2),
            ]),
          ],
          if (homeC != null)
            MarkerLayer(markers: [
              Marker(
                point: LatLng((homeC[0] as num).toDouble(), (homeC[1] as num).toDouble()),
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(color: Dc.gold, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                ),
              ),
            ]),
          SimpleAttributionWidget(
            source: Text(_sentinel ? 'Copernicus Sentinel-2 · ${_satellite ? 'Esri' : 'OpenStreetMap'}'
                : 'NASA GIBS MODIS · ${_satellite ? 'Esri, Maxar' : 'OpenStreetMap'}'),
          ),
        ],
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _glass(Row(children: [
              const Icon(Icons.place_outlined, size: 18, color: Dc.green),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _region,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: 'kz', child: Text('Бүкіл Қазақстан')),
                      for (final r in _regions) DropdownMenuItem(value: r['key'] as String, child: Text(r['name'] as String)),
                    ],
                    onChanged: (v) => _goRegion(v ?? 'kz'),
                  ),
                ),
              ),
              IconButton(
                tooltip: _satellite ? 'Карта фоны' : 'Спутник фоны',
                icon: Icon(_satellite ? Icons.map_outlined : Icons.satellite_alt, color: Dc.green),
                onPressed: () => setState(() => _satellite = !_satellite),
              ),
            ])),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < _seasons.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_seasons[i]['label'] as String),
                      selected: _season == i,
                      selectedColor: Dc.ink,
                      labelStyle: TextStyle(color: _season == i ? Dc.cream : Dc.ink, fontWeight: FontWeight.w700),
                      backgroundColor: Colors.white,
                      onSelected: (_) => setState(() => _season = i),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (season['winter'] == true)
            _glass(const Text('Қыс айларында жерді қар басады — NDVI төмен көрінеді. Жаз маусымын таңдаңыз.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF2F4A91)))),
          if (_tapInfo != null) ...[
            const SizedBox(height: 8),
            _glass(Text(_tapInfo!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
          ],
          const SizedBox(height: 8),
          _glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('NDVI', style: TextStyle(fontWeight: FontWeight.w800)),
              Expanded(
                child: Slider(
                  value: _opacity,
                  activeColor: Dc.gold,
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
              Text('${(_opacity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(colors: [
                  Color(0xFFC8B89A), Color(0xFFE8D998), Color(0xFFC4D66D), Color(0xFF8FBF48), Color(0xFF4F9A2A), Color(0xFF0B4A0B),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Text('0 · жалаңаш жер', style: TextStyle(fontSize: 11, color: Dc.muted)),
              const Spacer(),
              Text(_sentinel ? 'Sentinel-2 · 10 м' : 'MODIS · 250 м', style: const TextStyle(fontSize: 11, color: Dc.muted)),
              const Spacer(),
              const Text('0,9 · қалың', style: TextStyle(fontSize: 11, color: Dc.muted)),
            ]),
          ])),
        ]),
      ),
    ]);
  }

  Widget _glass(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: child,
      );
}
