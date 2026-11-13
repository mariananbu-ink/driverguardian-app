import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../push.dart';
import '../ui.dart';
import '../web/bridge.dart';
import 'guide.dart';
import 'permissions.dart';
import 'attendance.dart';
import 'copilot.dart';

/// SOS: alert the school admins with the current location.
Future<void> sendSos(BuildContext context) async {
  final note = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
    title: const Text('Send SOS alert?'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('The school admins are alerted immediately with your location.'),
      const SizedBox(height: 10),
      TextField(controller: note, decoration: const InputDecoration(hintText: 'What happened? (optional)')),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Send SOS'))],
  ));
  if (ok != true) return;
  double? lat, lng;
  try {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
      lat = pos.latitude;
      lng = pos.longitude;
    }
  } catch (_) {}
  try {
    await Api.I.post('/sos', {'note': note.text.trim(), if (lat != null) 'lat': lat, if (lng != null) 'lng': lng});
    toast(context, 'SOS sent. The school has been alerted.');
  } catch (e) {
    toast(context, errText(e), error: true);
  }
}

/// Account tab: profile, school, quick links, password, sign out.
class AccountScreen extends StatelessWidget {
  final VoidCallback? onSwitchSchool;
  final Future<void> Function() onSignOut;
  const AccountScreen({super.key, this.onSwitchSchool, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final u = Api.I.user ?? {};
    final school = u['school'] as Map?;
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return ListView(padding: const EdgeInsets.all(14), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Avatar(u['name']?.toString() ?? '?', size: 58, colors: const [Color(0xFFFDE68A), kYellow]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            Text('${u['role_label'] ?? ''} · ${u['login'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w300)),
            if (u['phone'] != null) Text('${u['phone']}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w300)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      if (school != null || Api.I.schoolName != null)
        Card(child: ListTile(
          leading: const GradientIcon(Icons.school_rounded, gTeal, size: 40),
          title: Text(school?['name']?.toString() ?? Api.I.schoolName ?? ''),
          subtitle: Text(school != null ? 'School Code ${school['code']}${school['city'] != null ? ' · ${school['city']}' : ''}' : 'Working inside this school'),
          trailing: school?['phone'] != null ? IconButton.filledTonal(icon: const Icon(Icons.call, size: 18), onPressed: () => launchUrl(Uri.parse('tel:${school!['phone']}'))) : null,
        )),
      _tile(Icons.person_outline, 'My profile & password', gBlue, () => go(const ProfileScreen())),
      _tile(Icons.notifications_none_rounded, 'Notifications', gOrange, () => go(const NotificationsScreen())),
      _tile(Icons.menu_book_rounded, 'User guide & help', gIndigo, () => go(const GuideScreen())),
      if (!kIsWeb) _tile(Icons.verified_user_outlined, 'App permissions', gTeal, () => go(const PermissionsScreen())),
      if (u['copilot'] == true) _tile(Icons.auto_awesome, 'AI Copilot', gPink, () => go(const CopilotScreen())),
      if (Api.I.role == 'parent') _tile(Icons.event_available_outlined, 'Attendance & leave', gTeal, () => go(const ChildAttendanceScreen())),
      if (onSwitchSchool != null) _tile(Icons.swap_horiz_rounded, 'Switch school', gViolet, onSwitchSchool!),
      if (Api.I.role == 'driver' || Api.I.role == 'parent') _tile(Icons.sos, 'Send SOS', gRed, () => sendSos(context)),
      _tile(Icons.logout_rounded, 'Sign out', gSlate, onSignOut),
      const SizedBox(height: 16),
      Text('DriverGuardian $kVersion · ${Api.I.server}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: kMuted)),
      const Text(kCredit, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: kMuted)),
      const SizedBox(height: 70),
    ]);
  }

  Widget _tile(IconData i, String t, List<Color> g, VoidCallback onTap) => Card(
        child: ListTile(leading: GradientIcon(i, g, size: 36), title: Text(t), trailing: const Icon(Icons.chevron_right, color: kMuted), onTap: onTap),
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int k = 0;
  static const icons = {'attendance': Icons.fact_check, 'payment': Icons.currency_rupee, 'message': Icons.chat_bubble, 'alert': Icons.campaign, 'sos': Icons.warning_amber_rounded};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar('Notifications', actions: [
        TextButton(onPressed: () async { await Api.I.post('/notifications/read'); setState(() => k++); }, child: const Text('Mark all read', style: TextStyle(color: Colors.white))),
      ]),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(k),
        load: () => Api.I.get('/notifications'),
        builder: (context, d, _) {
          final list = (d['notifications'] as List).cast<Map>();
          return ListView(children: [
            if (list.isEmpty) const EmptyState(Icons.notifications_off_outlined, 'You are all caught up.'),
            for (final n in list)
              ListTile(
                tileColor: n['read'] == true ? null : const Color(0xFFEFF4FF),
                leading: CircleAvatar(backgroundColor: kBlue.withValues(alpha: .12), child: Icon(icons[n['type']] ?? Icons.notifications, color: kBlue, size: 20)),
                title: Text(n['title'] as String, style: TextStyle(fontWeight: n['read'] == true ? FontWeight.w500 : FontWeight.w700)),
                subtitle: Text('${n['body'] ?? ''}\n${n['at']}'),
                isThreeLine: true,
                onTap: () async { await Api.I.post('/notifications/read', {'id': n['id']}); setState(() => n['read'] = true); },
              ),
          ]);
        },
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final cur = TextEditingController();
  final pw = TextEditingController();
  final pw2 = TextEditingController();

  Future<void> _change() async {
    try {
      final r = await Api.I.put('/me/password', {'current_password': cur.text, 'password': pw.text, 'password_confirmation': pw2.text});
      toast(context, r['message']?.toString() ?? 'Password changed');
      cur.clear(); pw.clear(); pw2.clear();
    } catch (e) {
      toast(context, errText(e), error: true);
    }
  }

  Future<void> _enablePush() async {
    final msg = await Push.enableWeb();
    if (!mounted) return;
    toast(context, msg, error: Push.token == null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final u = Api.I.user ?? {};
    return Scaffold(
      appBar: dgBar('My profile'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Avatar(u['name']?.toString() ?? '?', size: 72)),
        const SizedBox(height: 10),
        Center(child: Text(u['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        Center(child: Text('${u['role_label'] ?? ''} · ${u['login'] ?? ''}')),
        if (u['phone'] != null) Center(child: Text('${u['phone']}', style: const TextStyle(color: Colors.black54))),
        const SectionTitle('Change password'),
        TextField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
        const SizedBox(height: 8),
        TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'New password (8+, letters & numbers)')),
        const SizedBox(height: 8),
        TextField(controller: pw2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
        const SizedBox(height: 12),
        FilledButton(onPressed: _change, child: const Text('Change password')),
        const SectionTitle('About'),
        Text('Server: ${Api.I.server}', style: const TextStyle(fontSize: 12)),
        if (kIsWeb) ...[
          Text('Notifications: ${Push.webStatus()}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (Push.available && Push.token == null && webPushPermission() != 'denied')
              FilledButton.tonalIcon(onPressed: _enablePush, icon: const Icon(Icons.notifications_active_outlined, size: 18), label: const Text('Turn on notifications')),
            if (!webIsStandalone())
              OutlinedButton.icon(onPressed: webShowInstallHelp, icon: const Icon(Icons.add_to_home_screen, size: 18), label: const Text('Install on Home Screen')),
          ]),
        ] else
          Text('Push notifications: ${Push.available ? 'enabled' : 'in-app only (no Firebase config in this build)'}', style: const TextStyle(fontSize: 12)),
        if (Push.token != null) SelectableText('Device token: ${Push.token}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 10),
        const Text(kCredit, style: TextStyle(fontSize: 12, color: Colors.black45)),
      ]),
    );
  }
}
