import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../push.dart';
import '../ui.dart';
import 'home.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _pw = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _show = false;

  /// Server setting: the School Code is required for school users (platform owner: blank).
  bool _codeRequired = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final c = p.getString('last_school_code');
      if (c != null && c.isNotEmpty && _code.text.isEmpty && mounted) setState(() => _code.text = c);
    });
    Api.I.get('/ping').then((r) { if (mounted) setState(() => _codeRequired = r['school_code'] != 'optional'); }).catchError((_) {});
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _pw.text.isEmpty) {
      toast(context, 'Enter your email / User ID and password.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.I.login(_login.text, _pw.text, _code.text);
      final p = await SharedPreferences.getInstance();
      await p.setString('last_school_code', _code.text.trim().toUpperCase());
      Push.register();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final login = TextEditingController(text: _login.text);
    final code = TextEditingController(text: _code.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('We will email a new password to the address on your account.'),
          const SizedBox(height: 12),
          TextField(controller: login, decoration: const InputDecoration(labelText: 'Email, User ID or mobile number')),
          const SizedBox(height: 8),
          TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'School Code')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Send'))],
      ),
    );
    if (ok != true) return;
    try {
      final r = await Api.I.post('/auth/forgot', {'login': login.text.trim(), 'school_code': code.text.trim()});
      toast(context, r['message']?.toString() ?? 'Done');
    } catch (e) {
      toast(context, errText(e), error: true);
    }
  }

  Future<void> _server() async {
    final c = TextEditingController(text: Api.I.server);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server address'),
        content: TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://bus.yourschool.in')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
      ),
    );
    if (ok == true && c.text.trim().startsWith('http')) {
      await Api.I.saveServer(c.text);
      try {
        final r = await Api.I.get('/ping');
        toast(context, 'Connected to ${r['app']} ${r['version']}');
      } catch (e) {
        toast(context, 'Saved, but the server did not answer: ${errText(e)}', error: true);
      }
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            height: h * .38 < 280 ? 280 : h * .38,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(40))),
            child: SafeArea(
              child: Stack(children: [
                Positioned(right: -40, top: -30, child: Container(width: 170, height: 170, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),
                Positioned(left: -50, bottom: 10, child: Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .05)))),
                if (!kIsWeb) Align(alignment: Alignment.topRight, child: IconButton(onPressed: _server, icon: const Icon(Icons.dns_outlined, color: Colors.white70), tooltip: 'Server')),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 30),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 20, offset: const Offset(0, 8))]),
                      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/icon/icon.png', width: 60, height: 60)),
                    ),
                    const SizedBox(height: 16),
                    const Text('DriverGuardian', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.3)),
                    const Text('Every school bus, safe & on time.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w300)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final f in const [['Live GPS', Icons.my_location], ['RFID & QR', Icons.contactless_outlined], ['CCTV', Icons.videocam_outlined], ['UPI fees', Icons.currency_rupee]])
                        Glass(radius: 20, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(f[1] as IconData, color: Colors.white, size: 13), const SizedBox(width: 5), Text(f[0] as String, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ])),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -26),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .10), blurRadius: 30, offset: const Offset(0, 12))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Welcome back 👋', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const Text('Sign in as an admin, driver or parent.', style: TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w300)),
                const SizedBox(height: 18),
                TextField(controller: _login, keyboardType: TextInputType.emailAddress, autocorrect: false, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email, User ID or mobile number', prefixIcon: Icon(Icons.person_outline, size: 20))),
                const SizedBox(height: 12),
                TextField(
                  controller: _pw,
                  obscureText: !_show,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline, size: 20), suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), onPressed: () => setState(() => _show = !_show))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: _codeRequired ? 'School Code' : 'School Code (optional)',
                    hintText: 'e.g. GVPS — from your school',
                    helperText: _codeRequired ? 'Platform owner: leave blank' : null,
                    prefixIcon: const Icon(Icons.school_outlined, size: 20),
                  ),
                ),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgot, child: const Text('Forgot password?', style: TextStyle(fontSize: 12)))),
                const SizedBox(height: 4),
                DecoratedBox(
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4338CA), kSky]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6))]),
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, minimumSize: const Size.fromHeight(52)),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Sign in'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 18)]),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: const [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('new here?', style: TextStyle(fontSize: 11, color: kMuted))), Expanded(child: Divider())]),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Create a parent account')),
              ]),
            ),
          ),
          Text(Api.I.server, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 11)),
          const Padding(padding: EdgeInsets.fromLTRB(0, 2, 0, 24), child: Text(kCredit, textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 11))),
        ]),
      ),
    );
  }
}
