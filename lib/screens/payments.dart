import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';

/// Parents: invoices + pay by UPI. Admins: verify submitted UTRs.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  int k = 0;
  String filter = 'submitted';

  Future<void> _verify(Map p, bool ok) async {
    String reason = '';
    final extra = <String, String>{};
    if (ok) {
      // 2.12: receipt no. and a note for the office record (both optional)
      final rc = TextEditingController(), nc = TextEditingController();
      final go = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Verify ${p['invoice_no']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${p['amount_label'] ?? ''}${p['upi_ref'] != null ? ' · UTR ${p['upi_ref']}' : ''}', style: const TextStyle(color: Colors.black54)),
          TextField(controller: rc, decoration: const InputDecoration(labelText: 'Receipt no. (optional)')),
          TextField(controller: nc, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark as paid'))],
      ));
      if (go != true) return;
      if (rc.text.trim().isNotEmpty) extra['receipt_no'] = rc.text.trim();
      if (nc.text.trim().isNotEmpty) extra['pay_note'] = nc.text.trim();
    }
    if (!ok) {
      final c = TextEditingController(text: 'UTR not found in bank statement');
      final go = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Send back to parent'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send'))],
      ));
      if (go != true) return;
      reason = c.text;
    }
    try {
      await Api.I.post('/payments/${p['id']}/${ok ? 'verify' : 'reject'}', {'reason': reason, ...extra});
      toast(context, ok ? '${p['invoice_no']} marked as paid' : 'Sent back to parent');
      setState(() => k++);
    } catch (e) {
      toast(context, errText(e), error: true);
    }
  }

  void _receipt(Map p) {
    final school = (Api.I.user?['school'] as Map?)?['name'] ?? '';
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Payment receipt'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$school', style: const TextStyle(fontWeight: FontWeight.w700)),
        const Divider(),
        Text('Invoice: ${p['invoice_no']}'),
        Text('Student: ${p['student'] ?? ''}'),
        Text('Period: ${p['period'] ?? ''}'),
        Text('Amount: ${p['amount_label']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('Paid: ${p['paid_at'] ?? ''}'),
        Text('Method: ${p['method_label'] ?? (p['method'] ?? '').toString().toUpperCase()}'),
        if (p['upi_ref'] != null) Text('UTR / Ref: ${p['upi_ref']}'),
        if (p['receipt_no'] != null) Text('Receipt no.: ${p['receipt_no']}'),
        if (p['received_on'] != null) Text('Received on: ${p['received_on']}'),
        if (((p['discount'] as num?) ?? 0) > 0) Text('Discount: ₹${p['discount']}'),
        if (p['note'] != null && Api.I.isAdmin) Text('Note: ${p['note']}'),
        const SizedBox(height: 8),
        const Text('Printable copy: sign in on the website → Fees & Payments.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final admin = Api.I.isAdmin;
    return Loader<Map<String, dynamic>>(
      key: ValueKey('$k-$filter'),
      load: () => Api.I.get('/payments', admin && filter != 'all' ? {'status': filter} : null),
      builder: (context, d, reload) {
        final list = (d['payments'] as List).cast<Map>();
        final pending = list.where((p) => p['status'] == 'pending');
        return ListView(padding: const EdgeInsets.all(12), children: [
          if (admin)
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'submitted', label: Text('To verify')), ButtonSegment(value: 'pending', label: Text('Pending')), ButtonSegment(value: 'paid', label: Text('Paid'))],
              selected: {filter},
              onSelectionChanged: (s) => setState(() => filter = s.first),
            )
          else
            Row(children: [
              Expanded(child: Kpi(label: 'Outstanding', value: inr(pending.fold<num>(0, (a, p) => a + (p['amount'] as num))), meta: '${pending.length} to pay', icon: Icons.currency_rupee, colors: gOrange)),
              const SizedBox(width: 10),
              Expanded(child: Kpi(label: 'Paid', value: inr(list.where((p) => p['status'] == 'paid').fold<num>(0, (a, p) => a + (p['amount'] as num))), meta: '${list.where((p) => p['status'] == 'paid').length} receipts', icon: Icons.receipt_long, colors: gGreen)),
            ]),
          const SizedBox(height: 10),
          if (list.isEmpty) const EmptyState(Icons.receipt_long, 'No invoices here.'),
          for (final p in list)
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['invoice_no'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${p['student'] ?? ''} · ${p['period'] ?? ''}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  ])),
                  StatusChip(p['status'] as String?),
                ]),
                const SizedBox(height: 6),
                Text(p['amount_label'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text('${p['description'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (p['due_date'] != null && p['status'] != 'paid') Text('Due ${p['due_date']}${p['overdue'] == true ? ' · overdue' : ''}', style: TextStyle(fontSize: 12, color: p['overdue'] == true ? Colors.red : Colors.black54)),
                if (p['upi_ref'] != null) Text('UTR ${p['upi_ref']}', style: const TextStyle(fontSize: 12)),
                if (p['reject_reason'] != null && p['status'] == 'pending') Text('⚠ ${p['reject_reason']}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                if (p['paid_at'] != null) Text('Paid ${p['paid_at']} · ${(p['method'] ?? '').toString().toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                const SizedBox(height: 8),
                if (!admin && p['status'] != 'paid')
                  FilledButton.icon(
                    onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => PayScreen(id: p['id'] as int))); setState(() => k++); },
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(p['status'] == 'submitted' ? 'View / correct UTR' : 'Pay now'),
                  ),
                if (p['status'] == 'paid')
                  OutlinedButton.icon(onPressed: () => _receipt(p), icon: const Icon(Icons.receipt), label: const Text('Receipt')),
                if (admin && p['status'] == 'submitted')
                  Row(children: [
                    Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700), onPressed: () => _verify(p, true), icon: const Icon(Icons.check), label: const Text('Verify'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _verify(p, false), icon: const Icon(Icons.close), label: const Text('Reject'))),
                  ]),
              ]),
            )),
          const SizedBox(height: 70),
        ]);
      },
    );
  }
}

