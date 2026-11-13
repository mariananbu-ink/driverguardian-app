// Field modules: parent QR bus pass, driver QR scanner, driver's bus & documents,
// and CCTV cameras (HLS video, snapshots, external MJPEG / web players).
// Developed & Powered by Marian Anbu Juwan
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../ui.dart';
import 'modules_admin.dart' show VehicleCard;

List<Map> _list(Map d, String k) => ((d[k] as List?) ?? const []).cast<Map>();
String _s(Object? v) => v?.toString() ?? '';

/* ======================================================= Parent: QR bus pass */
class PassesScreen extends StatelessWidget {
  const PassesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Bus pass'),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/passes'),
          builder: (context, d, _) {
            final list = _list(d, 'passes');
            if (list.isEmpty) return ListView(children: const [EmptyState(Icons.qr_code_2, 'No active children yet.')]);
            return PageView(
              controller: PageController(viewportFraction: .9),
              children: [for (final p in list) _PassCard(p, _s(d['school']))],
            );
          },
        ),
      );
}

class _PassCard extends StatelessWidget {
  final Map p;
  final String school;
  const _PassCard(this.p, this.school);
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(6, 18, 6, 18), children: [
        Container(
          decoration: BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14))]),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.directions_bus_filled, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(school, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              const Text('BUS PASS', style: TextStyle(color: kYellow, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
            ]),
            const SizedBox(height: 20),
            Avatar(_s(p['name']), size: 64, colors: const [Colors.white30, Colors.white10]),
            const SizedBox(height: 10),
            Text(_s(p['name']), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            Text('${p['class']} · ${p['route'] ?? 'No route'}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w300)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: p['qr'] == null
                  ? const SizedBox(width: 200, height: 200, child: Center(child: Text('No QR pass issued yet.\nAsk the school office.', textAlign: TextAlign.center, style: TextStyle(color: kMuted))))
                  : QrImageView(data: _s(p['qr']), size: 210, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: kInk), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: kInk)),
            ),
            const SizedBox(height: 12),
            if (p['qr'] != null) Text(_s(p['qr']), style: const TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.w600)),
            if (p['rfid'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Glass(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('RFID card · ${p['rfid']}', style: const TextStyle(color: Colors.white, fontSize: 12)))),
          ]),
        ),
        const SizedBox(height: 14),
        const Text('Show this QR to the driver while boarding — the scan marks attendance and you get an instant alert. Turn the screen brightness up if it does not scan.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kMuted)),
      ]);
}

/* ======================================================= Driver: scan passes */
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final cam = MobileScannerController(detectionSpeed: DetectionSpeed.normal, formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39]);
  List<Map> routes = [];
  int? routeId;
  Map? last;
  final history = <Map>[];
  String? lastUid;
  DateTime lastAt = DateTime(2000);
  bool busy = false;

  @override
  void initState() {
    super.initState();
    Api.I.get('/dashboard').then((d) {
      if (!mounted) return;
      setState(() {
        routes = _list(d, 'routes');
        routeId = routes.isNotEmpty ? routes.first['route_id'] as int : null;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    cam.dispose();
    super.dispose();
  }

  Future<void> _submit(String uid) async {
    uid = uid.trim();
    if (uid.isEmpty || busy) return;
    if (uid == lastUid && DateTime.now().difference(lastAt).inSeconds < 4) return; // same code still in view
    lastUid = uid;
    lastAt = DateTime.now();
    setState(() => busy = true);
    double? lat, lng;
    try {
      final p = await Geolocator.getLastKnownPosition();
      lat = p?.latitude;
      lng = p?.longitude;
    } catch (_) {}
    try {
      final r = await Api.I.post('/driver/scan', {'uid': uid, if (routeId != null) 'route_id': routeId, if (lat != null) 'lat': lat, if (lng != null) 'lng': lng});
      HapticFeedback.mediumImpact();
      setState(() { last = r; history.insert(0, {...r, 'at': TimeOfDay.now().format(context)}); });
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => last = {'ok': false, 'action': 'denied', 'message': errText(e)});
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _manual() async {
    final c = TextEditingController();
    final v = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Enter pass / card number'),
      content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'e.g. QRA1B2C3D4E5')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Submit'))],
    ));
    if (v != null) { lastUid = null; _submit(v); }
  }

  List<Color> _grad(String? a) => switch (a) { 'boarded' || 'entry' => gGreen, 'dropped' || 'exit' => gBlue, 'unknown' => gOrange, _ => gRed };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: dgBar('Scan bus pass', actions: [
        IconButton(tooltip: 'Torch', icon: const Icon(Icons.flashlight_on_outlined), onPressed: () => cam.toggleTorch()),
        IconButton(tooltip: 'Switch camera', icon: const Icon(Icons.cameraswitch_outlined), onPressed: () => cam.switchCamera()),
        IconButton(tooltip: 'Type number', icon: const Icon(Icons.keyboard_alt_outlined), onPressed: _manual),
      ]),
      body: Column(children: [
        if (routes.length > 1)
          Container(
            color: kInk,
            height: 50,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: [
              for (final r in routes)
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(_s(r['route'])), selected: routeId == r['route_id'], onSelected: (_) => setState(() => routeId = r['route_id'] as int))),
            ]),
          ),
        Expanded(child: Stack(fit: StackFit.expand, children: [
          MobileScanner(
            controller: cam,
            onDetect: (cap) {
              final code = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
              if (code != null) _submit(code);
            },
          ),
          Center(child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: busy ? kYellow : Colors.white, width: 3)),
          )),
          Positioned(top: 16, left: 0, right: 0, child: Center(child: Glass(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(busy ? 'Checking…' : 'Point at the student’s QR pass', style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          ))),
          if (last != null)
            Positioned(left: 14, right: 14, bottom: 14, child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey(history.length),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: _grad(last!['action'] as String?))),
                child: Row(children: [
                  Icon(last!['ok'] == true ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 34),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(_s(last!['action']).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
                    Text(_s(last!['message']), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ])),
                ]),
              ),
            )),
        ])),
        if (history.isNotEmpty)
          Container(
            color: Colors.white,
            height: 130,
            child: ListView(children: [
              for (final h in history.take(20))
                ListTile(dense: true, leading: StatusChip(h['action'] as String?), title: Text(_s(h['message'])), trailing: Text(_s(h['at']), style: const TextStyle(fontSize: 11, color: kMuted))),
            ]),
          ),
      ]),
    );
  }
}

