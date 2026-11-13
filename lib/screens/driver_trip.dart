import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api.dart';
import '../ui.dart';
import 'modules_field.dart' show ScanScreen;

/// Tab: pick one of the driver's routes.
class DriverTripPicker extends StatelessWidget {
  const DriverTripPicker({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      load: () => Api.I.get('/dashboard'),
      builder: (context, d, _) {
        final routes = (d['routes'] as List).cast<Map>();
        return ListView(padding: const EdgeInsets.all(14), children: [
          const SectionTitle('Choose a route to start'),
          Text(kIsWeb ? 'Web app: keep the trip screen open and the phone unlocked while driving — browsers stop GPS in the background. The Android app keeps running with the screen off.' : 'The trip screen keeps GPS running (even with the screen off) until you tap “Stop & end trip”.', style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 8),
          if (routes.isEmpty) const EmptyState(Icons.alt_route, 'No routes are assigned to you yet.'),
          for (final r in routes)
            Card(child: ListTile(
              leading: CircleAvatar(backgroundColor: hexColor(r['color'] as String?), child: const Icon(Icons.directions_bus, color: Colors.white)),
              title: Text(r['route'] as String),
              subtitle: Text('${r['vehicle'] ?? ''} · ${r['students']} students'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTripScreen(routeId: r['route_id'] as int))),
            )),
        ]);
      },
    );
  }
}

