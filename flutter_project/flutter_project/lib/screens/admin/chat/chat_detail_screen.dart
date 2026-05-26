import 'dart:async';
import 'package:flutter/material.dart';
import '../../../database/daos/chat_dao.dart';
import '../../../models/chat_message.dart';
import '../../../utils/constants.dart';

// Point 9: Direct chat between admin and each partner
class ChatDetailScreen extends StatefulWidget {
  final int myId;
  final String myName;
  final int otherId;
  final String otherName;

  const ChatDetailScreen({
    super.key,
    required this.myId,
    required this.myName,
    required this.otherId,
    required this.otherName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _dao = ChatDao();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Poll every 5 seconds for new messages
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final msgs =
        await _dao.getConversation(widget.myId, widget.otherId);
    await _dao.markAsRead(widget.otherId, widget.myId);
    if (mounted) {
      setState(() => _messages = msgs);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    // Do NOT clear before the insert — restore text if it fails
    final msg = ChatMessage(
      senderId: widget.myId,
      receiverId: widget.otherId,
      senderName: widget.myName,
      message: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _dao.insert(msg);
      _msgCtrl.clear(); // clear only after successful save
      _load();
    } catch (e) {
      // Restore the text so the user doesn't lose their message
      _msgCtrl.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الرسالة: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.otherName),
          backgroundColor: const Color(AppColors.primaryInt),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Text('لا توجد رسائل بعد',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final m = _messages[i];
                        final isMine = m.senderId == widget.myId;
                        return _MessageBubble(msg: m, isMine: isMine);
                      },
                    ),
            ),
            // Input area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, -1))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    backgroundColor: const Color(AppColors.primaryInt),
                    foregroundColor: Colors.white,
                    onPressed: _send,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMine;

  const _MessageBubble({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final time = msg.createdAt.length >= 16
        ? msg.createdAt.substring(11, 16)
        : '';
    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMine
              ? const Color(AppColors.primaryInt)
              : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine ? Radius.zero : const Radius.circular(16),
            bottomRight: isMine ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.message,
              style: TextStyle(
                  color: isMine ? Colors.white : Colors.black87,
                  fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                  fontSize: 10,
                  color: isMine
                      ? Colors.white70
                      : Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
