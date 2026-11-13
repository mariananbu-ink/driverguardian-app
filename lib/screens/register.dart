import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

/// Parent self-registration — mirrors the web form (email or User ID mode,
/// child + both parents; the other parent gets their own login).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _f = <String, TextEditingController>{};
  TextEditingController c(String k) => _f.putIfAbsent(k, () => TextEditingController());
  String mode = 'email';
  String relation = 'father';
  String? gender;
  String? schoolName;
  List routes = [];
  List grades = [];
  String? gradePick;
  int? routeId;
  int? stopId;
  bool busy = false;

  Future<void> _check() async {
    final code = c('school_code').text.trim();
    if (code.isEmpty) return;
    try {
      final d = await Api.I.get('/public/school', {'code': code});
      setState(() {
        schoolName = d['school']['name'] as String;
        routes = d['routes'] as List;
        grades = (d['grades'] as List?) ?? const [];
        gradePick = null;
        routeId = null;
        stopId = null;
      });
    } catch (e) {
      setState(() { schoolName = null; routes = []; });
      toast(context, errText(e), error: true);
    }
  }

  Future<void> _submit() async {
    setState(() => busy = true);
    try {
      final body = {for (final e in _f.entries) e.key: e.value.text.trim()};
      body['mode'] = mode;
      body['relation'] = relation;
      if (gender != null) body['gender'] = gender!;
      if (routeId != null) body['route_id'] = '$routeId';
      if (stopId != null) body['stop_id'] = '$stopId';
      body['password'] = c('password').text;
      body['password_confirmation'] = c('password_confirmation').text;
      final r = await Api.I.post('/auth/register', body);
      if (!mounted) return;
      await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Registration sent ✅'),
        content: SelectableText(r['message']?.toString() ?? ''),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(String k, String label, {TextInputType? type, bool obscure = false, TextCapitalization cap = TextCapitalization.none}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c(k), keyboardType: type, obscureText: obscure, textCapitalization: cap, decoration: InputDecoration(labelText: label)),
      );

  @override
  Widget build(BuildContext context) {
    final route = routes.cast<Map>().where((r) => r['id'] == routeId).firstOrNull;
    final stops = (route?['stops'] as List?) ?? [];
    return Scaffold(
      appBar: dgBar('Create parent account'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'email', label: Text('I have an email'), icon: Icon(Icons.email_outlined)), ButtonSegment(value: 'userid', label: Text('Use a User ID'), icon: Icon(Icons.badge_outlined))],
          selected: {mode},
          onSelectionChanged: (s) => setState(() => mode = s.first),
        ),
        const SectionTitle('School'),
        Row(children: [
          Expanded(child: TextField(controller: c('school_code'), textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'School Code'), onSubmitted: (_) => _check())),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _check, child: const Text('Check')),
        ]),
        if (schoolName != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('✓ $schoolName', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
        const SectionTitle('Child'),
        field('child_name', "Child's full name", cap: TextCapitalization.words),
        Row(children: [
          // 2.12: the school's own grade list (Other… = type it)
          Expanded(child: grades.isEmpty || gradePick == '__other'
              ? field('grade', 'Grade')
              : DropdownButtonFormField<String>(
                  value: gradePick,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Grade'),
                  items: [
                    for (final g in grades.cast<Map>()) DropdownMenuItem(value: g['value'].toString(), child: Text(g['label'].toString(), overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(value: '__other', child: Text('Other…')),
                  ],
                  onChanged: (v) => setState(() { gradePick = v; c('grade').text = v == null || v == '__other' ? '' : v; }),
                )),
          const SizedBox(width: 8),
          Expanded(child: field('section', 'Section', cap: TextCapitalization.characters)),
        ]),
        DropdownButtonFormField<String>(
          value: gender,
          decoration: const InputDecoration(labelText: 'Gender'),
          items: const [DropdownMenuItem(value: 'male', child: Text('Boy')), DropdownMenuItem(value: 'female', child: Text('Girl')), DropdownMenuItem(value: 'other', child: Text('Other'))],
          onChanged: (v) => setState(() => gender = v),
        ),
        const SizedBox(height: 10),
        if (routes.isNotEmpty) ...[
          DropdownButtonFormField<int>(
            value: routeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Bus route (optional)'),
            items: [for (final r in routes.cast<Map>()) DropdownMenuItem(value: r['id'] as int, child: Text(r['name'].toString(), overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() { routeId = v; stopId = null; }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey(routeId),
            value: stopId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Stop (optional)'),
            items: [for (final s in stops.cast<Map>()) DropdownMenuItem(value: s['id'] as int, child: Text('${s['seq']}. ${s['name']}'))],
            onChanged: (v) => setState(() => stopId = v),
          ),
        ],
        const SectionTitle('Parents'),
        field('father_name', "Father's name", cap: TextCapitalization.words),
        field('father_email', "Father's email", type: TextInputType.emailAddress),
        field('father_phone', "Father's mobile", type: TextInputType.phone),
        field('mother_name', "Mother's name", cap: TextCapitalization.words),
        field('mother_email', "Mother's email", type: TextInputType.emailAddress),
        field('mother_phone', "Mother's mobile", type: TextInputType.phone),
        const Text('The other parent’s email/mobile gets their own login (activated together on approval).', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SectionTitle('Your sign-in'),
        DropdownButtonFormField<String>(
          value: relation,
          decoration: const InputDecoration(labelText: 'I am the'),
          items: const [DropdownMenuItem(value: 'father', child: Text('Father')), DropdownMenuItem(value: 'mother', child: Text('Mother')), DropdownMenuItem(value: 'guardian', child: Text('Guardian'))],
          onChanged: (v) => setState(() => relation = v ?? 'father'),
        ),
        const SizedBox(height: 10),
        field('name', 'Your full name', cap: TextCapitalization.words),
        field('phone', 'Your mobile', type: TextInputType.phone),
        if (mode == 'email') field('email', 'Your email (used to sign in)', type: TextInputType.emailAddress),
        field('password', 'Password (8+ with letters & numbers)', obscure: true),
        field('password_confirmation', 'Confirm password', obscure: true),
        if (mode == 'userid') const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('We will create a User ID like DG-4F9K2P for you to sign in with.', style: TextStyle(color: kBlue))),
        FilledButton.icon(onPressed: busy ? null : _submit, icon: const Icon(Icons.person_add), label: const Text('Create account')),
        const SizedBox(height: 20),
      ]),
    );
  }
}
