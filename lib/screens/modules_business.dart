import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';

// v2.3 — My subscription (plan, usage, renew / pay now) and announcements (SMS · WhatsApp · Email).
// Developed & Powered by Marian Anbu Juwan

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int k = 0;
  bool busy = false;

  Future<Map?> _renew({int? planId}) async {
    setState(() => busy = true);
    try {
      final r = await Api.I.post('/subscription/renew', {if (planId != null) 'plan_id': planId});
      return r['invoice'] as Map?;
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pay(Map d, {Map? invoice}) async {
    invoice ??= (d['open'] as Map?) ?? await _renew();
    if (invoice == null || !mounted) return;
    final gws = ((d['gateways'] as List?) ?? const []).cast<Map>();
    final upi = d['upi_link'] as String?;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pay ${inr(invoice!['amount'] as num)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('${invoice['invoice_no']}', textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
          const SizedBox(height: 12),
          for (final g in gws)
            Card(child: ListTile(
              leading: const Icon(Icons.payments_outlined, color: kBlue),
              title: Text(g['label'] as String),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(c, g['key'] as String),
            )),
          if (upi != null)
            Card(child: ListTile(
              leading: const Icon(Icons.qr_code_2, color: kBlue),
              title: const Text('UPI QR + submit UTR'),
              subtitle: Text('${d['upi']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(c, '__upi'),
            )),
          if (gws.isEmpty && upi == null) const Padding(padding: EdgeInsets.all(12), child: Text('The platform has not set up online payment yet. Please contact DriverGuardian support.', textAlign: TextAlign.center)),
        ]),
      )),
    );
    if (choice == null || !mounted) return;
    if (choice == '__upi') return _upi(d, invoice);
    setState(() => busy = true);
    try {
      final r = await Api.I.post('/subscription/${invoice['id']}/pay', {'gateway': choice});
      final url = r['url'] as String?;
      if (url == null) throw ApiException(r['message']?.toString() ?? 'Could not start the payment.', 422);
      if (!mounted) return;
      if (!await openCheckout(context, url) || !mounted) return;
      await showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text('Finish in your browser'),
        content: const Text('Complete the payment on the page that opened. Your plan is extended automatically — tap Done when you are back.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
      ));
      if (mounted) setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _upi(Map d, Map invoice) async {
    final ref = TextEditingController(text: (invoice['reference'] ?? '').toString());
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: QrImageView(data: d['upi_link'] as String, size: 190, backgroundColor: Colors.white)),
          Text('Pay ${inr(invoice['amount'] as num)} to ${d['upi']}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(d['upi_link'] as String), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: const Text('Open UPI app')),
          const SizedBox(height: 10),
          TextField(controller: ref, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'UTR / reference number')),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Submit for verification')),
        ]),
      ),
    );
    if (go != true) return;
    try {
      final r = await Api.I.post('/subscription/${invoice['id']}/utr', {'reference': ref.text.trim()});
      if (!mounted) return;
      toast(context, r['message']?.toString() ?? 'Sent');
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _changePlan(Map d) async {
    final plans = ((d['plans'] as List?) ?? const []).cast<Map>();
    final id = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), children: [
        for (final p in plans)
          Card(child: ListTile(
            title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${inr(p['price'] as num)} / ${p['interval']}'),
            trailing: p['current'] == true ? const StatusChip('active') : const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(c, p['id'] as int),
          )),
      ])),
    );
    if (id == null) return;
    final inv = await _renew(planId: id);
    if (inv != null && mounted) {
      await _pay(d, invoice: inv);
      if (mounted) setState(() => k++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar('My subscription'),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(k),
        load: () => Api.I.get('/subscription'),
        builder: (context, d, _) {
          final plan = d['plan'] as Map?;
          final u = (d['usage'] as Map?) ?? const {};
          final open = d['open'] as Map?;
          final state = (d['state'] ?? 'none').toString();
          final days = d['days_left'] as num?;
          final invoices = ((d['invoices'] as List?) ?? const []).cast<Map>();
          final stateColor = switch (state) { 'active' => Colors.greenAccent, 'due' => kYellow, 'grace' || 'expired' => Colors.redAccent, _ => Colors.white70 };
          final stateLabel = switch (state) { 'active' => 'Active', 'due' => 'Renew soon', 'grace' => 'Grace period', 'expired' => 'Expired', _ => 'No plan' };
          return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 28), children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: kHeroGradient),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('CURRENT PLAN', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: stateColor.withValues(alpha: .2), borderRadius: BorderRadius.circular(8)),
                    child: Text(stateLabel, style: TextStyle(color: stateColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(plan?['name']?.toString() ?? 'No plan', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                if (plan != null) Text('${inr(plan['price'] as num)} / ${plan['interval']}', style: const TextStyle(color: Colors.white, fontSize: 15)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('RENEWS ON', style: TextStyle(color: Colors.white70, fontSize: 10.5, letterSpacing: 1)),
                      Text(d['renews_on']?.toString() ?? '—', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ])),
                    if (days != null)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${days.abs()}', style: const TextStyle(color: kYellow, fontSize: 28, fontWeight: FontWeight.w800)),
                        Text(days < 0 ? 'DAYS OVERDUE' : 'DAYS LEFT', style: const TextStyle(color: Colors.white70, fontSize: 10.5, letterSpacing: 1)),
                      ]),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kInk),
                    onPressed: busy ? null : () => _pay(d),
                    icon: Icon(open != null ? Icons.payments_outlined : Icons.autorenew),
                    label: Text(open != null ? 'Pay now' : 'Renew now'),
                  )),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                    onPressed: busy ? null : () => _changePlan(d),
                    icon: const Icon(Icons.layers_outlined),
                    label: const Text('Change plan'),
                  ),
                ]),
              ]),
            ),
            if (open != null)
              Card(
                margin: const EdgeInsets.only(top: 12),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: kBlue),
                  title: Text('${open['invoice_no']} · ${inr(open['amount'] as num)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${open['period']}${open['status'] == 'submitted' ? '\nUTR ${open['reference']} · awaiting confirmation' : ''}${open['notes'] != null && open['status'] == 'pending' ? '\n${open['notes']}' : ''}'),
                  trailing: StatusChip(open['status'] as String?),
                ),
              ),
            const SectionTitle('Usage this month'),
            Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                for (final e in const {'students': ('Students', Icons.groups_outlined), 'vehicles': ('Buses', Icons.directions_bus_outlined), 'users': ('App users', Icons.people_alt_outlined), 'sms': ('SMS', Icons.sms_outlined), 'whatsapp': ('WhatsApp', Icons.chat_outlined), 'email': ('Emails', Icons.mail_outline)}.entries)
                  _meter(e.value.$1, e.value.$2, u[e.key] as List?),
              ]),
            )),
            const SectionTitle('Traffic'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                Kpi(label: 'Web views', value: '${u['web'] ?? 0}', icon: Icons.language, colors: gBlue),
                Kpi(label: 'App / API', value: '${u['api'] ?? 0}', icon: Icons.phone_android, colors: gViolet),
                Kpi(label: 'Trips', value: '${u['trips'] ?? 0}', meta: '${u['km'] ?? 0} km', icon: Icons.alt_route, colors: gOrange),
                Kpi(label: 'GPS points', value: '${u['gps'] ?? 0}', icon: Icons.location_on_outlined, colors: gGreen),
                Kpi(label: 'Sign-ins', value: '${u['logins'] ?? 0}', icon: Icons.login, colors: gCyan),
                Kpi(label: 'Storage', value: '${u['storage_mb'] ?? 0} MB', icon: Icons.storage, colors: gSlate),
              ],
            ),
            _spark(((d['series'] as List?) ?? const []).cast<Map>()),
            const SectionTitle('Billing history'),
            if (invoices.isEmpty) const EmptyState(Icons.receipt_long, 'No invoices yet.'),
            for (final i in invoices)
              Card(child: ListTile(
                title: Text('${i['invoice_no']} · ${inr(i['amount'] as num)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${i['plan'] ?? ''} · ${i['period']}${i['paid'] != null ? '\nPaid ${i['paid']} · ${i['via'] ?? ''}' : ''}'),
                trailing: StatusChip(i['status'] as String?),
              )),
          ]);
        },
      ),
    );
  }

  Widget _meter(String label, IconData icon, List? v) {
    final used = (v != null && v.isNotEmpty ? v[0] as num? : null) ?? 0;
    final cap = v != null && v.length > 1 ? v[1] as num? : null;
    final f = cap == null || cap == 0 ? 0.0 : (used / cap).clamp(0, 1).toDouble();
    final col = f >= .9 ? Colors.red : (f >= .75 ? Colors.orange : kBlue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(children: [
        Row(children: [
          Icon(icon, size: 16, color: kMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text('$used', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(cap == null ? ' / unlimited' : ' / $cap', style: const TextStyle(color: kMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: cap == null ? 0 : f, minHeight: 6, backgroundColor: const Color(0xFFEEF0F6), color: col)),
      ]),
    );
  }

  Widget _spark(List<Map> s) {
    if (s.isEmpty) return const SizedBox.shrink();
    final vals = [for (final x in s) ((x['web'] as num? ?? 0) + (x['api'] as num? ?? 0)).toDouble()];
    final mx = vals.fold<double>(1, (a, b) => b > a ? b : a);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Requests · last 30 days', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final v in vals)
                Expanded(child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 4 + 66 * v / mx,
                  decoration: BoxDecoration(color: kBlue.withValues(alpha: .75), borderRadius: BorderRadius.circular(2)),
                )),
            ]),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text('${s.first['day']}', style: const TextStyle(fontSize: 10.5, color: kMuted)),
            const Spacer(),
            Text('${s.last['day']}', style: const TextStyle(fontSize: 10.5, color: kMuted)),
          ]),
        ]),
      ),
    );
  }
}

