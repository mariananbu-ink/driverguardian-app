import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';
import 'choose_stop.dart';

/// School admin: approve or reject self-registered students (and their parents).
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});
  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  int k = 0;

  Future<void> _act(Map s, bool approve) async {
    if (!approve) {
      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: Text('Reject ${s['name']}?'),
        content: const Text('The registration and its pending parent logins will be removed.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Reject'))],
      ));
      if (ok != true) return;
    }
    try {
      final r = await Api.I.post('/approvals/${s['id']}/${approve ? 'approve' : 'reject'}');
      toast(context, r['message']?.toString() ?? 'Done');
      setState(() => k++);
    } catch (e) {
      toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      key: ValueKey(k),
      load: () => Api.I.get('/approvals'),
      builder: (context, d, _) {
        final list = (d['students'] as List).cast<Map>();
        return ListView(padding: const EdgeInsets.all(12), children: [
          // 2.12: parents' stop requests
          Card(child: ListTile(
            leading: const Icon(Icons.where_to_vote_outlined, color: kBlue),
            title: const Text('Stop requests from parents'),
            subtitle: const Text('Approve the stop a parent chose for their child'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StopRequestsScreen())),
          )),
          const SectionTitle('Waiting for approval'),
          if (list.isEmpty) const EmptyState(Icons.verified_outlined, 'No sign-ups waiting.'),
          for (final s in list)
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Avatar(s['name'] as String),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${s['class']} · ${s['registered']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ])),
                ]),
                const SizedBox(height: 8),
                if ((s['father'] as String).isNotEmpty) Text('Father: ${s['father']}'),
                if ((s['mother'] as String).isNotEmpty) Text('Mother: ${s['mother']}'),
                Text('Route: ${s['route'] ?? '—'}${s['stop'] != null ? ' · ${s['stop']}' : ''}'),
                Text('Logins: ${(s['logins'] as List).join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700), onPressed: () => _act(s, true), icon: const Icon(Icons.check), label: const Text('Approve'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _act(s, false), icon: const Icon(Icons.close), label: const Text('Reject'))),
                ]),
              ]),
            )),
          const SizedBox(height: 70),
        ]);
      },
    );
  }
}

class SosListScreen extends StatelessWidget {
  const SosListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar('SOS alerts'),
      body: Loader<Map<String, dynamic>>(
        load: () => Api.I.get('/sos'),
        builder: (context, d, _) {
          final list = (d['alerts'] as List).cast<Map>();
          return ListView(children: [
            if (list.isEmpty) const EmptyState(Icons.health_and_safety_outlined, 'No SOS alerts.'),
            for (final a in list)
              ListTile(
                tileColor: a['status'] == 'open' ? const Color(0xFFFFEBEE) : null,
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: Text('${a['from'] ?? ''} (${a['role'] ?? ''})'),
                subtitle: Text('${a['note'] ?? 'No note'} · ${a['at']}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (a['lat'] != null) IconButton(icon: const Icon(Icons.map), onPressed: () => launchUrl(Uri.parse('https://www.openstreetmap.org/?mlat=${a['lat']}&mlon=${a['lng']}#map=17/${a['lat']}/${a['lng']}'), mode: LaunchMode.externalApplication)),
                  if (a['phone'] != null) IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => launchUrl(Uri.parse('tel:${a['phone']}'))),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
