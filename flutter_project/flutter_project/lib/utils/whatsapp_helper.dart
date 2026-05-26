import 'package:url_launcher/url_launcher.dart';

  class WhatsAppHelper {
    /// Normalizes phone number: adds +20 prefix for Egyptian numbers
    static String normalizeEgyptianPhone(String phone) {
      String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleaned.startsWith('+20')) return cleaned;
      if (cleaned.startsWith('20') && cleaned.length > 11) return '+$cleaned';
      if (cleaned.startsWith('0') && cleaned.length == 11) {
        return '+20${cleaned.substring(1)}';
      }
      if (cleaned.length == 10) return '+20$cleaned';
      return cleaned.startsWith('+') ? cleaned : '+20$cleaned';
    }

    static Future<void> sendMessage({
      required String phone,
      required String message,
    }) async {
      final normalized = normalizeEgyptianPhone(phone);
      final encoded = Uri.encodeComponent(message);
      final url = Uri.parse('https://wa.me/$normalized?text=$encoded');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        final fallback = Uri.parse('https://api.whatsapp.com/send?phone=$normalized&text=$encoded');
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }

    static Future<void> sendInstallmentReminder({
      required String phone,
      required String customerName,
      required String productName,
      required double amount,
      required String dueDate,
    }) async {
      final msg = '''السلام عليكم ${customerName.isNotEmpty ? customerName : ""}،
  تذكير بموعد سداد القسط الخاص بـ: $productName
  المبلغ المستحق: ${amount.toStringAsFixed(2)} جنيه
  تاريخ الاستحقاق: $dueDate
  يرجى السداد في الموعد المحدد. شكراً لتعاملكم معنا. 🙏
  متجر فرصتك للتقسيط''';
      await sendMessage(phone: phone, message: msg);
    }

    static Future<void> sendLoginCode({
      required String phone,
      required String name,
      required String code,
      required String role,
    }) async {
      final roleAr = role == 'partner' ? 'شريك' : 'مدير';
      final msg = '''مرحباً $name،
  تم إنشاء حساب $roleAr لك في نظام فرصتك للتقسيط.
  كود الدخول الخاص بك: $code
  احتفظ بهذا الكود وادخل به في التطبيق.
  📱 متجر فرصتك للتقسيط''';
      await sendMessage(phone: phone, message: msg);
    }

    static Future<void> sendCustomerCode({
      required String phone,
      required String name,
      required String code,
    }) async {
      final msg = '''مرحباً $name،
  تم قبول طلب تسجيلك في نظام فرصتك للتقسيط.
  كود الدخول الخاص بك: $code
  ادخل هذا الكود في التطبيق من قسم "دخول عميل".
  📱 متجر فرصتك للتقسيط''';
      await sendMessage(phone: phone, message: msg);
    }

    static Future<void> sendInvoiceNotification({
      required String phone,
      required String customerName,
      required String invoiceNo,
      required double total,
    }) async {
      final msg = '''السلام عليكم $customerName،
  تم استلام طلبك رقم: $invoiceNo
  إجمالي الفاتورة: ${total.toStringAsFixed(2)} جنيه
  سيتم التواصل معك قريباً لتأكيد الطلب.
  📱 متجر فرصتك للتقسيط''';
      await sendMessage(phone: phone, message: msg);
    }
  }
  