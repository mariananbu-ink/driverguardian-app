// Fleet & safety modules (2.2): trip history with replay, incident log / complaints,
// maintenance log, driver safety and substitute drivers.
// Developed & Powered by Marian Anbu Juwan
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';
import 'tracking.dart' show kTiles, kUserAgent;

List<Map> _list(Map d, String k) => ((d[k] as List?) ?? const []).cast<Map>();
String _s(Object? v) => v?.toString() ?? '';
num _n(Object? v) => v is num ? v : (num.tryParse(_s(v)) ?? 0);

/* ======================================================= Trip history */
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? day;
  int? routeId;
  String? type;

  Map<String, String> get query => {
        if (day != null) 'date': DateFormat('yyyy-MM-dd').format(day!) else 'month': DateFormat('yyyy-MM').format(month),
        if (routeId != null) 'route_id': '$routeId',
        if (type != null) 'type': type!,
      };

  @override
  Widget build(BuildContext context) {
    final mf = DateFormat('MMM yyyy');
    return Scaffold(
      appBar: dgBar(Api.I.role == 'driver' ? 'My trips' : 'Trip history', subtitle: day != null ? DateFormat('EEE, d MMM yyyy').format(day!) : mf.format(month)),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(query.toString()),
        load: () => Api.I.get('/trips', query),
        builder: (context, d, _) {
          final st = (d['stats'] as Map?) ?? const {};
          final routes = _list(d, 'routes');
          final groups = _list(d, 'groups');
          return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), children: [
                ActionChip(avatar: const Icon(Icons.chevron_left, size: 18), label: const Text(''), onPressed: () => setState(() { day = null; month = DateTime(month.year, month.month - 1); })),
                const SizedBox(width: 6),
                ChoiceChip(label: Text(mf.format(month)), selected: day == null, onSelected: (_) => setState(() => day = null)),
                const SizedBox(width: 6),
                ActionChip(avatar: const Icon(Icons.chevron_right, size: 18), label: const Text(''), onPressed: () => setState(() { day = null; month = DateTime(month.year, month.month + 1); })),
                const SizedBox(width: 6),
                ActionChip(avatar: const Icon(Icons.event, size: 16), label: Text(day == null ? 'Pick a date' : DateFormat('d MMM').format(day!)), onPressed: () async {
                  final p = await showDatePicker(context: context, initialDate: day ?? DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
                  if (p != null) setState(() => day = p);
                }),
                const SizedBox(width: 6),
                for (final t in const [['pickup', 'Pickup'], ['drop', 'Drop']])
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(t[1]), selected: type == t[0], onSelected: (v) => setState(() => type = v ? t[0] : null))),
              ]),
            ),
            if (routes.length > 1)
              SizedBox(
                height: 46,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), children: [
                  Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: const Text('All routes'), selected: routeId == null, onSelected: (_) => setState(() => routeId = null))),
                  for (final r in routes)
                    Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
                      avatar: CircleAvatar(radius: 5, backgroundColor: hexColor(r['color'] as String?)),
                      label: Text(_s(r['name'])), selected: routeId == r['id'], onSelected: (_) => setState(() => routeId = r['id'] as int))),
                ]),
              ),
            const SizedBox(height: 6),
            StatStrip([
              StatCard('Trips', '${st['trips'] ?? 0}', Icons.route, gBlue),
              StatCard('Distance', '${st['km'] ?? 0} km', Icons.add_road, gGreen),
              StatCard('Top speed', '${_n(st['max']).round()} km/h', Icons.speed, gOrange),
              StatCard('Over-speed', '${st['over'] ?? 0}', Icons.warning_amber_rounded, gRed),
            ]),
            if (groups.isEmpty) const EmptyState(Icons.route, 'No trips recorded for this period.'),
            for (final g in groups)
              Card(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: groups.length < 3,
                  shape: const Border(),
                  leading: GradientIcon(Icons.alt_route, [hexColor(g['color'] as String?), hexColor(g['color'] as String?).withValues(alpha: .6)], size: 38),
                  title: Text(_s(g['route'])),
                  subtitle: Text('${g['count']} trips · ${g['km']} km'),
                  children: [
                    for (final t in _list(g, 'trips'))
                      ListTile(
                        dense: true,
                        leading: Icon(t['type'] == 'drop' ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined, color: t['type'] == 'drop' ? Colors.deepPurple : Colors.orange),
                        title: Text('${t['date']} · ${t['start'] ?? ''} – ${t['end'] ?? '…'}'),
                        subtitle: Text('${t['driver'] ?? ''}${t['substitute'] == true ? ' (sub)' : ''} · ${t['vehicle'] ?? ''} · ${_n(t['km']).toStringAsFixed(1)} km · max ${_n(t['max']).round()} km/h'
                            '${_n(t['over']) > 0 ? ' · ⚠ ${t['over']} over-speed' : ''}${t['source'] == 'device' ? ' · tracker' : ''}'),
                        trailing: t['status'] == 'running' ? const StatusChip('live') : const Icon(Icons.play_circle_fill, color: kBlue),
                        onTap: _n(t['points']) < 2 ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripReplayScreen(id: t['id'] as int))),
                      ),
                  ],
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class TripReplayScreen extends StatefulWidget {
  final int id;
  const TripReplayScreen({super.key, required this.id});
  @override
  State<TripReplayScreen> createState() => _TripReplayScreenState();
}

