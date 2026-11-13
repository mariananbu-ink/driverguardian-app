// AI Insights — school admins: morning briefing, alerts the AI watchdog raised (running late, trip
// not started, long stop, off route, GPS lost, repeated absence, flagged incidents), driver coaching,
// fee follow-up with one-tap reminders, route timetable suggestions and (2.10) the efficiency view:
// score, AI recommendations, fleet load / km / idling / fuel ₹, service & documents, data to fix,
// children not riding (one tap asks their parents) and staff hours saved.
// Drivers: their own 30-day performance score with a coaching tip.
// Developed & Powered by Marian Anbu Juwan
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});
  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  int k = 0;
  bool busy = false;

  Future<void> _act(Future<Map<String, dynamic>> Function() call, String done) async {
    setState(() => busy = true);
    try {
      final r = await call();
      if (mounted) toast(context, (r['message'] ?? done).toString());
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: dgBar(Api.I.role == 'driver' ? 'My performance' : 'AI Insights', subtitle: Api.I.role == 'driver' ? 'Last 30 days' : 'Automation & smart alerts'),
        body: Loader<Map<String, dynamic>>(
          key: ValueKey(k),
          load: () => Api.I.get('/ai/insights'),
          builder: (context, d, reload) => RefreshIndicator(
            onRefresh: reload,
            child: d['role'] == 'driver' ? _driver(d) : _admin(d),
          ),
        ),
      );

  /* ------------------------------------------------------------ driver */
  Widget _driver(Map d) {
    final me = d['me'] as Map?;
    if (me == null) return ListView(children: const [EmptyState(Icons.badge_outlined, 'Your driver profile is not set up yet.')]);
    return ListView(padding: const EdgeInsets.all(14), children: [
      _ScoreCard(row: me, big: true),
      const SectionTitle('Your last 30 days'),
      StatStrip([
        StatCard('Trips', '${me['trips']}', Icons.route, gBlue),
        StatCard('Km', '${me['km']}', Icons.speed, gTeal),
        StatCard('Over-speed', '${me['overspeed']}', Icons.warning_amber_rounded, gOrange),
      ]),
      const SizedBox(height: 10),
      StatStrip([
        StatCard('Late starts', '${me['not_started']}', Icons.alarm, gRed),
        StatCard('Long stops', '${me['long_stops']}', Icons.pan_tool_alt_outlined, gViolet),
        StatCard('GPS gaps', '${me['gps_lost']}', Icons.gps_off, gSlate),
      ]),
    ]);
  }

  /* ------------------------------------------------------------ admin */
  Widget _admin(Map d) {
    final b = d['briefing'] as Map?;
    final events = ((d['events'] as List?) ?? const []).cast<Map>();
    final open = events.where((e) => e['open'] == true).toList();
    final drivers = ((d['drivers'] as List?) ?? const []).cast<Map>();
    final fees = (d['fees'] as Map?) ?? const {};
    final feeList = ((fees['list'] as List?) ?? const []).cast<Map>();
    final routes = ((d['routes'] as List?) ?? const []).cast<Map>();
    final ops = d['ops'] as Map?;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 40), children: [
      // briefing
      Container(
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('☀️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text(b == null ? 'Morning briefing' : 'Briefing · ${b['date']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
            if (b != null) _chip(b['source'] == 'ai' ? '✨ AI' : 'Auto'),
          ]),
          const SizedBox(height: 8),
          if (b == null)
            const Text('Not generated yet today.', style: TextStyle(color: Colors.white70))
          else
            for (final line in (b['body'] as String).split('\n').where((l) => l.trim().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line.startsWith('- ') ? '•  ${line.substring(2)}' : line, style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35, fontWeight: line.startsWith('- ') ? FontWeight.w400 : FontWeight.w600)),
              ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: busy ? null : () => _act(() => Api.I.post('/ai/briefing', {'send': true}), 'Briefing ready.'),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(b == null ? 'Generate now' : 'Refresh'),
            ),
          ),
        ]),
      ),
      if (ops != null) ..._ops(ops),
      SectionTitle('Alerts (${open.length} open)'),
      if (events.isEmpty) const EmptyState(Icons.verified_user_outlined, 'All quiet — nothing unusual detected.'),
      for (final e in events.take(20)) _event(e),
      if (drivers.isNotEmpty) ...[
        const SectionTitle('Driver coaching'),
        for (final r in drivers.take(6)) _ScoreCard(row: r),
      ],
      SectionTitle('Fee follow-up', trailing: feeList.isEmpty ? null : TextButton.icon(
        onPressed: busy ? null : () => _act(() => Api.I.post('/ai/fees/remind'), 'Reminders sent.'),
        icon: const Icon(Icons.send, size: 16), label: const Text('Remind high & medium'),
      )),
      if (feeList.isEmpty)
        const EmptyState(Icons.check_circle_outline, 'No overdue fees.')
      else ...[
        Text('${fees['parents']} parents · ${inr(fees['amount'] as num?)} overdue · ${fees['high']} high risk', style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 6),
        for (final f in feeList.take(10))
          Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: _riskColor(f['risk']).withValues(alpha: .15), child: Text('${f['score']}', style: TextStyle(color: _riskColor(f['risk']), fontWeight: FontWeight.w700, fontSize: 13))),
            title: Text('${f['parent']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${f['children']} · ${inr(f['amount'] as num?)} · ${f['days']} days${f['reminded'] != null ? ' · reminded ${f['reminded']}' : ''}'),
            trailing: IconButton(
              tooltip: 'Send reminder',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: busy ? null : () => _act(() => Api.I.post('/ai/fees/remind', {'parents': [f['parent_id']]}), 'Reminder sent.'),
            ),
          )),
      ],
      if (routes.isNotEmpty) ...[
        const SectionTitle('Routes & timetable'),
        for (final r in routes)
          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${r['samples']} trips', style: const TextStyle(color: kMuted, fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              Text('${r['summary']}', style: const TextStyle(fontSize: 12.5, height: 1.35)),
              if ((r['changes'] as num? ?? 0) > 0)
                Wrap(spacing: 8, children: [
                  for (final t in ['pickup', 'drop'])
                    OutlinedButton(
                      onPressed: busy ? null : () => _act(() => Api.I.post('/ai/routes/${r['id']}/apply', {'type': t}), 'Times updated.'),
                      child: Text('Apply $t times'),
                    ),
                ]),
            ]),
          )),
      ],
      const SizedBox(height: 10),
      Text(d['model'] == true ? '✨ AI model connected — texts are written by AI from your data.' : 'Rules & templates — connect an AI model on the web (School Settings → AI Copilot) for AI-written briefings and tips.',
          textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 11.5)),
    ]);
  }

  /* ------------------------------------------------------------ efficiency */
  Color _scoreColor(num? v) => v == null ? Colors.grey : (v >= 90 ? Colors.green : (v >= 75 ? kBlue : (v >= 55 ? Colors.orange : Colors.red)));

  List<Widget> _ops(Map o) {
    final score = (o['score'] as Map?) ?? const {};
    final overall = score['overall'] as num?;
    final parts = ((score['parts'] as Map?) ?? const {}).values.cast<Map>().toList();
    final rec = (o['recommendations'] as Map?) ?? const {};
    final items = ((rec['items'] as List?) ?? const []).map((e) => '$e').toList();
    final saved = (o['saved'] as Map?) ?? const {};
    final fleet = (o['fleet'] as Map?) ?? const {};
    final buses = ((fleet['rows'] as List?) ?? const []).cast<Map>();
    final over = ((o['over'] as List?) ?? const []).cast<Map>();
    final merge = ((o['merge'] as List?) ?? const []).cast<Map>();
    final health = ((o['health'] as List?) ?? const []).cast<Map>();
    final riding = (o['riding'] as Map?) ?? const {};
    final rideList = ((riding['list'] as List?) ?? const []).cast<Map>();
    final c = _scoreColor(overall);
    return [
      const SectionTitle('Efficiency'),
      Card(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            SizedBox(width: 86, height: 86, child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(value: (overall ?? 0) / 100, strokeWidth: 9, backgroundColor: kLine, color: c)),
              Text(overall == null ? '—' : '$overall', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c)),
            ])),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Efficiency score', style: TextStyle(color: kMuted, fontSize: 12)),
              Text('${score['grade'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: c)),
              const SizedBox(height: 4),
              Text('⏱ Automation saved ≈ ${saved['hours'] ?? 0} staff hours in 30 days', style: const TextStyle(fontSize: 12.5)),
            ])),
          ]),
          const SizedBox(height: 10),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 128, child: Text('${p['label']}', style: const TextStyle(fontSize: 12))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: ((p['value'] as num?) ?? 0) / 100, minHeight: 7, backgroundColor: kLine, color: _scoreColor(p['value'] as num?)))),
                SizedBox(width: 34, child: Text(p['value'] == null ? '—' : '${p['value']}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ]),
            ),
        ]),
      )),
      if (items.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE0E7FF))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 6),
              const Expanded(child: Text('What to do this week', style: TextStyle(fontWeight: FontWeight.w700))),
              Text(rec['source'] == 'ai' ? '✨ AI' : 'Rules', style: const TextStyle(color: kMuted, fontSize: 11)),
            ]),
            const SizedBox(height: 8),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 10, backgroundColor: const Color(0xFF6366F1), child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(items[i], style: const TextStyle(fontSize: 12.8, height: 1.35))),
                ]),
              ),
          ]),
        ),
      const SizedBox(height: 6),
      StatStrip([
        StatCard('Km · 7 days', '${fleet['km7'] ?? 0}', Icons.route, gBlue),
        StatCard('Fuel · 7 days', inr(fleet['fuel_inr7'] as num?), Icons.local_gas_station_outlined, gTeal),
        StatCard('Idling', '${fleet['idle_min7'] ?? 0} min', Icons.hourglass_bottom_rounded, gOrange),
      ]),
      for (final x in over) _note(Icons.groups_outlined, Colors.red, '${x['name']}: ${x['children']} children for ${x['capacity']} seats (${x['bus'] ?? ''}).'),
      for (final m in merge) _note(Icons.merge_type, kBlue, '${m['a']} + ${m['b']}: ${m['children']} children within ${m['km']} km — one bus (${m['bus'] ?? ''}) could run both.'),
      if (buses.isNotEmpty) ...[
        const SizedBox(height: 6),
        for (final v in buses) _bus(v),
      ],
      if (health.isNotEmpty) ...[
        const SectionTitle('Data to fix'),
        Card(child: Column(children: [
          for (final h in health)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 15, backgroundColor: (h['severity'] == 'critical' ? Colors.red : (h['severity'] == 'warning' ? Colors.orange : kBlue)).withValues(alpha: .14),
                  child: Text('${h['count']}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: h['severity'] == 'critical' ? Colors.red : (h['severity'] == 'warning' ? Colors.orange : kBlue)))),
              title: Text('${h['label']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${h['hint']}'),
            ),
        ])),
      ],
      if ((riding['count'] as num? ?? 0) > 0) ...[
        SectionTitle('Not riding (${riding['count']})', trailing: TextButton.icon(
          onPressed: busy ? null : () => _act(() => Api.I.post('/ai/ops/confirm-riders'), 'Parents asked.'),
          icon: const Icon(Icons.send, size: 16), label: const Text('Ask parents'),
        )),
        Text('No boarding for 14 days while their bus ran${(riding['monthly_inr'] as num? ?? 0) > 0 ? ' · ${inr(riding['monthly_inr'] as num?)}/month in fares' : ''}.', style: const TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 6),
        for (final x in rideList.take(8))
          Card(child: ListTile(
            dense: true,
            leading: const Icon(Icons.event_seat_outlined),
            title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${x['class']} · ${x['route']}'),
            trailing: x['phone'] == null ? null : IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => launchUrl(Uri.parse('tel:${x['phone']}'))),
          )),
      ],
    ];
  }

  Widget _note(IconData i, Color c, String t) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: .25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: c, size: 20), const SizedBox(width: 8), Expanded(child: Text(t, style: const TextStyle(fontSize: 12.8, height: 1.35)))]),
      );

  Widget _bus(Map v) {
    final load = v['load'] as num?;
    final lc = load == null ? Colors.grey : (load > 100 ? Colors.red : (load < 40 ? Colors.orange : Colors.green));
    final docs = ((v['docs'] as List?) ?? const []).cast<Map>();
    final svc = v['service'] as Map?;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.directions_bus_rounded, color: kBlue, size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text('${v['reg']}', style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${v['children']}/${v['capacity']} seats', style: TextStyle(color: lc, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: ((load ?? 0) / 100).clamp(0, 1).toDouble(), minHeight: 7, backgroundColor: kLine, color: lc)),
        const SizedBox(height: 6),
        Text('${v['km7']} km · ${v['idle_min7']} min idling · ${inr(v['fuel_inr7'] as num?)} fuel (7 days)', style: const TextStyle(color: kMuted, fontSize: 12)),
        if (svc != null || docs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              if (svc != null) _tag('🔧 ${svc['title']}${svc['days'] != null ? ((svc['days'] as num) < 0 ? ' · ${(svc['days'] as num).abs()}d overdue' : ' · in ${svc['days']}d') : ''}', Colors.orange),
              for (final d in docs) _tag('${d['label']} ${(d['days'] as num) < 0 ? 'expired' : d['date']}', Colors.red),
            ]),
          ),
      ]),
    ));
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Color _riskColor(dynamic r) => r == 'high' ? Colors.red : (r == 'medium' ? Colors.orange : Colors.grey);

  Widget _event(Map e) {
    final sev = e['severity'];
    final c = sev == 'critical' ? Colors.red : (sev == 'warning' ? Colors.orange : kBlue);
    final icon = switch (e['type']) {
      'late' => Icons.hourglass_bottom_rounded,
      'not_started' => Icons.pause_circle_outline,
      'long_stop' => Icons.pan_tool_alt_outlined,
      'off_route' => Icons.alt_route_rounded,
      'gps_lost' => Icons.gps_off,
      'absence' => Icons.person_off_outlined,
      'fee_reminder' => Icons.currency_rupee,
      'incident' => Icons.car_crash_outlined,
      'capacity' => Icons.groups_outlined,
      'service_due' => Icons.build_circle_outlined,
      'doc_expiry' => Icons.assignment_late_outlined,
      'not_riding' => Icons.event_seat_outlined,
      'data_health' => Icons.storage_outlined,
      _ => Icons.info_outline,
    };
    return Opacity(
      opacity: e['open'] == true ? 1 : .55,
      child: Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: c.withValues(alpha: .12), child: Icon(icon, color: c, size: 20)),
        title: Text('${e['title']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${e['body'] ?? ''}${(e['body'] ?? '').toString().isEmpty ? '' : '\n'}${e['label']} · ${e['ago']}', style: const TextStyle(fontSize: 12)),
        isThreeLine: (e['body'] ?? '').toString().isNotEmpty,
        trailing: e['open'] == true
            ? IconButton(tooltip: 'Mark handled', icon: const Icon(Icons.check_circle_outline), onPressed: busy ? null : () => _act(() => Api.I.post('/ai/events/${e['id']}/resolve'), 'Marked handled.'))
            : null,
      )),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final Map row;
  final bool big;
  const _ScoreCard({required this.row, this.big = false});

  @override
  Widget build(BuildContext context) {
    final s = (row['score'] as num?)?.toInt() ?? 0;
    final c = s >= 90 ? Colors.green : (s >= 75 ? kBlue : (s >= 55 ? Colors.orange : Colors.red));
    return Card(child: Padding(
      padding: EdgeInsets.all(big ? 18 : 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: big ? 84 : 54, height: big ? 84 : 54, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: s / 100, strokeWidth: big ? 8 : 6, backgroundColor: kLine, color: c)),
          Text('$s', style: TextStyle(fontSize: big ? 24 : 16, fontWeight: FontWeight.w700, color: c)),
        ])),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(big ? 'Your score' : '${row['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${row['grade']}', style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Text('✨ ${row['tip']}', style: const TextStyle(fontSize: 12.5, height: 1.35)),
          if (!big && row['phone'] != null)
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
              onPressed: () => launchUrl(Uri.parse('tel:${row['phone']}')),
              icon: const Icon(Icons.call, size: 16), label: const Text('Call'),
            )),
        ])),
      ]),
    ));
  }
}
