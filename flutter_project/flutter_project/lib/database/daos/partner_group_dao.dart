import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../models/partner_group.dart';

class PartnerGroupDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insertGroup(PartnerGroup g) async {
    try {

    final map = g.toMap()..remove('id');
    final result = await _client.from('partner_groups').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> updateGroup(PartnerGroup g) async {
    try {

    final map = g.toMap()..remove('id');
    await _client.from('partner_groups').update(map).eq('id', g.id!);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<int> deleteGroup(int id) async {
    try {

    await _client.from('partner_group_members').delete().eq('group_id', id);
    await _client.from('product_group_assignments').delete().eq('group_id', id);
    await _client.from('group_product_revenues').delete().eq('group_id', id);
    await _client.from('group_cash_flows').delete().eq('group_id', id);
    await _client.from('partner_groups').delete().eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<List<PartnerGroup>> getAllGroups() async {
    try {

    final r = await _client.from('partner_groups').select().order('name', ascending: true);
    return r.map((m) => PartnerGroup.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<PartnerGroup?> findGroupById(int id) async {
    try {

    final r = await _client.from('partner_groups').select().eq('id', id);
    return r.isEmpty ? null : PartnerGroup.fromMap(r.first);
    } catch (_) {
      return null;
    }
}

  Future<List<PartnerGroupMember>> getGroupMembers(int groupId) async {
    try {

    final r = await _client
        .from('partner_group_members')
        .select('*, customers(name, phone), users(name, phone)')
        .eq('group_id', groupId)
        .order('number_of_shares', ascending: false);

    return r.map((row) {
      final m = Map<String, dynamic>.from(row);
      final c = m['customers'] as Map?;
      final u = m['users'] as Map?;
      m['customer_name'] = u?['name'] ?? c?['name'];
      m['customer_phone'] = u?['phone'] ?? c?['phone'];
      m.remove('customers');
      m.remove('users');
      return PartnerGroupMember.fromMap(m);
    }).toList();
    } catch (error, stack) {
      debugPrint('PartnerGroupDao.getGroupMembers failed: $error');
      debugPrint('$stack');
      return [];
    }
}

  Future<int> totalShares(int groupId) async {
    try {

    final members = await getGroupMembers(groupId);
    return members.fold<int>(0, (s, m) => s + m.numberOfShares);
    } catch (_) {
      return -1;
    }
}

  Future<void> setGroupMembers(int groupId, List<PartnerGroupMember> members) async {
    try {

    await _client.from('partner_group_members').delete().eq('group_id', groupId);
    for (final m in members) {
      final map = m.toMap()..remove('id');
      await _client.from('partner_group_members').insert(map);
    }
    } catch (_) {}
}

  Future<int> upsertMember(PartnerGroupMember m) async {
    try {

    final existing = await _client
        .from('partner_group_members')
        .select('id')
        .eq('group_id', m.groupId)
        .eq('customer_id', m.customerId!);
    if (existing.isEmpty) {
      final map = m.toMap()..remove('id');
      final result = await _client.from('partner_group_members').insert(map).select('id').single();
      return result['id'] as int;
    } else {
      await _client.from('partner_group_members')
          .update({'number_of_shares': m.numberOfShares, 'capital_amount': m.capitalAmount})
          .eq('group_id', m.groupId)
          .eq('customer_id', m.customerId!);
      return 1;
    }
    } catch (_) {
      return -1;
    }
}

  Future<int> upsertUserMember(int groupId, int userId, int numberOfShares, double capitalAmount) async {
    try {

    final existing = await _client
        .from('partner_group_members')
        .select('id')
        .eq('group_id', groupId)
        .eq('user_id', userId);
    if (existing.isEmpty) {
      final result = await _client.from('partner_group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'customer_id': null,
        'number_of_shares': numberOfShares,
        'capital_amount': capitalAmount,
      }).select('id').single();
      return result['id'] as int;
    } else {
      await _client.from('partner_group_members')
          .update({'number_of_shares': numberOfShares, 'capital_amount': capitalAmount})
          .eq('group_id', groupId)
          .eq('user_id', userId);
      return 1;
    }
    } catch (error, stack) {
      debugPrint('PartnerGroupDao.upsertUserMember failed: $error');
      debugPrint('$stack');
      return -1;
    }
}

  Future<int> removeMember(int groupId, int customerId) async {
    try {

    await _client.from('partner_group_members')
        .delete().eq('group_id', groupId).eq('customer_id', customerId);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<int> removeUserMember(int groupId, int userId) async {
    try {

    await _client.from('partner_group_members')
        .delete().eq('group_id', groupId).eq('user_id', userId);
    return 1;
    } catch (_) {
      return -1;
    }
}

  // ─── الأقساط المحصلة تُضاف لرصيد الجروب تلقائياً ────────────────────────

  /// يُستدعى عند تحصيل قسط — يضيف المبلغ للتدفق النقدي للجروب
  Future<void> addCollectedInstallmentToBalance({
    required int groupId,
    required double amount,
    required String customerName,
    required String productName,
    String? date,
  }) async {
    try {

    final today = date ?? DateTime.now().toIso8601String().substring(0, 10);
    await _client.from('group_cash_flows').insert({
      'group_id': groupId,
      'type': 'in',
      'amount': amount,
      'description': 'قسط محصّل — $customerName — $productName',
      'date': today,
      'created_at': DateTime.now().toIso8601String(),
    });
    } catch (_) {}
}

  /// يُستدعى عند بيع منتج على تقسيط — يخصم تكلفة المنتج من رأس مال الجروب
  Future<void> deductProductCostFromCapital({
    required int groupId,
    required double cost,
    required String productName,
    String? date,
  }) async {
    try {

    final today = date ?? DateTime.now().toIso8601String().substring(0, 10);
    await _client.from('group_cash_flows').insert({
      'group_id': groupId,
      'type': 'out',
      'amount': cost,
      'description': 'تكلفة منتج — $productName',
      'date': today,
      'created_at': DateTime.now().toIso8601String(),
    });
    } catch (_) {}
}

  // ─── رصيد الجروب ─────────────────────────────────────────────────────────

  Future<double> getGroupBalance(int groupId) async {
    final group = await findGroupById(groupId);
    final startBalance = group?.startingBalance ?? 0.0;

    try {
      final flows = await _client
          .from('group_cash_flows')
          .select('type, amount')
          .eq('group_id', groupId);

      double inFlow = 0, outFlow = 0;
      for (final f in flows) {
        final amt = (f['amount'] as num? ?? 0).toDouble();
        if (f['type'] == 'in') { inFlow += amt; }
        else { outFlow += amt; }
      }
      return startBalance + inFlow - outFlow;
    } catch (_) {
      return startBalance;
    }
  }

  Future<List<Map<String, dynamic>>> getCashFlows(int groupId) async {
    final r = await _client
        .from('group_cash_flows')
        .select()
        .eq('group_id', groupId)
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  /// Alias used by partner_groups_screen
  Future<List<Map<String, dynamic>>> getCashFlowsForGroup(int groupId) =>
      getCashFlows(groupId);

  /// Generic cash flow insertion — used by partner_groups_screen bottom sheet
  Future<void> insertCashFlow({
    required int groupId,
    required String type,
    required double amount,
    String? description,
    String? date,
  }) async {
    try {

    final today = date ?? DateTime.now().toIso8601String().substring(0, 10);
    await _client.from('group_cash_flows').insert({
      'group_id': groupId,
      'type': type,
      'amount': amount,
      'description': description,
      'date': today,
      'created_at': DateTime.now().toIso8601String(),
    });
    } catch (_) {}
}

  /// Returns all group_product_revenues rows for every group the user belongs to
  Future<List<Map<String, dynamic>>> getRevenuesForUser(int userId) async {
    final memberships = await _client
        .from('partner_group_members')
        .select('group_id')
        .eq('user_id', userId);
    if (memberships.isEmpty) return [];

    final groupIds = memberships.map((m) => m['group_id'] as int).toList();
    final r = await _client
        .from('group_product_revenues')
        .select()
        .inFilter('group_id', groupIds)
        .order('year', ascending: false)
        .order('month', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  // ─── Product assignments ──────────────────────────────────────────────────

  Future<int> assignProductToGroup({
    required int? itemId,
    required String itemName,
    required int groupId,
    required double salePrice,
  }) async {
    try {

    final existing = await _client
        .from('product_group_assignments')
        .select('id')
        .eq('group_id', groupId)
        .eq('item_name', itemName);
    if (existing.isNotEmpty) {
      await _client.from('product_group_assignments').update({
        'sale_price': salePrice,
        'assigned_at': DateTime.now().toIso8601String(),
      }).eq('group_id', groupId).eq('item_name', itemName);
      return 1;
    }
    final result = await _client.from('product_group_assignments').insert({
      'item_id': itemId,
      'item_name': itemName,
      'group_id': groupId,
      'sale_price': salePrice,
      'assigned_at': DateTime.now().toIso8601String(),
    }).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<List<Map<String, dynamic>>> getProductAssignments(int groupId) async {
    final r = await _client
        .from('product_group_assignments')
        .select()
        .eq('group_id', groupId)
        .order('assigned_at', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  Future<int> removeProductAssignment(int id) async {
    try {

    await _client.from('product_group_assignments').delete().eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<double> calculateGroupProfit(int groupId) async {
    try {

    final r = await _client
        .from('product_group_assignments')
        .select('sale_price')
        .eq('group_id', groupId);
    return r.fold<double>(0.0, (s, row) => s + (row['sale_price'] as num? ?? 0).toDouble());
    } catch (_) {
      return 0.0;
    }
}

  // ─── Monthly Revenue ──────────────────────────────────────────────────────

  Future<int> upsertMonthlyRevenue({
    required int groupId,
    required String itemName,
    required int month,
    required int year,
    required double revenue,
    String? notes,
  }) async {
    try {

    final existing = await _client
        .from('group_product_revenues')
        .select('id')
        .eq('group_id', groupId)
        .eq('item_name', itemName)
        .eq('month', month)
        .eq('year', year);
    if (existing.isEmpty) {
      final result = await _client.from('group_product_revenues').insert({
        'group_id': groupId,
        'item_name': itemName,
        'month': month,
        'year': year,
        'revenue': revenue,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();
      return result['id'] as int;
    } else {
      await _client.from('group_product_revenues').update({
        'revenue': revenue,
        'notes': notes,
      }).eq('group_id', groupId)
          .eq('item_name', itemName)
          .eq('month', month)
          .eq('year', year);
      return 1;
    }
    } catch (_) {
      return -1;
    }
}

  Future<List<Map<String, dynamic>>> getRevenuesForGroup(int groupId, {int? year}) async {
    var q = _client.from('group_product_revenues').select().eq('group_id', groupId);
    if (year != null) q = q.eq('year', year) as dynamic;
    final r = await (q as dynamic).order('year', ascending: false).order('month', ascending: false);
    return List<Map<String, dynamic>>.from(r as List);
  }

  Future<int> deleteRevenue(int id) async {
    try {

    await _client.from('group_product_revenues').delete().eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<List<Map<String, dynamic>>> getInstallmentsForGroup(int groupId) async {
    final r = await _client
        .from('installments')
        .select('*, customers(name, phone)')
        .eq('partner_group_id', groupId)
        .order('created_at', ascending: false);
    return r.map((row) {
      final m = Map<String, dynamic>.from(row);
      final c = m['customers'] as Map?;
      m['customer_name'] = c?['name'] ?? m['customer_name'];
      m['customer_phone'] = c?['phone'] ?? m['customer_phone'];
      m.remove('customers');
      // Normalise field names: some screens use paid_amount, others use total_price
      if (!m.containsKey('paid_amount')) {
        m['paid_amount'] = m['total_paid'] ?? 0;
      }
      if (!m.containsKey('total_price')) {
        m['total_price'] = m['total_installment_price'] ?? m['amount'] ?? 0;
      }
      // Compute status from paid_amount vs total_price if missing
      if (m['status'] == null || (m['status'] as String).isEmpty) {
        final paid = (m['paid_amount'] as num? ?? 0).toDouble();
        final total = (m['total_price'] as num? ?? 0).toDouble();
        m['status'] = total > 0 && paid >= total ? 'completed' : 'active';
      }
      return m;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupsForCustomer(int customerId) async {
    final r = await _client
        .from('partner_group_members')
        .select('number_of_shares, capital_amount, partner_groups(id, name, description, starting_balance, created_at)')
        .eq('customer_id', customerId);
    return r.map((row) {
      final m = Map<String, dynamic>.from(row);
      final g = m['partner_groups'] as Map?;
      return {
        ...?g?.cast<String, dynamic>(),
        'number_of_shares': m['number_of_shares'],
        'capital_amount': m['capital_amount'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupsForUser(int userId) async {
    final r = await _client
        .from('partner_group_members')
        .select('number_of_shares, capital_amount, partner_groups(id, name, description, starting_balance, created_at)')
        .eq('user_id', userId);
    return r.map((row) {
      final m = Map<String, dynamic>.from(row);
      final g = m['partner_groups'] as Map?;
      return {
        ...?g?.cast<String, dynamic>(),
        'number_of_shares': m['number_of_shares'],
        'capital_amount': m['capital_amount'],
      };
    }).toList();
  }

  Future<int> upsertUserMemberWithCapital(
      int groupId, int userId, int numberOfShares, double capitalAmount) async {
    try {

    return upsertUserMember(groupId, userId, numberOfShares, capitalAmount);
    } catch (_) {
      return -1;
    }
}
}

extension PartnerGroupDaoExt on PartnerGroupDao {
  /// Returns summary: {'in': totalIn, 'out': totalOut}
  Future<Map<String, double>> getCashFlowSummary(int groupId) async {
    try {

    final flows = await getCashFlows(groupId);
    double inFlow = 0, outFlow = 0;
    for (final f in flows) {
      final amt = (f['amount'] as num? ?? 0).toDouble();
      if (f['type'] == 'in') { inFlow += amt; } else { outFlow += amt; }
    }
    return {'in': inFlow, 'out': outFlow};
    } catch (_) {
      return {};
    }
}
}
