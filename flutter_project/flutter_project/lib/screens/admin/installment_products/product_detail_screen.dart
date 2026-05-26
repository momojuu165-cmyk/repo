import 'dart:io';
import '../../../utils/image_helper.dart';
import 'package:flutter/material.dart';
import '../../../models/installment_product.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

/// Product detail screen with image gallery (swipeable PageView).
/// Accessible by admin, manager, and partner by tapping a product card.
class ProductDetailScreen extends StatefulWidget {
  final InstallmentProduct product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final PageController _pageCtrl = PageController();
  int _currentImageIndex = 0;
  int _selectedMonths = 1;

  @override
  void initState() {
    super.initState();
    _selectedMonths = widget.product.maxInstallmentMonths > 1 ? 1 : 1;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  List<String> get _allImages {
    final imgs = <String>[];
    if (widget.product.imagePaths.isNotEmpty) {
      imgs.addAll(widget.product.imagePaths);
    } else if (widget.product.imagePath != null) {
      imgs.add(widget.product.imagePath!);
    }
    return imgs;
  }

  Color get _storeColor {
    switch (widget.product.storeType) {
      case AppConstants.storeElectrical:
        return const Color(AppColors.electricalInt);
      case AppConstants.storeClothing:
        return const Color(AppColors.clothingInt);
      case AppConstants.storeMobiles:
        return const Color(AppColors.mobilesInt);
      case AppConstants.storeAccessories:
        return const Color(AppColors.accessoriesInt);
      default:
        return const Color(AppColors.installmentInt);
    }
  }

  String get _storeLabel {
    return AppConstants.storeLabels[widget.product.storeType] ??
        widget.product.storeType;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = _allImages;
    final hasImages = images.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(AppColors.surfaceInt),
      appBar: AppBar(
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: _storeColor,
        foregroundColor: Colors.white,
        actions: [
          if (!p.isAvailable)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('مخفي',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Image Gallery ─────────────────────────────────────────
            if (hasImages) ...[
              SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageCtrl,
                      itemCount: images.length,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                      itemBuilder: (ctx, i) {
                        final isUrl = images[i].startsWith('http');
                        final imgFile = File(images[i]);
                        if (isUrl || imgFile.existsSync()) {
                          return buildProductImage(
                            images[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        }
                        return _ImagePlaceholder(name: p.name, color: _storeColor);
                      },
                    ),
                    // Dots indicator
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentImageIndex == i ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentImageIndex == i
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),
                    // Image counter badge
                    if (images.length > 1)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1} / ${images.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Thumbnail strip
              if (images.length > 1)
                SizedBox(
                  height: 68,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: images.length,
                    itemBuilder: (ctx, i) {
                      final selected = i == _currentImageIndex;
                      return GestureDetector(
                        onTap: () => _pageCtrl.animateToPage(i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(left: 6),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? _storeColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: (images[i].startsWith('http') || File(images[i]).existsSync())
                                ? buildProductImage(images[i],
                                    fit: BoxFit.cover)
                                : Container(
                                    color:
                                        _storeColor.withValues(alpha: 0.1),
                                    child: Icon(Icons.image,
                                        color: _storeColor)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ] else
              Container(
                height: 220,
                width: double.infinity,
                color: _storeColor.withValues(alpha: 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64, color: _storeColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    Text('لا توجد صور',
                        style: TextStyle(
                            color: _storeColor.withValues(alpha: 0.5))),
                  ],
                ),
              ),

            // ─── Product Info ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store type badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _storeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_storeLabel,
                          style: TextStyle(
                              color: _storeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (p.category != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(p.category!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 12),

                  // Product name
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),

                  // Description
                  if (p.description != null &&
                      p.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(p.description!,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 14,
                            height: 1.5)),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ─── Pricing ───────────────────────────────────────
                  const Text('الأسعار',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),

                  if (p.showCashPrice && p.effectiveCashPrice > 0)
                    _PriceRow(
                      label: 'السعر نقداً',
                      value: AppFormatters.formatCurrency(
                          p.effectiveCashPrice),
                      color: Colors.green,
                      icon: Icons.money,
                    ),

                  if (p.showInstallmentPrice &&
                      p.effectiveInstallmentPrice > 0) ...[
                    const SizedBox(height: 6),
                    _PriceRow(
                      label: 'إجمالي التقسيط',
                      value: AppFormatters.formatCurrency(
                          p.effectiveInstallmentPrice),
                      color: _storeColor,
                      icon: Icons.payment,
                    ),
                  ],

                  // ─── Installment Calculator ─────────────────────────
                  if (p.showInstallmentPrice &&
                      p.effectiveInstallmentPrice > 0 &&
                      p.maxInstallmentMonths > 1) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _storeColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _storeColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.calculate,
                                  color: _storeColor, size: 18),
                              const SizedBox(width: 6),
                              Text('حاسبة الأقساط الشهرية',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _storeColor)),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              const Text('عدد الأشهر: '),
                              Expanded(
                                child: Slider(
                                  value:
                                      _selectedMonths.toDouble(),
                                  min: 1,
                                  max: p.maxInstallmentMonths
                                      .toDouble(),
                                  divisions:
                                      p.maxInstallmentMonths - 1,
                                  activeColor: _storeColor,
                                  label: '$_selectedMonths شهر',
                                  onChanged: (v) => setState(
                                      () => _selectedMonths =
                                          v.round()),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _storeColor,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text('$_selectedMonths شهر',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight.bold)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    const Text('القسط الشهري:',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold)),
                                    Text(
                                      AppFormatters.formatCurrency(
                                          p.monthlyPayment(
                                              _selectedMonths)),
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 18,
                                          color: _storeColor),
                                    ),
                                  ]),
                            ),
                          ]),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ─── Product Specs ──────────────────────────────────
                  const Text('تفاصيل المنتج',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),

                  if (p.purchasePrice > 0)
                    _SpecRow(
                        label: 'سعر الشراء',
                        value: AppFormatters.formatCurrency(
                            p.purchasePrice)),

                  _SpecRow(
                      label: 'أقصى فترة تقسيط',
                      value: '${p.maxInstallmentMonths} شهر'),

                  _SpecRow(
                      label: 'الحالة',
                      value: p.isAvailable
                          ? 'متاح للعملاء'
                          : 'مخفي عن العملاء'),

                  if (images.isNotEmpty)
                    _SpecRow(
                        label: 'عدد الصور',
                        value: '${images.length} صورة'),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub widgets ──────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _PriceRow(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ]),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 14)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String name;
  final Color color;
  const _ImagePlaceholder({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.08),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(name.isNotEmpty ? name[0] : '?',
              style: TextStyle(
                  fontSize: 32,
                  color: color.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