class _TripReplayScreenState extends State<TripReplayScreen> {
  Map? trip;
  String? error;
  final pts = <LatLng>[];
  final speeds = <double?>[];
  final times = <double>[];
  final cum = <double>[0];
  double t0 = 0, tN = 1, cur = 0, factor = 30;
  int limit = 50;
  Timer? timer;
  bool playing = false;

  @override
  void initState() {
    super.initState();
    Api.I.get('/trips/${widget.id}').then((d) {
      final t = d['trip'] as Map;
      double? prev;
      for (final p in (t['points'] as List)) {
        final l = p as List;
        pts.add(LatLng(_n(l[0]).toDouble(), _n(l[1]).toDouble()));
        speeds.add(l[2] == null ? null : _n(l[2]).toDouble());
        var ts = l[3] == null ? (prev == null ? 0.0 : prev + 10) : _n(l[3]).toDouble();
        if (prev != null && ts < prev) ts = prev;
        times.add(ts);
        prev = ts;
      }
      const dist = Distance();
      for (var i = 1; i < pts.length; i++) {
        final km = dist.as(LengthUnit.Meter, pts[i - 1], pts[i]) / 1000;
        cum.add(cum.last + (km < 5 ? km : 0));
      }
      if (times.isNotEmpty) { t0 = times.first; tN = math.max(times.last, t0 + 1); cur = t0; }
      if (mounted) setState(() { trip = t; limit = _n(t['limit']).toInt(); });
    }).catchError((Object e) { if (mounted) setState(() => error = errText(e)); });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void toggle([bool? on]) {
    timer?.cancel();
    setState(() => playing = on ?? !playing);
    if (!playing) return;
    if (cur >= tN) cur = t0;
    timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      setState(() {
        cur = math.min(tN, cur + 0.08 * factor);
        if (cur >= tN) { playing = false; timer?.cancel(); }
      });
    });
  }

  int get idx {
    var i = 0;
    while (i < times.length - 2 && times[i + 1] <= cur) { i++; }
    return i;
  }

  (LatLng, double, double) get snap {
    final i = idx, j = math.min(i + 1, pts.length - 1);
    final span = times[j] - times[i];
    final f = span > 0 ? ((cur - times[i]) / span).clamp(0.0, 1.0) : 0.0;
    final p = LatLng(pts[i].latitude + (pts[j].latitude - pts[i].latitude) * f, pts[i].longitude + (pts[j].longitude - pts[i].longitude) * f);
    return (p, speeds[j] ?? speeds[i] ?? 0, cum[i] + (cum[j] - cum[i]) * f);
  }

  List<Polyline> get coloured {
    final out = <Polyline>[];
    var run = <LatLng>[pts.first];
    bool? over;
    for (var i = 1; i < pts.length; i++) {
      final o = (speeds[i] ?? 0) > limit;
      if (over != null && o != over) {
        out.add(Polyline(points: run, color: over ? Colors.red : Colors.green.shade600, strokeWidth: 5));
        run = [pts[i - 1]];
      }
      over = o;
      run.add(pts[i]);
    }
    out.add(Polyline(points: run, color: (over ?? false) ? Colors.red : Colors.green.shade600, strokeWidth: 5));
    return out;
  }

  String fmt(double s) => DateFormat('hh:mm:ss a').format(DateTime.fromMillisecondsSinceEpoch((s * 1000).round()));

  @override
  Widget build(BuildContext context) {
    if (error != null) return Scaffold(appBar: dgBar('Trip replay'), body: EmptyState(Icons.cloud_off, error!));
    if (trip == null) return Scaffold(appBar: dgBar('Trip replay'), body: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
    final t = trip!;
    if (pts.length < 2) return Scaffold(appBar: dgBar('Trip replay'), body: const EmptyState(Icons.route, 'Not enough GPS points to replay.'));
    final (bus, sp, km) = snap;
    final over = sp > limit;
    final color = hexColor(t['color'] as String?);
    return Scaffold(
      appBar: dgBar(_s(t['route']), subtitle: '${t['date']} · ${t['type'] == 'drop' ? 'Drop' : 'Pickup'} · ${t['driver'] ?? ''}'),
      body: Column(children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(initialCameraFit: CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(40))),
            children: [
              TileLayer(urlTemplate: kTiles, userAgentPackageName: kUserAgent),
              PolylineLayer(polylines: coloured),
              PolylineLayer(polylines: [Polyline(points: [...pts.sublist(0, idx + 1), bus], color: color.withValues(alpha: .45), strokeWidth: 8)]),
              MarkerLayer(markers: [
                for (final s in _list(t, 'stops'))
                  Marker(point: LatLng(_n(s['lat']).toDouble(), _n(s['lng']).toDouble()), width: 24, height: 24,
                      child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                          child: Text('${s['seq']}', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)))),
                for (final m in _list(t, 'marks'))
                  Marker(point: LatLng(_n(m['lat']).toDouble(), _n(m['lng']).toDouble()), width: 14, height: 14,
                      child: Tooltip(message: '${m['name']} · ${m['status']} ${m['time'] ?? ''}', child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2),
                          color: m['status'] == 'boarded' ? Colors.green : (m['status'] == 'dropped' ? kBlue : Colors.red))))),
                Marker(point: bus, width: 40, height: 40, child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                    border: Border.all(color: over ? Colors.red : color, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]), child: const Text('🚌', style: TextStyle(fontSize: 18)))),
              ]),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                _big('${sp.round()}', 'km/h', over ? Colors.red : Colors.green.shade700),
                _big(km.toStringAsFixed(1), 'km', kInk),
                _big(_dur(cur - t0), 'of ${_dur(tN - t0)}', kInk),
                Expanded(child: Text(fmt(cur), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
              SizedBox(height: 46, child: CustomPaint(painter: _SpeedPainter(times, speeds, limit, t0, tN, cur), size: Size.infinite)),
              Slider(value: (cur - t0) / (tN - t0), onChanged: (v) => setState(() => cur = t0 + (tN - t0) * v)),
              Row(children: [
                IconButton.filled(onPressed: () => toggle(), icon: Icon(playing ? Icons.pause : Icons.play_arrow)),
                IconButton(onPressed: () => setState(() => cur = t0), icon: const Icon(Icons.replay)),
                const SizedBox(width: 4),
                // 2.12: Normal = real time
                Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: Row(children: [
                  for (final x in const [1, 2, 5, 10, 30, 60, 120])
                    Padding(padding: const EdgeInsets.only(left: 4), child: ChoiceChip(label: Text(x == 1 ? 'Normal 1×' : '$x×'), selected: factor == x, visualDensity: VisualDensity.compact, onSelected: (_) => setState(() => factor = x.toDouble()))),
                ]))),
              ]),
              if (_list(t, 'events').isNotEmpty)
                Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, children: [
                  for (final e in _list(t, 'events'))
                    ActionChip(avatar: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16), label: Text('${_n(e['max']).round()} km/h · ${e['time']}', style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() { toggle(false); cur = _n(e['at']).toDouble().clamp(t0, tN); })),
                ])),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _big(String v, String l, Color c) => Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c)),
          Text(l, style: const TextStyle(fontSize: 10.5, color: kMuted)),
        ]),
      );
}

