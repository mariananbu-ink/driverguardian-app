import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../ui.dart';

// Attendance — calendar view (v2.3).
// Developed & Powered by Marian Anbu Juwan

const cPresent = Color(0xFF16A34A);
const cAbsent = Color(0xFFDC2626);
const cLate = Color(0xFFF59E0B);
const cLeave = Color(0xFF7C3AED);

Color statusColor(String? s) => switch (s) {
      'present' => cPresent,
      'absent' => cAbsent,
      'late' => cLate,
      'leave' => cLeave,
      _ => kMuted,
    };

String statusLabel(String? s) => switch (s) {
      'present' => 'Present',
      'absent' => 'Absent',
      'late' => 'Late',
      'leave' => 'Leave',
      _ => 'No trip',
    };

final _ym = DateFormat('yyyy-MM');
final _iso = DateFormat('yyyy-MM-dd');

/// Percentage ring.
class AttRing extends StatelessWidget {
  final int pct;
  final String caption;
  final double size;
  final Color color;
  const AttRing({super.key, required this.pct, this.caption = 'present', this.size = 132, this.color = kBlue});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(pct / 100, color),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$pct%', style: TextStyle(fontSize: size * .2, fontWeight: FontWeight.w800, color: kInk)),
            Text(caption, style: const TextStyle(fontSize: 12, color: kMuted)),
          ])),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  _RingPainter(this.v, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .11;
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = const Color(0xFFE7EAF7));
    if (v > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v.clamp(0, 1), false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}

/// Coloured count tile (Present / Absent / Late / Leave).
class AttTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const AttTile(this.label, this.value, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500)),
        ]),
      );
}

/// Month navigation: ‹  October 2026 ▾  ›  + jump-to-date.
class MonthNav extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime>? onDate;
  const MonthNav({super.key, required this.month, required this.onMonth, this.onDate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canNext = DateTime(month.year, month.month + 1).isBefore(DateTime(now.year, now.month + 1));
    return Row(children: [
      Expanded(child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final m = await pickMonth(context, month);
          if (m != null) onMonth(m);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(children: [
            Text(DateFormat('MMMM yyyy').format(month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Icon(Icons.arrow_drop_down, color: kMuted),
          ]),
        ),
      )),
      if (onDate != null)
        IconButton(
          tooltip: 'Jump to a date',
          icon: const Icon(Icons.event_outlined),
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: month.isAfter(now) ? now : DateTime(month.year, month.month, month.month == now.month && month.year == now.year ? now.day : 1), firstDate: DateTime(2023), lastDate: now);
            if (d != null) onDate!(d);
          },
        ),
      _navBtn(Icons.chevron_left, () => onMonth(DateTime(month.year, month.month - 1))),
      const SizedBox(width: 6),
      _navBtn(Icons.chevron_right, canNext ? () => onMonth(DateTime(month.year, month.month + 1)) : null),
    ]);
  }

  Widget _navBtn(IconData i, VoidCallback? on) => SizedBox(
        width: 38,
        height: 38,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: on,
          child: Icon(i, size: 20),
        ),
      );
}

/// Month + year picker sheet.
Future<DateTime?> pickMonth(BuildContext context, DateTime current) {
  int year = current.year;
  final now = DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(onPressed: () => set(() => year--), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text('$year', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          IconButton(onPressed: year < now.year ? () => set(() => year++) : null, icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var m = 1; m <= 12; m++)
              Builder(builder: (_) {
                final d = DateTime(year, m);
                final sel = year == current.year && m == current.month;
                final future = d.isAfter(DateTime(now.year, now.month));
                return Material(
                  color: sel ? kBlue : const Color(0xFFF1F3F9),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: future ? null : () => Navigator.pop(c, d),
                    child: Center(child: Text(DateFormat('MMM').format(d), style: TextStyle(fontWeight: FontWeight.w600, color: sel ? Colors.white : (future ? Colors.black26 : kInk)))),
                  ),
                );
              }),
          ],
        ),
      ]),
    )),
  );
}

