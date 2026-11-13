import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class ThreadsScreen extends StatefulWidget {
  const ThreadsScreen({super.key});
  @override
  State<ThreadsScreen> createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends State<ThreadsScreen> {
  int k = 0;

  Future<void> _new() async {
    try {
      final d = await Api.I.get('/messages/contacts');
      final list = (d['contacts'] as List).cast<Map>();
      if (!mounted) return;
      final picked = await showModalBottomSheet<Map>(context: context, builder: (c) => ListView(children: [
        const ListTile(title: Text('New message', style: TextStyle(fontWeight: FontWeight.w700))),
        if (list.isEmpty) const EmptyState(Icons.people_outline, 'No contacts available.'),
        for (final u in list) ListTile(leading: Avatar(u['name'] as String, size: 36), title: Text(u['name'] as String), subtitle: Text(u['role'] as String), onTap: () => Navigator.pop(c, u)),
      ]));
      if (picked != null && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(userId: picked['id'] as int, name: picked['name'] as String)));
        setState(() => k++);
      }
    } catch (e) {
      toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Loader<Map<String, dynamic>>(
        key: ValueKey(k),
        load: () => Api.I.get('/messages/threads'),
        builder: (context, d, _) {
          final list = (d['threads'] as List).cast<Map>();
          return ListView(children: [
            if (list.isEmpty) const EmptyState(Icons.chat_bubble_outline, 'No conversations yet. Tap + to message the school or driver.'),
            for (final t in list)
              ListTile(
                leading: Avatar((t['user'] as Map)['name'] as String),
                title: Text((t['user'] as Map)['name'] as String, style: TextStyle(fontWeight: (t['unread'] as int) > 0 ? FontWeight.w700 : FontWeight.w500)),
                subtitle: Text('${t['mine'] == true ? 'You: ' : ''}${t['last']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(t['at'] as String, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  if ((t['unread'] as int) > 0) Badge(label: Text('${t['unread']}')),
                ]),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(userId: (t['user'] as Map)['id'] as int, name: (t['user'] as Map)['name'] as String)));
                  setState(() => k++);
                },
              ),
          ]);
        },
      ),
      Positioned(right: 16, bottom: 86, child: FloatingActionButton.small(heroTag: 'newmsg', onPressed: _new, child: const Icon(Icons.add))),
    ]);
  }
}

class ChatScreen extends StatefulWidget {
  final int userId;
  final String name;
  const ChatScreen({super.key, required this.userId, required this.name});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final msgs = <Map>[];
  final input = TextEditingController();
  final scroll = ScrollController();
  Timer? timer;
  String? error;

  @override
  void initState() {
    super.initState();
    _poll();
    timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final after = msgs.isEmpty ? 0 : msgs.last['id'] as int;
    try {
      final d = await Api.I.get('/messages/${widget.userId}', {'after': '$after'});
      final list = (d['messages'] as List).cast<Map>();
      if (list.isNotEmpty && mounted) {
        setState(() => msgs.addAll(list.where((m) => !msgs.any((x) => x['id'] == m['id']))));
        _bottom();
      }
    } catch (e) {
      if (mounted && msgs.isEmpty) setState(() => error = errText(e));
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  Future<void> _send() async {
    final t = input.text.trim();
    if (t.isEmpty) return;
    input.clear();
    try {
      final r = await Api.I.post('/messages/${widget.userId}', {'body': t});
      setState(() => msgs.add(r['message'] as Map));
      _bottom();
    } catch (e) {
      input.text = t;
      toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar(widget.name),
      body: Column(children: [
        Expanded(
          child: error != null
              ? EmptyState(Icons.block, error!)
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = m['mine'] == true;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .75),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: mine ? kBlue : Colors.white, borderRadius: BorderRadius.circular(14), border: mine ? null : Border.all(color: const Color(0xFFE6EAF2))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(m['body'] as String, style: TextStyle(color: mine ? Colors.white : Colors.black87)),
                          Text(m['time'] as String, style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.black45)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Type a message…'))),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
