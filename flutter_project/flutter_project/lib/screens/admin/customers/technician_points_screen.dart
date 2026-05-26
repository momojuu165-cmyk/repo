import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/customer_points_dao.dart';
import '../../../models/customer.dart';
import '../../../providers/customer_provider.dart';
import '../../../utils/constants.dart';
import 'customer_points_screen.dart';

/// Lists all technician-type customers and their current unsettled points total.
/// Tapping a row opens the full CustomerPointsScreen for that technician.
class TechnicianPointsScreen extends StatefulWidget {
  const TechnicianPointsScreen({super.key});

  @override
  State<TechnicianPointsScreen> createState() =>
      _TechnicianPointsScreenState();
}

class _TechnicianPointsScreenState extends State<TechnicianPointsScreen> {
  final _pointsDao = CustomerPointsDao();
  List<Customer> _technicians = [];
  Map<int, int> _pointsTotals = {};
  bool _loading = true;
  CustomerProvider? _providerRef;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _providerRef = context.read<CustomerProvider>();
        _providerRef!.addListener(_onProviderChanged);
      }
    });
  }

  void _onProviderChanged() {
    if (mounted && !_loading) _load();
  }

  @override
  void dispose() {
    _providerRef?.removeListener(_onProviderChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Load all customers then filter to technicians
      final all = await context.read<CustomerProvider>().getAll();
      final techs =
          all.where((c) => c.customerType == 'technician').toList();

      // Load unsettled point totals for every customer in one query
      final totals = await _pointsDao.getTotalsPerCustomer();

      if (mounted) {
        setState(() {
          _technicians = techs;
          _pointsTotals = totals;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _errorMsg = e.toString(); });
      }
    }
  }

  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقاط الفنيين'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 52),
                        const SizedBox(height: 12),
                        const Text('فشل تحميل بيانات الفنيين',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SelectableText(_errorMsg!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : _technicians.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.engineering_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('لا يوجد فنيون مسجّلون',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey)),
                      SizedBox(height: 6),
                      Text('أضف عملاء من نوع "فني" لتظهر نقاطهم هنا',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary banner
                    Container(
                      color: const Color(AppColors.primaryInt),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.engineering,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${_technicians.length} فني',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          'إجمالي النقاط: ${_pointsTotals.values.fold<int>(0, (s, v) => s + v)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ]),
                    ),
                    // Technician list
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _technicians.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final tech = _technicians[i];
                          final pts = _pointsTotals[tech.id] ?? 0;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: const Color(AppColors.primaryInt)
                                  .withValues(alpha: 0.12),
                              child: Text(
                                tech.name.isNotEmpty
                                    ? tech.name[0]
                                    : 'ف',
                                style: const TextStyle(
                                    color: Color(AppColors.primaryInt),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              tech.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            subtitle: tech.phone != null &&
                                    tech.phone!.isNotEmpty
                                ? Text(tech.phone!,
                                    style: const TextStyle(fontSize: 12))
                                : null,
                            trailing: pts > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.teal.shade200),
                                    ),
                                    child: Text(
                                      '$pts نقطة',
                                      style: TextStyle(
                                          color: Colors.teal.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      '0 نقطة',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13),
                                    ),
                                  ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerPointsScreen(customer: tech)),
                              );
                              // Refresh totals after returning in case points changed
                              _load();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