class PayScreen extends StatefulWidget {
  final int id;
  const PayScreen({super.key, required this.id});
  @override
  State<PayScreen> createState() => _PayScreenState();
}

IconData _gwIcon(String k) => switch (k) {
      'razorpay' => Icons.bolt,
      'cashfree' => Icons.payments_outlined,
      'phonepe' => Icons.phone_android,
      'payu' => Icons.credit_card,
      'stripe' => Icons.public,
      'demo' => Icons.science_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };

String _gwHint(String k) => switch (k) {
      'razorpay' || 'cashfree' || 'phonepe' || 'payu' => 'UPI, cards, net-banking, wallets',
      'stripe' => 'International cards',
      'demo' => 'Test only',
      _ => 'Online payment',
    };

class _PayScreenState extends State<PayScreen> {
  final utr = TextEditingController();
  bool busy = false;
  int reload = 0;

  Future<void> _open(String link) async {
    final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!ok && mounted) toast(context, 'That app is not installed. Try another UPI app or scan the QR.', error: true);
  }

  /// Online gateway: server creates the order and returns a signed checkout link; we open it in the browser.
  Future<void> _gateway(String key) async {
    setState(() => busy = true);
    try {
      final r = await Api.I.post('/payments/${widget.id}/online', {'gateway': key});
      final url = r['url'] as String?;
      if (url == null) throw ApiException(r['message']?.toString() ?? 'Could not start the payment.', 422);
      if (!mounted) return;
      final ok = await openCheckout(context, url);
      if (!mounted) return;
      if (!ok) {
        toast(context, 'Payment page not opened.', error: true);
      } else {
        await showDialog(context: context, builder: (c) => AlertDialog(
          title: const Text('Finish in your browser'),
          content: const Text('Complete the payment on the page that opened. The invoice is marked paid automatically — tap Done when you are back.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
        ));
        if (mounted) setState(() => reload++);
      }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    final v = utr.text.trim();
    if (!RegExp(r'^[A-Za-z0-9]{8,30}$').hasMatch(v)) {
      toast(context, 'Enter the 12-digit UTR / UPI reference from your payment app.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      await Api.I.post('/payments/${widget.id}/utr', {'upi_ref': v});
      toast(context, 'Thank you! Sent to the school for verification.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar('Pay fees'),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(reload),
        load: () => Api.I.get('/payments/${widget.id}/upi'),
        builder: (context, d, _) {
          final p = d['payment'] as Map;
          final link = d['upi_link'] as String?;
          final apps = (d['apps'] as Map?) ?? {};
          final gws = ((d['gateways'] as List?) ?? const []).cast<Map>();
          if (utr.text.isEmpty && p['upi_ref'] != null) utr.text = p['upi_ref'] as String;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Center(child: Text(p['amount_label'] as String, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800))),
            Center(child: Text('${p['invoice_no']} · ${p['student'] ?? ''}', style: const TextStyle(color: Colors.black54))),
            if (p['status'] == 'paid')
              const Padding(padding: EdgeInsets.only(top: 16), child: Card(child: ListTile(leading: Icon(Icons.verified, color: Colors.green), title: Text('Paid — thank you!'), subtitle: Text('The receipt is in Fees & Payments.')))),
            const SizedBox(height: 16),
            if (p['status'] != 'paid' && gws.isNotEmpty) ...[
              const SectionTitle('Pay online · confirmed instantly'),
              for (final g in gws)
                Card(child: ListTile(
                  leading: GradientIcon(_gwIcon(g['key'] as String), g['key'] == 'demo' ? gSlate : gBlue, size: 40),
                  title: Text(g['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_gwHint(g['key'] as String)),
                  trailing: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
                  onTap: busy ? null : () => _gateway(g['key'] as String),
                )),
              if (link != null) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('— or pay by UPI and submit the UTR —', textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 12.5))),
            ],
            if (p['status'] == 'paid')
              const SizedBox.shrink()
            else if (link == null && gws.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('The school has not set up online payment yet. Please pay at the school office.')))
            else if (link != null) ...[
              Center(child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFC7D2FE), width: 2)),
                child: Column(children: [
                  QrImageView(data: link, size: 210, backgroundColor: Colors.white),
                  const SizedBox(height: 6),
                  Text('Pay to ${d['payee']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${d['upi_id']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ]),
              )),
              const SizedBox(height: 14),
              const Text('Or open your UPI app:', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                for (final e in {'gpay': 'GPay', 'phonepe': 'PhonePe', 'paytm': 'Paytm', 'bhim': 'BHIM / any UPI'}.entries)
                  if (apps[e.key] != null) OutlinedButton(onPressed: () => _open(apps[e.key] as String), child: Text(e.value)),
              ]),
              const SectionTitle('Step 2 · Submit the UTR'),
              const Text('After paying, copy the UTR / UPI reference number (usually 12 digits) from the transaction details in your UPI app.', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              if (p['reject_reason'] != null) Text('⚠ ${p['reject_reason']}', style: const TextStyle(color: Colors.red)),
              TextField(controller: utr, keyboardType: TextInputType.text, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'UTR / reference number')),
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: busy ? null : _submit, icon: const Icon(Icons.send), label: const Text('Submit for verification')),
            ],
          ]);
        },
      ),
    );
  }
}
