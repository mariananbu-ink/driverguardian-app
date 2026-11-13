import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';
import 'choose_stop.dart';

const kTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const kUserAgent = 'in.marianstudio.driverguardian';
const _distance = Distance();

/// Live bus map (OpenStreetMap — no paid key). Polls the server.
/// Parents see a circle around their stop (the school's alert radius, e.g. 200 m),
/// how far the bus is and when it is inside the circle.
/// Developed & Powered by Marian Anbu Juwan
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  List<Map> routes = [];
  int? selected;
  String? error;
  bool loading = true;
  Timer? timer;
  final map = MapController();
  final trail = <int, List<LatLng>>{};
  bool followed = false;
  final insideBefore = <int, bool>{};

  bool _busy = false;
  bool _paused = false;
  int _wait = 8;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _wait = (Api.I.user?['map_poll'] as int?) ?? 8;
    // 2.11.1: one request at a time, the server says when to ask again (fast while the bus moves,
    // slow when idle) and nothing is fetched while the app is in the background.
    _life = AppLifecycleListener(
      onHide: () => _paused = true,
      onShow: () { _paused = false; _schedule(0); },
    );
    _load();
  }

  @override
  void dispose() {
    timer?.cancel();
    _life.dispose();
    super.dispose();
  }

  void _schedule(int secs) {
    timer?.cancel();
    if (!mounted || _paused) return;
    timer = Timer(Duration(seconds: secs), _load);
  }

  Future<void> _load() async {
    if (_busy || _paused) return;
    _busy = true;
    try {
      final d = await Api.I.get('/tracking/routes');
      final next = (d['next'] as num?)?.toInt();
      if (next != null && next > 0) _wait = next.clamp(4, 120);
      final list = (d['routes'] as List).cast<Map>();
      for (final r in list) {
        final b = r['bus'] as Map?;
        if (b != null && b['live'] == true) {
          final p = LatLng((b['lat'] as num).toDouble(), (b['lng'] as num).toDouble());
          final t = trail.putIfAbsent(r['id'] as int, () => []);
          if (t.isEmpty || t.last != p) t.add(p);
        }
      }
      if (!mounted) return;
      setState(() {
        routes = list;
        error = null;
        loading = false;
        selected ??= list.isNotEmpty ? list.first['id'] as int : null;
      });
      _follow();
      _announce();
    } catch (e) {
      _wait = (_wait * 2).clamp(8, 60);   // offline or server busy → back off
      if (mounted) setState(() { error = errText(e); loading = false; });
    } finally {
      _busy = false;
      _schedule(_wait);
    }
  }

  Map? get route => routes.where((r) => r['id'] == selected).firstOrNull;

  void _follow() {
    final b = route?['bus'] as Map?;
    if (b != null && b['live'] == true && !followed) {
      followed = true;
      try { map.move(LatLng((b['lat'] as num).toDouble(), (b['lng'] as num).toDouble()), 15); } catch (_) {}
    }
  }

  /// Shows a pop-up the moment the bus enters the circle while the map is open
  /// (the push notification comes from the server).
  void _announce() {
    for (final r in routes) {
      final n = _near(r);
      if (n == null) continue;
      final id = r['id'] as int;
      final was = insideBefore[id] ?? true; // no pop-up for a bus already inside when the map opens
      insideBefore[id] = n.inside;
      if (n.inside && !was && mounted) toast(context, '🟢 ${r['name']}: bus is within ${_fmt(n.radius.toDouble())} of ${n.stopName}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null && routes.isEmpty) return EmptyState(Icons.cloud_off, error!);
    if (routes.isEmpty) {
      return EmptyState(Icons.map_outlined, Api.I.role == 'parent' ? 'Your child is not on a tracked bus route yet.' : 'No routes with live tracking yet.');
    }
    final r = route!;
    final color = hexColor(r['color'] as String?);
    final stops = (r['stops'] as List).cast<Map>().where((s) => s['lat'] != null).toList();
    final pts = [for (final s in stops) LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble())];
    final b = r['bus'] as Map?;
    final busPt = b != null ? LatLng((b['lat'] as num).toDouble(), (b['lng'] as num).toDouble()) : null;
    final start = r['start'] is List ? LatLng(((r['start'] as List)[0] as num).toDouble(), ((r['start'] as List)[1] as num).toDouble()) : null;
    final center = busPt ?? (pts.isNotEmpty ? pts.first : start) ?? LatLng(12.9716, 77.5946);
    final near = _near(r) ?? _nextStop(r);
    final radius = (r['alert_radius'] as num?)?.toDouble() ?? 0;
    final mine = _myStops(r);

    final noStop = Api.I.role == 'parent' ? routes.expand((x) => ((x['no_stop'] as List?) ?? const []).map((e) => '$e')).toSet().toList() : const <String>[];
    return Column(children: [
      // 2.12: child without a stop → choose it (distance / arrival need a stop)
      if (noStop.isNotEmpty)
        Material(
          color: const Color(0xFFFFF7E0),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.add_location_alt_outlined, color: Color(0xFFB45309)),
            title: Text('${noStop.join(' & ')} ${noStop.length == 1 ? 'has' : 'have'} no bus stop yet'),
            subtitle: const Text('Choose it to see distance and arrival time'),
            trailing: FilledButton(
              onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChooseStopScreen())); _load(); },
              child: const Text('Choose'),
            ),
          ),
        ),
      if (routes.length > 1)
        SizedBox(
          height: 54,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: [
            for (final x in routes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(x['name'] as String),
                  avatar: CircleAvatar(radius: 6, backgroundColor: (x['bus'] as Map?)?['live'] == true ? Colors.green : Colors.grey),
                  selected: x['id'] == selected,
                  onSelected: (_) => setState(() { selected = x['id'] as int; followed = false; _follow(); }),
                ),
              ),
          ]),
        ),
      Expanded(
        child: Stack(children: [
          FlutterMap(
            key: ValueKey(selected),
            mapController: map,
            options: MapOptions(initialCenter: center, initialZoom: busPt != null ? 15 : 13),
            children: [
              TileLayer(urlTemplate: kTiles, userAgentPackageName: kUserAgent),
              if (radius > 0 && mine.isNotEmpty)
                CircleLayer(circles: [
                  for (final s in mine)
                    CircleMarker(
                      point: s.point,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: const Color(0xFF22C55E).withValues(alpha: near != null && near.inside && near.stopId == s.id ? .30 : .12),
                      borderColor: const Color(0xFF16A34A),
                      borderStrokeWidth: near != null && near.inside && near.stopId == s.id ? 3 : 2,
                    ),
                ]),
              if (pts.length > 1) PolylineLayer(polylines: [Polyline(points: pts, color: color.withValues(alpha: .55), strokeWidth: 4)]),
              if ((trail[selected] ?? []).length > 1) PolylineLayer(polylines: [Polyline(points: trail[selected]!, color: color, strokeWidth: 5)]),
              MarkerLayer(markers: [
                for (final s in stops)
                  Marker(
                    point: LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()),
                    width: 26, height: 26,
                    child: Tooltip(
                      message: '${s['name']}  ↑${s['pickup'] ?? '—'} ↓${s['drop'] ?? '—'}',
                      child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                          child: Text('${s['seq']}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
                    ),
                  ),
                for (final s in mine)
                  Marker(
                    point: s.point, width: 34, height: 34, alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: 'Your stop: ${s.name}',
                      child: Container(
                        decoration: BoxDecoration(color: const Color(0xFF16A34A), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)]),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                if (busPt != null)
                  Marker(
                    point: busPt, width: 96, height: 104, alignment: Alignment.center,
                    child: _BusMarker(
                      live: b?['live'] == true,
                      color: color,
                      label: (b?['reg'] ?? r['vehicle'] ?? 'Bus').toString(),
                      overspeed: b?['live'] == true && b?['overspeed'] == true,
                      onTap: () => _busSheet(r, near),
                    ),
                  ),
              ]),
              SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
            ],
          ),
          // keep the card above the phone's navigation bar / gesture area (edge-to-edge Android 15+)
          Positioned(
            left: 10, right: 10, bottom: 10 + MediaQuery.viewPaddingOf(context).bottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .48),
              child: SingleChildScrollView(child: _InfoPanel(route: r, near: near, nearestStop: _nearestStop(r))),
            ),
          ),
          Positioned(
            right: 12, top: 12,
            child: Column(children: [
              if (busPt != null) FloatingActionButton.small(heroTag: 'center', tooltip: 'Bus', onPressed: () => map.move(busPt, 16), child: const Icon(Icons.directions_bus)),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 8),
                FloatingActionButton.small(heroTag: 'home', tooltip: 'My stop', backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
                    onPressed: () => map.move(mine.first.point, 16), child: const Icon(Icons.home_rounded)),
              ],
            ]),
          ),
        ]),
      ),
    ]);
  }

  /// Tap on the bus: everything about it in one sheet.
  void _busSheet(Map r, _Near? n) {
    final b = (r['bus'] as Map?) ?? const {};
    final live = b['live'] == true;
    final speed = (b['speed'] as num?)?.round();
    final color = hexColor(r['color'] as String?);
    final nearest = _nearestStop(r);
    final rows = <List<Object>>[
      [Icons.route, 'Route', '${r['name']}'],
      [Icons.directions_bus_rounded, 'Bus', '${b['reg'] ?? r['vehicle'] ?? '—'}'],
      [Icons.badge_outlined, 'Driver', '${r['driver'] ?? 'Not assigned'}${r['substitute'] == true ? ' (substitute)' : ''}'],
      [Icons.flag_outlined, 'Trip', live ? (b['trip_type'] == 'drop' ? 'Drop · in progress' : 'Pickup · in progress') : 'Not on a trip'],
      [Icons.speed, 'Speed', live && speed != null ? '$speed km/h${b['overspeed'] == true ? '  ⚠ over ${b['limit'] ?? ''} km/h' : ''}' : '—'],
      if (nearest != null) [Icons.place_outlined, 'Near', nearest],
      if (n != null && n.meters != null) [Icons.home_outlined, 'Your stop', '${n.stopName} · ${_fmt(n.meters!)}${n.etaAt != null ? ' · ~${n.etaAt}' : ''}'],
      [Icons.groups_outlined, 'Students', '${r['students'] ?? 0} on this route'],
      [Icons.update, 'Updated', '${b['ago'] ?? '—'}'],
    ];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Image.asset('assets/icon/marker.png', width: 54, height: 54),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b['reg'] ?? r['vehicle'] ?? 'Bus'}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                Text('${r['name']}', style: const TextStyle(color: kMuted, fontSize: 12.5), overflow: TextOverflow.ellipsis),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: (live ? Colors.green : Colors.grey).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                child: Text(live ? 'LIVE' : 'IDLE', style: TextStyle(color: live ? Colors.green.shade700 : Colors.grey.shade700, fontWeight: FontWeight.w800, fontSize: 11.5)),
              ),
            ]),
            const SizedBox(height: 10),
            for (final x in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(x[0] as IconData, size: 18, color: color),
                  const SizedBox(width: 10),
                  SizedBox(width: 78, child: Text(x[1] as String, style: const TextStyle(color: kMuted, fontSize: 13))),
                  Expanded(child: Text(x[2] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                ]),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(ctx); if (b['lat'] != null) map.move(LatLng((b['lat'] as num).toDouble(), (b['lng'] as num).toDouble()), 17); },
                icon: const Icon(Icons.center_focus_strong), label: const Text('Centre'),
              )),
              if (r['driver_phone'] != null && Api.I.role != 'driver') ...[
                const SizedBox(width: 10),
                Expanded(child: FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${r['driver_phone']}')),
                  icon: const Icon(Icons.call), label: const Text('Call driver'),
                )),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  /* ------------------------------------------------------------ helpers */

  List<_Stop> _myStops(Map r) {
    final stops = (r['stops'] as List).cast<Map>();
    final out = <_Stop>[];
    for (final m in ((r['my_stops'] as List?) ?? const []).cast<Map>()) {
      final s = stops.where((x) => x['id'] == m['stop_id'] && x['lat'] != null).firstOrNull;
      if (s == null) continue;
      out.add(_Stop(s['id'] as int, s['name'] as String, LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()),
          ((m['children'] as List?) ?? const []).join(' & ')));
    }
    return out;
  }

  /// Distance from the bus to the parent's nearest stop (null for staff or when unknown).
  _Near? _near(Map r) {
    final mine = _myStops(r);
    if (mine.isEmpty) return null;
    final b = r['bus'] as Map?;
    final radius = (r['alert_radius'] as num?)?.toInt() ?? 0;
    final alerted = r['alerted'] is Map ? (r['alerted'] as Map) : const {};
    if (b == null) return _Near(mine.first.id, mine.first.name, mine.first.children, null, radius, false, false, alerted['${mine.first.id}']?.toString());
    final bp = LatLng((b['lat'] as num).toDouble(), (b['lng'] as num).toDouble());
    _Stop best = mine.first;
    double bestD = double.infinity;
    for (final s in mine) {
      final d = _distance.as(LengthUnit.Meter, bp, s.point);
      if (d < bestD) { bestD = d; best = s; }
    }
    final live = b['live'] == true;
    final n = _Near(best.id, best.name, best.children, bestD, radius, live, live && radius > 0 && bestD <= radius, alerted['${best.id}']?.toString());
    final eta = r['eta'] is Map ? r['eta'] as Map : null;
    final x = eta != null && eta['stops'] is Map ? (eta['stops'] as Map)['${best.id}'] : null;
    if (live && x is Map) {
      n.etaMin = (x['min'] as num?)?.toInt();
      n.etaAt = x['at']?.toString();
      n.lateMin = (x['late'] as num?)?.toInt();
      n.learned = eta!['learned'] == true;
    }
    return n;
  }

  /// No stop of your own (staff, or a child without a stop yet): distance and arrival time to the bus's
  /// next stop — the earliest AI-predicted stop, otherwise the nearest stop with a map pin (2.11.1).
  _Near? _nextStop(Map r) {
    final b = r['bus'] as Map?;
    if (b == null || b['live'] != true) return null;
    final stops = (r['stops'] as List).cast<Map>().where((s) => s['lat'] != null).toList();
    if (stops.isEmpty) return null;
    final bp = LatLng((b['lat'] as num).toDouble(), (b['lng'] as num).toDouble());
    final eta = r['eta'] is Map ? r['eta'] as Map : null;
    final pred = eta != null && eta['stops'] is Map ? eta['stops'] as Map : const {};
    Map? best;
    num? bestMin;
    for (final s in stops) {
      final x = pred['${s['id']}'];
      final m = x is Map ? x['min'] as num? : null;
      if (m != null && (bestMin == null || m < bestMin)) { bestMin = m; best = s; }
    }
    double bestD = double.infinity;
    if (best == null) {
      for (final s in stops) {
        final d = _distance.as(LengthUnit.Meter, bp, LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()));
        if (d < bestD) { bestD = d; best = s; }
      }
    } else {
      bestD = _distance.as(LengthUnit.Meter, bp, LatLng((best['lat'] as num).toDouble(), (best['lng'] as num).toDouble()));
    }
    final s = best!;
    final n = _Near(s['id'] as int, s['name'] as String, '', bestD, 0, true, false, null)..own = false;
    final x = pred['${s['id']}'];
    if (x is Map) {
      n.etaMin = (x['min'] as num?)?.toInt();
      n.etaAt = x['at']?.toString();
      n.learned = eta!['learned'] == true;
    }
    return n;
  }

  /// Nearest stop to the bus — shown to drivers and admins.
  String? _nearestStop(Map r) {
    final b = r['bus'] as Map?;
    if (b == null) return null;
    final bp = LatLng((b['lat'] as num).toDouble(), (b['lng'] as num).toDouble());
    String? name;
    double best = double.infinity;
    for (final s in (r['stops'] as List).cast<Map>().where((s) => s['lat'] != null)) {
      final d = _distance.as(LengthUnit.Meter, bp, LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()));
      if (d < best) { best = d; name = s['name'] as String; }
    }
    return name == null ? null : '$name · ${_fmt(best)}';
  }
}

