import 'package:flutter/material.dart';
import '../../database/daos/customer_dao.dart';
import '../../models/customer.dart';
import '../../models/item.dart';
import '../../models/installment_product.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class InstallmentCalculatorScreen extends StatefulWidget {
  final Item? preselectedItem;
  final InstallmentProduct? installmentProduct;
  final Customer? customer;

  const InstallmentCalculatorScreen({
    super.key,
    this.preselectedItem,
    this.installmentProduct,
    this.customer,
  });

  @override
  State<InstallmentCalculatorScreen> createState() =>
      _InstallmentCalculatorScreenState();
}

class _InstallmentCalculatorScreenState
    extends State<InstallmentCalculatorScreen> {
  final _productNameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _downPaymentCtrl = TextEditingController(text: '0');
  int _months = 12;
  bool _submitted = false;
  bool _loading = false;

  double get _effectiveProfitRate {
    if (widget.installmentProduct != null) {
      return widget.installmentProduct!.profitRate;
    }
    return AppConstants.installmentFeeRate;
  }

  double get _price => double.tryParse(_priceCtrl.text) ?? 0;
  double get _downPayment => double.tryParse(_downPaymentCtrl.text) ?? 0;
  double get _installmentFee => _price * _effectiveProfitRate;
  double get _totalPrice => _price + _installmentFee;
  double get _remaining => _totalPrice - _downPayment;
  double get _monthlyAmount => _months > 0 ? _remaining / _months : 0;

  @override
  void initState() {
    super.initState();
    if (widget.installmentProduct != null) {
      _productNameCtrl.text = widget.installmentProduct!.name;
      _priceCtrl.text = widget.installmentProduct!.salePrice.toStringAsFixed(0);
    } else if (widget.preselectedItem != null) {
      _productNameCtrl.text = widget.preselectedItem!.name;
      _priceCtrl.text =
          widget.preselectedItem!.priceRetail.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _productNameCtrl.dispose();
    _priceCtrl.dispose();
    _downPaymentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    if (_productNameCtrl.text.isEmpty || _price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال المنتج والسعر')));
      return;
    }
    if (widget.customer?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
      return;
    }
    setState(() => _loading = true);
    try {

    final now = DateTime.now();
    final dao = CustomerDao();
    await dao.insertCustomerPayment({
      'customer_id': widget.customer!.id,
      'amount': _monthlyAmount,
      'payment_method': 'installment_request',
      'status': 'pending',
      'notes':
          'طلب تقسيط: ${_productNameCtrl.text} | ${_months} شهر | قسط شهري: ${AppFormatters.formatCurrency(_monthlyAmount)} | مقدم: ${AppFormatters.formatCurrency(_downPayment)}',
      'date': now.toIso8601String().substring(0, 10),
      'created_at': now.toIso8601String(),
    });
    setState(() {
      _loading = false;
      _submitted = true;
    });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة التقسيط'),
        backgroundColor: const Color(AppColors.installmentInt),
        foregroundColor: Colors.white,
      ),
      body: _submitted ? _buildSuccess() : _buildCalculator(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade600, size: 72),
            ),
            const SizedBox(height: 24),
            const Text('تم إرسال طلب التقسيط!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'سيراجع المدير طلبك ويتواصل معك قريباً لإتمام الإجراءات.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.installmentInt),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculator() {
    final ratePercent = (_effectiveProfitRate * 100).toStringAsFixed(0);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(AppColors.installmentInt),
                  Color(AppColors.installment2Int),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('حاسبة التقسيط',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(
                          'نسبة التقسيط: $ratePercent% | اختر عدد الأشهر',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _productNameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم المنتج',
              prefixIcon: Icon(Icons.shopping_bag),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'السعر الأصلي',
              prefixIcon: Icon(Icons.sell),
              suffixText: 'ج.م',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _downPaymentCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المقدم (اختياري)',
              prefixIcon: Icon(Icons.payments),
              suffixText: 'ج.م',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('عدد الأشهر',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(AppColors.installmentInt).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_months شهر',
                  style: const TextStyle(
                      color: Color(AppColors.installmentInt),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(AppColors.installmentInt),
              thumbColor: const Color(AppColors.installmentInt),
              inactiveTrackColor:
                  const Color(AppColors.installmentInt).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _months.toDouble(),
              min: 3,
              max: 36,
              divisions: 33,
              onChanged: (v) => setState(() => _months = v.toInt()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in [3, 6, 12, 24, 36])
                GestureDetector(
                  onTap: () => setState(() => _months = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _months == m
                          ? const Color(AppColors.installmentInt)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$m',
                      style: TextStyle(
                          color: _months == m
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_price > 0) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(AppColors.installmentInt).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(AppColors.installmentInt).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const Text('ملخص التقسيط',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _ResultRow(
                    label: 'السعر الأصلي',
                    value: AppFormatters.formatCurrency(_price),
                  ),
                  _ResultRow(
                    label: 'رسوم التقسيط ($ratePercent%)',
                    value: AppFormatters.formatCurrency(_installmentFee),
                    valueColor: Colors.orange,
                  ),
                  _ResultRow(
                    label: 'المقدم',
                    value: '- ${AppFormatters.formatCurrency(_downPayment)}',
                    valueColor: Colors.green,
                  ),
                  const Divider(),
                  _ResultRow(
                    label: 'الإجمالي',
                    value: AppFormatters.formatCurrency(_totalPrice),
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(AppColors.installmentInt),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('القسط الشهري',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          AppFormatters.formatCurrency(_monthlyAmount),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 26),
                        ),
                        Text(
                          'لمدة $_months شهر',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.installmentInt),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _loading ? null : _sendRequest,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('إرسال طلب التقسيط للمدير'),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _ResultRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
              fontSize: bold ? 15 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
