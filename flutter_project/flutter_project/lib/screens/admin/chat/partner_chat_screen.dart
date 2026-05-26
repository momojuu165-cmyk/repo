import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/user_dao.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';
import 'chat_detail_screen.dart';

// Point 9: Partner-side chat screen (chat with admin)
class PartnerChatScreen extends StatefulWidget {
  const PartnerChatScreen({super.key});

  @override
  State<PartnerChatScreen> createState() => _PartnerChatScreenState();
}

class _PartnerChatScreenState extends State<PartnerChatScreen> {
  int? _adminId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveAdminId();
  }

  Future<void> _resolveAdminId() async {
    try {
      final admins = await UserDao().getByRole(AppConstants.roleAdmin);
      if (mounted) {
        setState(() {
          // Use the first active admin; fall back to 1 if none found yet
          _adminId = admins.isNotEmpty ? admins.first.id : 1;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _adminId = 1; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('يجب تسجيل الدخول أولاً')));
    }

    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return ChatDetailScreen(
      myId: user.id ?? 0,
      myName: user.name,
      otherId: _adminId!,
      otherName: 'الإدارة',
    );
  }
}
