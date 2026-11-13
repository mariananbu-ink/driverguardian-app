// School-admin & platform modules: students, classes, siblings, parents & staff,
// drivers, vehicles, routes, assignments, RFID cards, academic years, logs,
// reports, invoices with installments and the school switcher.
// Developed & Powered by Marian Anbu Juwan
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';
import 'messages.dart';

List<Map> _list(Map d, String k) => ((d[k] as List?) ?? const []).cast<Map>();
String _s(Object? v) => v?.toString() ?? '';
Future<void> _call(String? phone) async {
  if (phone != null && phone.isNotEmpty) await launchUrl(Uri.parse('tel:$phone'));
}

/* ======================================================= Students */
class StudentsScreen extends StatefulWidget {
  final String? classFilter;
  final String? section;
  final String? classLabel;
  const StudentsScreen({super.key, this.classFilter, this.section, this.classLabel});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar(widget.classFilter == null ? 'Students' : (widget.classFilter!.isEmpty ? 'No class' : '${widget.classLabel ?? widget.classFilter}${(widget.section ?? '').isNotEmpty ? ' - ${widget.section}' : ''}')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceScreen())),
          icon: const Icon(Icons.receipt_long), label: const Text('New invoice'),
        ),
        body: Column(children: [
          SearchBox(hint: 'Search name or admission no', onSearch: (v) => setState(() => q = v)),
          Expanded(child: Loader<Map<String, dynamic>>(
            key: ValueKey(q),
            load: () => Api.I.get('/students', {if (q.isNotEmpty) 'q': q, if (widget.classFilter != null) 'class': widget.classFilter!, if ((widget.section ?? '').isNotEmpty) 'section': widget.section!}),
            builder: (context, d, _) {
              final list = _list(d, 'students');
              return ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 90), children: [
                Text('${list.length} student(s)', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                if (list.isEmpty) const EmptyState(Icons.groups, 'No students found.'),
                for (final s in list)
                  Card(child: ListTile(
                    leading: Avatar(_s(s['name']), size: 40),
                    title: Text(_s(s['name'])),
                    subtitle: Text('${s['class']} · ${s['route'] ?? 'No bus'}${s['stop'] != null ? ' · ${s['stop']}' : ''}', maxLines: 2),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_s(s['medical']).isNotEmpty) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.medical_information, color: Colors.red, size: 18)),
                      if (s['phone'] != null) IconButton(icon: const Icon(Icons.call, color: Colors.green, size: 20), onPressed: () => _call(s['phone'] as String?)),
                    ]),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailScreen(id: s['id'] as int, name: _s(s['name'])))),
                  )),
              ]);
            },
          )),
        ]),
      );
}

