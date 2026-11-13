// App permissions: Android and iOS never grant location, camera or notification
// permission at install time (not even from the Play Store) — the app must ask.
// This screen asks for everything the user's role needs in one place, right after
// the first sign-in, and is available later from Account → App permissions.
// Developed & Powered by Marian Anbu Juwan
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ui.dart';

class AppPermissions {
  AppPermissions._();
  static const _key = 'perm_onboarded_v1';

  /// Show the permissions screen once after the first sign-in on this phone.
  static Future<void> maybeShow(BuildContext context) async {
    if (kIsWeb) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_key) == true) return;
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsScreen(firstRun: true)));
    await p.setBool(_key, true);
  }
}

class _Item {
  final Permission permission;
  final IconData icon;
  final String title;
  final String why;
  final bool required;
  const _Item(this.permission, this.icon, this.title, this.why, {this.required = false});
}

class PermissionsScreen extends StatefulWidget {
  final bool firstRun;
  const PermissionsScreen({super.key, this.firstRun = false});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  final status = <Permission, PermissionStatus>{};
  bool busy = false;

  List<_Item> get items {
    final driver = Api.I.role == 'driver';
    final android = defaultTargetPlatform == TargetPlatform.android;
    return [
      const _Item(Permission.notification, Icons.notifications_active_outlined, 'Notifications',
          'Bus started, near your stop, boarding / drop, delays, SOS and fee alerts.', required: true),
      _Item(Permission.locationWhenInUse, Icons.my_location, 'Location',
          driver ? 'Share the bus position with parents and the school during a trip (it keeps running with the screen off while the trip is on).' : 'Attach your location to SOS alerts and complaints.', required: driver),
      _Item(Permission.camera, Icons.photo_camera_outlined, 'Camera',
          driver ? 'Scan students’ QR bus passes and add photos to incident reports.' : 'Add a photo to a complaint or incident.'),
      if (driver && android)
        const _Item(Permission.ignoreBatteryOptimizations, Icons.battery_charging_full_rounded, 'Unrestricted battery',
            'Stops Android from pausing GPS sharing during a trip. Opens Settings → Battery → choose “Unrestricted”.', required: true),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // back from the phone's Settings → re-check
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final i in items) {
      try { status[i.permission] = await i.permission.status; } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  bool _ok(PermissionStatus? s) => s != null && (s.isGranted || s.isLimited);

  Future<void> _ask(_Item i) async {
    final s = status[i.permission];
    if (s != null && s.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    if (i.permission == Permission.ignoreBatteryOptimizations) {
      // shown in the app's own Settings page (Battery → Unrestricted); re-checked when the user comes back
      if (mounted) toast(context, 'Battery → choose “Unrestricted”, then come back.');
      await openAppSettings();
      return;
    }
    try { status[i.permission] = await i.permission.request(); } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _all() async {
    setState(() => busy = true);
    for (final i in items) {
      if (_ok(status[i.permission])) continue;
      if (status[i.permission]?.isPermanentlyDenied ?? false) continue;
      if (i.permission == Permission.ignoreBatteryOptimizations) continue;   // needs the Settings page — its own button
      await _ask(i);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    final done = list.where((i) => _ok(status[i.permission])).length;
    return Scaffold(
      appBar: dgBar('App permissions', subtitle: '$done of ${list.length} allowed'),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 30), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, color: Colors.white, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(
              widget.firstRun ? 'One last step: allow what DriverGuardian needs to work. You can change this any time in Account → App permissions.' : 'Allow what DriverGuardian needs. Blocked items open the phone’s Settings.',
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
            )),
          ]),
        ),
        const SizedBox(height: 12),
        for (final i in list) _tile(i),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: busy || done == list.length ? null : _all,
          icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.done_all),
          label: Text(done == list.length ? 'Everything is allowed' : 'Allow all'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.firstRun ? (done == list.length ? 'Continue' : 'Skip for now') : 'Done')),
      ]),
    );
  }

  Widget _tile(_Item i) {
    final s = status[i.permission];
    final ok = _ok(s);
    final blocked = s?.isPermanentlyDenied ?? false;
    final c = ok ? Colors.green : (blocked ? Colors.red : (i.required ? Colors.orange : kMuted));
    return Card(child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: c.withValues(alpha: .12), child: Icon(i.icon, color: c)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (i.required && !ok) Padding(padding: const EdgeInsets.only(left: 6), child: Text('needed', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
          Text(i.why, style: const TextStyle(fontSize: 12, color: kMuted, height: 1.3)),
        ])),
        const SizedBox(width: 6),
        ok
            ? const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.check_circle, color: Colors.green))
            : TextButton(onPressed: () => _ask(i), child: Text(blocked ? 'Settings' : 'Allow')),
      ]),
    ));
  }
}