String _fmt(double m) => m < 1000 ? '${(m / 10).round() * 10} m' : '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0)} km';

class _Stop {
  final int id;
  final String name;
  final LatLng point;
  final String children;
  _Stop(this.id, this.name, this.point, this.children);
}

class _Near {
  final int stopId;
  final String stopName;
  final String children;
  final double? meters;
  final int radius;
  final bool live;
  final bool inside;
  final String? alertedAt;

  /// Server prediction (AI, learned from past trips): minutes, clock time, minutes late.
  int? etaMin;
  String? etaAt;
  int? lateMin;
  bool learned = false;
  /// false = not the viewer's own stop but the bus's next stop
  bool own = true;
  _Near(this.stopId, this.stopName, this.children, this.meters, this.radius, this.live, this.inside, this.alertedAt);
}

/// Coloured bottom card: indigo on the way, amber when close, green inside the circle, slate when idle.
class _InfoPanel extends StatelessWidget {
  final Map route;
  final _Near? near;
  final String? nearestStop;
  const _InfoPanel({required this.route, required this.near, required this.nearestStop});

  @override
  Widget build(BuildContext context) {
    final b = route['bus'] as Map?;
    final live = b?['live'] == true;
    final speed = (b?['speed'] as num?)?.toDouble();
    final n = near;
    final colors = !live
        ? const [Color(0xFF334155), Color(0xFF64748B)]
        : n == null
            ? const [Color(0xFF312E81), Color(0xFF4F46E5)]
            : n.inside
                ? const [Color(0xFF047857), Color(0xFF10B981)]
                : (n.meters ?? 99999) < 1500
                    ? const [Color(0xFFB45309), Color(0xFFF59E0B)]
                    : const [Color(0xFF312E81), Color(0xFF4F46E5)];

    String headline;
    String sub;
    if (b == null) {
      headline = 'No GPS received yet';
      sub = n != null ? 'Your stop: ${n.stopName}' : '${route['students'] ?? 0} students on this route';
    } else if (!live) {
      headline = 'Bus is not on a trip right now';
      sub = 'Last seen ${b['ago']}${n != null ? ' · your stop ${n.stopName}' : ''}';
    } else if (n != null && n.meters != null && !n.own) {
      headline = 'Next stop: ${n.stopName}';
      sub = '${_fmt(n.meters!)} away${n.etaAt != null ? ' · arrives ~${n.etaAt}' : ''}'
          '${(route['no_stop'] as List?)?.isNotEmpty == true ? ' · tap Choose to set ${(route['no_stop'] as List).join(' & ')}’s stop' : ''}';
    } else if (n != null && n.meters != null) {
      headline = n.inside ? 'Bus is within ${_fmt(n.radius.toDouble())} of your stop' : '${_fmt(n.meters!)} away from your stop';
      sub = '${n.stopName}${n.children.isNotEmpty ? ' · ${n.children}' : ''}'
          '${n.etaAt != null && !n.inside ? ' · arrives ~${n.etaAt}' : ''}'
          '${(n.lateMin ?? 0) >= 3 ? ' · running ~${n.lateMin} min late' : ''}'
          '${n.alertedAt != null ? ' · alert sent ${n.alertedAt}' : ''}';
    } else {
      headline = '${b['trip_type'] == 'drop' ? 'Drop' : 'Pickup'} trip in progress';
      final pinned = (route['stops'] as List).cast<Map>().any((s) => s['lat'] != null);
      sub = nearestStop != null
          ? 'Near $nearestStop'
          : !pinned && (route['stops'] as List).isNotEmpty
              ? 'Stops have no map pins yet — each pin is set the first time the driver marks a child at that stop'
              : '${route['students'] ?? 0} students on this route';
    }

    // rough minutes at the current speed (20 km/h city average when crawling)
    String? eta;
    if (live && n?.etaMin != null && !(n!.inside)) {
      eta = '${n.etaMin} min';   // AI prediction from the server (learned stop-to-stop times)
    } else if (live && n?.meters != null && !(n!.inside)) {
      final v = (speed != null && speed >= 5) ? speed : 20.0;
      eta = '${(n.meters! / 1000 / v * 60).ceil().clamp(1, 600)} min';
    }
    final progress = n?.meters == null ? null : (1 - (n!.meters! / 5000)).clamp(0.02, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: .45), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(route['name'] as String, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          _pill(live ? (b?['overspeed'] == true ? '⚠ OVER ${b?['limit'] ?? ''} km/h' : 'LIVE · ${b?['trip_type'] == 'drop' ? 'Drop' : 'Pickup'}') : 'Idle', live),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n?.inside == true ? '🟢' : '🚌', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(headline, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        if (progress != null && live) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          _stat(Icons.social_distance, n?.meters != null ? _fmt(n!.meters!) : '—', n?.meters != null ? (n!.own ? 'to your stop' : 'to next stop') : 'distance'),
          _stat(Icons.speed, live && speed != null ? '${speed.round()}' : '—', 'km/h'),
          _stat(n?.learned == true ? Icons.auto_awesome : Icons.schedule, n?.inside == true ? 'Now' : (eta ?? '—'), n?.learned == true ? 'AI arrival' : 'approx. arrival'),
          _stat(Icons.update, (b?['ago'] ?? '—').toString().replaceAll(' ago', ''), 'updated'),
        ]),
        if (route['driver'] != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.badge_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(child: Text('${route['driver']}${route['vehicle'] != null ? ' · ${route['vehicle']}' : ''}${route['substitute'] == true ? ' · substitute' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
              if (route['driver_phone'] != null && Api.I.role == 'parent')
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                  onPressed: () => launchUrl(Uri.parse('tel:${route['driver_phone']}')),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Call'),
                ),
            ]),
          ),
        ],
        if (n != null && n.radius > 0 && !n.inside) ...[
          const SizedBox(height: 6),
          Text('You get a notification when the bus is within ${_fmt(n.radius.toDouble())} of your stop.', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ]),
    );
  }

  Widget _pill(String t, bool live) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: live ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: live ? const Color(0xFF047857) : Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
      );

  Widget _stat(IconData icon, String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(height: 2),
            FittedBox(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

/// The bus on the map: the DriverGuardian seal, a pulsing ring while live and the bus number.
class _BusMarker extends StatefulWidget {
  final bool live;
  final bool overspeed;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _BusMarker({required this.live, required this.color, required this.label, required this.onTap, this.overspeed = false});
  @override
  State<_BusMarker> createState() => _BusMarkerState();
}

class _BusMarkerState extends State<_BusMarker> with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.live) pulse.repeat();
  }

  @override
  void didUpdateWidget(_BusMarker old) {
    super.didUpdateWidget(old);
    if (widget.live && !pulse.isAnimating) pulse.repeat();
    if (!widget.live && pulse.isAnimating) pulse.stop();
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.overspeed ? Colors.red : (widget.live ? widget.color : Colors.grey);
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 84, height: 80,
          child: Stack(alignment: Alignment.center, children: [
            if (widget.live)
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => Container(
                  width: 52 + 30 * pulse.value, height: 52 + 30 * pulse.value,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ring.withValues(alpha: .28 * (1 - pulse.value))),
                ),
              ),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: ring, width: 3),
                  boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))]),
              padding: const EdgeInsets.all(3),
              child: ColorFiltered(
                colorFilter: widget.live ? const ColorFilter.mode(Colors.transparent, BlendMode.dst) : const ColorFilter.matrix(<double>[.5, .5, .1, 0, 20, .3, .6, .1, 0, 20, .3, .5, .2, 0, 20, 0, 0, 0, 1, 0]),
                child: Image.asset('assets/icon/marker.png', fit: BoxFit.contain),
              ),
            ),
          ]),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 96),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: ring, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]),
          child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .3)),
        ),
      ]),
    );
  }
}