class _SpeedPainter extends CustomPainter {
  final List<double> t;
  final List<double?> s;
  final int limit;
  final double t0, tN, cur;
  _SpeedPainter(this.t, this.s, this.limit, this.t0, this.tN, this.cur);

  @override
  void paint(Canvas c, Size z) {
    final maxS = math.max(limit + 10.0, s.fold<double>(0, (a, b) => math.max(a, b ?? 0)));
    double x(double v) => (v - t0) / (tN - t0) * z.width;
    double y(double v) => z.height - v / maxS * z.height;
    final path = Path();
    var started = false;
    for (var i = 0; i < t.length; i++) {
      final v = s[i];
      if (v == null) continue;
      started ? path.lineTo(x(t[i]), y(v)) : path.moveTo(x(t[i]), y(v));
      started = true;
    }
    final fill = Path.from(path)..lineTo(z.width, z.height)..lineTo(0, z.height)..close();
    c.drawPath(fill, Paint()..color = kBlue.withValues(alpha: .10));
    c.drawPath(path, Paint()..color = kBlue..style = PaintingStyle.stroke..strokeWidth = 1.6);
    final ly = y(limit.toDouble());
    for (double i = 0; i < z.width; i += 8) { c.drawLine(Offset(i, ly), Offset(i + 4, ly), Paint()..color = Colors.red..strokeWidth = 1); }
    c.drawLine(Offset(x(cur), 0), Offset(x(cur), z.height), Paint()..color = kInk..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter o) => o.cur != cur || o.limit != limit;
}

/* ======================================================= Incidents / complaints */
class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});
  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  int k = 0;
  bool openOnly = false;
  static const icons = {'breakdown': Icons.build_outlined, 'accident': Icons.car_crash_outlined, 'delay': Icons.hourglass_bottom, 'complaint': Icons.chat_bubble_outline, 'other': Icons.error_outline};
  static const grads = {'breakdown': gOrange, 'accident': gRed, 'delay': gBlue, 'complaint': gViolet, 'other': gSlate};

  @override
  Widget build(BuildContext context) {
    final parent = Api.I.role == 'parent';
    Map? last;
    return Scaffold(
      appBar: dgBar(parent ? 'Complaints' : 'Incident log', actions: [
        if (!parent) IconButton(tooltip: 'Open only', icon: Icon(openOnly ? Icons.filter_alt : Icons.filter_alt_outlined), onPressed: () => setState(() { openOnly = !openOnly; k++; })),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
        onPressed: () async {
          if (last == null) return;
          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ReportIncidentScreen(meta: last!)));
          if (ok == true) setState(() => k++);
        },
        icon: const Icon(Icons.add), label: Text(parent ? 'New complaint' : 'Report'),
      ),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey('$k$openOnly'),
        load: () => Api.I.get('/incidents', openOnly ? {'status': 'open'} : null),
        builder: (context, d, reload) {
          last = d;
          final st = (d['stats'] as Map?) ?? const {};
          final list = _list(d, 'incidents');
          return ListView(padding: const EdgeInsets.only(top: 14, bottom: 90), children: [
            if (!parent)
              StatStrip([
                StatCard('Open', '${st['open'] ?? 0}', Icons.error_outline, gRed, hint: '${st['high'] ?? 0} high / critical'),
                StatCard('This month', '${st['month'] ?? 0}', Icons.calendar_month, gBlue),
                StatCard('All time', '${st['total'] ?? 0}', Icons.list_alt, gSlate),
              ]),
            if (list.isEmpty) EmptyState(Icons.shield_outlined, parent ? 'You have not sent any complaints.' : 'No incidents. Safe travels!'),
            for (final i in list)
              Card(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: ListTile(
                  leading: GradientIcon(icons[i['type']] ?? Icons.error_outline, grads[i['type']] ?? gSlate, size: 40),
                  title: Text(_s(i['title'])),
                  subtitle: Text('${i['type_label']} · ${i['route'] ?? 'No route'} · ${i['ago']}${i['delay'] != null ? ' · ${i['delay']} min late' : ''}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    StatusChip(_s(i['status']) == 'in_progress' ? 'pending' : (_s(i['status']) == 'resolved' ? 'resolved' : (_s(i['status']) == 'closed' ? 'closed' : 'open'))),
                    const SizedBox(height: 4),
                    Text(_s(i['severity']).toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ['high', 'critical'].contains(i['severity']) ? Colors.red : kMuted)),
                  ]),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => IncidentDetailScreen(i: i, severities: (d['severities'] as Map?) ?? const {})));
                    setState(() => k++);
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class IncidentDetailScreen extends StatefulWidget {
  final Map i;
  final Map severities;
  const IncidentDetailScreen({super.key, required this.i, required this.severities});
  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  late String status = _s(widget.i['status']);
  late String severity = _s(widget.i['severity']);
  late final resolution = TextEditingController(text: _s(widget.i['resolution']));
  bool notify = false, busy = false;

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await Api.I.put('/incidents/${widget.i['id']}', {'status': status, 'severity': severity, 'resolution': resolution.text.trim(), 'notify_parents': notify});
      if (!mounted) return;
      toast(context, 'Incident updated.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.i;
    return Scaffold(
      appBar: dgBar('${i['type_label']} #${i['id']}'),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Text(_s(i['title']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${i['at']} · reported by ${i['reporter'] ?? '—'}', style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          InfoRow(Icons.alt_route, 'Route', i['route'] as String?),
          InfoRow(Icons.directions_bus_outlined, 'Bus', i['vehicle'] as String?),
          InfoRow(Icons.badge_outlined, 'Driver', i['driver'] as String?),
          if (i['student'] != null) InfoRow(Icons.child_care, 'Student', i['student'] as String?),
          if (i['delay'] != null) InfoRow(Icons.timer_outlined, 'Delay', '${i['delay']} minutes'),
          if (i['cost'] != null) InfoRow(Icons.currency_rupee, 'Cost', inr(_n(i['cost']))),
          if (i['location'] != null) InfoRow(Icons.place_outlined, 'Location', i['location'] as String?,
              trailing: i['lat'] != null ? IconButton(icon: const Icon(Icons.map_outlined, size: 19), onPressed: () => launchUrl(Uri.parse('https://www.openstreetmap.org/?mlat=${i['lat']}&mlon=${i['lng']}#map=17/${i['lat']}/${i['lng']}'), mode: LaunchMode.externalApplication)) : null),
        ]))),
        if (_s(i['description']).isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_s(i['description'])))),
        if (i['photo'] != null) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(_s(i['photo']), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
        if (_s(i['resolution']).isNotEmpty || i['resolved_at'] != null)
          Card(color: const Color(0xFFEFFAF3), child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: const Text('Resolution'), subtitle: Text('${i['resolution'] ?? ''}\n${i['resolved_at'] ?? ''}'))),
        if (Api.I.isAdmin) ...[
          const SectionTitle('Update'),
          DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'),
              items: const [DropdownMenuItem(value: 'open', child: Text('Open')), DropdownMenuItem(value: 'in_progress', child: Text('In progress')), DropdownMenuItem(value: 'resolved', child: Text('Resolved')), DropdownMenuItem(value: 'closed', child: Text('Closed'))],
              onChanged: (v) => setState(() => status = v ?? status)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: widget.severities.containsKey(severity) ? severity : null, decoration: const InputDecoration(labelText: 'Severity'),
              items: [for (final e in widget.severities.entries) DropdownMenuItem(value: _s(e.key), child: Text(_s(e.value)))],
              onChanged: (v) => setState(() => severity = v ?? severity)),
          const SizedBox(height: 10),
          TextField(controller: resolution, maxLines: 3, decoration: const InputDecoration(labelText: 'Resolution / action taken')),
          if (i['route'] != null && i['type'] != 'complaint') SwitchListTile(contentPadding: EdgeInsets.zero, value: notify, onChanged: (v) => setState(() => notify = v), title: const Text('Send an update to parents on this route', style: TextStyle(fontSize: 13))),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save')),
        ],
      ]),
    );
  }
}

