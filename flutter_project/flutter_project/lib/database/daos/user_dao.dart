import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter/foundation.dart';
import '../../models/user.dart';

class UserDao {
  SupabaseClient get _client => Supabase.instance.client;

  String? lastError;

  Future<int> insert(User u) async {
    try {
      final existing =
          await _client.from('users').select('id').eq('username', u.username);
      if ((existing as List).isNotEmpty) {
        lastError = 'اسم المستخدم موجود بالفعل';
        return -2;
      }

      final map = u.toMap()..remove('id');
      map.removeWhere((key, value) => value == null);
      if (map['permissions'] == '') {
        map.remove('permissions');
      }

      final result =
          await _client.from('users').insert(map).select('id').single();
      return result['id'] as int;
    } catch (error, stack) {
      lastError = error.toString();
      debugPrint('UserDao.insert failed: $error');
      debugPrint('$stack');
      return -1;
    }
  }

  Future<User?> findById(int id) async {
    try {
      final r = await _client.from('users').select().eq('id', id);
      return r.isEmpty ? null : User.fromMap(r.first);
    } catch (_) {
      return null;
    }
  }

  Future<User?> findByUsername(String username) async {
    try {
      final r = await _client
          .from('users')
          .select()
          .eq('username', username)
          .eq('is_active', true);
      return r.isEmpty ? null : User.fromMap(r.first);
    } catch (_) {
      return null;
    }
  }

  Future<User?> findByLoginCode(String code) async {
    try {
      final normalizedCode = code.trim();
      final r = await _client
          .from('users')
          .select()
          .ilike('login_code', normalizedCode)
          .eq('is_active', true);
      try {
        final list = r as List;
        if (list.isEmpty) {
          debugPrint(
              'UserDao.findByLoginCode: no match for "$normalizedCode". Running diagnostic.');
          print(
              'UserDao.findByLoginCode: no match for "$normalizedCode". Running diagnostic.');
          final diag = await _client
              .from('users')
              .select('id, login_code, role, is_active')
              .ilike('login_code', '%$normalizedCode%')
              .limit(10);
          debugPrint('UserDao.findByLoginCode diagnostic result: $diag');
          print('UserDao.findByLoginCode diagnostic result: $diag');
          return null;
        }
        debugPrint(
            'UserDao.findByLoginCode: found ${list.length} row(s) for "$normalizedCode".');
        print(
            'UserDao.findByLoginCode: found ${list.length} row(s) for "$normalizedCode".');
        return User.fromMap(list.first as Map<String, dynamic>);
      } catch (e) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<List<User>> findAllByLoginCode(String code) async {
    try {
      final normalizedCode = code.trim();
      final r = await _client
          .from('users')
          .select()
          .ilike('login_code', normalizedCode)
          .eq('is_active', true);
      final list = r as List;
      if (list.isEmpty) {
        debugPrint(
            'UserDao.findAllByLoginCode: no match for "$normalizedCode". Running diagnostic.');
        print(
            'UserDao.findAllByLoginCode: no match for "$normalizedCode". Running diagnostic.');
        final diag = await _client
            .from('users')
            .select('id, login_code, role, is_active')
            .ilike('login_code', '%$normalizedCode%')
            .limit(10);
        debugPrint('UserDao.findAllByLoginCode diagnostic result: $diag');
        print('UserDao.findAllByLoginCode diagnostic result: $diag');
        return [];
      }
      debugPrint(
          'UserDao.findAllByLoginCode: found ${list.length} row(s) for "$normalizedCode".');
      print(
          'UserDao.findAllByLoginCode: found ${list.length} row(s) for "$normalizedCode".');
      return list.map((m) => User.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> loginCodeExists(String code) async {
    try {
      final normalizedCode = code.trim();
      // Check users
      final u = await _client
          .from('users')
          .select('id')
          .ilike('login_code', normalizedCode)
          .limit(1);
      if ((u as List).isNotEmpty) return true;
      // Check customers
      final c = await _client
          .from('customers')
          .select('id')
          .ilike('login_code', normalizedCode)
          .limit(1);
      if ((c as List).isNotEmpty) return true;
      // Check temporary access codes (exact match)
      final t = await _client
          .from('temporary_access_codes')
          .select('id')
          .eq('code', normalizedCode)
          .limit(1);
      return (t as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<User>> getAll({bool activeOnly = false}) async {
    try {
      var query = _client.from('users').select();
      if (activeOnly) query = query.eq('is_active', true) as dynamic;
      final r = await (query as dynamic).order('name', ascending: true);
      return (r as List)
          .map<User>((m) => User.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<User>> getByRole(String role) async {
    try {
      final r = await _client
          .from('users')
          .select()
          .eq('role', role)
          .eq('is_active', true)
          .order('name', ascending: true);
      return r.map((m) => User.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> update(User u) async {
    try {
      final map = u.toMap()..remove('id');
      await _client.from('users').update(map).eq('id', u.id!);
      return 1;
    } catch (_) {
      return -1;
    }
  }

  Future<int> updateLoginCode(int id, String? code,
      {String? codeType, String? codeExpiry}) async {
    try {
      final normalized = code?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        // Remove same code from other users (case-insensitive)
        await _client
            .from('users')
            .update({
              'login_code': null,
              'code_type': 'permanent',
              'code_expiry': null
            })
            .ilike('login_code', normalized)
            .neq('id', id);

        // Remove same code from customers
        await _client
            .from('customers')
            .update({'login_code': null}).ilike('login_code', normalized);

        // Remove temporary access codes that match exactly
        try {
          await _client
              .from('temporary_access_codes')
              .delete()
              .eq('code', normalized);
        } catch (_) {
          // ignore if table/column doesn't exist
        }
      }

      // Finally assign to target user (set as permanent by default)
      await _client.from('users').update({
        'login_code': normalized,
        if (codeType != null) 'code_type': codeType,
        if (codeExpiry != null) 'code_expiry': codeExpiry,
      }).eq('id', id);
      return 1;
    } catch (_) {
      return -1;
    }
  }

  Future<int> updateCredentials(
      int id, String username, String passwordHash) async {
    try {
      await _client.from('users').update({
        'username': username,
        'password_hash': passwordHash,
      }).eq('id', id);
      return 1;
    } catch (_) {
      return -1;
    }
  }

  Future<int> delete(int id) async {
    try {
      await _client.from('users').update({'is_active': false}).eq('id', id);
      return 1;
    } catch (_) {
      return -1;
    }
  }

  Future<int> hardDelete(int id) async {
    try {
      await _client.from('users').delete().eq('id', id);
      return 1;
    } catch (_) {
      return -1;
    }
  }
}
