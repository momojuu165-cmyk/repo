import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/chat_dao.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';
import 'chat_detail_screen.dart';

// Point 9: Admin sees list of all partners to chat with
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _dao = ChatDao();
  List<Map<String, dynamic>> _partners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final adminId = auth.currentUser?.id ?? 0;
      final list = await _dao.getPartnerChatList(adminId);
      if (mounted) {
        setState(() {
          _partners = list;
          _loading = false;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myId = auth.currentUser?.id ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحادثات مع الشركاء'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _partners.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('لا يوجد شركاء للمحادثة',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Directionality(
                  textDirection: TextDirection.rtl,
                  child: ListView.separated(
                    itemCount: _partners.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = _partners[i];
                      final unread = (p['unread_count'] as int? ?? 0);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(AppColors.primaryInt),
                          child: Text(
                            (p['name'] as String? ?? '?')
                                .substring(0, 1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(p['name'] as String? ?? ''),
                        subtitle: Text(
                          p['last_message'] as String? ?? 'لا توجد رسائل',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: unread > 0
                                  ? Colors.black87
                                  : Colors.grey),
                        ),
                        trailing: unread > 0
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    const Color(AppColors.accentInt),
                                child: Text('$unread',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              )
                            : null,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                myId: myId,
                                myName: auth.currentUser?.name ?? 'الإدارة',
                                otherId: p['id'] as int,
                                otherName: p['name'] as String? ?? '',
                              ),
                            ),
                          );
                          _load();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
