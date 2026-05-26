import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../../database/daos/partner_group_dao.dart';
import '../../../database/daos/app_settings_dao.dart';
import '../../../database/daos/user_dao.dart';
import '../../../models/partner_group.dart';
import '../../../models/app_settings.dart';
import '../../../models/user.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import 'partner_group_statement_screen.dart';

class PartnerGroupsScreen extends StatefulWidget {
  const PartnerGroupsScreen({super.key});
  @override
  State<PartnerGroupsScreen> createState() => _PartnerGroupsScreenState();
}

class _PartnerGroupsScreenState extends State<PartnerGroupsScreen> {
  final _dao = PartnerGroupDao();
  final _settingsDao = AppSettingsDao();
  List<PartnerGroup> _groups = [];
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final g = await _dao.getAllGroups();
    final s = await _settingsDao.getSettings();
    if (mounted) setState(() { _groups = g; _settings = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مجموعات الشركاء'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: _showGroupForm,
        icon: const Icon(Icons.group_add),
        label: const Text('مجموعة جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) => _GroupCard(
                    group: _groups[i], dao: _dao, settings: _settings, onChanged: _load),
                ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.group, size: 72, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      const Text('لا توجد مجموعات شركاء', style: TextStyle(color: Colors.grey, fontSize: 16)),
      const SizedBox(height: 8),
      const Text('أنشئ مجموعة وأضف لها شركاء بنسب أسهم', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(AppColors.primaryInt), foregroundColor: Colors.white),
        onPressed: _showGroupForm,
        icon: const Icon(Icons.group_add),
        label: const Text('إنشاء مجموعة'),
      ),
    ]),
  );

  void _showGroupForm({PartnerGroup? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final balCtrl = TextEditingController(
        text: (existing?.startingBalance ?? 0) > 0 ? existing!.startingBalance.toStringAsFixed(0) : '');
    final mgmtFeeCtrl = TextEditingController(
        text: existing?.managementFeeRate != null ? existing!.managementFeeRate!.toStringAsFixed(1) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(existing == null ? 'مجموعة جديدة' : 'تعديل المجموعة',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextFormField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المجموعة *', prefixIcon: Icon(Icons.group))),
          const SizedBox(height: 10),
          TextFormField(controller: descCtrl,
              decoration: const InputDecoration(labelText: 'وصف / ملاحظات', prefixIcon: Icon(Icons.note))),
          const SizedBox(height: 10),
          TextFormField(
            controller: balCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'رأس المال الإجمالي للمجموعة',
              helperText: 'المبلغ الكلي الذي يشارك به الشركاء مجتمعين',
              prefixIcon: Icon(Icons.account_balance_wallet, color: Colors.green),
              suffixText: 'ج.م',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: mgmtFeeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'نسبة رسوم الإدارة',
              hintText: 'اتركه فارغاً للقيمة الافتراضية (${_settings.defaultAdminFeeRate.toStringAsFixed(0)}%)',
              prefixIcon: const Icon(Icons.percent, color: Colors.orange),
              suffixText: '%',
              helperText: 'نسبة خاصة بهذه المجموعة تُخصم من صافي الربح',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final now = DateTime.now().toIso8601String();
                final g = PartnerGroup(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  startingBalance: double.tryParse(balCtrl.text) ?? 0,
                  managementFeeRate: mgmtFeeCtrl.text.trim().isEmpty
                      ? null
                      : double.tryParse(mgmtFeeCtrl.text),
                  createdAt: existing?.createdAt ?? now,
                );
                if (existing == null) await _dao.insertGroup(g); else await _dao.updateGroup(g);
                _load();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'إنشاء المجموعة' : 'حفظ التعديلات'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Group Card ───────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final PartnerGroup group;
  final PartnerGroupDao dao;
  final AppSettings settings;
  final VoidCallback onChanged;

  const _GroupCard({required this.group, required this.dao, required this.settings, required this.onChanged});
  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  List<PartnerGroupMember> _members = [];
  Map<String, double> _cashFlow = {'in': 0, 'out': 0};
  bool _expanded = false;
  bool _loadingDetails = false;

  Future<void> _loadDetails() async {
    if (_loadingDetails) return;
    setState(() => _loadingDetails = true);
    try {
      final results = await Future.wait([
        widget.dao.getGroupMembers(widget.group.id!),
        widget.dao.getCashFlowSummary(widget.group.id!),
      ]);
      if (mounted) setState(() {
        _members = results[0] as List<PartnerGroupMember>;
        _cashFlow = results[1] as Map<String, double>;
        _loadingDetails = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  // ── Computed financials ────────────────────────────────────────────────────
  int get _totalSharesInt => _members.fold(0, (s, m) => s + m.numberOfShares);
  double get _totalShares => _totalSharesInt.toDouble();
  double get _totalMemberCapital => _members.fold(0.0, (s, m) => s + m.capitalAmount);
  // الأقساط المحصلة = مجموع التدفق النقدي الداخل (cash flow in)
  double get _totalCollected => _cashFlow['in'] ?? 0;
  double get _totalOut => _cashFlow['out'] ?? 0;
  double get _capitalRemaining => (widget.group.startingBalance + _totalMemberCapital) - _totalOut + (_cashFlow['in'] ?? 0);
  double get _netProfit => _totalCollected - _totalOut;
  /// معدل رسوم الإدارة الفعلي — يفضّل قيمة المجموعة على الإعداد العام
  double get _effectiveFeeRate =>
      widget.group.managementFeeRate ?? widget.settings.defaultAdminFeeRate;
  double get _managementFee => _netProfit > 0 ? _netProfit * (_effectiveFeeRate / 100) : 0;
  double get _distributableProfit => _netProfit - _managementFee;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        // ── Header tap row ────────────────────────────────────────────────────
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (_expanded && _members.isEmpty) _loadDetails();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF6200EE).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group, color: Color(0xFF6200EE), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (g.description != null)
                  Text(g.description!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (g.startingBalance > 0)
                  Text('رأس المال: ${AppFormatters.formatCurrency(g.startingBalance)}',
                      style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                Text('${_members.length} شريك', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ]),
          ),
        ),

        if (_expanded) ...[
          const Divider(height: 1),
          if (_loadingDetails)
            const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
          else ...[
            // ── Financial KPIs ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  _KPIBox('إجمالي محصّل', AppFormatters.formatCurrency(_totalCollected), Colors.green),
                  _KPIBox('صافي الربح', AppFormatters.formatCurrency(_netProfit),
                      _netProfit >= 0 ? Colors.blue : Colors.red),
                  _KPIBox('رسوم إدارة\n(${_effectiveFeeRate.toStringAsFixed(0)}%)',
                      AppFormatters.formatCurrency(_managementFee), Colors.orange),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _KPIBox('للتوزيع', AppFormatters.formatCurrency(_distributableProfit), Colors.purple),
                  _KPIBox('رصيد المجموعة', AppFormatters.formatCurrency(_capitalRemaining), Colors.teal),
                  _KPIBox('المصروفات الكلية', AppFormatters.formatCurrency(_totalOut), Colors.red),
                ]),
              ]),
            ),

            // ── Shares Section ────────────────────────────────────────────────
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const Icon(Icons.pie_chart, size: 16, color: Colors.purple),
                  const SizedBox(width: 6),
                  const Text('الشركاء والأسهم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (_totalShares > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('(إجمالي ${_totalShares.toStringAsFixed(0)} سهم)',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                ]),
                TextButton.icon(
                  onPressed: _showAddMemberSheet,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('إضافة', style: TextStyle(fontSize: 13)),
                ),
              ]),
            ),

            if (_members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text('لا يوجد شركاء — أضف شريكاً وحدد عدد أسهمه',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ...(_members.map((m) => _MemberRow(
                member: m,
                distributableProfit: _distributableProfit,
                totalShares: _totalShares,
                onRemove: () async {
                  if (m.userId != null && m.userId! > 0) {
                    await widget.dao.removeUserMember(widget.group.id!, m.userId!);
                  } else if (m.customerId != null) {
                    await widget.dao.removeMember(widget.group.id!, m.customerId!);
                  }
                  _loadDetails();
                },
              ))),

            const Divider(height: 1),


            // ── Action buttons ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PartnerGroupStatementScreen(group: widget.group))),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('كشف الحساب'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  TextButton.icon(
                    onPressed: _showEditForm,
                    icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                    label: const Text('تعديل', style: TextStyle(color: Colors.blue)),
                  ),
                  TextButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text('حذف', style: TextStyle(color: Colors.red)),
                  ),
                ]),
              ]),
            ),
          ],
        ],
      ]),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showEditForm() {
    final nameCtrl = TextEditingController(text: widget.group.name);
    final descCtrl = TextEditingController(text: widget.group.description ?? '');
    final balCtrl = TextEditingController(
        text: widget.group.startingBalance > 0 ? widget.group.startingBalance.toStringAsFixed(0) : '');
    final mgmtFeeCtrl = TextEditingController(
        text: widget.group.managementFeeRate != null
            ? widget.group.managementFeeRate!.toStringAsFixed(1)
            : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تعديل المجموعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المجموعة *')),
          const SizedBox(height: 10),
          TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'وصف')),
          const SizedBox(height: 10),
          TextFormField(controller: balCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'رأس المال', suffixText: 'ج.م')),
          const SizedBox(height: 10),
          TextFormField(
            controller: mgmtFeeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'نسبة رسوم الإدارة',
              hintText: 'اتركه فارغاً للقيمة الافتراضية',
              prefixIcon: Icon(Icons.percent, color: Colors.orange),
              suffixText: '%',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await widget.dao.updateGroup(PartnerGroup(
                  id: widget.group.id, name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  startingBalance: double.tryParse(balCtrl.text) ?? 0,
                  managementFeeRate: mgmtFeeCtrl.text.trim().isEmpty
                      ? null
                      : double.tryParse(mgmtFeeCtrl.text),
                  createdAt: widget.group.createdAt,
                ));
                widget.onChanged();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المجموعة'),
        content: Text('سيتم حذف "${widget.group.name}" وجميع بياناتها. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.dao.deleteGroup(widget.group.id!);
      widget.onChanged();
    }
  }

  Future<void> _transferInstallment(int installmentId, String customerName) async {
    // Get all groups except the current one
    final allGroups = await widget.dao.getAllGroups();
    final otherGroups = allGroups.where((g) => g.id != widget.group.id).toList();

    if (!mounted) return;

    if (otherGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا توجد مجموعات أخرى للنقل إليها'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    PartnerGroup? targetGroup;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('نقل عقد التقسيط'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('عميل: $customerName', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          DropdownButtonFormField<PartnerGroup>(
            value: targetGroup,
            decoration: const InputDecoration(
              labelText: 'اختر الجروب المستهدف *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.group, color: Colors.purple),
            ),
            items: otherGroups.map((g) => DropdownMenuItem<PartnerGroup>(
              value: g,
              child: Text(g.name),
            )).toList(),
            onChanged: (g) => setS(() => targetGroup = g),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: targetGroup == null ? null : () => Navigator.pop(ctx, true),
            child: const Text('نقل'),
          ),
        ],
      )),
    );

    if (ok == true && targetGroup != null) {
      try {
        await Supabase.instance.client
            .from('installments')
            .update({'partner_group_id': targetGroup!.id})
            .eq('id', installmentId);
        _loadDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تم نقل العقد إلى "${targetGroup!.name}" ✓'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ في النقل: $e'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  void _showAddMemberSheet() {
    List<User> partnerUsers = [];
    User? selectedUser;
    final sharesCtrl = TextEditingController(text: '1');
    final capitalCtrl = TextEditingController();
    bool loadingUsers = true;
    bool loadInitiated = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (!loadInitiated) {
          loadInitiated = true;
          UserDao().getByRole('partner').then((users) {
            if (ctx.mounted) setS(() { partnerUsers = users; loadingUsers = false; });
          });
        }
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('إضافة شريك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.purple),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'نظام الأسهم: عدد أسهم كل شريك يحدد نسبته.\nمثال: شريك بـ 2 سهم يأخذ ضعف من له سهم واحد.',
                  style: TextStyle(fontSize: 12, color: Colors.purple),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            if (loadingUsers)
              const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
            else if (partnerUsers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200)),
                child: const Row(children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'لا يوجد مستخدمون بصلاحية "شريك" في النظام.\nأضف مستخدمين من إعدادات الأدمن أولاً.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  )),
                ]),
              )
            else
              DropdownButtonFormField<User>(
                value: selectedUser,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'اختر الشريك *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                items: partnerUsers.map((u) => DropdownMenuItem<User>(
                  value: u,
                  child: Row(children: [
                    const Icon(Icons.account_circle, size: 18, color: Colors.purple),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      u.phone != null && u.phone!.isNotEmpty
                          ? '${u.name} — ${u.phone}'
                          : u.name,
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                )).toList(),
                onChanged: (v) => setS(() => selectedUser = v),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: sharesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد الأسهم *',
                    helperText: '1 سهم = حصة واحدة',
                    prefixIcon: Icon(Icons.pie_chart, color: Colors.purple),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: capitalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رأس ماله (ج.م)',
                    helperText: 'اختياري',
                    prefixIcon: Icon(Icons.attach_money, color: Colors.green),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.primaryInt),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: partnerUsers.isEmpty ? null : () async {
                  if (selectedUser == null) return;
                  final shares = int.tryParse(sharesCtrl.text) ?? 1;
                  final capital = double.tryParse(capitalCtrl.text) ?? 0;
                  final result = await widget.dao.upsertUserMemberWithCapital(
                      widget.group.id!, selectedUser!.id!, shares, capital);
                  if (result <= 0) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('فشل إضافة الشريك، تأكد من إعدادات Supabase.'),
                        backgroundColor: Colors.red,
                      ));
                    }
                    return;
                  }
                  await _loadDetails();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.person_add),
                label: const Text('إضافة الشريك'),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _showCashFlowSheet() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String flowType = 'in';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تسجيل حركة مالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setS(() => flowType = 'in'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: flowType == 'in' ? Colors.green : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: flowType == 'in' ? Colors.green : Colors.grey.shade300),
                  ),
                  child: Column(children: [
                    Icon(Icons.arrow_downward, color: flowType == 'in' ? Colors.white : Colors.green),
                    Text('وارد (دخل)',
                        style: TextStyle(color: flowType == 'in' ? Colors.white : Colors.green,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setS(() => flowType = 'out'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: flowType == 'out' ? Colors.red : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: flowType == 'out' ? Colors.red : Colors.grey.shade300),
                  ),
                  child: Column(children: [
                    Icon(Icons.arrow_upward, color: flowType == 'out' ? Colors.white : Colors.red),
                    Text('صادر (مصروف)',
                        style: TextStyle(color: flowType == 'out' ? Colors.white : Colors.red,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المبلغ *', suffixText: 'ج.م', prefixIcon: Icon(Icons.attach_money)),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'البيان / الوصف',
              hintText: 'مثال: شراء منتج، قسط محصّل...',
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: flowType == 'in' ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) return;
                await widget.dao.insertCashFlow(
                  groupId: widget.group.id!,
                  type: flowType,
                  amount: amount,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  date: DateTime.now().toIso8601String().substring(0, 10),
                );
                _loadDetails();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(flowType == 'in' ? 'تم تسجيل الوارد ✓' : 'تم تسجيل المصروف ✓'),
                    backgroundColor: flowType == 'in' ? Colors.green : Colors.red,
                  ));
                }
              },
              child: Text(flowType == 'in' ? 'تسجيل وارد' : 'تسجيل مصروف'),
            ),
          ),
        ]),
      )),
    );
  }
}