/// 7-column month grid (Mon first). [cell] decides colours / sub-label per day map.
class MonthGrid extends StatelessWidget {
  final List<Map> days;
  final String? selected;
  final ValueChanged<Map>? onTap;
  final ({Color bg, Color fg, String? sub}) Function(Map d) cell;
  const MonthGrid({super.key, required this.days, required this.cell, this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final lead = ((days.first['dow'] as num?) ?? 1).toInt() - 1;
    final cells = <Widget>[
      for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Center(child: Text(w, style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600))),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final d in days) _day(d),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }

  Widget _day(Map d) {
    final future = d['future'] == true;
    final today = d['today'] == true;
    final sel = d['date'] == selected;
    final c = cell(d);
    return Material(
      color: future ? Colors.transparent : c.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: future || onTap == null ? null : () => onTap!(d),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: sel ? Border.all(color: kBlue, width: 2) : (today ? Border.all(color: kBlue.withValues(alpha: .5), width: 1.5) : null),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${d['day']}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: future ? Colors.black26 : c.fg)),
            if (c.sub != null && !future) Text(c.sub!, style: TextStyle(fontSize: 8.5, color: c.fg, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Map<String, Color> items;
  const _Legend(this.items);
  @override
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 6, children: [
        for (final e in items.entries)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(e.key, style: const TextStyle(fontSize: 12, color: kMuted)),
          ]),
      ]);
}