class StudentDetailScreen extends StatelessWidget {
  final int id;
  final String name;
  const StudentDetailScreen({super.key, required this.id, required this.name});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: dgBar(name, bottom: dgTabs(const ['Profile', 'Attendance', 'Fees', 'History'])),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/students/$id'),
          builder: (context, d, _) {
            final s = d['student'] as Map;
            Widget person(String label, Map? p) {
              if (p == null || (_s(p['name']).isEmpty && _s(p['phone']).isEmpty)) return const SizedBox.shrink();
              return InfoRow(Icons.person_outline, label, '${p['name'] ?? ''}${_s(p['phone']).isNotEmpty ? '\n${p['phone']}' : ''}',
                  trailing: _s(p['phone']).isNotEmpty ? IconButton(icon: const Icon(Icons.call, color: Colors.green, size: 19), onPressed: () => _call(p['phone'] as String?)) : null);
            }

            return TabBarView(children: [
              ListView(padding: const EdgeInsets.all(14), children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    Avatar(_s(s['name']), size: 56, colors: const [Colors.white24, Colors.white10]),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(s['name']), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('${s['class']} · ${s['admission_no'] ?? 'no admission no'}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w300)),
                      const SizedBox(height: 6),
                      StatusChip(s['status'] as String?),
                    ])),
                  ]),
                ),
                if (_s(s['medical']).isNotEmpty)
                  Card(color: const Color(0xFFFFF1F2), margin: const EdgeInsets.only(top: 12), child: ListTile(leading: const Icon(Icons.medical_information, color: Colors.red), title: const Text('Medical / allergies'), subtitle: Text(_s(s['medical'])))),
                const SectionTitle('Transport'),
                Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                  InfoRow(Icons.alt_route, 'Route', s['route'] as String?),
                  InfoRow(Icons.place_outlined, 'Stop', s['stop'] as String?),
                  InfoRow(Icons.schedule, 'Timings', s['pickup'] == null ? null : 'Pickup ${s['pickup']} · Drop ${s['drop'] ?? '—'}'),
                  for (final c in _list(s, 'cards')) InfoRow(c['type'] == 'qr' ? Icons.qr_code_2 : Icons.contactless_outlined, _s(c['type']).toUpperCase(), _s(c['uid']), trailing: StatusChip(c['status'] as String?)),
                ]))),
                const SectionTitle('Family'),
                Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                  person('Father', s['father'] as Map?),
                  person('Mother', s['mother'] as Map?),
                  person('Guardian', s['guardian'] as Map?),
                  if (s['family'] != null) InfoRow(Icons.diversity_3, 'Family', '${s['family']}'),
                  if ((s['siblings'] as List).isNotEmpty) InfoRow(Icons.child_care, 'Siblings', (s['siblings'] as List).join('\n')),
                  for (final l in _list(s, 'logins')) InfoRow(Icons.key_outlined, 'App login', '${l['name']} · ${l['login']}', trailing: StatusChip(l['status'] as String?)),
                ]))),
              ]),
              ListView(padding: const EdgeInsets.all(14), children: [
                if (_list(s, 'attendance').isEmpty) const EmptyState(Icons.event_available, 'No attendance yet.'),
                for (final a in _list(s, 'attendance'))
                  Card(child: ListTile(
                    leading: GradientIcon(a['trip'] == 'drop' ? Icons.home_outlined : Icons.directions_bus, a['trip'] == 'drop' ? gViolet : gBlue, size: 38),
                    title: Text('${DateFormat('EEE, d MMM').format(DateTime.parse(_s(a['date'])))} · ${_s(a['trip'])}'),
                    subtitle: Text('Boarded ${a['boarded_at'] ?? '—'} · Dropped ${a['dropped_at'] ?? '—'}${a['via'] != null ? ' · ${_s(a['via']).toUpperCase()}' : ''}'),
                    trailing: StatusChip(a['status'] as String?),
                  )),
              ]),
              ListView(padding: const EdgeInsets.all(14), children: [
                FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceScreen(studentId: id, studentName: name))), icon: const Icon(Icons.add), label: const Text('New invoice / installments')),
                const SizedBox(height: 10),
                if (_list(s, 'payments').isEmpty) const EmptyState(Icons.receipt_long, 'No invoices.'),
                for (final p in _list(s, 'payments'))
                  Card(child: ListTile(leading: const GradientIcon(Icons.receipt_long, gOrange, size: 38), title: Text('${p['amount']} · ${p['period'] ?? ''}'), subtitle: Text(_s(p['invoice_no'])), trailing: StatusChip(p['status'] as String?))),
              ]),
              ListView(padding: const EdgeInsets.all(14), children: [
                if (_list(s, 'history').isEmpty) const EmptyState(Icons.history_edu, 'No previous academic sessions yet.'),
                for (final h in _list(s, 'history'))
                  Card(child: ListTile(leading: const GradientIcon(Icons.school_outlined, gTeal, size: 38), title: Text(_s(h['year'])), subtitle: Text('${h['class']}'), trailing: StatusChip(h['result'] as String?))),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}

/* ======================================================= Classes (card view) */
class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});
  static const _grads = [gBlue, gGreen, gPink, gOrange, gCyan, gViolet, gSlate, gRed];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Students', subtitle: 'Choose a class'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsScreen())),
          icon: const Icon(Icons.list_alt), label: const Text('All students'),
        ),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/classes'),
          builder: (context, d, _) {
            final list = _list(d, 'classes');
            final sm = (d['summary'] as Map?) ?? const {};
            return ListView(padding: const EdgeInsets.only(top: 14, bottom: 90), children: [
              StatStrip([
                StatCard('Active', '${sm['active'] ?? 0}', Icons.groups, gBlue, hint: '${sm['pending'] ?? 0} pending'),
                StatCard('Bus riders', '${sm['bus'] ?? 0}', Icons.directions_bus, gGreen),
                StatCard('Boarded today', '${sm['boarded'] ?? 0}', Icons.fact_check_outlined, gCyan),
                StatCard('Medical alerts', '${sm['medical'] ?? 0}', Icons.medical_information_outlined, gRed),
                StatCard('Fees due', inr(sm['dues'] as num?), Icons.currency_rupee, gOrange),
              ]),
              const SizedBox(height: 6),
              if (list.isEmpty) const EmptyState(Icons.groups, 'No students yet.'),
              for (var i = 0; i < list.length; i++) _ClassCard(list[i], _grads[i % _grads.length]),
            ]);
          },
        ),
      );
}