// ─── KPI Box ─────────────────────────────────────────────────────────────────

class _KPIBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KPIBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    ),
  );
}

// ─── Member Row ───────────────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  final PartnerGroupMember member;
  final double distributableProfit;
  final double totalShares;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.member, required this.distributableProfit,
    required this.totalShares, required this.onRemove,
  });

  double get _pct => totalShares > 0 ? (member.numberOfShares / totalShares) : 0;
  double get _myProfit => _pct * distributableProfit;

  @override
  Widget build(BuildContext context) {
    final name = member.customerName ??
        (member.userId != null && member.userId! > 0 ? 'مستخدم #${member.userId}' : 'شريك');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: const Color(AppColors.primaryInt).withValues(alpha: 0.1),
          child: Text(name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(fontSize: 13, color: Color(AppColors.primaryInt),
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '${member.numberOfShares} أسهم — ${(_pct * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (member.capitalAmount > 0)
            Text(AppFormatters.formatCurrency(member.capitalAmount),
                style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600)),
          if (distributableProfit > 0)
            Text(AppFormatters.formatCurrency(_myProfit),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple)),
        ]),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('إزالة الشريك'),
                content: Text('هل تريد إزالة الشريك "$name" من المجموعة؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('إزالة'),
                  ),
                ],
              ),
            );
            if (ok == true) onRemove();
          },
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
          tooltip: 'إزالة الشريك',
        ),
      ]),
    );
  }
}
