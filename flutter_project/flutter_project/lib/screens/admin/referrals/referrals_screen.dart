import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../database/daos/customer_dao.dart';
import '../../../models/customer.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/pdf_helper.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});
  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام الإحالات والنقاط'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt), text: 'إحالات العملاء'),
            Tab(icon: Icon(Icons.engineering), text: 'نقاط الفنيين'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CustomerReferralsTab(),
          _TechnicianPointsTab(),
        ],
      ),
    );
  }
}

// ─── Customer Referrals Tab ───────────────────────────────────────────────────

class _CustomerReferralsTab extends StatefulWidget {
  const _CustomerReferralsTab();
  @override
  State<_CustomerReferralsTab> createState() => _CustomerReferralsTabState();
}

class _CustomerReferralsTabState extends State<_CustomerReferralsTab> {
  final SupabaseClient _client = Supabase.instance.client;
  final CustomerDao _dao = CustomerDao();

  List<Map<String, dynamic>> _referrals = [];
  Map<int, String> _customerNames = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rawReferrals = await _client
          .from('referrals')
          .select()
          .order('created_at', ascending: false);
      final customers = await _dao.getAll();
      final nameMap = <int, String>{for (final c in customers) if (c.id != null) c.id!: c.name};

      if (mounted) {
        setState(() {
          _referrals = List<Map<String, dynamic>>.from(rawReferrals as List);
          _customerNames = nameMap;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _customerName(dynamic id) {
    if (id == null) return 'غير محدد';
    return _customerNames[id as int] ?? 'عميل #$id';
  }

  Future<void> _exportPdf() async {
    if (_referrals.isEmpty) return;
    final Map<String, num> byReferrer = {};
    for (final r in _referrals) {
      final name = _customerName(r['referrer_customer_id']);
      byReferrer[name] = (byReferrer[name] ?? 0) + ((r['reward_amount'] as num?) ?? 0);
    }
    await PdfHelper.printReport(
      context: context,
      title: 'تقرير إحالات العملاء',
      subtitle: 'إجمالي ${_referrals.length} إحالة',
      headers: [['العميل المُحيل', 'العميل المُحال', 'المكافأة', 'التاريخ']],
      rows: _referrals.map((r) => <String>[
        _customerName(r['referrer_customer_id']),
        _customerName(r['referred_customer_id']),
        '${r['reward_amount'] ?? 0}',
        AppFormatters.formatDateFromString(
            (r['created_at'] as String?)?.substring(0, 10) ?? ''),
      ]).toList(),
      summaryRows: byReferrer.entries
          .map((e) => {'label': e.key, 'value': '${e.value}'})
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_referrals.isNotEmpty)
            FloatingActionButton.small(
              heroTag: 'pdf_referral',
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              onPressed: _exportPdf,
              tooltip: 'تصدير PDF',
              child: const Icon(Icons.picture_as_pdf),
            ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add_referral',
            backgroundColor: const Color(AppColors.primaryInt),
            foregroundColor: Colors.white,
            onPressed: () => _showAddReferralSheet(),
            icon: const Icon(Icons.person_add),
            label: const Text('إضافة إحالة'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _referrals.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_alt, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('لا توجد إحالات بعد',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('أضف عملاء الذين رشّحوك لآخرين وتابع مكافآتهم',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                    itemCount: _referrals.length,
                    itemBuilder: (ctx, i) {
                      final r = _referrals[i];
                      final referrerName = _customerName(r['referrer_customer_id']);
                      final referredName = _customerName(r['referred_customer_id']);
                      final reward = (r['reward_amount'] as num?) ?? 0;
                      final status = r['status'] as String? ?? 'pending';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(AppColors.primaryInt)
                                  .withValues(alpha: 0.12),
                              child: Text(
                                referrerName.isNotEmpty ? referrerName[0] : '؟',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(AppColors.primaryInt)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(referrerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Row(children: [
                                  const Icon(Icons.arrow_forward,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(referredName,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                ]),
                                if (r['notes'] != null)
                                  Text(r['notes'] as String,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blueGrey)),
                                Row(children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: status == 'approved'
                                          ? Colors.green.shade50
                                          : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: status == 'approved'
                                              ? Colors.green.shade300
                                              : Colors.orange.shade300),
                                    ),
                                    child: Text(
                                      status == 'approved'
                                          ? 'مقبولة'
                                          : status == 'rejected'
                                              ? 'مرفوضة'
                                              : 'قيد الانتظار',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: status == 'approved'
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppFormatters.formatDateFromString(
                                        (r['created_at'] as String?)
                                                ?.substring(0, 10) ??
                                            ''),
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ]),
                              ]),
                            ),
                            Column(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.amber.shade300),
                                ),
                                child: Column(children: [
                                  Text('$reward',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.amber)),
                                  const Text('مكافأة',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.amber)),
                                ]),
                              ),
                              const SizedBox(height: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: Colors.blue),
                                onPressed: () =>
                                    _showAddReferralSheet(existing: r),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () => _delete(r['id'] as int),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإحالة'),
        content: const Text('هل تريد حذف هذه الإحالة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _client.from('referrals').delete().eq('id', id);
      _load();
    }
  }

  void _showAddReferralSheet({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddReferralSheet(
        existing: existing,
        customerNames: _customerNames,
        onSaved: _load,
      ),
    );
  }
}

class _AddReferralSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Map<int, String> customerNames;
  final VoidCallback onSaved;
  const _AddReferralSheet(
      {this.existing, required this.customerNames, required this.onSaved});
  @override
  State<_AddReferralSheet> createState() => _AddReferralSheetState();
}

class _AddReferralSheetState extends State<_AddReferralSheet> {
  final SupabaseClient _client = Supabase.instance.client;
  final CustomerDao _dao = CustomerDao();

