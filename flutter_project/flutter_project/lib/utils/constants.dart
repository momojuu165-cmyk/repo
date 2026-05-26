class AppConstants {
  static const String appName = 'فرصتك للتقسيط';
  static const String appSubtitle = 'أدوات كهربائية ونظام تقسيط';
  static const String dbName = 'farsa_taqsit.db';
  static const int dbVersion = 17;

  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String rolePartner = 'partner';
  static const String roleEmployee = 'employee';
  static const String roleCustomer = 'customer';

  static const String storeElectrical = 'electrical';
  static const String storeInstallment = 'installment';
  static const String storeClothing = 'clothing';
  static const String storeMobiles = 'mobiles';
  static const String storeAccessories = 'accessories';

  // Department types for managers
  static const String deptAll = 'all';
  static const String deptInstallment = 'installment';
  static const String deptElectrical = 'electrical';
  static const String deptClothing = 'clothing';
  static const String deptMobiles = 'mobiles';
  static const String deptAccessories = 'accessories';

  static const Map<String, String> deptLabels = {
    deptAll: 'جميع الأقسام',
    deptInstallment: 'قسم التقسيط',
    deptElectrical: 'قسم الأدوات الكهربائية',
    deptClothing: 'قسم الملابس',
    deptMobiles: 'قسم الموبايلات',
    deptAccessories: 'قسم الإكسسوارات',
  };

  static const Map<String, String> storeLabels = {
    storeInstallment: 'منتجات التقسيط',
    storeElectrical: 'الأدوات الكهربائية',
    storeClothing: 'الملابس',
    storeMobiles: 'الموبايلات',
    storeAccessories: 'الإكسسوارات',
  };

  // Code types (Feature 3: temporary vs permanent codes)
  static const String codeTypePermanent = 'permanent';
  static const String codeTypeTemporary = 'temporary';
  static const int temporaryCodeHours = 12;

  // Customer status (Feature 12: VIP / blacklist)
  static const String customerStatusRegular = 'regular';
  static const String customerStatusVip = 'vip';
  static const String customerStatusBlacklist = 'blacklist';

  static const String permViewSales = 'view_sales';
  static const String permManageSales = 'manage_sales';
  static const String permViewInventory = 'view_inventory';
  static const String permManageInventory = 'manage_inventory';
  static const String permViewCustomers = 'view_customers';
  static const String permManageCustomers = 'manage_customers';
  static const String permViewInstallments = 'view_installments';
  static const String permManageInstallments = 'manage_installments';
  static const String permViewReports = 'view_reports';
  static const String permViewTreasury = 'view_treasury';
  static const String permManageTreasury = 'manage_treasury';
  static const String permViewPartners = 'view_partners';
  static const String permManageRequests = 'manage_requests';
  static const String permManageProducts = 'manage_products';
  static const String permViewChat = 'view_chat';

  static const List<String> allPermissions = [
    permViewSales,
    permManageSales,
    permViewInventory,
    permManageInventory,
    permViewCustomers,
    permManageCustomers,
    permViewInstallments,
    permManageInstallments,
    permViewReports,
    permViewTreasury,
    permManageTreasury,
    permViewPartners,
    permManageRequests,
    permManageProducts,
    permViewChat,
  ];

  static const Map<String, String> permissionLabels = {
    permViewSales: 'عرض المبيعات',
    permManageSales: 'إدارة المبيعات',
    permViewInventory: 'عرض المخزن',
    permManageInventory: 'إدارة المخزن',
    permViewCustomers: 'عرض العملاء',
    permManageCustomers: 'إدارة العملاء',
    permViewInstallments: 'عرض الأقساط',
    permManageInstallments: 'إدارة الأقساط',
    permViewReports: 'عرض التقارير',
    permViewTreasury: 'عرض الخزنة',
    permManageTreasury: 'إدارة الخزنة',
    permViewPartners: 'عرض الشركاء',
    permManageRequests: 'إدارة الطلبات',
    permManageProducts: 'إدارة المنتجات',
    permViewChat: 'المحادثات',
  };

  static const String priceWholesale = 'wholesale';
  static const String priceSemiWholesale = 'semi_wholesale';
  static const String priceRetail = 'retail';
  static const String priceSpecial = 'special';

  static const String paymentCash = 'cash';
  static const String paymentInstallment = 'installment';
  static const String paymentPartial = 'partial';
  static const String paymentTransfer = 'transfer';

  static const String paymentMethodStore = 'in_store';
  static const String paymentMethodReceipt = 'receipt';

  static const String invoiceStatusPaid = 'paid';
  static const String invoiceStatusPartial = 'partial';
  static const String invoiceStatusUnpaid = 'unpaid';
  static const String invoiceStatusReturn = 'return';

  static const String installmentStatusActive = 'active';
  static const String installmentStatusCompleted = 'completed';
  static const String installmentStatusOverdue = 'overdue';

  static const String movementDeposit = 'deposit';
  static const String movementWithdrawal = 'withdrawal';
  static const String movementTransfer = 'transfer';

  static const String requestStatusPending = 'pending';
  static const String requestStatusApproved = 'approved';
  static const String requestStatusRejected = 'rejected';
  static const String requestStatusCompleted = 'completed';

  static const String customerTypeRegular = 'regular';
  static const String customerTypeTechnician = 'technician';
  static const String customerTypeEngineer = 'engineer';

  static const double defaultAdminFeeRate = 0.05;
  static const double installmentFeeRate = 0.10;

  static const int pointsPerCurrency = 1;
  static const double pointsRedemptionRate = 0.01;

  static const int defaultMaxInstallmentMonths = 24;
}

class AppColors {
  static const int primaryInt = 0xFFBF360C;
  static const int primary2Int = 0xFFE65100;
  static const int accentInt = 0xFFF57F20;
  static const int accent2Int = 0xFFFFAB40;
  static const int electricalInt = 0xFFBF360C;
  static const int electrical2Int = 0xFFFF6D00;
  static const int installmentInt = 0xFFD84315;
  static const int installment2Int = 0xFFFF7043;
  static const int successInt = 0xFF1B5E20;
  static const int dangerInt = 0xFFB71C1C;
  static const int warningInt = 0xFFE65100;
  static const int errorInt = 0xFFB71C1C;
  static const int surfaceInt = 0xFFFFF8F2;
  static const int cardInt = 0xFFFFFFFF;
  static const int clothingInt = 0xFFFF6F00;
  static const int mobilesInt = 0xFFE64A19;
  static const int accessoriesInt = 0xFFBF360C;
  static const int vipInt = 0xFFFFD700;
  static const int blacklistInt = 0xFF8B0000;
}
