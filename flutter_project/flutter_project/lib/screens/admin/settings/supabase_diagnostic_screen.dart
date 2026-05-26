import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/supabase_config.dart';

class SupabaseDiagnosticScreen extends StatefulWidget {
  const SupabaseDiagnosticScreen({super.key});

  @override
  State<SupabaseDiagnosticScreen> createState() =>
      _SupabaseDiagnosticScreenState();
}

class _SupabaseDiagnosticScreenState extends State<SupabaseDiagnosticScreen> {
  SupabaseClient get _db => Supabase.instance.client;

  final List<_DiagRow> _results = [];
  bool _running = false;

  // SQL to copy and run in the Supabase SQL Editor
  static const _setupSql = '''-- ═══════════════════════════════════════════════════════
-- إعداد نظام النقاط — شغّل هذا في Supabase SQL Editor
-- ═══════════════════════════════════════════════════════

-- 1. إضافة عمود النقاط لجدول العملاء (إن لم يوجد)
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS points INTEGER NOT NULL DEFAULT 0;

-- 2. إنشاء جدول سجل النقاط (إن لم يوجد)
CREATE TABLE IF NOT EXISTS public.customer_points_log (
  id          BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  invoice_id  BIGINT,
  invoice_no  TEXT NOT NULL DEFAULT \\'\\',
  date        TEXT NOT NULL DEFAULT \\'\\',
  points_earned INTEGER NOT NULL DEFAULT 0,
  point_value DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  point_currency TEXT NOT NULL DEFAULT \\'piasters\\',
  is_settled  BOOLEAN NOT NULL DEFAULT FALSE,
  settled_at  TEXT,
  notes       TEXT,
  created_at  TEXT NOT NULL DEFAULT NOW()::TEXT
);

-- 3. تفعيل RLS + صلاحيات كاملة على جدول سجل النقاط
ALTER TABLE public.customer_points_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "points_log_all_ops" ON public.customer_points_log;
CREATE POLICY "points_log_all_ops"
  ON public.customer_points_log FOR ALL
  USING (true) WITH CHECK (true);

-- 4. صلاحية تحديث نقاط العملاء (تحقق من policies الموجودة أولاً)
-- إذا كان RLS مفعّلاً على customers أضف هذا:
-- DROP POLICY IF EXISTS "customers_allow_all" ON public.customers;
-- CREATE POLICY "customers_allow_all"
--   ON public.customers FOR ALL
--   USING (true) WITH CHECK (true);

-- 5. دالة RPC لزيادة/إنقاص النقاط بشكل آمن (بدون race condition)
CREATE OR REPLACE FUNCTION public.increment_customer_points(
  p_customer_id BIGINT,
  p_delta       INTEGER
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS \$\$
  UPDATE public.customers
  SET    points = GREATEST(0, COALESCE(points, 0) + p_delta)
  WHERE  id = p_customer_id;
\$\$;

GRANT EXECUTE ON FUNCTION public.increment_customer_points(BIGINT, INTEGER)
  TO anon, authenticated;
''';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _results.clear();
      _running = true;
    });

    final checks = [
      ('customers', 'جدول العملاء'),
      ('sales_invoices', 'جدول فواتير المبيعات'),
      ('installments', 'جدول الأقساط'),
      ('customer_points_log', 'جدول سجل النقاط (عملاء + فنيين)'),
    ];

    for (final (table, label) in checks) {
      final row = await _checkTable(table, label);
      if (mounted) setState(() => _results.add(row));
    }

    // Test SELECT on customer_points_log
    await _testPointsSelect();

    // Test INSERT into customer_points_log (real RLS check)
    await _testPointsInsert();

    // Test UPDATE on customers.points
    await _testCustomersPointsUpdate();

    if (mounted) setState(() => _running = false);
  }

  Future<_DiagRow> _checkTable(String table, String label) async {
    try {
      final r = await _db.from(table).select('id').limit(1);
      final count = (r as List).length;
      return _DiagRow(
        table: table,
        label: label,
        ok: true,
        message: 'متاح (${count == 0 ? "فارغ" : "به سجلات"})',
      );
    } catch (e) {
      return _DiagRow(
        table: table,
        label: label,
        ok: false,
        message: e.toString(),
      );
    }
  }

  Future<void> _testPointsSelect() async {
    if (mounted) {
      setState(() => _results.add(_DiagRow(
            table: 'customer_points_log (SELECT)',
            label: 'اختبار قراءة سجل النقاط',
            ok: true,
            message: 'جارٍ الاختبار...',
            loading: true,
          )));
    }
    try {
      final rows = await _db
          .from('customer_points_log')
          .select('id')
          .limit(1);
      final count = (rows as List).length;
      if (mounted) {
        setState(() {
          _results.last = _DiagRow(
            table: 'customer_points_log (SELECT)',
            label: 'اختبار قراءة سجل النقاط',
            ok: true,
            message: 'SELECT ناجح ✓ (${count == 0 ? "الجدول فارغ" : "به سجلات"})',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results.last = _DiagRow(
            table: 'customer_points_log (SELECT)',
            label: 'اختبار قراءة سجل النقاط',
            ok: false,
            message: 'فشل SELECT: $e',
          );
        });
      }
    }
  }

  Future<void> _testPointsInsert() async {
    if (mounted) {
      setState(() => _results.add(_DiagRow(
            table: 'customer_points_log (INSERT)',
            label: 'اختبار إدراج في سجل النقاط ← مهم جداً',
            ok: true,
            message: 'جارٍ الاختبار...',
            loading: true,
          )));
    }
    try {
      // Get an existing customer id to use as FK
      final customers = await _db.from('customers').select('id').limit(1);
      if ((customers as List).isEmpty) {
        if (mounted) {
          setState(() {
            _results.last = _DiagRow(
              table: 'customer_points_log (INSERT)',
              label: 'اختبار إدراج في سجل النقاط',
              ok: false,
              message: 'لا يوجد عملاء — أضف عميلاً واحداً على الأقل ثم أعد الفحص',
            );
          });
        }
        return;
      }
      final testCustomerId = customers.first['id'] as int;

      final testEntry = {
        'customer_id': testCustomerId,
        'invoice_no': 'TEST-DIAG',
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'points_earned': 0,
        'point_value': 1.0,
        'point_currency': 'piasters',
        'is_settled': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final inserted = await _db
          .from('customer_points_log')
          .insert(testEntry)
          .select('id')
          .single();
      final testId = inserted['id'] as int;

      // Clean up the test row immediately
      await _db.from('customer_points_log').delete().eq('id', testId);

      if (mounted) {
        setState(() {
          _results.last = _DiagRow(
            table: 'customer_points_log (INSERT)',
            label: 'اختبار إدراج في سجل النقاط ← مهم جداً',
            ok: true,
            message: 'INSERT ناجح ✓ — النقاط ستُحفظ بشكل صحيح',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results.last = _DiagRow(
            table: 'customer_points_log (INSERT)',
            label: 'اختبار إدراج في سجل النقاط ← مهم جداً',
            ok: false,
            message: 'فشل INSERT: $e\n\n→ هذا هو سبب عدم ظهور النقاط!\n'
                'انسخ SQL أدناه وشغّله في Supabase SQL Editor.',
          );
        });
      }
    }
  }

  Future<void> _testCustomersPointsUpdate() async {
    if (mounted) {
      setState(() => _results.add(_DiagRow(
            table: 'customers.points (UPDATE)',
            label: 'اختبار تحديث نقاط العميل',
            ok: true,
            message: 'جارٍ الاختبار...',
            loading: true,
          )));
    }
    try {
      final customers =
          await _db.from('customers').select('id, points').limit(1);
      if ((customers as List).isEmpty) {
        if (mounted) {
          setState(() {
            _results.last = _DiagRow(
              table: 'customers.points (UPDATE)',
              label: 'اختبار تحديث نقاط العميل',
              ok: false,
              message: 'لا يوجد عملاء للاختبار',
            );
          });
        }
        return;
      }

      final testId = customers.first['id'] as int;
      final origPoints = (customers.first['points'] as num? ?? 0).toInt();

      // Set to same value (no-op change — just verifying UPDATE is allowed)
      final updated = await _db
          .from('customers')
          .update({'points': origPoints})
          .eq('id', testId)
          .select('id');

      final affected = (updated as List).length;
      if (mounted) {
        setState(() {
          _results.last = _DiagRow(
            table: 'customers.points (UPDATE)',
            label: 'اختبار تحديث نقاط العميل',
            ok: affected > 0,
            message: affected > 0
                ? 'UPDATE ناجح ✓ — رصيد النقاط سيُحدَّث بشكل صحيح'
                : 'UPDATE لم يؤثر على أي صف (0 rows) — RLS يحجب التحديث!\n'
                    'انسخ SQL أدناه وشغّله في Supabase SQL Editor.',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results.last = _DiagRow(
            table: 'customers.points (UPDATE)',
            label: 'اختبار تحديث نقاط العميل',
            ok: false,
            message: 'فشل UPDATE: $e\n'
                'انسخ SQL أدناه وشغّله في Supabase SQL Editor.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFailures = _results.any((r) => !r.ok && !r.loading);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تشخيص Supabase'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (!_running)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _run,
              tooltip: 'إعادة الفحص',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مشروع Supabase',
                  style: TextStyle(
                      color: Colors.indigo.shade800,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  SupabaseConfig.url,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty && _running
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final row = _results[i];
                      return Card(
                        color: row.loading
                            ? Colors.grey.shade50
                            : row.ok
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                        child: ListTile(
                          leading: row.loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : Icon(
                                  row.ok
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: row.ok ? Colors.green : Colors.red,
                                ),
                          title: Text(row.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: SelectableText(
                            '${row.table}\n${row.message}',
                            style: TextStyle(
                                fontSize: 11,
                                color: row.ok ? Colors.grey : Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_running && hasFailures) ...[
            const Divider(),
            Container(
              color: Colors.orange.shade50,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إصلاح المشكلة — انسخ SQL التالي وشغّله في:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.deepOrange),
                  ),
                  const Text(
                    'Supabase Dashboard → SQL Editor → New Query',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Clipboard.setData(
                          const ClipboardData(text: _setupSql));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم نسخ SQL ✓ — الصقه في Supabase SQL Editor'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('نسخ SQL الإصلاح'),
                  ),
                ],
              ),
            ),
          ] else if (!_running) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'جميع الاختبارات ناجحة — نظام النقاط يعمل بشكل صحيح',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagRow {
  final String table;
  final String label;
  final bool ok;
  final String message;
  final bool loading;

  const _DiagRow({
    required this.table,
    required this.label,
    required this.ok,
    required this.message,
    this.loading = false,
  });
}