/// Admin: send an announcement by app / SMS / WhatsApp / email.
class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});
  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  int k = 0;
  String audience = 'parents';
  final channels = <String>{'app'};
  final title = TextEditingController();
  final body = TextEditingController();
  bool busy = false;

  Future<void> _send() async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      toast(context, 'Add a title and a message.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final r = await Api.I.post('/messaging/broadcast', {'title': title.text.trim(), 'body': body.text.trim(), 'audience': audience, 'channels': channels.toList()});
      if (!mounted) return;
      toast(context, r['message']?.toString() ?? 'Sent');
      title.clear();
      body.clear();
      setState(() => k++);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar('Announcements'),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(k),
        load: () => Api.I.get('/messaging'),
        builder: (context, d, _) {
          final ch = (d['channels'] as Map?) ?? const {};
          final auds = ((d['audiences'] as List?) ?? const []).cast<Map>();
          final recent = ((d['recent'] as List?) ?? const []).cast<Map>();
          if (!auds.any((a) => a['key'] == audience) && auds.isNotEmpty) audience = auds.first['key'] as String;
          return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 28), children: [
            Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<String>(
                  value: auds.any((a) => a['key'] == audience) ? audience : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Send to'),
                  items: [for (final a in auds) DropdownMenuItem(value: a['key'] as String, child: Text(a['label'] as String, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => audience = v ?? audience),
                ),
                const SizedBox(height: 12),
                const Text('Send by', style: TextStyle(fontSize: 12.5, color: kMuted)),
                Wrap(spacing: 8, children: [
                  for (final c in const {'app': 'App', 'sms': 'SMS', 'whatsapp': 'WhatsApp', 'email': 'Email'}.entries)
                    Builder(builder: (_) {
                      final info = ch[c.key] as Map?;
                      final enabled = c.key == 'app' || info?['active'] == true;
                      return FilterChip(
                        label: Text(info?['left'] != null && c.key != 'app' ? '${c.value} · ${info!['left']} left' : c.value),
                        selected: channels.contains(c.key),
                        onSelected: enabled ? (v) => setState(() => v ? channels.add(c.key) : channels.remove(c.key)) : null,
                      );
                    }),
                ]),
                if (ch.values.every((v) => (v as Map)['active'] != true))
                  const Text('SMS / WhatsApp providers are set up on the website → SMS, WhatsApp & Email.', style: TextStyle(fontSize: 11.5, color: kMuted)),
                const SizedBox(height: 10),
                TextField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. School closed tomorrow')),
                TextField(controller: body, maxLength: 900, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
                FilledButton.icon(onPressed: busy || channels.isEmpty ? null : _send, icon: const Icon(Icons.send), label: const Text('Send announcement')),
              ]),
            )),
            const SectionTitle('Recent'),
            if (recent.isEmpty) const EmptyState(Icons.campaign_outlined, 'No announcements yet.'),
            for (final b in recent)
              Card(child: ListTile(
                leading: const GradientIcon(Icons.campaign_outlined, gOrange, size: 40),
                title: Text('${b['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${b['body']}\n${b['recipients']} people · ${b['channels']} · ${b['sent']} sent${(b['failed'] as num? ?? 0) > 0 ? ' · ${b['failed']} failed' : ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                trailing: Text('${b['ago']}', style: const TextStyle(fontSize: 11, color: kMuted)),
                isThreeLine: true,
              )),
          ]);
        },
      ),
    );
  }
}
