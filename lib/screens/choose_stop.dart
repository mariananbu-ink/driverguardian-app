import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../api.dart';
import '../ui.dart';
import 'tracking.dart' show kTiles, kUserAgent;

/// 2.12 "Choose my stop": a parent picks the child's bus stop — from the route's stops or by pinning a new
/// place on the map. The school approves it; then the map shows distance and arrival time.
/// Developed & Powered by Marian Anbu Juwan
class ChooseStopScreen extends StatefulWidget {
  final int? studentId;
  const ChooseStopScreen({super.key, this.studentId});
  @override
  State<ChooseStopScreen> createState() => _ChooseStopScreenState();
}

class _ChooseStopScreenState extends State<ChooseStopScreen> {
  int k = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar('Choose my stop'),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(k),
        load: () => Api.I.get('/stop-options'),
        builder: (context, d, _) {
          final kids = ((d['children'] as List?) ?? const []).cast<Map>();
          if (kids.isEmpty) return const EmptyState(Icons.directions_bus_outlined, 'Your child is not on a bus route yet — the school assigns the route first.');
          final list = widget.studentId == null ? kids : [...kids.where((x) => x['id'] == widget.studentId), ...kids.where((x) => x['id'] != widget.studentId)];
          return ListView(padding: const EdgeInsets.all(12), children: [
            const Text('Pick where your child gets on and off the bus. The school confirms it, then you see distance, arrival time and the “bus is near” alert.', style: TextStyle(color: kMuted)),
            const SizedBox(height: 8),
            for (final c in list) _KidCard(c, onSent: () => setState(() => k++)),
          ]);
        },
      ),
    );
  }
}

class _KidCard extends StatelessWidget {
  final Map c;
  final VoidCallback onSent;
  const _KidCard(this.c, {required this.onSent});

  Future<void> _send(BuildContext context, Map<String, dynamic> body) async {
    try {
      final r = await Api.I.post('/stop-requests', {'student_id': c['id'], ...body});
      if (!context.mounted) return;
      toast(context, r['message']?.toString() ?? 'Sent to the school');
      onSent();
    } catch (e) {
      if (context.mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = ((c['stops'] as List?) ?? const []).cast<Map>();
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text('${c['route'] ?? ''} · stop: ${c['stop'] ?? 'not set'}', style: const TextStyle(color: kMuted, fontSize: 12)),
        if (c['pending'] != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Chip(avatar: const Icon(Icons.hourglass_top, size: 16), label: Text('Waiting for the school: ${c['pending']}'), visualDensity: VisualDensity.compact)),
        const SizedBox(height: 8),
        for (final s in stops)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 14, backgroundColor: s['id'] == c['stop_id'] ? Colors.green : kBlue.withValues(alpha: .12),
                child: Text('${s['seq']}', style: TextStyle(fontSize: 12, color: s['id'] == c['stop_id'] ? Colors.white : kBlue))),
            title: Text('${s['name']}'),
            subtitle: Text('${s['pickup'] != null ? '↑ ${s['pickup']}  ' : ''}${s['drop'] != null ? '↓ ${s['drop']}' : ''}'),
            trailing: s['id'] == c['stop_id'] ? const Icon(Icons.check_circle, color: Colors.green) : TextButton(onPressed: () => _send(context, {'stop_id': s['id']}), child: const Text('Choose')),
          ),
        const Divider(),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('None of these — pin the place on the map'),
          onPressed: () async {
            final r = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => _PinScreen(stops: stops)));
            if (r != null && context.mounted) await _send(context, r);
          },
        ),
      ]),
    ));
  }
}

class _PinScreen extends StatefulWidget {
  final List<Map> stops;
  const _PinScreen({required this.stops});
  @override
  State<_PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<_PinScreen> {
  LatLng? pin;
  final name = TextEditingController();
  final note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final pts = [for (final s in widget.stops.where((s) => s['lat'] != null)) LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble())];
    return Scaffold(
      appBar: dgBar('Pin the pickup place'),
      body: Column(children: [
        Expanded(child: FlutterMap(
          options: MapOptions(initialCenter: pts.isNotEmpty ? pts.first : const LatLng(12.9716, 77.5946), initialZoom: pts.isNotEmpty ? 15 : 12,
              onTap: (_, p) => setState(() => pin = p)),
          children: [
            TileLayer(urlTemplate: kTiles, userAgentPackageName: kUserAgent),
            if (pts.length > 1) PolylineLayer(polylines: [Polyline(points: pts, color: kBlue.withValues(alpha: .5), strokeWidth: 4)]),
            MarkerLayer(markers: [
              for (final p in pts) Marker(point: p, width: 14, height: 14, child: Container(decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
              if (pin != null) Marker(point: pin!, width: 40, height: 40, alignment: Alignment.topCenter, child: const Icon(Icons.location_pin, color: Colors.red, size: 40)),
            ]),
          ],
        )),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(pin == null ? 'Tap the map where your child should be picked up.' : '📍 Pinned — tap again to move it.', style: const TextStyle(color: kMuted)),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name of the place (e.g. Opp. Ram Temple, 4th Cross)')),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note for the school (optional)')),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: pin == null ? null : () => Navigator.pop(context, {'lat': pin!.latitude, 'lng': pin!.longitude, 'new_name': name.text.trim(), 'note': note.text.trim()}),
              icon: const Icon(Icons.send), label: const Text('Send to the school'))),
          ]),
        )),
      ]),
    );
  }
}

/// School admin: stop requests from parents (approve / decline).
class StopRequestsScreen extends StatefulWidget {
  const StopRequestsScreen({super.key});
  @override
  State<StopRequestsScreen> createState() => _StopRequestsScreenState();
}

class _StopRequestsScreenState extends State<StopRequestsScreen> {
  int k = 0;

  Future<void> _act(Map r, bool ok) async {
    String reply = '';
    if (!ok) {
      final c = TextEditingController(text: 'Please use the nearest existing stop.');
      final go = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Decline'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Reason (sent to the parent)')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Decline'))],
      ));
      if (go != true) return;
      reply = c.text;
    }
    try {
      await Api.I.post('/stop-requests/${r['id']}/${ok ? 'approve' : 'reject'}', {'reply': reply});
      if (mounted) toast(context, ok ? 'Approved — stop set' : 'Declined');
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar('Stop requests'),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(k),
        load: () => Api.I.get('/stop-requests'),
        builder: (context, d, _) {
          final list = ((d['requests'] as List?) ?? const []).cast<Map>();
          if (list.isEmpty) return const EmptyState(Icons.where_to_vote_outlined, 'No stop requests waiting.');
          return ListView(padding: const EdgeInsets.all(12), children: [
            for (final r in list)
              Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['student']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${r['class'] ?? ''} · ${r['route'] ?? ''} · by ${r['by'] ?? ''} ${r['ago'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('Now: ${r['current'] ?? 'no stop'}'),
                  Text('Asks for: ${r['asks']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (r['note'] != null) Text('Note: ${r['note']}', style: const TextStyle(color: kMuted)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700), onPressed: () => _act(r, true), icon: const Icon(Icons.check), label: Text(r['new'] == true ? 'Add stop & approve' : 'Approve'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _act(r, false), icon: const Icon(Icons.close), label: const Text('Decline'))),
                  ]),
                ]),
              )),
          ]);
        },
      ),
    );
  }
}