class _ClassCard extends StatelessWidget {
  final Map c;
  final List<Color> g;
  const _ClassCard(this.c, this.g);
  @override
  Widget build(BuildContext context) {
    final cls = _s(c['class']);
    final label = c['label'] != null ? _s(c['label']) : (cls.isEmpty ? 'No class' : (int.tryParse(cls) != null ? 'Grade $cls' : cls));
    final total = (c['total'] as int?) ?? 0, bus = (c['bus'] as int?) ?? 0, boarded = (c['boarded'] as int?) ?? 0;
    final boys = (c['boys'] as int?) ?? 0, girls = (c['girls'] as int?) ?? 0;
    final sections = ((c['sections'] is Map) ? (c['sections'] as Map) : const {}).entries.toList();
    void open([String? sec]) => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentsScreen(classFilter: cls, section: sec, classLabel: label)));
    Widget metric(IconData i, String l, String v, double? frac, Color col) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(children: [
            Row(children: [Icon(i, size: 15, color: kMuted), const SizedBox(width: 6), Text(l, style: const TextStyle(fontSize: 12, color: kMuted)), const Spacer(), Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))]),
            if (frac != null) Padding(padding: const EdgeInsets.only(top: 4), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0), minHeight: 5, backgroundColor: kLine, color: col))),
          ]),
        );
    return Card(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => open(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('${sections.length} section(s)${(c['pending'] ?? 0) > 0 ? ' · ${c['pending']} pending' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w300)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$total', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1)),
                const Text('STUDENTS', style: TextStyle(color: Colors.white70, fontSize: 9.5, letterSpacing: 1)),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in sections)
                  ActionChip(visualDensity: VisualDensity.compact, label: Text('${_s(e.key).isEmpty ? '—' : e.key}  ${e.value}', style: const TextStyle(fontSize: 11.5)), onPressed: () => open(_s(e.key))),
              ]),
              metric(Icons.wc, 'Boys / girls', '$boys / $girls', (boys + girls) == 0 ? null : boys / (boys + girls), kBlue),
              metric(Icons.directions_bus_outlined, 'Bus riders', '$bus (${total == 0 ? 0 : (bus * 100 / total).round()}%)', total == 0 ? 0 : bus / total, Colors.green),
              metric(Icons.fact_check_outlined, 'Boarded today', '$boarded / $bus', bus == 0 ? 0 : boarded / bus, kSky),
              const Divider(height: 20),
              Row(children: [
                Icon(Icons.currency_rupee, size: 15, color: (c['dues'] as num? ?? 0) > 0 ? Colors.red : kMuted),
                Text((c['dues'] as num? ?? 0) > 0 ? inr(c['dues'] as num) + ' due' : 'No dues', style: TextStyle(fontSize: 12, color: (c['dues'] as num? ?? 0) > 0 ? Colors.red : kMuted)),
                const Spacer(),
                Icon(Icons.medical_information_outlined, size: 15, color: (c['medical'] ?? 0) > 0 ? Colors.red : kMuted),
                Text(' ${c['medical'] ?? 0} medical', style: const TextStyle(fontSize: 12, color: kMuted)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/* ======================================================= Siblings */
class SiblingsScreen extends StatelessWidget {
  const SiblingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Siblings'),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/siblings'),
          builder: (context, d, _) {
            final list = _list(d, 'groups');
            return ListView(padding: const EdgeInsets.all(14), children: [
              if (list.isEmpty) const EmptyState(Icons.diversity_3, 'No sibling groups yet.'),
              for (final g in list)
                Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const GradientIcon(Icons.diversity_3, gPink, size: 36),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_s(g['family']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Parent: ${g['parent'] ?? '—'}', style: const TextStyle(fontSize: 11.5, color: kMuted)),
                      ])),
                    ]),
                    const Divider(height: 18),
                    for (final s in _list(g, 'students'))
                      Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                        Avatar(_s(s['name']), size: 26),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_s(s['name']))),
                        Text('${s['class']} · ${s['route'] ?? 'no bus'}', style: const TextStyle(fontSize: 11, color: kMuted)),
                      ])),
                  ]),
                )),
            ]);
          },
        ),
      );
}

/* ======================================================= Parents & staff */
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: dgBar('Parents & staff', bottom: dgTabs(const ['Parents', 'Staff'])),
          body: const TabBarView(children: [_PeopleTab('parent'), _PeopleTab('school_admin')]),
        ),
      );
}

class _PeopleTab extends StatefulWidget {
  final String role;
  const _PeopleTab(this.role);
  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> with AutomaticKeepAliveClientMixin {
  String q = '';
  int k = 0;
  @override
  bool get wantKeepAlive => true;

  Future<void> _reset(Map u) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('Reset password for ${u['name']}?'),
      content: const Text('A new password is generated, they are signed out of the app and it is emailed if an address is on file.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset'))],
    ));
    if (ok != true || !mounted) return;
    try {
      final r = await Api.I.post('/people/${u['id']}/reset-password');
      if (!mounted) return;
      await showDialog(context: context, builder: (c) => AlertDialog(
        icon: const Icon(Icons.key, color: kBlue),
        title: const Text('New credentials'),
        content: SelectableText('Login: ${r['login']}\nPassword: ${r['password']}\n\n${r['emailed'] == true ? 'Also emailed to them.' : 'Share these with them — no email was sent.'}'),
        actions: [
          TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: 'Login: ${r['login']}\nPassword: ${r['password']}')); Navigator.pop(c); }, child: const Text('Copy')),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
        ],
      ));
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _approve(Map u) async {
    try {
      final r = await Api.I.post('/people/${u['id']}/approve');
      if (!mounted) return;
      toast(context, _s(r['message']));
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      SearchBox(hint: 'Search name, email, User ID or phone', onSearch: (v) => setState(() => q = v)),
      Expanded(child: Loader<Map<String, dynamic>>(
        key: ValueKey('$q$k'),
        load: () => Api.I.get('/people', {'role': widget.role, if (q.isNotEmpty) 'q': q}),
        builder: (context, d, _) {
          final st = d['stats'] as Map;
          final list = _list(d, 'people');
          return ListView(padding: const EdgeInsets.only(top: 6, bottom: 30), children: [
            StatStrip([
              StatCard('Total', '${st['total']}', Icons.people_alt_outlined, gBlue),
              StatCard('Active', '${st['active']}', Icons.verified_user_outlined, gGreen),
              StatCard('Pending', '${st['pending']}', Icons.hourglass_top, gOrange),
              StatCard('App users · 30d', '${st['app30']}', Icons.phone_android, gViolet),
              StatCard('User-ID logins', '${st['userid']}', Icons.badge_outlined, gCyan),
            ]),
            const SizedBox(height: 8),
            if (list.isEmpty) const EmptyState(Icons.person_search, 'Nobody found.'),
            for (final u in list)
              Card(margin: const EdgeInsets.fromLTRB(14, 0, 14, 8), child: ListTile(
                leading: Avatar(_s(u['name'])),
                title: Text(_s(u['name'])),
                subtitle: Text('${u['login']}${u['phone'] != null ? ' · ${u['phone']}' : ''}\nLast app login: ${u['last_login']}'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'approve') _approve(u);
                    if (v == 'reset') _reset(u);
                    if (v == 'call') _call(u['phone'] as String?);
                    if (v == 'msg') Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(userId: u['id'] as int, name: _s(u['name']))));
                  },
                  itemBuilder: (_) => [
                    if (u['status'] == 'pending' && widget.role == 'parent') const PopupMenuItem(value: 'approve', child: Text('Approve')),
                    const PopupMenuItem(value: 'msg', child: Text('Message')),
                    if (u['phone'] != null) const PopupMenuItem(value: 'call', child: Text('Call')),
                    const PopupMenuItem(value: 'reset', child: Text('Reset password')),
                  ],
                  child: Padding(padding: const EdgeInsets.all(4), child: StatusChip(u['status'] as String?)),
                ),
              )),
          ]);
        },
      )),
    ]);
  }
}