class ReportIncidentScreen extends StatefulWidget {
  final Map meta;
  const ReportIncidentScreen({super.key, required this.meta});
  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  late final types = _list(widget.meta, 'types');
  late String type = types.isNotEmpty ? _s(types.first['key']) : 'complaint';
  String severity = 'medium';
  final title = TextEditingController(), details = TextEditingController(), delay = TextEditingController(), location = TextEditingController();
  int? routeId, vehicleId, studentId;
  double? lat, lng;
  List<int>? photo;
  String? photoName;
  bool notify = false, busy = false;

  Map get opts => (widget.meta['options'] as Map?) ?? const {};

  @override
  void initState() {
    super.initState();
    if (types.any((t) => t['key'] == 'delay')) type = 'delay';
    final r = _list(opts, 'routes'), v = _list(opts, 'vehicles'), c = _list(opts, 'children');
    if (r.isNotEmpty && Api.I.role == 'driver') routeId = r.first['id'] as int;
    if (v.isNotEmpty && Api.I.role == 'driver') vehicleId = v.first['id'] as int;
    if (c.isNotEmpty) studentId = c.first['id'] as int;
  }

  Future<void> _gps() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
      setState(() { lat = pos.latitude; lng = pos.longitude; if (location.text.isEmpty) location.text = 'GPS ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'; });
    } catch (_) {
      if (mounted) toast(context, 'Location unavailable', error: true);
    }
  }

  Future<void> _photo(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 75);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() { photo = bytes; photoName = x.name.isEmpty ? 'photo.jpg' : x.name; });
  }

  Future<void> _send() async {
    if (title.text.trim().isEmpty) return toast(context, 'Add a short title.', error: true);
    setState(() => busy = true);
    try {
      final f = <String, String>{
        'type': type, 'title': title.text.trim(), 'description': details.text.trim(),
        if (Api.I.role != 'parent') 'severity': severity,
        if (routeId != null) 'route_id': '$routeId', if (vehicleId != null) 'vehicle_id': '$vehicleId', if (studentId != null) 'student_id': '$studentId',
        if (delay.text.trim().isNotEmpty) 'delay_minutes': delay.text.trim(), if (location.text.trim().isNotEmpty) 'location': location.text.trim(),
        if (lat != null) 'lat': '$lat', if (lng != null) 'lng': '$lng', if (notify) 'notify_parents': '1',
      };
      final r = await Api.I.postMultipart('/incidents', f, fileField: photo == null ? null : 'photo', fileBytes: photo, fileName: photoName);
      if (!mounted) return;
      toast(context, _s(r['message']).isEmpty ? 'Sent.' : _s(r['message']));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = Api.I.role == 'parent';
    final routes = _list(opts, 'routes'), vehicles = _list(opts, 'vehicles'), kids = _list(opts, 'children');
    const icons = {'breakdown': Icons.build_outlined, 'accident': Icons.car_crash_outlined, 'delay': Icons.hourglass_bottom, 'complaint': Icons.chat_bubble_outline, 'other': Icons.error_outline};
    return Scaffold(
      appBar: dgBar(parent ? 'New complaint' : 'Report an incident'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!parent) ...[
          const Text('What happened?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in types)
              ChoiceChip(avatar: Icon(icons[t['key']] ?? Icons.error_outline, size: 16), label: Text(_s(t['label'])), selected: type == t['key'], onSelected: (_) => setState(() => type = _s(t['key']))),
          ]),
          const SizedBox(height: 14),
        ],
        if (kids.length > 1)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<int>(initialValue: studentId, decoration: const InputDecoration(labelText: 'About'),
              items: [for (final k in kids) DropdownMenuItem(value: k['id'] as int, child: Text(_s(k['name'])))], onChanged: (v) => setState(() => studentId = v))),
        TextField(controller: title, decoration: InputDecoration(labelText: parent ? 'Subject' : 'Title', hintText: parent ? 'e.g. Bus arrived late today' : 'e.g. Flat tyre near Domlur')),
        const SizedBox(height: 12),
        TextField(controller: details, maxLines: 4, decoration: const InputDecoration(labelText: 'Details')),
        if (!parent) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(initialValue: severity, decoration: const InputDecoration(labelText: 'Severity'),
                items: const [DropdownMenuItem(value: 'low', child: Text('Low')), DropdownMenuItem(value: 'medium', child: Text('Medium')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'critical', child: Text('Critical'))],
                onChanged: (v) => setState(() => severity = v ?? severity))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: delay, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Delay (min)'))),
          ]),
          if (routes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: DropdownButtonFormField<int>(initialValue: routeId, decoration: const InputDecoration(labelText: 'Route'),
              items: [for (final r in routes) DropdownMenuItem(value: r['id'] as int, child: Text(_s(r['name']), overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => routeId = v))),
          if (vehicles.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: DropdownButtonFormField<int>(initialValue: vehicleId, decoration: const InputDecoration(labelText: 'Bus'),
              items: [for (final v in vehicles) DropdownMenuItem(value: v['id'] as int, child: Text(_s(v['name'])))], onChanged: (v) => setState(() => vehicleId = v))),
          const SizedBox(height: 12),
          TextField(controller: location, decoration: InputDecoration(labelText: 'Location', suffixIcon: IconButton(icon: Icon(Icons.my_location, color: lat != null ? Colors.green : null), onPressed: _gps))),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: notify, onChanged: (v) => setState(() => notify = v), title: const Text('Alert parents on this route', style: TextStyle(fontSize: 13))),
        ],
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton.icon(onPressed: () => _photo(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: () => _photo(ImageSource.gallery), icon: const Icon(Icons.photo_outlined), label: const Text('Gallery')),
          if (photo != null) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check_circle, color: Colors.green)),
        ]),
        const SizedBox(height: 18),
        FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600), onPressed: busy ? null : _send,
            icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send), label: Text(parent ? 'Send to school' : 'Report')),
      ]),
    );
  }
}

