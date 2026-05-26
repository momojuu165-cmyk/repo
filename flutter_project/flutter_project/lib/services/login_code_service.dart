import 'dart:math';
import '../database/daos/user_dao.dart';

class LoginCodeService {
  final _userDao = UserDao();
  final _random = Random();

  /// Generate a unique 6-digit code and assign it to [userId].
  /// If [temporary] is true, set expiry to [hours] hours from now.
  Future<String> generateAndAssign(int userId, {bool temporary = false, int hours = 12}) async {
    String code = '';
    int attempts = 0;
    while (attempts < 10) {
      code = _generateCode();
      final exists = await _userDao.loginCodeExists(code);
      if (!exists) break;
      attempts++;
    }
    if (attempts >= 10) {
      // fallback to fully random 6-digit until unique
      do {
        code = _random.nextInt(1000000).toString().padLeft(6, '0');
      } while (await _userDao.loginCodeExists(code));
    }

    String? expiry;
    final codeType = temporary ? 'temporary' : 'permanent';
    if (temporary) {
      final exp = DateTime.now().add(Duration(hours: hours)).toUtc();
      expiry = exp.toIso8601String();
    }

    final res = await _userDao.updateLoginCode(userId, code, codeType: codeType, codeExpiry: expiry);
    if (res < 0) throw Exception('Failed to assign login code');
    return code;
  }

  String _generateCode() {
    final ts = DateTime.now().millisecondsSinceEpoch % 1000000;
    final seed = (ts + _random.nextInt(1000000)) % 1000000;
    return seed.toString().padLeft(6, '0');
  }
}
