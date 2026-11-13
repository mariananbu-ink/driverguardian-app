// Role dashboards & reusable home-screen cards.
// Developed & Powered by Marian Anbu Juwan
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';
import 'attendance.dart';
import 'driver_trip.dart';
import 'tracking.dart';

/// KPI tiles for the home carousel, by role.
List<Kpi> kpisFor(Map d) {
  final role = d['role'];
  if (role == 'parent') {
    final kids = (d['children'] as List? ?? const []).cast<Map>();
    final dues = (d['dues'] as Map?) ?? const {};
    return [
      Kpi(label: 'Children', value: '${kids.length}', meta: '${kids.where((k) => k['route'] != null).length} on a bus route', icon: Icons.child_care, colors: gPink),
      Kpi(label: 'Bus live', value: '${kids.where((k) => k['bus_live'] == true).length}', meta: 'tap Track bus to follow', icon: Icons.satellite_alt, colors: gGreen),
      Kpi(label: 'Fees due', value: inr(dues['amount'] as num?), meta: '${dues['count'] ?? 0} open · ${dues['submitted'] ?? 0} awaiting check', icon: Icons.currency_rupee, colors: gOrange),
      Kpi(label: 'Boarded today', value: '${kids.where((k) => (k['today'] as Map?)?['pickup'] == 'boarded').length}/${kids.length}', meta: 'morning pickup', icon: Icons.fact_check, colors: gBlue),
    ];
  }
  if (role == 'driver') {
    final rs = (d['routes'] as List? ?? const []).cast<Map>();
    int sum(String k) => rs.fold<int>(0, (a, r) => a + ((r[k] as int?) ?? 0));
    return [
      Kpi(label: 'Routes', value: '${rs.length}', meta: rs.isEmpty ? 'none assigned' : (rs.first['vehicle'] ?? '').toString(), icon: Icons.alt_route, colors: gBlue),
      Kpi(label: 'Students', value: '${sum('students')}', meta: 'on your routes', icon: Icons.groups, colors: gViolet),
      Kpi(label: 'Boarded', value: '${sum('boarded')}', meta: '${sum('dropped')} dropped', icon: Icons.check_circle_outline, colors: gGreen),
      Kpi(label: 'Absent', value: '${sum('absent')}', meta: 'today', icon: Icons.person_off_outlined, colors: gRed),
    ];
  }
  final k = (d['kpi'] as Map?) ?? const {};
  return [
    Kpi(label: 'Students', value: '${k['students'] ?? 0}', meta: '${k['routes'] ?? 0} routes · ${k['vehicles'] ?? 0} buses', icon: Icons.groups, colors: gBlue),
    Kpi(label: 'Boarded today', value: '${k['boarded'] ?? 0}', meta: '${k['absent'] ?? 0} absent · ${k['unmarked'] ?? 0} unmarked', icon: Icons.fact_check, colors: gGreen),
    Kpi(label: 'Collected', value: inr(k['collected_month'] as num?), meta: 'this month', icon: Icons.currency_rupee, colors: gOrange),
    Kpi(label: 'Buses live', value: '${k['live'] ?? 0}', meta: '${k['drivers'] ?? 0} drivers', icon: Icons.satellite_alt, colors: gPink),
    Kpi(label: 'Outstanding', value: inr(k['outstanding'] as num?), meta: '${k['to_verify'] ?? 0} UTRs to verify', icon: Icons.account_balance_wallet_outlined, colors: gViolet),
    Kpi(label: 'Approvals', value: '${k['pending_approvals'] ?? 0}', meta: 'waiting sign-ups', icon: Icons.how_to_reg, colors: gCyan),
  ];
}

/* ------------------------------------------------------------------ parent */
class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});
  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () => Api.I.get('/dashboard'),
        builder: (context, d, reload) {
          final kids = (d['children'] as List).cast<Map>();
          return ListView(padding: const EdgeInsets.all(14), children: [
            if (kids.isEmpty) const EmptyState(Icons.child_care, 'No children are linked to your account yet. Please contact the school office.'),
            for (final k in kids) KidCard(k),
          ]);
        },
      );
}

