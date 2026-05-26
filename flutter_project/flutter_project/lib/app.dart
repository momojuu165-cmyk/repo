import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/installment_provider.dart';
import 'providers/partner_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/quick_access_screen.dart';
import 'screens/auth/store_selection_screen.dart';
import 'screens/auth/customer_register_screen.dart';
import 'screens/guest/guest_browse_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/sales/sales_list_screen.dart';
import 'screens/admin/sales/sales_invoice_screen.dart';
import 'screens/admin/sales/pos_invoice_screen.dart';
import 'screens/admin/sales/sales_returns_screen.dart';
import 'screens/admin/purchases/purchases_screen.dart';
import 'screens/admin/purchases/purchase_returns_screen.dart';
import 'screens/admin/expenses/expenses_screen.dart';
import 'screens/admin/customers/customers_screen.dart';
import 'screens/admin/customers/customer_payments_screen.dart';
import 'screens/admin/customers/customer_statement_screen.dart';
import 'screens/admin/customers/technician_points_screen.dart';
import 'screens/admin/inventory/inventory_screen.dart';
import 'screens/admin/inventory/item_groups_screen.dart';
import 'screens/admin/installments/installments_screen.dart';
import 'screens/admin/installments/installments_by_section_screen.dart';
import 'screens/admin/partners/partners_screen.dart';
import 'screens/admin/reports/reports_screen.dart';
import 'screens/admin/treasury/treasury_screen.dart';
import 'screens/admin/requests/requests_screen.dart';
import 'screens/admin/settings/settings_screen.dart';
import 'screens/admin/settings/users_screen.dart';
import 'screens/admin/settings/departments_management_screen.dart';
import 'screens/admin/projects/projects_screen.dart';
import 'screens/admin/price_lists/price_lists_screen.dart';
import 'screens/admin/discounts/discounts_screen.dart';
import 'screens/admin/payment_tracking_screen.dart';
import 'screens/admin/installment_products/installment_products_screen.dart';
import 'screens/admin/installment_products/installment_categories_screen.dart';
import 'screens/admin/partner_groups/partner_groups_screen.dart';
import 'screens/admin/partner_groups/group_cash_flows_screen.dart';
import 'screens/admin/electrical_bundles/electrical_bundles_screen.dart';
import 'screens/admin/electrical_bundles/electrical_dashboard_screen.dart';
import 'screens/admin/electrical_bundles/electrical_categories_screen.dart';
import 'screens/admin/customer_invoices/customer_invoices_admin_screen.dart';
import 'screens/customer/electrical_customer_home.dart';
import 'screens/customer/installment_customer_home.dart';
import 'screens/partner/partner_dashboard.dart';
import 'screens/employee/employee_dashboard.dart';
import 'screens/admin/chat/chat_list_screen.dart';
import 'screens/admin/chat/partner_chat_screen.dart';
import 'screens/shared/notification_history_screen.dart';
import 'screens/admin/notifications/notifications_screen.dart';
import 'screens/admin/notifications/send_notification_screen.dart';
import 'screens/admin/installments/installment_contract_screen.dart';
import 'screens/admin/suppliers/suppliers_screen.dart';
import 'screens/admin/suppliers/supplier_comparison_screen.dart';
import 'screens/admin/price_sheet/price_sheet_screen.dart';
import 'screens/admin/audit/audit_log_screen.dart';
import 'screens/admin/electrical_bundles/electrical_pricing_screen.dart';
import 'models/installment.dart';
import 'utils/constants.dart';