/* ======================================================= Drivers */
class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Drivers'),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/drivers'),
          builder: (context, d, _) {
            final st = d['stats'] as Map;
            final list = _list(d, 'drivers');
            return ListView(padding: const EdgeInsets.only(top: 14, bottom: 30), children: [
              StatStrip([
                StatCard('Drivers', '${st['total']}', Icons.badge_outlined, gBlue),
                StatCard('On trip now', '${st['on_trip']}', Icons.satellite_alt, gGreen),
                StatCard('Assigned', '${st['assigned']}', Icons.alt_route, gTeal),
                StatCard('On leave', '${st['leave']}', Icons.beach_access_outlined, gOrange),
                StatCard('Licence ≤30d', '${st['expiring']}', Icons.warning_amber_rounded, gRed),
                StatCard('Avg experience', '${st['avg_exp']} y', Icons.workspace_premium_outlined, gViolet),
              ]),
              const SizedBox(height: 8),
              if (list.isEmpty) const EmptyState(Icons.badge_outlined, 'No drivers yet.'),
              for (final x in list)
                Card(margin: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Stack(children: [
                        Avatar(_s(x['name']), size: 44),
                        if (x['on_trip'] == true) Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                      ]),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_s(x['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${x['login'] ?? ''} · ${x['experience'] ?? 0} yrs${x['blood_group'] != null ? ' · ${x['blood_group']}' : ''}', style: const TextStyle(fontSize: 11.5, color: kMuted)),
                      ])),
                      StatusChip(x['status'] as String?),
                      if (x['phone'] != null) IconButton(icon: const Icon(Icons.call, color: Colors.green, size: 20), onPressed: () => _call(x['phone'] as String?)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ExpiryChip('Licence ${x['license_no'] ?? ''}', x['license_expiry'] as String?, x['license_days'] as int?),
                      for (final r in (x['routes'] as List)) Chip(avatar: const Icon(Icons.alt_route, size: 14), label: Text('$r'), visualDensity: VisualDensity.compact),
                    ]),
                  ]),
                )),
            ]);
          },
        ),
      );
}

/* ======================================================= Vehicles */
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Vehicles'),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/vehicles'),
          builder: (context, d, _) {
            final list = _list(d, 'vehicles');
            final expiring = list.where((v) => _list(v, 'docs').any((x) => x['days'] != null && (x['days'] as int) <= 30)).length;
            return ListView(padding: const EdgeInsets.only(top: 14, bottom: 30), children: [
              StatStrip([
                StatCard('Fleet', '${list.length}', Icons.directions_bus, gBlue),
                StatCard('Live now', '${list.where((v) => v['live'] == true).length}', Icons.satellite_alt, gGreen),
                StatCard('Docs due ≤30d', '$expiring', Icons.description_outlined, gRed),
                StatCard('Seats', '${list.fold<int>(0, (a, v) => a + ((v['capacity'] as int?) ?? 0))}', Icons.event_seat_outlined, gViolet),
              ]),
              const SizedBox(height: 8),
              if (list.isEmpty) const EmptyState(Icons.directions_bus, 'No vehicles yet.'),
              for (final v in list) VehicleCard(v),
            ]);
          },
        ),
      );
}

class VehicleCard extends StatelessWidget {
  final Map v;
  const VehicleCard(this.v, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GradientIcon(Icons.directions_bus_filled, v['live'] == true ? gGreen : gIndigo, size: 42),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_s(v['reg']), style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .5)),
                Text([v['model'], if (v['capacity'] != null) '${v['capacity']} seats', v['fuel']].where((e) => e != null && _s(e).trim().isNotEmpty).join(' · '), style: const TextStyle(fontSize: 11.5, color: kMuted)),
              ])),
              if (v['live'] == true) const StatusChip('live') else if (v['status'] != null) StatusChip(v['status'] as String?),
            ]),
            if ((v['assigned'] as List?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 6), child: Text('🧭 ${(v['assigned'] as List).join(', ')}', style: const TextStyle(fontSize: 12))),
            if (v['puc_no'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('PUC certificate: ${v['puc_no']}', style: const TextStyle(fontSize: 11.5, color: kMuted))),
            if (v['gps'] is Map)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon((v['gps'] as Map)['mode'] == 'none' ? Icons.phone_android : Icons.satellite_alt, size: 16, color: kBlue),
                  const SizedBox(width: 8),
                  Expanded(child: Text((v['gps'] as Map)['mode'] == 'none' ? 'GPS: driver app' : _s((v['gps'] as Map)['provider']), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  if ((v['gps'] as Map)['mode'] != 'none')
                    Text((v['gps'] as Map)['online'] == true ? '● online' : ((v['gps'] as Map)['error'] != null ? '⚠ error' : (_s((v['gps'] as Map)['last_seen']).isEmpty ? 'waiting' : _s((v['gps'] as Map)['last_seen']))),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (v['gps'] as Map)['online'] == true ? Colors.green : ((v['gps'] as Map)['error'] != null ? Colors.red : kMuted))),
                ]),
              ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final x in _list(v, 'docs')) ExpiryChip(_s(x['label']), x['date'] as String?, x['days'] as int?)]),
          ]),
        ),
      );
}