/// Share live GPS and mark boarding / drop without leaving the screen.
class DriverTripScreen extends StatefulWidget {
  final int routeId;
  final bool embedded;
  const DriverTripScreen({super.key, required this.routeId, this.embedded = false});
  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  Map<String, dynamic>? data;
  String? error;
  String trip = 'pickup';
  bool sharing = false;
  StreamSubscription<Position>? sub;
  Timer? timer;
  Position? last;
  DateTime? lastSent;
  String status = 'Not sharing';
  double km = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    sub?.cancel();
    timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.I.get('/driver/routes/${widget.routeId}');
      setState(() {
        data = d;
        if (!sharing) trip = (d['suggested_trip'] as String?) ?? 'pickup';
        error = null;
      });
    } catch (e) {
      setState(() => error = errText(e));
    }
  }

  Future<bool> _permission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      toast(context, 'Please turn on Location (GPS).', error: true);
      if (!kIsWeb) await Geolocator.openLocationSettings();
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      toast(context, kIsWeb ? 'Location is blocked. Allow it for this site (iPhone: Settings → Privacy → Location Services → Safari Websites).' : 'Location permission is needed to share the bus position.', error: true);
      if (p == LocationPermission.deniedForever && !kIsWeb) await Geolocator.openAppSettings();
      return false;
    }
    return true;
  }

  LocationSettings _settings() {
    if (kIsWeb) return const LocationSettings(accuracy: LocationAccuracy.high);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        // keeps GPS running with the screen off (foreground service + notification)
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'DriverGuardian — sharing bus location',
          notificationText: 'Parents and the school can see the bus live.',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(accuracy: LocationAccuracy.high, distanceFilter: 10, pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true);
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  Future<void> _start() async {
    if (!await _permission()) return;
    setState(() { sharing = true; status = 'Getting GPS fix…'; });
    WakelockPlus.enable();
    sub = Geolocator.getPositionStream(locationSettings: _settings()).listen((p) {
      last = p;
      final interval = (Api.I.user?['gps_interval'] as int?) ?? 8;
      if (lastSent == null || DateTime.now().difference(lastSent!).inSeconds >= interval - 1) _send();
    }, onError: (e) => setState(() => status = 'GPS error: $e'));
    final interval = (Api.I.user?['gps_interval'] as int?) ?? 8;
    timer = Timer.periodic(Duration(seconds: interval), (_) => _send());
  }

  bool _sending = false;
  Future<void> _send() async {
    final p = last;
    if (p == null || _sending || !sharing) return;
    _sending = true;
    try {
      final r = await Api.I.post('/driver/location', {
        'route_id': widget.routeId, 'lat': p.latitude, 'lng': p.longitude,
        'speed': p.speed >= 0 ? p.speed * 3.6 : null, 'heading': p.heading >= 0 ? p.heading : null, 'trip_type': trip,
      });
      lastSent = DateTime.now();
      km = (r['distance_km'] as num?)?.toDouble() ?? km;
      if (mounted) setState(() => status = 'LIVE · sent ${TimeOfDay.now().format(context)} · ±${p.accuracy.round()} m · ${km.toStringAsFixed(1)} km');
    } catch (e) {
      if (mounted) setState(() => status = 'Retrying — ${errText(e)}');
    } finally {
      _sending = false;
    }
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('End trip?'),
      content: const Text('Stop sharing the bus location and end this trip.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('End trip'))],
    ));
    if (ok != true) return;
    await sub?.cancel();
    timer?.cancel();
    sub = null;
    WakelockPlus.disable();
    setState(() { sharing = false; status = 'Trip ended'; });
    try { await Api.I.post('/driver/stop', {'route_id': widget.routeId}); } catch (_) {}
  }

  Future<void> _notify() async {
    try {
      final r = await Api.I.post('/driver/notify', {'route_id': widget.routeId, 'trip_type': trip});
      toast(context, 'Sent to ${r['count']} parent(s).');
    } catch (e) {
      toast(context, errText(e), error: true);
    }
  }

  Future<void> _mark(Map s, String st) async {
    final tt = st == 'dropped' ? 'drop' : trip;
    try {
      final r = await Api.I.post('/attendance/mark', {'student_id': s['id'], 'trip_type': tt, 'status': st, if (last != null) 'lat': last!.latitude, if (last != null) 'lng': last!.longitude});
      setState(() {
        s[tt] = st;
        s['${tt}_boarded_at'] = r['boarded_at'];
        s['${tt}_dropped_at'] = r['dropped_at'];
      });
    } catch (e) {
      toast(context, errText(e), error: true);
    }
  }

  Widget _student(Map s) {
    final cur = s[trip] as String?;
    Widget btn(String st, String label, Color c, IconData i) {
      final on = (st == 'dropped' ? s['drop'] : cur) == st;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: on
            ? FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: c, minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 10)), onPressed: () => _mark(s, st), icon: Icon(i, size: 16), label: Text(label))
            : OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: c, minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 10)), onPressed: () => _mark(s, st), icon: Icon(i, size: 16), label: Text(label)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('${s['class']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
        if (s['${trip}_boarded_at'] != null || s['drop_dropped_at'] != null)
          Text([
            if (s['${trip}_boarded_at'] != null) '↑ Boarded ${s['${trip}_boarded_at']}',
            if (s['drop_dropped_at'] != null) '↓ Dropped ${s['drop_dropped_at']}',
          ].join('   '), style: const TextStyle(fontSize: 11, color: kBlue, fontWeight: FontWeight.w600)),
        if (s['on_leave'] == true) const Text('On leave today', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
        if ((s['medical'] ?? '').toString().isNotEmpty) Text('⚕ ${s['medical']}', style: const TextStyle(color: Colors.red, fontSize: 12)),
        const SizedBox(height: 6),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          btn('boarded', 'Boarded', Colors.green.shade700, Icons.check),
          btn('dropped', 'Dropped', kBlue, Icons.home),
          btn('absent', 'Absent', Colors.red.shade700, Icons.close),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (data == null) {
      body = error != null ? EmptyState(Icons.cloud_off, error!) : const Center(child: CircularProgressIndicator());
    } else {
      final a = data!['assignment'] as Map;
      final stops = (data!['stops'] as List).cast<Map>();
      final students = (data!['students'] as List).cast<Map>();
      final byStop = <int, List<Map>>{};
      for (final s in students) {
        byStop.putIfAbsent((s['stop_id'] as int?) ?? 0, () => []).add(s);
      }
      final boarded = students.where((s) => s['pickup'] == 'boarded').length;
      final dropped = students.where((s) => s['drop'] == 'dropped').length;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (kIsWeb)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFCD34D))),
              child: const Row(children: [
                Icon(Icons.screen_lock_portrait_outlined, color: Color(0xFFB45309)),
                SizedBox(width: 10),
                Expanded(child: Text('Keep this screen open while sharing. In the web app the location stops if you lock the phone or switch apps.', style: TextStyle(fontSize: 12.5, color: Color(0xFF78350F)))),
              ]),
            ),
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                CircleAvatar(radius: 7, backgroundColor: hexColor(a['color'] as String?)),
                const SizedBox(width: 8),
                Expanded(child: Text(a['route'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
                Text(a['vehicle']?.toString() ?? '', style: const TextStyle(color: Colors.black54)),
              ]),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'pickup', label: Text('Pickup'), icon: Icon(Icons.wb_sunny_outlined)), ButtonSegment(value: 'drop', label: Text('Drop'), icon: Icon(Icons.nightlight_outlined))],
                selected: {trip},
                onSelectionChanged: (s) { setState(() => trip = s.first); _send(); },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: sharing ? Colors.green.shade50 : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.satellite_alt, color: sharing ? Colors.green : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text(status, style: TextStyle(fontWeight: FontWeight.w600, color: sharing ? Colors.green.shade900 : Colors.black54))),
                ]),
              ),
              if (a['tracking_enabled'] != true) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Live tracking is turned off for this route by the school. You can still mark attendance.', style: TextStyle(color: Colors.orange))),
              const SizedBox(height: 12),
              sharing
                  ? FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700, minimumSize: const Size.fromHeight(54)), onPressed: _stop, icon: const Icon(Icons.stop), label: const Text('Stop & end trip'))
                  : FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, minimumSize: const Size.fromHeight(54)), onPressed: a['tracking_enabled'] == true ? _start : null, icon: const Icon(Icons.play_arrow), label: const Text('Start sharing')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _notify, icon: const Icon(Icons.campaign_outlined), label: const Text('Notify parents'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())); _load(); }, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan passes'))),
              ]),
            ]),
          )),
          SectionTitle('Attendance', trailing: Text('$boarded boarded · $dropped dropped / ${students.length}', style: const TextStyle(color: Colors.black54, fontSize: 12))),
          for (final st in stops)
            Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: Row(children: [
                  CircleAvatar(radius: 12, backgroundColor: kBlue, child: Text('${st['seq']}', style: const TextStyle(color: Colors.white, fontSize: 11))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${st['name']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text('↑${st['pickup'] ?? '—'} ↓${st['drop'] ?? '—'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
              for (final s in byStop[st['id']] ?? <Map>[]) _student(s),
              if ((byStop[st['id']] ?? []).isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text('No students at this stop', style: TextStyle(color: Colors.black45))),
            ])),
          if (byStop[0] != null)
            Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(padding: EdgeInsets.all(10), child: Text('No stop assigned', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600))),
              for (final s in byStop[0]!) _student(s),
            ])),
          const SizedBox(height: 80),
        ]),
      );
    }
    if (widget.embedded) return body;
    return PopScope(
      canPop: !sharing,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) toast(context, 'End the trip before leaving this screen.'); },
      child: Scaffold(appBar: dgBar('Trip'), body: body),
    );
  }
}