/* ======================================================= Maintenance */
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  int k = 0;
  Map? data;

  Future<void> _add() async {
    final d = data;
    if (d == null) return;
    final vehicles = _list(d, 'vehicles'), types = _list(d, 'types');
    if (vehicles.isEmpty) return;
    int vid = vehicles.first['id'] as int;
    String type = 'service', status = 'completed';
    DateTime date = DateTime.now();
    DateTime? next;
    final title = TextEditingController(), cost = TextEditingController(), odo = TextEditingController(), vendor = TextEditingController(), nextKm = TextEditingController();
    final f = DateFormat('d MMM yyyy');
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add service record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<int>(initialValue: vid, decoration: const InputDecoration(labelText: 'Bus'), items: [for (final v in vehicles) DropdownMenuItem(value: v['id'] as int, child: Text(_s(v['reg'])))], onChanged: (v) => set(() => vid = v ?? vid))),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(initialValue: type, isExpanded: true, decoration: const InputDecoration(labelText: 'Type'), items: [for (final t in types) DropdownMenuItem(value: _s(t['key']), child: Text(_s(t['label']), overflow: TextOverflow.ellipsis))], onChanged: (v) => set(() => type = v ?? type))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Work done', hintText: 'e.g. Oil + filters, brake check')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost (₹)'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odometer (km)'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: vendor, decoration: const InputDecoration(labelText: 'Workshop / vendor')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.event, size: 18), label: Text(f.format(date)), onPressed: () async {
              final p = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2018), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (p != null) set(() => date = p);
            })),
            const SizedBox(width: 8),
            Expanded(child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'completed', label: Text('Done')), ButtonSegment(value: 'scheduled', label: Text('Planned'))], selected: {status}, onSelectionChanged: (s) => set(() => status = s.first))),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E6), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Next service reminder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () async {
                  final p = await showDatePicker(context: c, initialDate: next ?? date.add(const Duration(days: 90)), firstDate: date.add(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 1000)));
                  if (p != null) set(() => next = p);
                }, child: Text(next == null ? 'On date…' : f.format(next!)))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: nextKm, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'or at km'))),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ])),
      )),
    );
    if (ok != true) return;
    try {
      final iso = DateFormat('yyyy-MM-dd');
      await Api.I.post('/maintenance', {'vehicle_id': vid, 'type': type, 'title': title.text.trim(), 'service_date': iso.format(date), 'status': status,
        if (cost.text.trim().isNotEmpty) 'cost': cost.text.trim(), if (odo.text.trim().isNotEmpty) 'odometer_km': odo.text.trim(), if (vendor.text.trim().isNotEmpty) 'vendor': vendor.text.trim(),
        if (next != null) 'next_service_date': iso.format(next!), if (nextKm.text.trim().isNotEmpty) 'next_service_km': nextKm.text.trim()});
      if (!mounted) return;
      toast(context, 'Service record saved.');
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Maintenance log'),
        floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add record')),
        body: Loader<Map<String, dynamic>>(
          key: ValueKey(k),
          load: () => Api.I.get('/maintenance'),
          builder: (context, d, _) {
            data = d;
            final st = (d['stats'] as Map?) ?? const {};
            return ListView(padding: const EdgeInsets.only(top: 14, bottom: 90), children: [
              StatStrip([
                StatCard('Spent this month', inr(_n(st['month'])), Icons.currency_rupee, gBlue),
                StatCard('Spent ${d['year']}', inr(_n(st['year'])), Icons.savings_outlined, gViolet),
                StatCard('Overdue', '${st['overdue'] ?? 0}', Icons.error_outline, gRed),
                StatCard('Due in 14 days', '${st['soon'] ?? 0}', Icons.event, gOrange),
              ]),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SectionTitle('Due & upcoming')),
              if (_list(d, 'due').isEmpty) const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Text('Nothing due. Add a next-service date or km when you log a service.', style: TextStyle(color: kMuted, fontSize: 12))),
              for (final x in _list(d, 'due'))
                Card(margin: const EdgeInsets.fromLTRB(14, 0, 14, 8), child: ListTile(
                  leading: GradientIcon(Icons.build_circle_outlined, (_n(x['days']) < 0 && x['days'] != null) || (_n(x['km_left']) < 0 && x['km_left'] != null) ? gRed : gOrange, size: 38),
                  title: Text('${x['vehicle']} · ${x['title']}'),
                  subtitle: Text([if (x['date'] != null) x['date'], if (x['km_left'] != null) '${x['km_left']} km left'].join(' · ')),
                  trailing: x['days'] == null ? null : Text(_n(x['days']) < 0 ? '${-_n(x['days'])} d overdue' : 'in ${x['days']} d',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _n(x['days']) < 0 ? Colors.red : Colors.orange.shade800)),
                )),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SectionTitle('Service records')),
              for (final r in _list(d, 'records'))
                ListTile(
                  leading: const Icon(Icons.handyman_outlined, color: kBlue),
                  title: Text('${r['vehicle']} · ${r['title']}'),
                  subtitle: Text('${r['date']} · ${r['type_label']}${r['vendor'] != null ? ' · ${r['vendor']}' : ''}${_s(r['next']).isNotEmpty ? '\nNext: ${r['next']}' : ''}'),
                  isThreeLine: _s(r['next']).isNotEmpty,
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(inr(_n(r['cost'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (r['status'] == 'scheduled') const Text('planned', style: TextStyle(fontSize: 10, color: kBlue)),
                  ]),
                ),
            ]);
          },
        ),
      );
}

