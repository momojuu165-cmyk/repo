import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../models/installment.dart';
import '../../../models/customer.dart';
import '../../../models/item.dart';
import '../../../models/partner_group.dart';
import '../../../database/daos/partner_group_dao.dart';
import '../../../database/daos/item_dao.dart';
import '../../../utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Point 7: Installment contract form matching the uploaded image
class InstallmentContractScreen extends StatefulWidget {
  final Installment? installment;
  final Customer? customer;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;

  const InstallmentContractScreen({
    super.key,
    this.installment,
    this.customer,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
  });

  @override
  State<InstallmentContractScreen> createState() =>
      _InstallmentContractScreenState();
}

class _InstallmentContractScreenState
    extends State<InstallmentContractScreen> {
  final _dateCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _guarantorNameCtrl = TextEditingController();
  final _guarantorPhoneCtrl = TextEditingController();
  final _guarantorAddressCtrl = TextEditingController();
  final _productNameCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _totalDebtCtrl = TextEditingController();
  final _installmentAmountCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();

  final List<TextEditingController> _payDateCtrls =
      List.generate(24, (_) => TextEditingController());
  final List<TextEditingController> _payAmtCtrls =
      List.generate(24, (_) => TextEditingController());

  bool _showCost = true;
  List<PartnerGroup> _partnerGroups = [];
  int? _selectedPartnerGroupId;
  bool _savingGroup = false;

  @override
  void initState() {
    super.initState();
    _loadPartnerGroups();
    _dateCtrl.text = DateFormat('yyyy/MM/dd').format(DateTime.now());
    _durationCtrl.addListener(() { if (mounted) setState(() {}); });
    if (widget.customer != null) {
      _customerNameCtrl.text = widget.customer!.name;
      _customerAddressCtrl.text =
          widget.customer!.address ?? widget.customer!.homeAddress ?? '';
      _customerPhoneCtrl.text = widget.customer!.phone ?? '';
    } else {
      if (widget.customerName != null && widget.customerName!.isNotEmpty) {
        _customerNameCtrl.text = widget.customerName!;
      }
      if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty) {
        _customerPhoneCtrl.text = widget.customerPhone!;
      }
      if (widget.customerAddress != null && widget.customerAddress!.isNotEmpty) {
        _customerAddressCtrl.text = widget.customerAddress!;
      }
    }
    if (widget.installment != null) {
      _prefill(widget.installment!);
    }
  }

  void _prefill(Installment inst) {
    _productNameCtrl.text = inst.productName;
    _costCtrl.text = inst.salePrice.toStringAsFixed(0);
    _totalDebtCtrl.text = inst.totalInstallmentPrice.toStringAsFixed(0);
    _installmentAmountCtrl.text = inst.monthlyAmount.toStringAsFixed(0);
    _durationCtrl.text = inst.numInstallments.toString();
    _startDateCtrl.text = inst.startDate;
    _guarantorNameCtrl.text = inst.guarantorName ?? '';
    _guarantorPhoneCtrl.text = inst.guarantorPhone ?? '';
    _guarantorAddressCtrl.text = inst.guarantorAddress ?? '';
    if (inst.endDate != null) _endDateCtrl.text = inst.endDate!;

    // Auto-fill payment schedule
    final start = DateTime.tryParse(inst.startDate) ?? DateTime.now();
    final count = inst.numInstallments.clamp(0, 24);
    for (int i = 0; i < count; i++) {
      final d = DateTime(start.year, start.month + i + 1, start.day);
      _payDateCtrls[i].text = DateFormat('yyyy/MM/dd').format(d);
      _payAmtCtrls[i].text = inst.monthlyAmount.toStringAsFixed(0);
    }

    if (inst.endDate == null && inst.numInstallments > 0) {
      final end =
          DateTime(start.year, start.month + inst.numInstallments, start.day);
      _endDateCtrl.text = DateFormat('yyyy/MM/dd').format(end);
    }
  }

  Future<void> _loadPartnerGroups() async {
    try {
      final groups = await PartnerGroupDao().getAllGroups();
      if (mounted) setState(() => _partnerGroups = groups);
      // Pre-select group from installment if available
      if (widget.installment?.partnerGroupId != null && mounted) {
        setState(() => _selectedPartnerGroupId = widget.installment!.partnerGroupId);
      }
    } catch (_) {}
  }

  Future<void> _savePartnerGroup() async {
    final id = widget.installment?.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا يوجد عقد محفوظ لتحديثه'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _savingGroup = true);
    try {
      await Supabase.instance.client
          .from('installments')
          .update({'partner_group_id': _selectedPartnerGroupId})
          .eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_selectedPartnerGroupId == null
              ? 'تم إزالة تحديد مجموعة الشركاء'
              : 'تم حفظ مجموعة الشركاء بنجاح'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في الحفظ: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingGroup = false);
    }
  }

  Future<void> _pickContact() async {
    try {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('يجب منح إذن الوصول لجهات الاتصال'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null && mounted) {
        final fullContact = await FlutterContacts.getContact(contact.id,
            withProperties: true);
        setState(() {
          _customerNameCtrl.text = fullContact?.displayName ?? contact.displayName;
          if (fullContact != null && fullContact.phones.isNotEmpty) {
            _customerPhoneCtrl.text = fullContact.phones.first.number;
          } else if (contact.phones.isNotEmpty) {
            _customerPhoneCtrl.text = contact.phones.first.number;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر فتح جهات الاتصال: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _pickProduct() async {
    try {
      final items = await ItemDao().getAll();
      if (!mounted) return;
      final searchCtrl = TextEditingController();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setInner) {
            final query = searchCtrl.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? items
                : items
                    .where((i) => i.name.toLowerCase().contains(query))
                    .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.92,
              builder: (_, scrollCtrl) => Column(children: [
                const SizedBox(height: 8),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('اختر منتجاً من المخزون',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchCtrl,
                    textDirection: ui.TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'بحث عن منتج...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (_) => setInner(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('لا توجد منتجات', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final item = visible[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.inventory_2_outlined, size: 20),
                              title: Text(item.name,
                                  style: const TextStyle(fontSize: 14),
                                  textDirection: ui.TextDirection.rtl),
                              trailing: item.salePrice != null
                                  ? Text('${item.salePrice!.toStringAsFixed(0)} ج',
                                      style: TextStyle(color: Colors.green[700], fontSize: 13))
                                  : null,
                              onTap: () {
                                setState(() {
                                  _productNameCtrl.text = item.name;
                                  if (item.salePrice != null && _costCtrl.text.isEmpty) {
                                    _costCtrl.text = item.salePrice!.toStringAsFixed(0);
                                  }
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ]),
            );
          });
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر تحميل المنتجات: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _dateCtrl, _customerNameCtrl, _customerAddressCtrl, _customerPhoneCtrl,
      _guarantorNameCtrl, _guarantorPhoneCtrl, _guarantorAddressCtrl,
      _productNameCtrl, _costCtrl, _totalDebtCtrl,
      _installmentAmountCtrl, _durationCtrl, _startDateCtrl, _endDateCtrl,
    ]) { c.dispose(); }
    for (final c in [..._payDateCtrls, ..._payAmtCtrls]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _printEmptyContract() async {
    final pdf = pw.Document();
    pw.Font arabicFont;
    pw.Font arabicBold;
    try {
      arabicFont = await PdfGoogleFonts.cairoRegular();
      arabicBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      arabicFont = pw.Font.helvetica();
      arabicBold = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('عقد التقسيط',
                  style: pw.TextStyle(font: arabicBold, fontSize: 18))),
              pw.SizedBox(height: 12),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                _pdfLabelBlank(arabicFont, 'التاريخ:'),
                _pdfLabelBlank(arabicFont, 'التكلفة:'),
                _pdfLabelBlank(arabicFont, 'إجمالي الدين:'),
              ]),
              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                _pdfLabelBlank(arabicFont, 'اسم الضامن:'),
                pw.SizedBox(width: 24),
                _pdfLabelBlank(arabicFont, 'تليفون:'),
              ]),
              _pdfLabelBlank(arabicFont, 'العنوان:'),
              pw.SizedBox(height: 4),
              _pdfLabelBlank(arabicFont, 'الصنف:'),
              pw.Row(children: [
                _pdfLabelBlank(arabicFont, 'قيمة القسط:'),
                pw.SizedBox(width: 24),
                _pdfLabelBlank(arabicFont, 'مدته:'),
              ]),
              pw.Row(children: [
                _pdfLabelBlank(arabicFont, 'بداية عملية التقسيط:'),
                pw.SizedBox(width: 24),
                _pdfLabelBlank(arabicFont, 'نهايتها:'),
              ]),
              _pdfLabelBlank(arabicFont, 'اسم العميل:'),
              pw.Row(children: [
                _pdfLabelBlank(arabicFont, 'العنوان:'),
                pw.SizedBox(width: 24),
                _pdfLabelBlank(arabicFont, 'تليفون:'),
              ]),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(22),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(22),
                  4: const pw.FlexColumnWidth(3),
                  5: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfCell('م', arabicBold, bold: true),
                      _pdfCell('تاريخ السداد', arabicBold, bold: true),
                      _pdfCell('القيمة', arabicBold, bold: true),
                      _pdfCell('م', arabicBold, bold: true),
                      _pdfCell('تاريخ السداد', arabicBold, bold: true),
                      _pdfCell('القيمة', arabicBold, bold: true),
                    ],
                  ),
                  ...List.generate(6, (i) {
                    final r = i + 6;
                    return pw.TableRow(children: [
                      _pdfCell('${i + 1}', arabicFont),
                      _pdfCell('', arabicFont),
                      _pdfCell('', arabicFont),
                      _pdfCell('${r + 1}', arabicFont),
                      _pdfCell('', arabicFont),
                      _pdfCell('', arabicFont),
                    ]);
                  }),
                ],
              ),
              pw.Spacer(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(children: [
                  pw.Text('توقيع العميل', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                  pw.SizedBox(height: 20),
                  pw.Container(width: 100, height: 1, color: PdfColors.black),
                ]),
                pw.Column(children: [
                  pw.Text('توقيع الضامن', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                  pw.SizedBox(height: 20),
                  pw.Container(width: 100, height: 1, color: PdfColors.black),
                ]),
                pw.Column(children: [
                  pw.Text('توقيع البائع', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                  pw.SizedBox(height: 20),
                  pw.Container(width: 100, height: 1, color: PdfColors.black),
                ]),
              ]),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _printEmptySchedule() async {
    final pdf = pw.Document();
    pw.Font arabicFont;
    pw.Font arabicBold;
    try {
      arabicFont = await PdfGoogleFonts.cairoRegular();
      arabicBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      arabicFont = pw.Font.helvetica();
      arabicBold = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('جدول السداد',
                  style: pw.TextStyle(font: arabicBold, fontSize: 18))),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                _pdfLabelBlank(arabicFont, 'اسم العميل:'),
                pw.SizedBox(width: 24),
                _pdfLabelBlank(arabicFont, 'الصنف:'),
              ]),
              pw.Row(children: [
                _pdfLabelBlank(arabicFont, 'قيمة القسط:'),
                pw.SizedBox(width: 24),
                _pdfLabelBlank(arabicFont, 'عدد الأشهر:'),
              ]),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(22),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(22),
                  4: const pw.FlexColumnWidth(3),
                  5: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfCell('م', arabicBold, bold: true),
                      _pdfCell('تاريخ السداد', arabicBold, bold: true),
                      _pdfCell('القيمة', arabicBold, bold: true),
                      _pdfCell('م', arabicBold, bold: true),
                      _pdfCell('تاريخ السداد', arabicBold, bold: true),
                      _pdfCell('القيمة', arabicBold, bold: true),
                    ],
                  ),
                  ...List.generate(12, (i) {
                    final r = i + 12;
                    return pw.TableRow(children: [
                      _pdfCell('${i + 1}', arabicFont),
                      _pdfCell('', arabicFont),
                      _pdfCell('', arabicFont),
                      _pdfCell('${r + 1}', arabicFont),
                      _pdfCell('', arabicFont),
                      _pdfCell('', arabicFont),
                    ]);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _printContract() async {
    final pdf = pw.Document();
    pw.Font arabicFont;
    pw.Font arabicBold;
    try {
      arabicFont = await PdfGoogleFonts.cairoRegular();
      arabicBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      arabicFont = pw.Font.helvetica();
      arabicBold = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Center(
                child: pw.Text(
                  'عقد التقسيط',
                  style: pw.TextStyle(
                      font: arabicBold, fontSize: 18),
                ),
              ),
              pw.SizedBox(height: 12),
              // Header row: date, cost (optional), total debt
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfLabelVal(arabicFont, 'التاريخ:', _dateCtrl.text),
                  if (_showCost)
                    _pdfLabelVal(arabicFont, 'التكلفة:', _costCtrl.text),
                  _pdfLabelVal(
                      arabicFont, 'إجمالي الدين:', _totalDebtCtrl.text),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 6),
              // Guarantor
              pw.Row(children: [
                _pdfLabelVal(
                    arabicFont, 'اسم الضامن:', _guarantorNameCtrl.text),
                pw.SizedBox(width: 24),
                _pdfLabelVal(
                    arabicFont, 'تليفون:', _guarantorPhoneCtrl.text),
              ]),
              _pdfLabelVal(
                  arabicFont, 'العنوان:', _guarantorAddressCtrl.text),
              pw.SizedBox(height: 4),
              // Partner group routing (if selected)
              if (_selectedPartnerGroupId != null) ...[
                _pdfLabelVal(
                  arabicFont,
                  'مجموعة الشركاء:',
                  _partnerGroups.firstWhere((g) => g.id == _selectedPartnerGroupId, orElse: () => PartnerGroup(name: '', createdAt: '')).name,
                ),
                pw.SizedBox(height: 4),
              ],
              // Product & installment info
              _pdfLabelVal(arabicFont, 'الصنف:', _productNameCtrl.text),
              pw.Row(children: [
                _pdfLabelVal(
                    arabicFont, 'قيمة القسط:', _installmentAmountCtrl.text),
                pw.SizedBox(width: 24),
                _pdfLabelVal(arabicFont, 'مدته:', '${_durationCtrl.text} شهر'),
              ]),
              pw.Row(children: [
                _pdfLabelVal(
                    arabicFont, 'بداية عملية التقسيط:', _startDateCtrl.text),
                pw.SizedBox(width: 24),
                _pdfLabelVal(arabicFont, 'نهايتها:', _endDateCtrl.text),
              ]),
              // Customer
              _pdfLabelVal(arabicFont, 'اسم العميل:', _customerNameCtrl.text),
              pw.Row(children: [
                _pdfLabelVal(
                    arabicFont, 'العنوان:', _customerAddressCtrl.text),
                pw.SizedBox(width: 24),
                _pdfLabelVal(
                    arabicFont, 'تليفون:', _customerPhoneCtrl.text),
              ]),
              pw.SizedBox(height: 12),
              // Payment schedule table — dynamic rows based on duration
              pw.Builder(builder: (ctx) {
                final numMonths = int.tryParse(_durationCtrl.text) ?? 12;
                final halfRows = (numMonths / 2).ceil();
                return pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(22),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FixedColumnWidth(22),
                    4: const pw.FlexColumnWidth(3),
                    5: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfCell('م', arabicBold, bold: true),
                        _pdfCell('تاريخ السداد', arabicBold, bold: true),
                        _pdfCell('القيمة', arabicBold, bold: true),
                        _pdfCell('م', arabicBold, bold: true),
                        _pdfCell('تاريخ السداد', arabicBold, bold: true),
                        _pdfCell('القيمة', arabicBold, bold: true),
                      ],
                    ),
                    ...List.generate(halfRows, (i) {
                      final r = i + halfRows;
                      return pw.TableRow(children: [
                        _pdfCell('${i + 1}', arabicFont),
                        _pdfCell(_payDateCtrls[i].text, arabicFont),
                        _pdfCell(_payAmtCtrls[i].text, arabicFont),
                        _pdfCell(r < numMonths ? '${r + 1}' : '', arabicFont),
                        _pdfCell(r < numMonths ? _payDateCtrls[r].text : '', arabicFont),
                        _pdfCell(r < numMonths ? _payAmtCtrls[r].text : '', arabicFont),
                      ]);
                    }),
                  ],
                );
              }),
              pw.Spacer(),
              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Text('توقيع العميل', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Container(width: 100, height: 1, color: PdfColors.black),
                  ]),
                  pw.Column(children: [
                    pw.Text('توقيع الضامن', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Container(width: 100, height: 1, color: PdfColors.black),
                  ]),
                  pw.Column(children: [
                    pw.Text('توقيع البائع', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Container(width: 100, height: 1, color: PdfColors.black),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  pw.Widget _pdfLabelVal(pw.Font font, String label, String val) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
          pw.SizedBox(width: 4),
          pw.Text(val,
              style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold)),
        ]),
      );

  pw.Widget _pdfLabelBlank(pw.Font font, String label) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
          pw.SizedBox(width: 6),
          pw.Container(width: 100, height: 0.5, color: PdfColors.grey600),
        ]),
      );

  pw.Widget _pdfCell(String text, pw.Font font, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(text,
            style: pw.TextStyle(
                font: font,
                fontSize: 8,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal),
            textAlign: pw.TextAlign.center),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('عقد التقسيط'),
          backgroundColor: const Color(AppColors.primaryInt),
          foregroundColor: Colors.white,
          actions: [
            if (widget.installment?.id != null)
              _savingGroup
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.save_rounded),
                      tooltip: 'حفظ مجموعة الشركاء',
                      onPressed: _savePartnerGroup,
                    ),
            IconButton(
              icon: Icon(_showCost ? Icons.visibility : Icons.visibility_off),
              tooltip: _showCost ? 'إخفاء التكلفة' : 'إظهار التكلفة',
              onPressed: () => setState(() => _showCost = !_showCost),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.print),
              tooltip: 'خيارات الطباعة',
              onSelected: (v) {
                if (v == 'filled') _printContract();
                if (v == 'empty_contract') _printEmptyContract();
                if (v == 'empty_schedule') _printEmptySchedule();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'filled', child: Row(children: [
                  Icon(Icons.print, size: 18, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('طباعة العقد المعبأ'),
                ])),
                PopupMenuItem(value: 'empty_contract', child: Row(children: [
                  Icon(Icons.print_outlined, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('طباعة عقد فارغ'),
                ])),
                PopupMenuItem(value: 'empty_schedule', child: Row(children: [
                  Icon(Icons.table_rows_outlined, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('طباعة جدول أقساط فارغ'),
                ])),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              _section('معلومات العقد', [
                Row(children: [
                  Expanded(child: _field('التاريخ', _dateCtrl)),
                  const SizedBox(width: 8),
                  if (_showCost) ...[
                    Expanded(child: _field('التكلفة', _costCtrl, num: true)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                      child: _field('إجمالي الدين', _totalDebtCtrl, num: true)),
                ]),
              ]),
              // Partner group selector
              if (_partnerGroups.isNotEmpty)
                _section('توجيه الدفع', [
                  DropdownButtonFormField<int?>(
                    value: _selectedPartnerGroupId,
                    decoration: InputDecoration(
                      labelText: 'مجموعة الشركاء',
                      prefixIcon: const Icon(Icons.group_work_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('— بدون تحديد —')),
                      ..._partnerGroups.map((g) => DropdownMenuItem<int?>(
                        value: g.id,
                        child: Text(g.name),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedPartnerGroupId = v),
                  ),
                ]),
              // Guarantor
              _section('بيانات الضامن', [
                Row(children: [
                  Expanded(child: _field('اسم الضامن', _guarantorNameCtrl)),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          _field('تليفون الضامن', _guarantorPhoneCtrl, phone: true)),
                ]),
                _field('عنوان الضامن', _guarantorAddressCtrl),
              ]),
              // Product & schedule
              _section('تفاصيل التقسيط', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _field('الصنف / المنتج', _productNameCtrl)),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickProduct,
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('من المخزون', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        side: const BorderSide(color: Color(AppColors.primaryInt)),
                        foregroundColor: Color(AppColors.primaryInt),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                Row(children: [
                  Expanded(
                      child: _field('قيمة القسط', _installmentAmountCtrl,
                          num: true)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _field('المدة (شهر)', _durationCtrl, num: true)),
                ]),
                Row(children: [
                  Expanded(child: _field('تاريخ البداية', _startDateCtrl)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('تاريخ النهاية', _endDateCtrl)),
                ]),
              ]),
              // Customer
              _section('بيانات العميل', [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickContact,
                      icon: const Icon(Icons.contacts_rounded, size: 16),
                      label: const Text('استيراد من جهات الاتصال', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Colors.teal),
                        foregroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _field('اسم العميل', _customerNameCtrl),
                Row(children: [
                  Expanded(
                      child:
                          _field('عنوان العميل', _customerAddressCtrl)),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          _field('تليفون', _customerPhoneCtrl, phone: true)),
                ]),
              ]),
              // Payment table — dynamic rows based on duration field
              Builder(builder: (ctx) {
                final numMonths = int.tryParse(_durationCtrl.text) ?? 12;
                final halfRows = (numMonths / 2).ceil();
                return _section('جدول السداد ($numMonths قسط)', [
                  Table(
                    border: TableBorder.all(
                        color: Colors.grey[300]!, width: 0.8),
                    columnWidths: const {
                      0: FixedColumnWidth(28),
                      1: FlexColumnWidth(3),
                      2: FlexColumnWidth(2),
                      3: FixedColumnWidth(28),
                      4: FlexColumnWidth(3),
                      5: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                            color: const Color(AppColors.primaryInt)
                                .withValues(alpha: 0.12)),
                        children: const [
                          _TH('م'), _TH('تاريخ السداد'), _TH('القيمة'),
                          _TH('م'), _TH('تاريخ السداد'), _TH('القيمة'),
                        ],
                      ),
                      ...List.generate(halfRows, (i) {
                        final r = i + halfRows;
                        return TableRow(children: [
                          _numCell(i + 1),
                          _editCell(_payDateCtrls[i]),
                          _editCell(_payAmtCtrls[i]),
                          r < numMonths ? _numCell(r + 1) : const Padding(padding: EdgeInsets.zero, child: SizedBox()),
                          r < numMonths ? _editCell(_payDateCtrls[r]) : const SizedBox(height: 34),
                          r < numMonths ? _editCell(_payAmtCtrls[r]) : const SizedBox(height: 34),
                        ]);
                      }),
                    ],
                  ),
                ]);
              }),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppColors.primaryInt),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة العقد'),
                    onPressed: _printContract,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('فارغ', style: TextStyle(fontSize: 13)),
                    onPressed: () async {
                      final choice = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('طباعة فارغة'),
                          content: const Text('اختر نوع النموذج الفارغ للطباعة:'),
                          actions: [
                            TextButton.icon(
                              onPressed: () => Navigator.pop(ctx, 'contract'),
                              icon: const Icon(Icons.description_outlined),
                              label: const Text('عقد فارغ'),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.pop(ctx, 'schedule'),
                              icon: const Icon(Icons.table_rows_outlined),
                              label: const Text('جدول أقساط فارغ'),
                            ),
                          ],
                        ),
                      );
                      if (choice == 'contract') _printEmptyContract();
                      if (choice == 'schedule') _printEmptySchedule();
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

  Widget _field(String label, TextEditingController ctrl,
      {bool num = false, bool phone = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: ctrl,
          textDirection: ui.TextDirection.rtl,
          keyboardType: num
              ? TextInputType.number
              : phone
                  ? TextInputType.phone
                  : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
          ),
        ),
      );

  Widget _numCell(int n) => Padding(
      padding: const EdgeInsets.all(4),
      child: Text('$n',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11)));

  Widget _editCell(TextEditingController ctrl) => SizedBox(
        height: 34,
        child: TextField(
          controller: ctrl,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          ),
        ),
      );
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(4),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 11)));
}