/* ======================================================= Routes & stops */
class BusRoutesScreen extends StatefulWidget {
  const BusRoutesScreen({super.key});
  @override
  State<BusRoutesScreen> createState() => _BusRoutesScreenState();
}

class _BusRoutesScreenState extends State<BusRoutesScreen> {
  int k = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Routes & stops'),
        body: Loader<Map<String, dynamic>>(
          key: ValueKey(k),
          load: () => Api.I.get('/bus-routes'),
          builder: (context, d, _) {
            final list = _list(d, 'routes');
            return ListView(padding: const EdgeInsets.all(14), children: [
              if (list.isEmpty) const EmptyState(Icons.alt_route, 'No routes yet.'),
              for (final r in list)
                Card(clipBehavior: Clip.antiAlias, child: ExpansionTile(
                  shape: const Border(),
                  leading: GradientIcon(Icons.alt_route, [hexColor(r['color'] as String?), hexColor(r['color'] as String?).withValues(alpha: .6)], size: 40),
                  title: Text(_s(r['name'])),
                  subtitle: Text('${r['students']} students · ${(r['stops'] as List).length} stops · ${r['fare']}\n${r['driver'] ?? 'No driver'} · ${r['vehicle'] ?? 'no bus'}'),
                  children: [
                    SwitchListTile(
                      dense: true,
                      title: const Text('Live tracking for parents'),
                      value: r['tracking'] == true,
                      onChanged: (_) async {
                        try {
                          await Api.I.post('/bus-routes/${r['id']}/tracking');
                          setState(() => k++);
                        } catch (e) {
                          if (context.mounted) toast(context, errText(e), error: true);
                        }
                      },
                    ),
                    for (final s in _list(r, 'stops'))
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(radius: 12, backgroundColor: hexColor(r['color'] as String?).withValues(alpha: .15), child: Text('${s['seq']}', style: TextStyle(fontSize: 10.5, color: hexColor(r['color'] as String?), fontWeight: FontWeight.w700))),
                        title: Text(_s(s['name'])),
                        subtitle: Text('Pickup ${s['pickup'] ?? '—'} · Drop ${s['drop'] ?? '—'}'),
                        trailing: s['lat'] != null ? IconButton(icon: const Icon(Icons.map_outlined, size: 19), onPressed: () => launchUrl(Uri.parse('https://www.openstreetmap.org/?mlat=${s['lat']}&mlon=${s['lng']}#map=17/${s['lat']}/${s['lng']}'), mode: LaunchMode.externalApplication)) : null,
                      ),
                    const SizedBox(height: 8),
                  ],
                )),
            ]);
          },
        ),
      );
}

/* ======================================================= Assignments */
class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Assignments'),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/assignments'),
          builder: (context, d, _) {
            final list = _list(d, 'assignments');
            return ListView(padding: const EdgeInsets.all(14), children: [
              if (list.isEmpty) const EmptyState(Icons.link, 'No assignments yet.'),
              for (final a in list)
                Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(width: 5, height: 58, decoration: BoxDecoration(color: hexColor(a['color'] as String?), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(a['route']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('👤 ${a['driver'] ?? '—'}   🚌 ${a['vehicle'] ?? '—'}', style: const TextStyle(fontSize: 12)),
                      if (_s(a['helper']).trim().isNotEmpty) Text('Helper: ${a['helper']}', style: const TextStyle(fontSize: 11.5, color: kMuted)),
                      Text('Shift: ${a['shift'] ?? 'both'}', style: const TextStyle(fontSize: 11.5, color: kMuted)),
                    ])),
                    Column(children: [
                      StatusChip(a['active'] == true ? 'active' : 'ended'),
                      if (a['phone'] != null) IconButton(icon: const Icon(Icons.call, color: Colors.green, size: 20), onPressed: () => _call(a['phone'] as String?)),
                    ]),
                  ]),
                )),
            ]);
          },
        ),
      );
}