/* ======================================================= Driver safety */
class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});
  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int k = 0;

  Color _sc(num s) => s >= 85 ? Colors.green : (s >= 60 ? Colors.orange : Colors.red);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Driver safety', subtitle: DateFormat('MMMM yyyy').format(month), actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => month = DateTime(month.year, month.month - 1))),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => month = DateTime(month.year, month.month + 1))),
        ]),
        body: Loader<Map<String, dynamic>>(
          key: ValueKey('${month.toIso8601String()}$k'),
          load: () => Api.I.get('/safety', {'month': DateFormat('yyyy-MM').format(month)}),
          builder: (context, d, _) {
            final st = (d['stats'] as Map?) ?? const {};
            final score = _n(st['fleetScore']);
            return ListView(padding: const EdgeInsets.only(top: 14, bottom: 40), children: [
              Card(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  SizedBox(width: 92, height: 92, child: Stack(alignment: Alignment.center, children: [
                    SizedBox.expand(child: CircularProgressIndicator(value: score / 100, strokeWidth: 9, backgroundColor: kLine, color: _sc(score))),
                    Text('${score.round()}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  ])),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Fleet safety score', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('${st['km'] ?? 0} km driven · limit ${d['limit']} km/h', style: const TextStyle(fontSize: 12, color: kMuted)),
                    if (st['safest'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('🏆 Safest: ${st['safest']}', style: const TextStyle(fontSize: 12.5))),
                  ])),
                ])),
              ),
              StatStrip([
                StatCard('Over-speed', '${st['events'] ?? 0}', Icons.warning_amber_rounded, gRed, hint: '${st['today'] ?? 0} today'),
                StatCard('Severe (+20)', '${st['severe'] ?? 0}', Icons.local_fire_department_outlined, gOrange),
                StatCard('Top speed', '${_n(st['top']).round()} km/h', Icons.speed, gBlue),
                StatCard('To review', '${st['unreviewed'] ?? 0}', Icons.fact_check_outlined, gSlate),
              ]),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SectionTitle('Driver scorecard')),
              for (final r in _list(d, 'drivers'))
                ListTile(
                  leading: Avatar(_s(r['name']), size: 38),
                  title: Text(_s(r['name'])),
                  subtitle: Text('${r['events']} events · ${r['km']} km${_n(r['severe']) > 0 ? ' · ${r['severe']} severe' : ''}'),
                  trailing: SizedBox(width: 90, child: Row(children: [
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: _n(r['score']) / 100, minHeight: 6, backgroundColor: kLine, color: _sc(_n(r['score']))))),
                    const SizedBox(width: 6),
                    Text('${r['score']}', style: TextStyle(fontWeight: FontWeight.w700, color: _sc(_n(r['score'])))),
                  ])),
                ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SectionTitle('Over-speed events')),
              if (_list(d, 'events').isEmpty) const EmptyState(Icons.verified_user_outlined, 'No over-speeding this month. 👏'),
              for (final e in _list(d, 'events'))
                Card(margin: const EdgeInsets.fromLTRB(14, 0, 14, 8), child: ListTile(
                  leading: GradientIcon(Icons.speed, e['level'] == 'severe' ? gRed : (e['level'] == 'high' ? gOrange : gCyan), size: 38),
                  title: Text('${_n(e['max']).round()} km/h  (+${e['over']}) · ${e['driver'] ?? ''}'),
                  subtitle: Text('${e['at']} · ${e['vehicle'] ?? ''} · ${e['sec']} s${e['note'] != null ? '\n✓ ${e['note']}' : ''}'),
                  isThreeLine: e['note'] != null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (e['trip_id'] != null) IconButton(tooltip: 'Replay', icon: const Icon(Icons.play_circle_outline, color: kBlue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripReplayScreen(id: e['trip_id'] as int)))),
                    if (e['reviewed'] != true)
                      IconButton(tooltip: 'Mark reviewed', icon: const Icon(Icons.check_circle_outline), onPressed: () async {
                        try { await Api.I.post('/safety/events/${e['id']}/review', {'note': 'Reviewed in app'}); setState(() => k++); } catch (x) { if (context.mounted) toast(context, errText(x), error: true); }
                      }),
                  ]),
                )),
            ]);
          },
        ),
      );
}

