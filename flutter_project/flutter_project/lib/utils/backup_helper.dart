import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// BackupHelper — يُصدِّر بيانات Supabase كـ JSON ويُشاركها
class BackupHelper {
  static const _prefKey = 'last_backup_ts';
  static final SupabaseClient _client = Supabase.instance.client;

  /// تشغيل نسخة احتياطية تلقائية إذا مرّت 24 ساعة منذ آخر نسخة
  static Future<void> maybeAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTs = prefs.getInt(_prefKey) ?? 0;
      final last = DateTime.fromMillisecondsSinceEpoch(lastTs);
      if (DateTime.now().difference(last).inHours >= 24) {
        await forceBackup(silent: true);
      }
    } catch (_) {}
  }

  /// إنشاء نسخة احتياطية كاملة وحفظها + مشاركتها
  static Future<String?> forceBackup({bool silent = false}) async {
    try {
      final data = await _exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName =
          'backup_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr, encoding: utf8);

      // حفظ وقت آخر نسخة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, now.millisecondsSinceEpoch);

      if (!silent) {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'نسخة احتياطية — فرصتك للتقسيط — ${_formatDate(now)}',
        ));
      }
      return file.path;
    } catch (e) {
      debugPrint('Backup error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _exportAllData() async {
    final tables = [
      'customers', 'items', 'installments', 'installment_payments',
      'sales_invoices', 'sales_invoice_items', 'suppliers',
      'partner_groups', 'partner_group_members', 'group_cash_flows',
      'group_product_revenues', 'notifications', 'audit_logs',
      'app_settings', 'price_lists', 'price_list_items',
      'electrical_bundles', 'expenses', 'treasuries',
    ];

    final export = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'فرصتك للتقسيط',
      'version': '3.1.0',
    };

    for (final table in tables) {
      try {
        final rows = await _client.from(table).select();
        export[table] = rows;
      } catch (_) {
        export[table] = [];
      }
    }
    return export;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
  static String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  /// قائمة النسخ الاحتياطية المحفوظة محلياً
  static Future<List<FileSystemEntity>> listBackups() async {
    try {
      final dir = await getTemporaryDirectory();
      return dir
          .listSync()
          .where((f) => f.path.contains('backup_') && f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (_) {
      return [];
    }
  }

  static Future<DateTime?> lastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_prefKey);
    if (ts == null || ts == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }
}