/* ======================================================= RFID & cards */
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});
  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  int k = 0;
  String q = '';

  Future<void> _testTap(List<Map> readers) async {
    if (readers.isEmpty) return toast(context, 'Add a reader on the web dashboard first.', error: true);
    int reader = readers.first['id'] as int;
    final uid = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(c).viewInsets.bottom + 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Test a card tap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Text('Runs exactly like a real reader: marks attendance and alerts parents.', style: TextStyle(fontSize: 12, color: kMuted)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: reader,
            decoration: const InputDecoration(labelText: 'Reader'),
            items: [for (final r in readers) DropdownMenuItem(value: r['id'] as int, child: Text(_s(r['name']), overflow: TextOverflow.ellipsis))],
            onChanged: (v) => set(() => reader = v ?? reader),
          ),
          const SizedBox(height: 10),
          TextField(controller: uid, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Card UID')),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.contactless), label: const Text('Tap')),
        ]),
      )),
    );
    if (ok != true || uid.text.trim().isEmpty) return;
    try {
      final r = await Api.I.post('/cards/simulate', {'reader_id': reader, 'uid': uid.text.trim()});
      if (!mounted) return;
      toast(context, '${_s(r['action']).toUpperCase()} — ${r['message']}', error: r['ok'] != true);
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _status(Map c, String st) async {
    try {
      await Api.I.post('/cards/${c['id']}/status', {'status': st});
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      key: ValueKey('$k$q'),
      load: () => Api.I.get('/cards', q.isEmpty ? null : {'q': q}),
      builder: (context, d, _) {
        final st = d['stats'] as Map;
        final readers = _list(d, 'readers');
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: dgBar('RFID & cards', bottom: dgTabs(const ['Cards', 'Readers', 'Taps'])),
            floatingActionButton: FloatingActionButton.extended(onPressed: () => _testTap(readers), icon: const Icon(Icons.contactless), label: const Text('Test tap')),
            body: Column(children: [
              const SizedBox(height: 12),
              StatStrip([
                StatCard('Active cards', '${st['active']}', Icons.credit_card, gBlue),
                StatCard('Blocked / lost', '${st['blocked']}', Icons.block, gRed),
                StatCard('Readers online', '${st['online']}/${st['readers']}', Icons.sensors, gGreen),
                StatCard('Taps today', '${st['taps_today']}', Icons.touch_app_outlined, gViolet),
              ]),
              Expanded(child: TabBarView(children: [
                ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                  SearchBox(hint: 'Search card UID', onSearch: (v) => setState(() => q = v)),
                  for (final c in _list(d, 'cards'))
                    ListTile(
                      leading: GradientIcon(c['type'] == 'qr' ? Icons.qr_code_2 : Icons.contactless_outlined, c['status'] == 'active' ? gBlue : gSlate, size: 38),
                      title: Text(_s(c['holder']).isEmpty ? 'Unassigned' : _s(c['holder'])),
                      subtitle: Text('${c['uid']} · ${_s(c['type']).toUpperCase()}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => _status(c, v),
                        itemBuilder: (_) => const [PopupMenuItem(value: 'active', child: Text('Activate')), PopupMenuItem(value: 'blocked', child: Text('Block')), PopupMenuItem(value: 'lost', child: Text('Mark lost'))],
                        child: StatusChip(c['status'] as String?),
                      ),
                    ),
                ]),
                ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 90), children: [
                  if (readers.isEmpty) const EmptyState(Icons.sensors_off, 'No readers yet. Add them on the web dashboard.'),
                  for (final r in readers)
                    Card(child: ListTile(
                      leading: GradientIcon(Icons.sensors, r['online'] == true ? gGreen : gSlate, size: 38),
                      title: Text(_s(r['name'])),
                      subtitle: Text('${_s(r['type']).toUpperCase()} · ${r['location']} · seen ${r['seen']}'),
                      trailing: StatusChip(r['online'] == true ? 'online' : 'offline'),
                    )),
                ]),
                ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                  if (_list(d, 'taps').isEmpty) const EmptyState(Icons.touch_app_outlined, 'No taps yet.'),
                  for (final t in _list(d, 'taps'))
                    ListTile(
                      dense: true,
                      leading: StatusChip(t['action'] as String?),
                      title: Text(_s(t['holder']).isEmpty ? _s(t['uid']) : '${t['holder']}'),
                      subtitle: Text('${t['reader'] ?? ''} · ${t['at']}${t['note'] != null ? '\n${t['note']}' : ''}'),
                    ),
                ]),
              ])),
            ]),
          ),
        );
      },
    );
  }
}

/* ======================================================= Academic year */
class YearsScreen extends StatelessWidget {
  const YearsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Academic year'),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/academic-years'),
          builder: (context, d, _) {
            final list = _list(d, 'years');
            return ListView(padding: const EdgeInsets.all(14), children: [
              Card(color: const Color(0xFFEEF2FF), child: const ListTile(
                leading: Icon(Icons.info_outline, color: kBlue),
                title: Text('Year-end rollover'),
                subtitle: Text('Promote students into a new session from the web dashboard (Academic Year → Rollover). Attendance, trips and fees stay here as history.'),
              )),
              for (final y in list)
                Card(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      GradientIcon(Icons.calendar_month, y['current'] == true ? gBlue : gSlate, size: 40),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_s(y['name']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('${y['starts'] ?? ''} – ${y['ends'] ?? ''}', style: const TextStyle(fontSize: 11.5, color: kMuted)),
                      ])),
                      if (y['current'] == true) const StatusChip('current'),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      _mini('Attendance', '${y['attendance']}'),
                      _mini('Trips', '${y['trips']}'),
                      _mini('Billed', _s(y['billed'])),
                      _mini('Paid', _s(y['paid'])),
                    ]),
                    if ((y['results'] as Map?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: [for (final e in (y['results'] as Map).entries) Chip(label: Text('${e.value} ${e.key}'), visualDensity: VisualDensity.compact)]),
                    ],
                  ]),
                )),
            ]);
          },
        ),
      );

  Widget _mini(String l, String v) => Expanded(child: Column(children: [
        FittedBox(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(l, style: const TextStyle(fontSize: 10.5, color: kMuted)),
      ]));
}

/* ======================================================= Audit log (who changed what — old → new, sign-ins, exports, security) */
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: dgBar('Audit log', subtitle: 'Kept for 365 days', bottom: dgTabs(const ['Changes', 'Sign-ins', 'Security'])),
          body: const TabBarView(children: [_LogTab('activity'), _LogTab('logins'), _LogTab('security')]),
        ),
      );
}