class StoreApp extends StatelessWidget {
  const StoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => InstallmentProvider()),
        ChangeNotifierProvider(create: (_) => PartnerProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context),
            child: SafeArea(top: false, child: child!),
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(AppColors.primaryInt),
          textTheme: GoogleFonts.cairoTextTheme(),
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        home: const _RootRouter(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/installment-home': (_) => const InstallmentCustomerHome(),
          '/electrical-home': (_) => const ElectricalCustomerHome(),
          '/quick-access': (_) => const QuickAccessScreen(),
          '/guest-browse': (_) => const GuestBrowseScreen(),
          '/store-select': (_) => const StoreSelectionScreen(),
          '/register': (_) => const CustomerRegisterScreen(),
          '/dashboard': (_) => const AdminDashboard(),
          '/pos': (_) => const PosInvoiceScreen(),
          '/sales': (_) => const SalesListScreen(),
          '/sales/new': (_) => const SalesInvoiceScreen(),
          '/sales/returns': (_) => const SalesReturnsScreen(),
          '/purchases': (_) => const PurchasesScreen(),
          '/purchases/new': (_) => const PurchasesScreen(),
          '/purchases/returns': (_) => const PurchaseReturnsScreen(),
          '/expenses': (_) => const ExpensesScreen(),
          '/customers': (_) => const CustomersScreen(),
          '/customers/add': (_) => const CustomersScreen(),
          '/technician-points': (_) => const TechnicianPointsScreen(),
          '/customer-payments': (_) => const CustomerPaymentsScreen(),
          '/customer-statement': (_) => const CustomerStatementScreen(),
          '/inventory': (_) => const InventoryScreen(),
          '/inventory/add': (_) => const InventoryScreen(),
          '/item-groups': (_) => const ItemGroupsScreen(),
          '/installments': (_) => const InstallmentsScreen(),
          '/installments-by-section': (_) => const InstallmentsBySectionScreen(),
          '/installments/electrical': (_) => const InstallmentsScreen(initialStoreType: 'electrical'),
          '/installments/installment': (_) => const InstallmentsScreen(initialStoreType: 'installment'),
          '/installment-products': (_) => const InstallmentProductsScreen(),
          '/electrical-products': (_) => const InstallmentProductsScreen(initialStoreType: 'electrical'),
          '/clothing-products': (_) => const InstallmentProductsScreen(initialStoreType: 'clothing'),
          '/mobiles-products': (_) => const InstallmentProductsScreen(initialStoreType: 'mobiles'),
          '/accessories-products': (_) => const InstallmentProductsScreen(initialStoreType: 'accessories'),
          '/installment-categories': (_) => const InstallmentCategoriesScreen(),
          '/electrical-categories': (_) => const ElectricalCategoriesScreen(),
          '/partners': (_) => const PartnersScreen(),
          '/partner-groups': (_) => const PartnerGroupsScreen(),
          '/group-cash-flows': (_) => const GroupCashFlowsScreen(),
          '/partner-dashboard': (_) => const PartnerDashboard(),
          '/electrical-bundles': (_) => const ElectricalBundlesScreen(),
          '/electrical-dashboard': (_) => const ElectricalDashboardScreen(),
          '/customer-invoices': (_) => const CustomerInvoicesAdminScreen(),
          '/reports': (_) => const ReportsScreen(),
          '/treasury': (_) => const TreasuryScreen(),
          '/requests': (_) => const RequestsScreen(),
          '/clothing-requests': (_) => const RequestsScreen(storeType: AppConstants.storeClothing),
          '/discounts': (_) => const DiscountsScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/users': (ctx) {
            final args = ModalRoute.of(ctx)?.settings.arguments;
            return UsersScreen(initialRole: args is String ? args : null);
          },
          '/departments': (_) => const DepartmentsManagementScreen(),
          '/projects': (_) => const ProjectsScreen(),
          '/price-lists': (_) => const PriceListsScreen(),
          '/payment-tracking': (_) => const PaymentTrackingScreen(),
          '/chat': (_) => const ChatListScreen(),
          '/partner-chat': (_) => const PartnerChatScreen(),
          '/notifications': (_) => const NotificationHistoryScreen(),
          '/send-notification': (_) => const SendNotificationScreen(),
          '/suppliers': (_) => const SuppliersScreen(),
          '/supplier-comparison': (_) => const SupplierComparisonScreen(),
          '/price-sheet': (_) => const PriceSheetScreen(),
          '/audit-log': (_) => const AuditLogScreen(),
          '/electrical-pricing': (_) => const ElectricalPricingScreen(),
          '/installment-contract': (ctx) {
            final args = ModalRoute.of(ctx)?.settings.arguments;
            Installment? inst;
            String? customerName, customerPhone, customerAddress;
            if (args is Installment) {
              inst = args;
            } else if (args is Map<String, dynamic>) {
              try { inst = Installment.fromMap(args); } catch (_) {}
              customerName = args['customer_name'] as String?;
              customerPhone = args['customer_phone'] as String?;
            }
            return InstallmentContractScreen(
              installment: inst,
              customerName: customerName,
              customerPhone: customerPhone,
              customerAddress: customerAddress,
            );
          },
        },
      ),
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _routeRestored = false;
  bool _wasViewingAsCustomer = false;
  bool _wasAuthenticated = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Feature 2: restore last route once after auto-login
    if (auth.isInitialized &&
        auth.isAuthenticated &&
        auth.lastRoute != null &&
        !_routeRestored &&
        !auth.needsQuickAccess) {
      _routeRestored = true;
      final routeToRestore = auth.lastRoute!;
      auth.clearLastRoute();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final routes = ModalRoute.of(context);
          if (routes?.settings.name != routeToRestore) {
            Navigator.of(context).pushNamed(routeToRestore);
          }
        }
      });
    }

    // Logout fix: when auth transitions from authenticated → unauthenticated,
    // pop all stacked routes so the login screen appears cleanly.
    if (!auth.isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } else if (auth.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
    }

    // Fix 6: When entering customer view, pop all stacked routes so the
    // customer home shows cleanly without admin screens underneath.
    if (auth.isViewingAsCustomer && !_wasViewingAsCustomer) {
      _wasViewingAsCustomer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } else if (!auth.isViewingAsCustomer && _wasViewingAsCustomer) {
      _wasViewingAsCustomer = false;
    }

    // Must check viewingAsCustomer FIRST before state switch
    if (auth.isViewingAsCustomer) {
      final customer = auth.currentCustomer;
      if (customer?.storeType == AppConstants.storeInstallment) {
        return const InstallmentCustomerHome();
      }
      return const ElectricalCustomerHome();
    }

    switch (auth.state) {
      case AuthState.customer:
        // Feature 4: show quick access after fresh login for customers too
        if (auth.needsQuickAccess) return const QuickAccessScreen();
        final customer = auth.currentCustomer;
        if (customer?.storeType == AppConstants.storeInstallment) {
          return const InstallmentCustomerHome();
        }
        return const ElectricalCustomerHome();
      case AuthState.partner:
        // Feature 4: show quick access after fresh login for partners
        if (auth.needsQuickAccess) return const QuickAccessScreen();
        return const PartnerDashboard();
      case AuthState.employee:
        if (auth.needsQuickAccess) return const QuickAccessScreen();
        return const EmployeeDashboard();
      case AuthState.unauthenticated:
        return const LoginScreen();
      default:
        // admin / manager: Feature 4: show quick access screen first
        if (auth.needsQuickAccess) return const QuickAccessScreen();
        return const AdminDashboard();
    }
  }
}