  List<Customer> _customers = [];
  bool _loadingCustomers = true;

  // Both are required (NOT NULL in schema)
  Customer? _referrerCustomer;
  Customer? _referredCustomer;

  final _rewardCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String _status = 'pending';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    if (widget.existing != null) {
      _rewardCtrl.text = '${widget.existing!['reward_amount'] ?? 0}';
      _notesCtrl.text = widget.existing!['notes'] ?? '';
      _status = widget.existing!['status'] ?? 'pending';
    }
  }

  @override
  void dispose() {
    _rewardCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final c = await _dao.getAll();
      if (mounted) {
        setState(() {
          _customers = c;
          _loadingCustomers = false;
          // Pre-select existing customers when editing
          if (widget.existing != null) {
            final referrerId = widget.existing!['referrer_customer_id'];
            final referredId = widget.existing!['referred_customer_id'];
            if (referrerId != null) {
              _referrerCustomer = c.where((x) => x.id == referrerId).firstOrNull;
            }
            if (referredId != null) {
              _referredCustomer = c.where((x) => x.id == referredId).firstOrNull;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  Future<void> _save() async {
    if (_referrerCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى تحديد العميل المُحيل'),
          backgroundColor: Colors.red));
      return;
    }
    if (_referredCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى تحديد العميل المُحال'),
          backgroundColor: Colors.red));
      return;
    }
    if (_referrerCustomer!.id == _referredCustomer!.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('لا يمكن أن يكون المُحيل والمُحال نفس العميل'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _saving = true);
    try {
      // Column names match the actual Supabase schema exactly
      final map = <String, dynamic>{
        'referrer_customer_id': _referrerCustomer!.id,
        'referred_customer_id': _referredCustomer!.id,
        'reward_amount': double.tryParse(_rewardCtrl.text) ?? 0,
        'status': _status,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      };

      if (widget.existing == null) {
        await _client.from('referrals').insert(map);
      } else {
        await _client
            .from('referrals')
            .update(map)
            .eq('id', widget.existing!['id'] as int);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              widget.existing == null
                  ? 'إضافة إحالة جديدة'
                  : 'تعديل الإحالة',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),

          // Referrer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.person, color: Colors.blue, size: 16),
                SizedBox(width: 6),
                Text('العميل المُحيل (اللي رشّحك) *',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue)),
              ]),
              const SizedBox(height: 8),
              _loadingCustomers
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<Customer>(
                      value: _referrerCustomer,
                      hint: const Text('اختر عميلاً'),
                      decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search)),
                      items: _customers
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('${c.name} — ${c.phone}')))
                          .toList(),
                      onChanged: (c) =>
                          setState(() => _referrerCustomer = c),
                    ),
            ]),
          ),

          const SizedBox(height: 12),

          // Referred
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.person_add, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text('العميل المُحال (اللي اتجاب) *',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ]),
              const SizedBox(height: 8),
              _loadingCustomers
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<Customer>(
                      value: _referredCustomer,
                      hint: const Text('اختر عميلاً'),
                      decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search)),
                      items: _customers
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('${c.name} — ${c.phone}')))
                          .toList(),
                      onChanged: (c) =>
                          setState(() => _referredCustomer = c),
                    ),
            ]),
          ),

          const SizedBox(height: 12),

          // Reward amount & status
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _rewardCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المكافأة',
                  prefixIcon: Icon(Icons.monetization_on, color: Colors.amber),
                  helperText: 'قيمة المكافأة للمُحيل',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                    labelText: 'الحالة', isDense: true),
                items: const [
                  DropdownMenuItem(
                      value: 'pending', child: Text('قيد الانتظار')),
                  DropdownMenuItem(value: 'approved', child: Text('مقبولة')),
                  DropdownMenuItem(value: 'rejected', child: Text('مرفوضة')),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
            ),
          ]),

          const SizedBox(height: 10),
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                prefixIcon: Icon(Icons.note)),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(
                  widget.existing == null ? 'حفظ الإحالة' : 'تحديث الإحالة'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Technician Points Tab ────────────────────────────────────────────────────

class _TechnicianPointsTab extends StatefulWidget {
  const _TechnicianPointsTab();
  @override
  State<_TechnicianPointsTab> createState() => _TechnicianPointsTabState();
}

class _TechnicianPointsTabState extends State<_TechnicianPointsTab> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _client
          .from('technician_points')
          .select()
          .order('points', ascending: false);
      if (mounted) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(r);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_records.isEmpty) return;
    await PdfHelper.printReport(
      context: context,
      title: 'تقرير نقاط الفنيين',
      subtitle: 'إجمالي ${_records.length} سجل',
      headers: [['رقم الفني', 'السبب / الاسم', 'النقاط', 'التاريخ']],
      rows: _records.map((t) => <String>[
        '${t['technician_id'] ?? ''}',
        (t['reason'] ?? '').toString(),
        '${t['points'] ?? 0}',
        AppFormatters.formatDateFromString(
            (t['created_at'] as String?)?.substring(0, 10) ?? ''),
      ]).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_records.isNotEmpty)
            FloatingActionButton.small(
              heroTag: 'pdf_tech',
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              onPressed: _exportPdf,
              tooltip: 'تصدير PDF',
              child: const Icon(Icons.picture_as_pdf),
            ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add_tech',
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            onPressed: () => _showAddTechSheet(),
            icon: const Icon(Icons.engineering),
            label: const Text('إضافة سجل نقاط'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.engineering, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('لا يوجد سجلات نقاط بعد',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('أضف نقاط الفنيين وتابع أداءهم',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                    itemCount: _records.length,
                    itemBuilder: (ctx, i) {
                      final t = _records[i];
                      final points = (t['points'] as num?)?.toInt() ?? 0;
                      final techId = t['technician_id'];
                      // 'reason' stores the display name / reason text
                      final reason = (t['reason'] as String? ?? '').trim();
                      final displayLabel = reason.isNotEmpty
                          ? reason
                          : 'فني #$techId';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade50,
                            child: Text(
                              displayLabel.isNotEmpty
                                  ? displayLabel[0]
                                  : '؟',
                              style: const TextStyle(
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(displayLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text('رقم الفني: $techId'),
                          trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.indigo.shade200),
                                  ),
                                  child: Column(children: [
                                    Text('$points',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.indigo)),
                                    const Text('نقطة',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.indigo)),
                                  ]),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.green, size: 20),
                                  onPressed: () =>
                                      _updatePoints(t, points + 1),
                                  tooltip: 'إضافة نقطة',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.blue, size: 18),
                                  onPressed: () =>
                                      _showAddTechSheet(existing: t),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 18),
                                  onPressed: () =>
                                      _deleteTech(t['id'] as int),
                                ),
                              ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _updatePoints(Map<String, dynamic> t, int newPoints) async {
    try {
      await _client
          .from('technician_points')
          .update({'points': newPoints}).eq('id', t['id'] as int);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ في تحديث النقاط: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteTech(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السجل'),
        content: const Text('هل تريد حذف هذا السجل؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _client.from('technician_points').delete().eq('id', id);
      _load();
    }
  }

  void _showAddTechSheet({Map<String, dynamic>? existing}) {
    final techIdCtrl = TextEditingController(
        text: existing != null ? '${existing['technician_id'] ?? ''}' : '');
    final pointsCtrl = TextEditingController(
        text: '${existing?['points'] ?? 0}');
    final reasonCtrl = TextEditingController(
        text: existing?['reason'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(existing == null ? 'إضافة نقاط فني' : 'تعديل سجل الفني',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextFormField(
              controller: techIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم معرّف الفني (ID) *',
                prefixIcon: Icon(Icons.engineering),
                helperText: 'أدخل الرقم التعريفي للفني في النظام',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'النقاط',
                  prefixIcon: Icon(Icons.star, color: Colors.amber)),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'الاسم / السبب (اختياري)',
                prefixIcon: Icon(Icons.note),
                helperText: 'مثال: محمد الفني - تركيب تكييف',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () async {
                  final techId = int.tryParse(techIdCtrl.text.trim());
                  if (techId == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content:
                            Text('يرجى إدخال رقم معرّف الفني بشكل صحيح'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  // Columns match the actual schema: technician_id, points, reason
                  final map = <String, dynamic>{
                    'technician_id': techId,
                    'points': int.tryParse(pointsCtrl.text) ?? 0,
                    if (reasonCtrl.text.trim().isNotEmpty)
                      'reason': reasonCtrl.text.trim(),
                  };
                  try {
                    if (existing == null) {
                      await _client.from('technician_points').insert(map);
                    } else {
                      await _client
                          .from('technician_points')
                          .update(map)
                          .eq('id', existing['id'] as int);
                    }
                    _load();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      final msg = e.toString();
                      // Foreign key constraint: technician_id not found in referenced table
                      final isFkError = msg.contains('23503') ||
                          msg.contains('foreign key') ||
                          msg.contains('technician_points_technician_id_fkey');
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(
                            isFkError
                                ? 'خطأ: رقم الفني ($techId) غير موجود في قاعدة البيانات.\n'
                                  'الحل: افتح Supabase → SQL Editor وشغّل:\n'
                                  'ALTER TABLE technician_points DROP CONSTRAINT technician_points_technician_id_fkey;'
                                : 'خطأ في الحفظ: $e',
                          ),
                          duration: const Duration(seconds: 8),
                          backgroundColor: Colors.red));
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: Text(existing == null ? 'حفظ' : 'تحديث'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