Widget _card(Widget child, {EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
      child: child,
    );

/// Parent (or admin for one student): ring, tiles, month calendar, day by day.
class ChildAttendanceScreen extends StatefulWidget {
  final int? studentId;
  const ChildAttendanceScreen({super.key, this.studentId});
  @override
  State<ChildAttendanceScreen> createState() => _ChildAttendanceScreenState();
}

class _ChildAttendanceScreenState extends State<ChildAttendanceScreen> {
  int reloadKey = 0;
  int? kid;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String? selected;

  @override
  void initState() {
    super.initState();
    kid = widget.studentId;
  }

  Future<Map<String, dynamic>> _load() async {
    final q = <String, String>{'month': _ym.format(month)};
    if (kid != null) q['student_id'] = '$kid';
    final cal = await Api.I.get('/attendance/calendar', q);
    Map<String, dynamic> extra = const {};
    if (Api.I.user?['role'] == 'parent') {
      try {
        extra = await Api.I.get('/attendance/child');
      } catch (_) {}
    }
    return {...cal, 'leaves': extra['leaves'] ?? const []};
  }

  Future<void> _leave(List<Map> kids) async {
    if (kids.isEmpty) return;
    int k = kid ?? kids.first['id'] as int;
    DateTime from = DateTime.now();
    DateTime to = DateTime.now();
    final reason = TextEditingController();
    final f = DateFormat('d MMM yyyy');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Child won’t take the bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: k,
            decoration: const InputDecoration(labelText: 'Child'),
            items: [for (final x in kids) DropdownMenuItem(value: x['id'] as int, child: Text(x['name'] as String))],
            onChanged: (v) => set(() => k = v ?? k),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () async {
              final d = await showDatePicker(context: c, initialDate: from, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 120)));
              if (d != null) set(() { from = d; if (to.isBefore(from)) to = from; });
            }, child: Text('From ${f.format(from)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () async {
              final d = await showDatePicker(context: c, initialDate: to, firstDate: from, lastDate: DateTime.now().add(const Duration(days: 120)));
              if (d != null) set(() => to = d);
            }, child: Text('To ${f.format(to)}'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason (optional)')),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Inform driver & school')),
        ]),
      )),
    );
    if (ok != true) return;
    try {
      final r = await Api.I.post('/attendance/leave', {'student_id': k, 'from_date': _iso.format(from), 'to_date': _iso.format(to), 'reason': reason.text.trim()});
      if (!mounted) return;
      toast(context, r['message']?.toString() ?? 'Saved');
      setState(() => reloadKey++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  void _goMonth(DateTime m) => setState(() { month = DateTime(m.year, m.month); selected = null; });
  void _goDate(DateTime d) => setState(() { month = DateTime(d.year, d.month); selected = _iso.format(d); });

  @override
  Widget build(BuildContext context) {
    final parent = Api.I.user?['role'] == 'parent';
    return Scaffold(
      appBar: dgBar('Attendance'),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey('$reloadKey-$kid-${_ym.format(month)}'),
        load: _load,
        builder: (context, d, _) {
          final kids = ((d['children'] as List?) ?? const []).cast<Map>();
          if (d['calendar'] == null && d['student'] == null) {
            return ListView(children: const [EmptyState(Icons.child_care, 'No child linked to your account yet.')]);
          }
          final days = (d['days'] as List).cast<Map>();
          final counts = (d['counts'] as Map?) ?? const {};
          final sess = (d['session'] as Map?) ?? const {};
          final st = d['student'] as Map;
          final leaves = ((d['leaves'] as List?) ?? const []).cast<Map>().where((l) => l['student_id'] == st['id']).toList();
          final sel = selected == null ? null : days.cast<Map?>().firstWhere((x) => x?['date'] == selected, orElse: () => null);
          final history = days.where((x) => x['status'] != null && x['future'] != true).toList().reversed.toList();
          final f = DateFormat('EEE, d MMM');

          return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 24), children: [
            if (parent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kYellow, foregroundColor: kInk),
                  onPressed: () => _leave(kids),
                  icon: const Icon(Icons.event_busy),
                  label: const Text('Child won’t take the bus'),
                ),
              ),
            if (kids.length > 1)
              SizedBox(
                height: 42,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final k in kids)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: kBlue, child: Text(initials(k['name'] as String), style: const TextStyle(fontSize: 9, color: Colors.white))),
                        label: Text(k['name'] as String),
                        selected: k['id'] == st['id'],
                        onSelected: (_) => setState(() { kid = k['id'] as int; selected = null; }),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 8),
            // ring + tiles
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AttRing(pct: (sess['pct'] as num? ?? 0).toInt()),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(st['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('${st['class'] ?? ''}${st['stop'] != null ? ' · ${st['stop']}' : ''}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Text('${sess['attended'] ?? 0} of ${sess['total'] ?? 0} days this session${sess['name'] != null ? ' (${sess['name']})' : ''}', style: const TextStyle(fontSize: 12.5)),
                ])),
              ]),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  AttTile('Present', (counts['present'] as num? ?? 0).toInt(), cPresent),
                  AttTile('Absent', (counts['absent'] as num? ?? 0).toInt(), cAbsent),
                  AttTile('Late', (counts['late'] as num? ?? 0).toInt(), cLate),
                  AttTile('Leave', (counts['leave'] as num? ?? 0).toInt(), cLeave),
                ],
              ),
              const SizedBox(height: 8),
              Text('${d['month_label']} · ${d['month_pct']}% attendance this month', style: const TextStyle(fontSize: 12, color: kMuted)),
            ])),
            // calendar
            MonthNav(month: month, onMonth: _goMonth, onDate: _goDate),
            const SizedBox(height: 6),
            _card(Column(children: [
              MonthGrid(
                days: days,
                selected: selected,
                onTap: (x) => setState(() => selected = selected == x['date'] ? null : x['date'] as String),
                cell: (x) {
                  final s = x['status'] as String?;
                  return s == null ? (bg: const Color(0xFFF1F3F9), fg: kInk, sub: null) : (bg: statusColor(s).withValues(alpha: .14), fg: statusColor(s), sub: null);
                },
              ),
              const SizedBox(height: 12),
              const _Legend({'Present': cPresent, 'Absent': cAbsent, 'Late': cLate, 'Leave': cLeave}),
            ]), padding: const EdgeInsets.fromLTRB(12, 14, 12, 14)),
            if (sel != null) _dayCard(sel),
            const SectionTitle('Day by day'),
            if (history.isEmpty) const EmptyState(Icons.event_available, 'No trips recorded this month.'),
            if (history.isNotEmpty)
              _card(Column(children: [
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: kLine),
                  InkWell(
                    onTap: () => setState(() => selected = history[i]['date'] as String),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.format(DateTime.parse(history[i]['date'] as String)), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(_times(history[i]), style: const TextStyle(fontSize: 12, color: kMuted)),
                        ])),
                        _pill(history[i]['status'] as String?),
                      ]),
                    ),
                  ),
                ],
              ]), padding: EdgeInsets.zero),
            if (leaves.isNotEmpty) ...[
              const SectionTitle('Leave requests'),
              for (final l in leaves)
                Card(child: ListTile(
                  leading: const Icon(Icons.event_busy, color: cLeave),
                  title: Text('${l['from']} → ${l['to']}'),
                  subtitle: (l['reason'] ?? '').toString().isEmpty ? null : Text('${l['reason']}'),
                  trailing: StatusChip(l['status'] as String?),
                )),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('“Late” means boarding more than ${d['grace'] ?? 10} minutes after the stop’s pickup time${st['pickup'] != null ? ' (${st['pickup']})' : ''}.', style: const TextStyle(fontSize: 11.5, color: kMuted)),
            ),
          ]);
        },
      ),
    );
  }

  String _times(Map x) {
    final p = x['pickup'] as Map?;
    final dr = x['drop'] as Map?;
    final parts = <String>[
      if (p?['boarded'] != null) '↑ ${p!['boarded']}',
      if (dr?['dropped'] != null) '↓ ${dr!['dropped']}',
    ];
    if (parts.isEmpty) return x['status'] == 'leave' ? 'On leave' : (x['status'] == 'absent' ? 'Did not board' : '');
    return parts.join('   ');
  }

  Widget _pill(String? s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: statusColor(s).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(statusLabel(s), style: TextStyle(color: statusColor(s), fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _dayCard(Map x) {
    final p = x['pickup'] as Map?;
    final dr = x['drop'] as Map?;
    Widget row(String label, IconData icon, Map? r, String key) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Icon(icon, size: 18, color: kMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (r == null)
              const Text('—', style: TextStyle(color: kMuted))
            else ...[
              Text('${r[key] ?? r['time'] ?? ''}', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 8),
              StatusChip(r['status'] as String?),
            ],
          ]),
        );
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(x['date'] as String)), style: const TextStyle(fontWeight: FontWeight.w700))),
        _pill(x['status'] as String?),
      ]),
      row('Morning pickup', Icons.wb_sunny_outlined, p, 'boarded'),
      row('Afternoon drop', Icons.home_outlined, dr, 'dropped'),
      if ((p?['via'] ?? dr?['via']) != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Marked via ${p?['via'] ?? dr?['via']}', style: const TextStyle(fontSize: 11.5, color: kMuted))),
    ]));
  }
}

