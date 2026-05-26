import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart' show BuildContext;

class PdfHelper {
  static Future<void> printReport({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<List<String>> headers,
    required List<List<String>> rows,
    List<Map<String, String>>? summaryRows,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'فرصتك للتقسيط',
                  style: pw.TextStyle(
                    font: arabicFontBold,
                    fontSize: 18,
                    color: PdfColors.blue800,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: arabicFontBold,
                    fontSize: 16,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                if (subtitle.isNotEmpty)
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 12,
                      color: PdfColors.grey,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.blue800),
              ],
            ),
          ),
          if (summaryRows != null && summaryRows.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: summaryRows.map((row) {
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        row['value'] ?? '',
                        style: pw.TextStyle(font: arabicFontBold, fontSize: 13),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        row['label'] ?? '',
                        style: pw.TextStyle(font: arabicFont, fontSize: 13),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (rows.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                for (int i = 0; i < headers[0].length; i++)
                  i: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: headers[0].map((h) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          font: arabicFontBold,
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                      ),
                    );
                  }).toList(),
                ),
                ...rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: row.map((cell) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          cell,
                          style: pw.TextStyle(font: arabicFont, fontSize: 10),
                          textDirection: pw.TextDirection.rtl,
                          textAlign: pw.TextAlign.center,
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          if (rows.isEmpty)
            pw.Center(
              child: pw.Text(
                'لا توجد بيانات',
                style: pw.TextStyle(font: arabicFont, color: PdfColors.grey),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: pw.TextStyle(font: arabicFont, fontSize: 10, color: PdfColors.grey),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              DateTime.now().toString().substring(0, 19),
              style: pw.TextStyle(font: arabicFont, fontSize: 10, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '$title.pdf',
    );
  }

  static Future<Uint8List> generateInvoicePdf({
    required String invoiceNo,
    required String date,
    required String customerName,
    required String paymentType,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paid,
    required double remaining,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'فرصتك للتقسيط',
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontSize: 18,
                          color: PdfColors.blue800),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Text(
                      'نظام إدارة المتجر',
                      style: pw.TextStyle(font: arabicFont, fontSize: 11, color: PdfColors.grey),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'فاتورة #$invoiceNo',
                      style: pw.TextStyle(font: arabicFontBold, fontSize: 14),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Text(
                      date,
                      style: pw.TextStyle(font: arabicFont, fontSize: 11, color: PdfColors.grey),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: PdfColors.blue800),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Text('العميل: ', style: pw.TextStyle(font: arabicFontBold, fontSize: 12), textDirection: pw.TextDirection.rtl),
                pw.Text(customerName, style: pw.TextStyle(font: arabicFont, fontSize: 12), textDirection: pw.TextDirection.rtl),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: ['المنتج', 'الكمية', 'السعر', 'الإجمالي'].map((h) =>
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(h,
                          style: pw.TextStyle(font: arabicFontBold, color: PdfColors.white, fontSize: 11),
                          textDirection: pw.TextDirection.rtl,
                          textAlign: pw.TextAlign.center),
                    )
                  ).toList(),
                ),
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      item['name'] as String,
                      item['qty'].toString(),
                      item['price'].toString(),
                      item['total'].toString(),
                    ].map((cell) =>
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(cell,
                            style: pw.TextStyle(font: arabicFont, fontSize: 10),
                            textDirection: pw.TextDirection.rtl,
                            textAlign: pw.TextAlign.center),
                      )
                    ).toList(),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                children: [
                  _summaryRow('المجموع', '${subtotal.toStringAsFixed(2)} ج.م', arabicFont, arabicFontBold),
                  if (discount > 0)
                    _summaryRow('الخصم', '${discount.toStringAsFixed(2)} ج.م', arabicFont, arabicFontBold, valueColor: PdfColors.red),
                  pw.Divider(),
                  _summaryRow('الإجمالي', '${total.toStringAsFixed(2)} ج.م', arabicFont, arabicFontBold, isBold: true),
                  _summaryRow('المدفوع', '${paid.toStringAsFixed(2)} ج.م', arabicFont, arabicFontBold, valueColor: PdfColors.green),
                  if (remaining > 0)
                    _summaryRow('المتبقي', '${remaining.toStringAsFixed(2)} ج.م', arabicFont, arabicFontBold, valueColor: PdfColors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryRow(String label, String value, pw.Font font, pw.Font boldFont, {bool isBold = false, PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  font: isBold ? boldFont : font,
                  fontSize: isBold ? 14 : 12,
                  color: valueColor),
              textDirection: pw.TextDirection.rtl),
          pw.Text(label,
              style: pw.TextStyle(
                  font: isBold ? boldFont : font,
                  fontSize: isBold ? 14 : 12),
              textDirection: pw.TextDirection.rtl),
        ],
      ),
    );
  }
}
