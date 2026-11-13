// Web app (PWA) prompts on the home tab: "Add to Home Screen" on iPhone Safari and
// "Install app" in Android Chrome, then "Turn on notifications" once installed.
// Hidden in the Android/iOS apps.
// Developed & Powered by Marian Anbu Juwan
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../push.dart';
import '../ui.dart';
import 'bridge.dart';

class WebAppBanner extends StatefulWidget {
  const WebAppBanner({super.key});
  @override
  State<WebAppBanner> createState() => _WebAppBannerState();
}

class _WebAppBannerState extends State<WebAppBanner> {
  bool hidden = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => hidden = p.getBool('web_banner_hidden_${_kind()}') ?? false);
    });
  }

  /// 'install', 'push' or '' (nothing to suggest).
  String _kind() {
    if ((webIsIos() || webIsAndroid()) && !webIsStandalone()) return 'install';
    if (Push.available && webPushPermission() == 'default') return 'push';
    return '';
  }

  Future<void> _hide() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('web_banner_hidden_${_kind()}', true);
    if (mounted) setState(() => hidden = true);
  }

  Future<void> _enable() async {
    setState(() => busy = true);
    final msg = await Push.enableWeb();
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, msg, error: Push.token == null);
  }

  @override
  Widget build(BuildContext context) {
    final kind = kIsWeb ? _kind() : '';
    if (hidden || kind.isEmpty) return const SizedBox.shrink();
    final install = kind == 'install';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFE0F2FE)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(children: [
        GradientIcon(install ? Icons.add_to_home_screen_rounded : Icons.notifications_active_outlined, install ? gBlue : gGreen, size: 42),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(install ? (webIsIos() ? 'Install on your iPhone' : 'Install the web app') : 'Get bus alerts instantly', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            install
                ? (webIsIos()
                    ? 'Tap Share, then “Add to Home Screen” — opens full-screen like an app and can receive notifications.'
                    : 'Add DriverGuardian to your Home screen — opens full-screen with its own icon and notifications.')
                : 'Boarding, drop, delay and SOS alerts even when the app is closed.',
            style: const TextStyle(fontSize: 12, color: kMuted, height: 1.3),
          ),
          const SizedBox(height: 6),
          busy
              ? const SizedBox(height: 30, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
              : FilledButton.tonal(
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: install ? webShowInstallHelp : _enable,
                  child: Text(install ? (webIsIos() ? 'Show me how' : 'Install') : 'Turn on notifications'),
                ),
        ])),
        IconButton(onPressed: _hide, icon: const Icon(Icons.close, size: 18, color: kMuted), tooltip: 'Hide'),
      ]),
    );
  }
}