class KidCard extends StatelessWidget {
  final Map k;
  const KidCard(this.k, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = (k['today'] as Map?) ?? const {};
    Widget cell(IconData icon, String label, String? status, String? time) => Expanded(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, size: 18, color: kBlue),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 10.5, color: kMuted)),
              const SizedBox(height: 2),
              StatusChip(status ?? 'not marked'),
              if (time != null) Text(time, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(k['name'] as String, size: 46),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('${k['class']}', style: const TextStyle(color: kMuted, fontSize: 12)),
            ])),
            k['bus_live'] == true ? const StatusChip('live') : StatusChip(k['status'] as String?),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.alt_route, size: 16, color: kMuted),
                const SizedBox(width: 6),
                Expanded(child: Text(k['route']?.toString() ?? 'No route yet', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              ]),
              if (k['stop'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
                const Icon(Icons.place_outlined, size: 16, color: kMuted),
                const SizedBox(width: 6),
                Expanded(child: Text('${k['stop']}', style: const TextStyle(fontSize: 12))),
                if (k['pickup_time'] != null) Text('↑ ${k['pickup_time']}  ↓ ${k['drop_time'] ?? '—'}', style: const TextStyle(fontSize: 11.5, color: kMuted)),
              ])),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            cell(Icons.wb_sunny_outlined, 'Pickup', t['pickup'] as String?, t['pickup_at'] as String?),
            cell(Icons.home_outlined, 'Drop', t['drop'] as String?, t['drop_at'] as String?),
          ]),
          if (k['driver'] != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const GradientIcon(Icons.badge_outlined, gCyan, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text('${k['driver']} · ${k['vehicle'] ?? ''}', style: const TextStyle(fontSize: 12.5))),
              if (k['driver_phone'] != null) IconButton.filledTonal(icon: const Icon(Icons.call, size: 18), onPressed: () => launchUrl(Uri.parse('tel:${k['driver_phone']}'))),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModulePage(title: 'Track bus', child: TrackingScreen()))), icon: const Icon(Icons.my_location, size: 18), label: const Text('Track'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildAttendanceScreen())), icon: const Icon(Icons.event_available, size: 18), label: const Text('Attendance'))),
          ]),
        ]),
      ),
    );
  }
}

/* ------------------------------------------------------------------ driver */
class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});
  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () => Api.I.get('/dashboard'),
        builder: (context, d, reload) {
          final routes = (d['routes'] as List).cast<Map>();
          return ListView(padding: const EdgeInsets.all(14), children: [
            if (routes.isEmpty) const EmptyState(Icons.alt_route, 'No routes are assigned to you yet.'),
            for (final r in routes) DriverRouteCard(r),
          ]);
        },
      );
}

class DriverRouteCard extends StatelessWidget {
  final Map r;
  const DriverRouteCard(this.r, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = hexColor(r['color'] as String?);
    final total = (r['students'] as int?) ?? 0;
    final boarded = (r['boarded'] as int?) ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 5, color: c),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GradientIcon(Icons.directions_bus_filled, [c, c.withValues(alpha: .6)], size: 42),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['route'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('${r['vehicle'] ?? ''}${r['helper'] != null ? ' · Helper ${r['helper']}' : ''}', style: const TextStyle(fontSize: 12, color: kMuted)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Text('$boarded / $total boarded', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${r['absent'] ?? 0} absent · ${r['dropped'] ?? 0} dropped', style: const TextStyle(fontSize: 11.5, color: kMuted)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: total == 0 ? 0 : boarded / total, minHeight: 7, backgroundColor: kLine, color: c)),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTripScreen(routeId: r['route_id'] as int))),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start trip on this route'),
            ),
          ]),
        ),
      ]),
    );
  }
}

/* ------------------------------------------------------------------ admin */
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () => Api.I.get('/dashboard'),
        builder: (context, d, reload) {
          final ks = kpisFor(d);
          return ListView(padding: const EdgeInsets.all(14), children: [
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.55,
              children: ks,
            ),
            const SectionTitle('Fee collection — last 6 months'),
            FeeChart((d['months'] as List? ?? const []).cast<Map>()),
          ]);
        },
      );
}

class FeeChart extends StatelessWidget {
  final List<Map> months;
  const FeeChart(this.months, {super.key});
  @override
  Widget build(BuildContext context) {
    final maxV = months.fold<double>(1, (a, m) => [a, (m['paid'] as num).toDouble(), (m['billed'] as num).toDouble()].reduce((x, y) => x > y ? x : y));
    return Card(child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(children: [
        SizedBox(height: 150, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final m in months)
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(inr(m['paid'] as num).replaceAll('₹', ''), style: const TextStyle(fontSize: 8.5, color: kMuted)),
              const SizedBox(height: 3),
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(height: 4 + 100 * ((m['billed'] as num).toDouble() / maxV), width: 9, decoration: BoxDecoration(color: kBlue.withValues(alpha: .18), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 3),
                Container(height: 4 + 100 * ((m['paid'] as num).toDouble() / maxV), width: 9, decoration: BoxDecoration(gradient: const LinearGradient(colors: [kSky, kBlue], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(4))),
              ]),
              const SizedBox(height: 5),
              Text(m['label'].toString(), style: const TextStyle(fontSize: 10.5)),
            ])),
        ])),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(kBlue.withValues(alpha: .25), 'Billed'),
          const SizedBox(width: 16),
          _legend(kBlue, 'Collected'),
        ]),
      ]),
    ));
  }

  Widget _legend(Color c, String t) => Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 5), Text(t, style: const TextStyle(fontSize: 11, color: kMuted))]);
}