void _showChanges(BuildContext context, Map l) {
  final ch = (l['changes'] is Map ? l['changes'] as Map : const {});
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
          Text('${l['detail'] ?? l['action']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text('${l['who']} · ${l['at']} · ${l['device']}', style: const TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 10),
          for (final e in ch.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e.key}'.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text('Old: ${(e.value is List && (e.value as List).isNotEmpty ? (e.value as List)[0] : null) ?? '—'}', style: const TextStyle(color: Color(0xFFC92A2A), fontSize: 12.5)),
                Text('New: ${(e.value is List && (e.value as List).length > 1 ? (e.value as List)[1] : null) ?? '—'}', style: const TextStyle(color: Color(0xFF2B8A3E), fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      ),
    ),
  );
}

class _LogTab extends StatelessWidget {
  final String tab;
  const _LogTab(this.tab);
  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () => Api.I.get('/logs', {'tab': tab}),
        builder: (context, d, _) {
          final list = _list(d, 'logs');
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.isEmpty ? 1 : list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 66),
            itemBuilder: (_, i) {
              if (list.isEmpty) return const EmptyState(Icons.history, 'Nothing logged yet.');
              final l = list[i];
              final failed = l['failed'] == true;
              final hasChanges = l['changes'] is Map && (l['changes'] as Map).isNotEmpty;
              return ListTile(
                onTap: hasChanges ? () => _showChanges(context, l) : null,
                leading: GradientIcon(failed ? Icons.gpp_bad_outlined : (tab == 'logins' ? Icons.login : Icons.history), failed ? gRed : (tab == 'logins' ? gGreen : gBlue), size: 36),
                title: Text('${l['who']} · ${l['action']}'),
                subtitle: Text('${l['detail'] ?? ''}\n${l['device']} · ${l['ip'] ?? ''} · ${l['at']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_s(l['ago']), style: const TextStyle(fontSize: 10, color: kMuted)),
                  if (hasChanges) const Icon(Icons.compare_arrows, size: 18, color: kBlue),
                ]),
              );
            },
          );
        },
      );
}

/* ======================================================= Reports */
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  static const icons = {'students': Icons.groups, 'attendance': Icons.fact_check, 'payments': Icons.currency_rupee, 'routes': Icons.alt_route, 'vehicles': Icons.directions_bus, 'drivers': Icons.badge_outlined};
  static const grads = [gBlue, gGreen, gOrange, gTeal, gViolet, gPink];

  @override
  Widget build(BuildContext context) {
    final iso = DateFormat('yyyy-MM-dd');
    final f = DateFormat('d MMM');
    return Scaffold(
      appBar: dgBar('Reports'),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(range),
        load: () => Api.I.get('/reports', {'from': iso.format(range.start), 'to': iso.format(range.end)}),
        builder: (context, d, _) {
          final list = _list(d, 'reports');
          return ListView(padding: const EdgeInsets.all(14), children: [
            OutlinedButton.icon(
              onPressed: () async {
                final r = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), initialDateRange: range);
                if (r != null) setState(() => range = r);
              },
              icon: const Icon(Icons.date_range),
              label: Text('Attendance & payments: ${f.format(range.start)} – ${f.format(range.end)}'),
            ),
            const SizedBox(height: 6),
            const Text('Each download is a CSV (opens in Excel / Google Sheets). Links work for 15 minutes.', style: TextStyle(fontSize: 11.5, color: kMuted)),
            const SizedBox(height: 10),
            for (var i = 0; i < list.length; i++)
              Card(child: ListTile(
                leading: GradientIcon(icons[list[i]['key']] ?? Icons.table_chart, grads[i % grads.length], size: 40),
                title: Text(_s(list[i]['title'])),
                subtitle: Text(_s(list[i]['desc'])),
                trailing: const Icon(Icons.download_rounded, color: kBlue),
                onTap: () => launchUrl(Uri.parse(_s(list[i]['url'])), mode: LaunchMode.externalApplication),
              )),
          ]);
        },
      ),
    );
  }
}