/* ======================================================= Substitute drivers */
class SubstitutesScreen extends StatefulWidget {
  const SubstitutesScreen({super.key});
  @override
  State<SubstitutesScreen> createState() => _SubstitutesScreenState();
}

class _SubstitutesScreenState extends State<SubstitutesScreen> {
  int k = 0;
  Map? data;

  Future<void> _assign() async {
    final d = data;
    if (d == null) return;
    final routes = _list(d, 'routes'), drivers = _list(d, 'drivers'), vehicles = _list(d, 'vehicles');
    if (routes.isEmpty || drivers.isEmpty) return;
    int route = routes.first['id'] as int;
    int? driver, vehicle;
    DateTimeRange range = DateTimeRange(start: DateTime.now(), end: DateTime.now());
    bool notify = true;
    final reason = TextEditingController();
    final f = DateFormat('d MMM');
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final reg = routes.firstWhere((r) => r['id'] == route)['regular_id'];
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Assign a substitute', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('The stand-in gets the route for tracking & attendance on these dates.', style: TextStyle(fontSize: 12, color: kMuted)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(initialValue: route, isExpanded: true, decoration: const InputDecoration(labelText: 'Route'),
                items: [for (final r in routes) DropdownMenuItem(value: r['id'] as int, child: Text('${r['name']}${r['regular'] != null ? ' · ${r['regular']}' : ''}', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => set(() { route = v ?? route; driver = null; })),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(initialValue: driver, isExpanded: true, decoration: const InputDecoration(labelText: 'Substitute driver'),
                items: [for (final x in drivers.where((x) => x['id'] != reg)) DropdownMenuItem(value: x['id'] as int, child: Text('${x['name']}${x['status'] == 'on_leave' ? ' (on leave)' : ''}'))],
                onChanged: (v) => set(() => driver = v)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.date_range, size: 18), label: Text('${f.format(range.start)} – ${f.format(range.end)}'), onPressed: () async {
                final p = await showDateRangePicker(context: c, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)), initialDateRange: range);
                if (p != null) set(() => range = p);
              })),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<int?>(initialValue: vehicle, isExpanded: true, decoration: const InputDecoration(labelText: 'Bus'),
                  items: [const DropdownMenuItem<int?>(value: null, child: Text('Usual bus')), for (final v in vehicles) DropdownMenuItem<int?>(value: v['id'] as int, child: Text(_s(v['reg'])))],
                  onChanged: (v) => set(() => vehicle = v))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. Regular driver on leave')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: notify, onChanged: (v) => set(() => notify = v), title: const Text('Tell parents who is driving', style: TextStyle(fontSize: 13))),
            FilledButton(onPressed: driver == null ? null : () => Navigator.pop(c, true), child: const Text('Assign cover')),
          ]),
        );
      }),
    );
    if (ok != true || driver == null) return;
    try {
      final iso = DateFormat('yyyy-MM-dd');
      final r = await Api.I.post('/substitutes', {'route_id': route, 'substitute_driver_id': driver, if (vehicle != null) 'vehicle_id': vehicle,
        'from_date': iso.format(range.start), 'to_date': iso.format(range.end), 'reason': reason.text.trim(), 'notify_parents': notify});
      if (!mounted) return;
      toast(context, _s(r['message']));
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Substitute drivers'),
        floatingActionButton: FloatingActionButton.extended(onPressed: _assign, icon: const Icon(Icons.person_add_alt), label: const Text('Assign')),
        body: Loader<Map<String, dynamic>>(
          key: ValueKey(k),
          load: () => Api.I.get('/substitutes'),
          builder: (context, d, _) {
            data = d;
            final list = _list(d, 'covers');
            final phase = {'today': ['Covering today', Colors.green], 'upcoming': ['Upcoming', kBlue], 'completed': ['Completed', kMuted], 'cancelled': ['Cancelled', Colors.red]};
            return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
              if (list.isEmpty) const EmptyState(Icons.person_pin_circle_outlined, 'No covers yet. Assign one when a driver is on leave.'),
              for (final c in list)
                Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 6, backgroundColor: hexColor(c['color'] as String?)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_s(c['route']), style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text(_s((phase[c['phase']] ?? ['', kMuted])[0]), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: (phase[c['phase']] ?? ['', kMuted])[1] as Color)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Avatar(_s(c['substitute']), size: 34),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c['substitute']} covers ${c['regular'] ?? 'the route'}', style: const TextStyle(fontSize: 13)),
                        Text('${c['dates']} · ${c['days']} day(s) · ${c['vehicle'] ?? ''}${_s(c['reason']).isNotEmpty ? '\n${c['reason']}' : ''}', style: const TextStyle(fontSize: 11.5, color: kMuted)),
                      ])),
                      if (c['phone'] != null) IconButton(icon: const Icon(Icons.call, color: Colors.green, size: 20), onPressed: () => launchUrl(Uri.parse('tel:${c['phone']}'))),
                    ]),
                    if (c['phase'] == 'today' || c['phase'] == 'upcoming')
                      Align(alignment: Alignment.centerRight, child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () async {
                          try { await Api.I.post('/substitutes/${c['id']}/cancel'); setState(() => k++); } catch (e) { if (context.mounted) toast(context, errText(e), error: true); }
                        },
                        icon: const Icon(Icons.block, size: 16), label: const Text('Cancel cover'))),
                  ]),
                )),
            ]);
          },
        ),
      );
}

/// 2.12: elapsed time as m:ss / h:mm:ss for the trip replay.
String _dur(double sec) {
  final t = sec.round().clamp(0, 999999);
  final h = t ~/ 3600, m = (t % 3600) ~/ 60, s = t % 60;
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
}