String initials(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

/// Admin / driver: month heat-map + day register with editable status.
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});
  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  DateTime date = DateTime.now();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int k = 0;

  Future<void> _set(Map s, String trip, String status) async {
    try {
      await Api.I.post('/attendance/mark', {'student_id': s['id'], 'trip_type': trip, 'status': status, 'date': _iso.format(date)});
      setState(() => s[trip] = status);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Color _heat(int? pct) {
    if (pct == null) return const Color(0xFFF1F3F9);
    if (pct >= 90) return cPresent.withValues(alpha: .16);
    if (pct >= 70) return cLate.withValues(alpha: .18);
    return cAbsent.withValues(alpha: .16);
  }

  Color _heatFg(int? pct) => pct == null ? kInk : (pct >= 90 ? const Color(0xFF15803D) : (pct >= 70 ? const Color(0xFFB45309) : cAbsent));

  @override
  Widget build(BuildContext context) {
    final iso = _iso.format(date);
    return Scaffold(
      appBar: dgBar('Attendance'),
      body: Loader<List<Map<String, dynamic>>>(
        key: ValueKey('$iso-${_ym.format(month)}-$k'),
        load: () => Future.wait([
          Api.I.get('/attendance/day', {'date': iso}),
          Api.I.get('/attendance/heat', {'month': _ym.format(month)}).catchError((_) => <String, dynamic>{'days': []}),
        ]),
        builder: (context, r, _) {
          final list = (r[0]['students'] as List).cast<Map>();
          final heat = r[1];
          final hdays = ((heat['days'] as List?) ?? const []).cast<Map>();
          final boarded = list.where((s) => s['pickup'] == 'boarded' || s['drop'] == 'dropped' || s['drop'] == 'boarded').length;
          final absent = list.where((s) => s['pickup'] == 'absent' || s['pickup'] == 'leave').length;
          final pct = list.isEmpty ? 0 : (boarded * 100 / list.length).round();
          return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 24), children: [
            _card(Row(children: [
              AttRing(pct: pct, caption: 'boarded', size: 112),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('EEE, d MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: AttTile('Boarded', boarded, cPresent)),
                  const SizedBox(width: 8),
                  Expanded(child: AttTile('Absent', absent, cAbsent)),
                ]),
                const SizedBox(height: 6),
                Text('${list.length} riders${heat['pct'] != null ? ' · month avg ${heat['pct']}%' : ''}', style: const TextStyle(fontSize: 12, color: kMuted)),
              ])),
            ])),
            MonthNav(
              month: month,
              onMonth: (m) => setState(() => month = DateTime(m.year, m.month)),
              onDate: (d) => setState(() { date = d; month = DateTime(d.year, d.month); }),
            ),
            const SizedBox(height: 6),
            _card(Column(children: [
              MonthGrid(
                days: hdays,
                selected: iso,
                onTap: (x) => setState(() => date = DateTime.parse(x['date'] as String)),
                cell: (x) {
                  final p = (x['pct'] as num?)?.toInt();
                  return (bg: _heat(p), fg: _heatFg(p), sub: p == null ? null : '$p%');
                },
              ),
              const SizedBox(height: 12),
              const _Legend({'≥ 90%': cPresent, '70–89%': cLate, '< 70%': cAbsent, 'No trips': Color(0xFFD1D5DB)}),
            ]), padding: const EdgeInsets.fromLTRB(12, 14, 12, 14)),
            SectionTitle('Register · ${DateFormat('d MMM').format(date)}'),
            if (list.isEmpty) const EmptyState(Icons.groups, 'No bus riders.'),
            for (final s in list)
              Card(child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Expanded(child: InkWell(
                    onTap: Api.I.isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChildAttendanceScreen(studentId: s['id'] as int))) : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${s['class']} · ${s['route'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      if (s['pickup_boarded_at'] != null || s['drop_dropped_at'] != null)
                        Text([
                          if (s['pickup_boarded_at'] != null) 'Boarded ${s['pickup_boarded_at']}${s['pickup_via'] != null ? ' (${s['pickup_via']})' : ''}',
                          if (s['drop_dropped_at'] != null) 'Dropped ${s['drop_dropped_at']}',
                        ].join(' · '), style: const TextStyle(fontSize: 10.5, color: kBlue, fontWeight: FontWeight.w600)),
                    ]),
                  )),
                  PopupMenuButton<String>(
                    child: Padding(padding: const EdgeInsets.all(4), child: Column(children: [const Text('Pickup', style: TextStyle(fontSize: 10)), StatusChip((s['pickup'] as String?) ?? '—')])),
                    onSelected: (v) => _set(s, 'pickup', v),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'boarded', child: Text('Boarded')), PopupMenuItem(value: 'absent', child: Text('Absent')), PopupMenuItem(value: 'leave', child: Text('On leave'))],
                  ),
                  PopupMenuButton<String>(
                    child: Padding(padding: const EdgeInsets.all(4), child: Column(children: [const Text('Drop', style: TextStyle(fontSize: 10)), StatusChip((s['drop'] as String?) ?? '—')])),
                    onSelected: (v) => _set(s, 'drop', v),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'dropped', child: Text('Dropped')), PopupMenuItem(value: 'absent', child: Text('Absent'))],
                  ),
                ]),
              )),
          ]);
        },
      ),
    );
  }
}