/* ======================================================= Invoice with installments */
class InvoiceScreen extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  const InvoiceScreen({super.key, this.studentId, this.studentName});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  int? sid;
  String? sname;
  final amount = TextEditingController();
  final desc = TextEditingController();
  late DateTime period = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime due = DateTime.now().add(const Duration(days: 10));
  int installments = 1;
  bool busy = false;
  List<Map>? created;

  @override
  void initState() {
    super.initState();
    sid = widget.studentId;
    sname = widget.studentName;
  }

  Future<void> _pickStudent() async {
    final picked = await showModalBottomSheet<Map>(context: context, isScrollControlled: true, builder: (_) => const _StudentPicker());
    if (picked != null) setState(() { sid = picked['id'] as int; sname = _s(picked['name']); });
  }

  /// Same split the server uses: equal parts, last one absorbs the rounding.
  List<double> get split {
    final total = double.tryParse(amount.text) ?? 0;
    if (total <= 0) return [];
    final each = (total / installments * 100).floorToDouble() / 100;
    return [for (var i = 0; i < installments; i++) i == installments - 1 ? double.parse((total - each * (installments - 1)).toStringAsFixed(2)) : each];
  }

  Future<void> _submit() async {
    if (sid == null) return toast(context, 'Choose a student.', error: true);
    if ((double.tryParse(amount.text) ?? 0) <= 0) return toast(context, 'Enter the amount.', error: true);
    setState(() => busy = true);
    try {
      final r = await Api.I.post('/invoices', {
        'student_id': sid, 'amount': double.parse(amount.text), 'period': DateFormat('yyyy-MM').format(period),
        'due_date': DateFormat('yyyy-MM-dd').format(due), 'description': desc.text.trim(), 'installments': installments,
      });
      setState(() => created = _list(r, 'invoices'));
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = [for (var i = -2; i < 12; i++) DateTime(DateTime.now().year, DateTime.now().month + i)];
    final mf = DateFormat('MMM yyyy');
    if (created != null) {
      return Scaffold(
        appBar: dgBar('Invoice created'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Center(child: GradientIcon(Icons.check_rounded, gGreen, size: 70)),
          const SizedBox(height: 12),
          Center(child: Text('${created!.length} invoice(s) for $sname', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          const Center(child: Text('Parents have been notified in the app.', style: TextStyle(color: kMuted))),
          const SizedBox(height: 14),
          for (final p in created!) Card(child: ListTile(title: Text(_s(p['description'])), subtitle: Text('${p['invoice_no']} · due ${p['due']}'), trailing: Text(_s(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)))),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ]),
      );
    }
    final parts = split;
    return Scaffold(
      appBar: dgBar('New invoice'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(
          leading: sname == null ? const GradientIcon(Icons.person_search, gBlue, size: 38) : Avatar(sname!),
          title: Text(sname ?? 'Choose a student'),
          subtitle: const Text('Tap to change'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickStudent,
        )),
        const SizedBox(height: 8),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Total amount (₹)', prefixIcon: Icon(Icons.currency_rupee))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<DateTime>(
            initialValue: months.firstWhere((m) => m == period, orElse: () => months[2]),
            decoration: const InputDecoration(labelText: 'Billing period'),
            items: [for (final m in months) DropdownMenuItem(value: m, child: Text(mf.format(m)))],
            onChanged: (v) => setState(() => period = v ?? period),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: due, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now().add(const Duration(days: 400)));
              if (d != null) setState(() => due = d);
            },
            icon: const Icon(Icons.event, size: 18),
            label: Text('Due ${DateFormat('d MMM').format(due)}'),
          )),
        ]),
        const SizedBox(height: 10),
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'Transport fee …')),
        const SectionTitle('Installments'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in const [1, 2, 3, 4, 6, 10, 12])
            ChoiceChip(label: Text(n == 1 ? 'Single' : '$n months'), selected: installments == n, onSelected: (_) => setState(() => installments = n)),
        ]),
        if (installments > 1 && parts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Each installment is billed as its own invoice, so parents can pay them one at a time.', style: TextStyle(fontSize: 11.5, color: kMuted)),
              const SizedBox(height: 6),
              for (var i = 0; i < parts.length; i++)
                Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
                  Text('Installment ${i + 1}/${parts.length}', style: const TextStyle(fontSize: 12.5)),
                  const Spacer(),
                  Text(mf.format(DateTime(period.year, period.month + i)), style: const TextStyle(fontSize: 11.5, color: kMuted)),
                  const SizedBox(width: 12),
                  Text('₹${parts[i].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ])),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: busy ? null : _submit, icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send), label: Text(installments > 1 ? 'Create $installments invoices' : 'Create invoice')),
      ]),
    );
  }
}

class _StudentPicker extends StatefulWidget {
  const _StudentPicker();
  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.of(context).size.height * .8,
        child: Column(children: [
          SearchBox(hint: 'Search student', onSearch: (v) => setState(() => q = v)),
          Expanded(child: Loader<Map<String, dynamic>>(
            key: ValueKey(q),
            load: () => Api.I.get('/students', q.isEmpty ? null : {'q': q}),
            builder: (context, d, _) => ListView(children: [
              for (final s in _list(d, 'students'))
                ListTile(leading: Avatar(_s(s['name']), size: 34), title: Text(_s(s['name'])), subtitle: Text('${s['class']} · ${s['route'] ?? 'no bus'}'), onTap: () => Navigator.pop(context, s)),
            ]),
          )),
        ]),
      );
}

/* ======================================================= Schools (platform admin) */
class SchoolsScreen extends StatelessWidget {
  final VoidCallback? onEntered;
  const SchoolsScreen({super.key, this.onEntered});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar('Schools'),
        body: Loader<Map<String, dynamic>>(
          load: () => Api.I.get('/schools'),
          builder: (context, d, _) {
            final list = _list(d, 'schools');
            return ListView(padding: const EdgeInsets.all(14), children: [
              StatStrip([
                StatCard('Schools', '${list.length}', Icons.apartment, gBlue),
                StatCard('Active', '${list.where((s) => s['status'] == 'active').length}', Icons.verified, gGreen),
                StatCard('Students', '${list.fold<int>(0, (a, s) => a + (s['students'] as int))}', Icons.groups, gOrange),
              ]),
              const SizedBox(height: 10),
              for (final s in list)
                Card(child: ListTile(
                  leading: Avatar(_s(s['name']), size: 42),
                  title: Text(_s(s['name'])),
                  subtitle: Text('${s['code']} · ${s['city'] ?? ''}\n${s['students']} students · ${s['users']} users'),
                  isThreeLine: true,
                  trailing: FilledButton.tonal(
                    onPressed: s['status'] == 'active' ? () async {
                      await Api.I.setSchool(s['id'] as int, _s(s['name']));
                      onEntered?.call();
                      if (context.mounted) Navigator.pop(context);
                    } : null,
                    child: Text(Api.I.schoolId == s['id'] ? 'Current' : 'Enter'),
                  ),
                )),
            ]);
          },
        ),
      );
}
