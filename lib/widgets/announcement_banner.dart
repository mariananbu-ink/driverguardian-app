// Announcements from the school flash at the top of every screen until the user
// closes them or marks them read (MaterialBanner on the app-wide ScaffoldMessenger).
// Developed & Powered by Marian Anbu Juwan
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';

class Announcements {
  Announcements._();
  static int? _showing;

  static Future<Set<String>> _closed() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList('ann_closed_${Api.I.user?['id'] ?? 0}') ?? const []).toSet();
  }

  static Future<void> _close(int id) async {
    final p = await SharedPreferences.getInstance();
    final k = 'ann_closed_${Api.I.user?['id'] ?? 0}';
    final list = [...(p.getStringList(k) ?? const <String>[]), '$id'];
    await p.setStringList(k, list.length > 50 ? list.sublist(list.length - 50) : list);
  }

  /// Call with the GET /notifications list (newest first).
  static Future<void> update(ScaffoldMessengerState? messenger, List<Map> list) async {
    if (messenger == null) return;
    final closed = await _closed();
    final open = list.where((n) => n['type'] == 'broadcast' && n['read'] != true && !closed.contains('${n['id']}')).toList();
    if (open.isEmpty) {
      if (_showing != null) { messenger.hideCurrentMaterialBanner(); _showing = null; }
      return;
    }
    final n = open.first;
    if (_showing == n['id']) return;
    _showing = n['id'] as int;
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(MaterialBanner(
      padding: EdgeInsets.zero,
      leadingPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      elevation: 0,
      dividerColor: Colors.transparent,
      content: _Flash(
        title: '${n['title']}',
        body: '${n['body'] ?? ''}',
        more: open.length - 1,
        onRead: () async {
          messenger.hideCurrentMaterialBanner();
          _showing = null;
          try { await Api.I.post('/notifications/read', {'id': n['id']}); } catch (_) {}
          n['read'] = true;
          await update(messenger, list);
        },
        onClose: () async {
          messenger.hideCurrentMaterialBanner();
          _showing = null;
          await _close(n['id'] as int);
          await update(messenger, list);
        },
      ),
      actions: const [SizedBox.shrink()],
    ));
  }
}

class _Flash extends StatefulWidget {
  final String title;
  final String body;
  final int more;
  final VoidCallback onRead;
  final VoidCallback onClose;
  const _Flash({required this.title, required this.body, required this.more, required this.onRead, required this.onClose});
  @override
  State<_Flash> createState() => _FlashState();
}

class _FlashState extends State<_Flash> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (context, child) => Container(
          margin: EdgeInsets.fromLTRB(10, MediaQuery.of(context).padding.top > 0 ? 6 : 8, 10, 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color.lerp(const Color(0xFF4F46E5), const Color(0xFF7C3AED), c.value)!, Color.lerp(const Color(0xFF7C3AED), const Color(0xFFDB2777), c.value)!]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: .25 + .35 * c.value), blurRadius: 8 + 12 * c.value, spreadRadius: 1 + 2 * c.value)],
          ),
          child: child,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RotationTransition(
              turns: Tween(begin: -.03, end: .03).animate(c),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.campaign_rounded, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
              if (widget.body.isNotEmpty) Text(widget.body, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
              Text('Announcement${widget.more > 0 ? ' · ${widget.more} more' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.white, size: 20), tooltip: 'Close', visualDensity: VisualDensity.compact),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white24, visualDensity: VisualDensity.compact),
              onPressed: widget.onRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark as read'),
            ),
          ),
        ]),
      );
}