/* ======================================================= Driver: my bus */
class MyVehicleScreen extends StatelessWidget {
  const MyVehicleScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('My bus & documents'),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/driver/vehicle'),
          builder: (context, d, _) {
            final lic = d['license'] as Map?;
            int? days;
            if (lic?['expiry'] != null) days = DateTime.parse(_s(lic!['expiry'])).difference(DateTime.now()).inDays;
            return ListView(padding: const EdgeInsets.only(top: 14, bottom: 30), children: [
              if (lic != null)
                Card(margin: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                  const GradientIcon(Icons.badge_outlined, gViolet, size: 42),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Driving licence', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(_s(lic['no']).isEmpty ? '—' : _s(lic['no']), style: const TextStyle(fontSize: 12, color: kMuted)),
                  ])),
                  ExpiryChip('Valid till', lic['expiry'] as String?, days),
                ]))),
              for (final v in _list(d, 'vehicles')) VehicleCard(v),
              if (_list(d, 'vehicles').isEmpty) const EmptyState(Icons.directions_bus, 'No bus assigned to you yet.'),
              const Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 0), child: SectionTitle('Recent trips')),
              for (final t in _list(d, 'trips'))
                ListTile(
                  leading: GradientIcon(t['trip'] == 'drop' ? Icons.home_outlined : Icons.wb_sunny_outlined, t['trip'] == 'drop' ? gViolet : gOrange, size: 36),
                  title: Text('${t['date']} · ${_s(t['trip'])}'),
                  subtitle: Text('${t['time']} · ${(t['km'] as num).toStringAsFixed(1)} km'),
                  trailing: StatusChip(t['status'] as String?),
                ),
            ]);
          },
        ),
      );
}

/* ======================================================= CCTV */
class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});
  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  bool grid = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0F1F),
        appBar: dgBar('CCTV', subtitle: 'Live bus cameras', actions: [
          IconButton(icon: Icon(grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded), onPressed: () => setState(() => grid = !grid)),
        ]),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/cameras'),
          builder: (context, d, _) {
            final list = _list(d, 'cameras');
            if (list.isEmpty) return ListView(children: const [EmptyState(Icons.videocam_off_outlined, 'No cameras are shared with you.')]);
            return GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: grid ? 2 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: grid ? .95 : 1.35,
              children: [for (final c in list) CameraTile(c)],
            );
          },
        ),
      );
}

class CameraTile extends StatelessWidget {
  final Map c;
  const CameraTile(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final type = _s(c['type']);
    final url = c['url'] as String?;
    Widget view;
    if (url == null || type == 'rtsp') {
      view = const _CamMsg(Icons.settings_input_antenna, 'RTSP stream — open it on the web dashboard through your restreamer, or in VLC.');
    } else if (type == 'hls') {
      view = _HlsView(url);
    } else if (type == 'snapshot') {
      view = _SnapshotView(url);
    } else {
      view = _CamMsg(Icons.open_in_new, type == 'mjpeg' ? 'MJPEG stream' : 'Web player', action: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: Colors.black,
        child: Column(children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            view,
            Positioned(left: 10, top: 10, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
              child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            )),
            if (url != null && type != 'rtsp')
              Positioned(right: 4, top: 4, child: IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, title: Text(_s(c['name']))), body: Center(child: CameraTile(c))))),
              )),
          ])),
          Container(
            color: const Color(0xFF151A30),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              const Icon(Icons.videocam, color: kSky, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('${c['name']}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              Text('${c['vehicle'] ?? ''} · ${c['position'] ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CamMsg extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? action;
  const _CamMsg(this.icon, this.text, {this.action});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white38, size: 34),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white), onPressed: action, child: const Text('Open stream'))),
        ]),
      ));
}

class _HlsView extends StatefulWidget {
  final String url;
  const _HlsView(this.url);
  @override
  State<_HlsView> createState() => _HlsViewState();
}

class _HlsViewState extends State<_HlsView> {
  late final VideoPlayerController v = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  String? err;

  @override
  void initState() {
    super.initState();
    v.initialize().then((_) {
      v..setVolume(0)..setLooping(true)..play();
      if (mounted) setState(() {});
    }).catchError((Object e) {
      if (mounted) setState(() => err = 'Stream offline');
    });
  }

  @override
  void dispose() {
    v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (err != null) return _CamMsg(Icons.videocam_off_outlined, err!);
    if (!v.value.isInitialized) return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54));
    return FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)));
  }
}

class _SnapshotView extends StatefulWidget {
  final String url;
  const _SnapshotView(this.url);
  @override
  State<_SnapshotView> createState() => _SnapshotViewState();
}

class _SnapshotViewState extends State<_SnapshotView> {
  int tick = 0;
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 2), (_) { if (mounted) setState(() => tick++); });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sep = widget.url.contains('?') ? '&' : '?';
    return Image.network('${widget.url}${sep}_t=$tick', fit: BoxFit.cover, gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _CamMsg(Icons.videocam_off_outlined, 'Camera offline'));
  }
}
