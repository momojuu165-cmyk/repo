// ─── Centralized notification message catalog ────────────────────────────────
// All user-facing notification strings live here.
// Rules:
//   • No PII in title or body (no names, invoice numbers, phone numbers, amounts)
//   • Messages are generic and professional
//   • referenceId / referenceType are stored separately in metadata — not in the body
// ─────────────────────────────────────────────────────────────────────────────

class NotifMsg {
  const NotifMsg._();

  // ── Request events ────────────────────────────────────────────────────────
  static const String requestApprovedTitle = 'تمت الموافقة على طلبك';
  static const String requestApprovedBody  = 'يسعدنا إخبارك أنه تمت الموافقة على طلبك بنجاح.';

  static const String requestRejectedTitle = 'بشأن طلبك الأخير';
  static const String requestRejectedBody  = 'نأسف، لم يتمكن الفريق من قبول طلبك في هذا الوقت. يمكنك التواصل معنا لمزيد من التفاصيل.';

  static const String newRequestAdminTitle = 'طلب جديد يحتاج مراجعة';
  static const String newRequestAdminBody  = 'وردنا طلب جديد ويحتاج إلى مراجعتك.';

  // ── Invoice events ────────────────────────────────────────────────────────
  static const String newInvoiceAdminTitle = 'طلب شراء جديد';
  static const String newInvoiceAdminBody  = 'وردنا طلب شراء جديد برقم';

  static const String invoiceApprovedTitle = 'تمت مراجعة طلبك';
  static const String invoiceApprovedBody  = 'أُبلغ طلبك وتمت الموافقة عليه بنجاح. شكراً لتعاملك معنا.';

  static const String invoiceRejectedTitle = 'بشأن طلبك';
  static const String invoiceRejectedBody  = 'تعذّر قبول طلبك حالياً. يُرجى التواصل مع الفريق لمزيد من المعلومات.';

  static const String invoiceDeliveredTitle = 'تم تسليم طلبك';
  static const String invoiceDeliveredBody  = 'يسعدنا إخبارك أنه تم تسليم طلبك بنجاح. نتمنى لك تجربة ممتازة.';

  // ── Installment / payment events ─────────────────────────────────────────
  static const String newInstallmentAdminTitle = 'عقد تقسيط جديد';
  static const String newInstallmentAdminBody  = 'تم إنشاء عقد تقسيط جديد ويمكن مراجعة تفاصيله من لوحة التحكم.';

  static const String overdueInstallmentTitle = 'تنبيه: أقساط تحتاج متابعة';
  static const String overdueInstallmentBody  = 'توجد أقساط متأخرة تحتاج إلى مراجعة ومتابعة.';

  static const String paymentReceivedTitle = 'تم تسجيل دفعتك';
  static const String paymentReceivedBody  = 'تم استلام دفعتك وتسجيلها بنجاح. شكراً لالتزامك.';

  static const String installmentDueTitle  = 'تذكير بقسطك القادم';
  static const String installmentDueBody   = 'نذكّرك بأن قسطك القادم موعده قريب. يُرجى التسوية في الوقت المحدد.';

  // ── General system ────────────────────────────────────────────────────────
  static const String systemUpdateTitle = 'تحديث من النظام';
  static const String systemUpdateBody  = 'يوجد تحديث جديد على حسابك. يُرجى الاطلاع على التفاصيل من التطبيق.';
}
