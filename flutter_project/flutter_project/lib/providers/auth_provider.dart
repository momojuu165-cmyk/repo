import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/customer.dart';
import '../database/daos/user_dao.dart';
import '../database/daos/customer_dao.dart';
import '../utils/hash_helper.dart';
import '../utils/constants.dart';
import '../services/push_notification_service.dart';

enum AuthState { unauthenticated, admin, manager, partner, employee, customer }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.unauthenticated;
  User? _currentUser;
  Customer? _currentCustomer;
  bool _initialized = false;
  bool _viewingAsCustomer = false;
  User? _adminUser;
  String? _lastRoute; // Feature 2: persist last screen
  bool _pendingQuickAccess = false; // Feature 4: show quick access after login

  AuthState get state => _state;
  User? get currentUser => _currentUser;
  Customer? get currentCustomer => _currentCustomer;
  bool get isAuthenticated => _state != AuthState.unauthenticated;
  bool get isInitialized => _initialized;
  bool get isAdmin => _state == AuthState.admin && !_viewingAsCustomer;
  bool get isManager =>
      (_state == AuthState.admin || _state == AuthState.manager) &&
      !_viewingAsCustomer;
  bool get isPartner => _state == AuthState.partner && !_viewingAsCustomer;
  bool get isEmployee => _state == AuthState.employee && !_viewingAsCustomer;
  bool get isCustomer => _state == AuthState.customer || _viewingAsCustomer;
  bool get mustChangePassword => _currentUser?.mustChangePassword ?? false;
  bool get isViewingAsCustomer => _viewingAsCustomer;
  bool get usesCodeLogin =>
      _currentUser != null &&
      _currentUser!.role != AppConstants.roleAdmin &&
      _state != AuthState.unauthenticated;

  // Feature 2: last screen / route
  String? get lastRoute => _lastRoute;

  // Feature 4: quick access screen pending after fresh login
  bool get needsQuickAccess => _pendingQuickAccess;

  String get currentUserName =>
      _currentUser?.name ?? _currentCustomer?.name ?? '';
  String get currentRole =>
      _currentUser?.role ?? (_currentCustomer != null ? 'customer' : '');
  String? get currentLoginCode =>
      _currentUser?.loginCode ?? _currentCustomer?.loginCode;

  String? get departmentType => _currentUser?.departmentType;
  String? get scopedDepartmentType {
    if (isAdmin) return null;
    final dept = _currentUser?.departmentType;
    if (dept == null || dept == AppConstants.deptAll) return null;
    return dept;
  }

  String? effectiveStoreType(String? requestedStoreType) {
    if (isAdmin) {
      return requestedStoreType == AppConstants.deptAll
          ? null
          : requestedStoreType;
    }
    final scoped = scopedDepartmentType;
    if (scoped == null) return requestedStoreType == AppConstants.deptAll ? null : requestedStoreType;
    if (requestedStoreType == null || requestedStoreType == AppConstants.deptAll) {
      return scoped;
    }
    return requestedStoreType == scoped ? requestedStoreType : scoped;
  }

  bool canAccessDept(String dept) => _currentUser?.canAccessDept(dept) ?? true;
  bool get canViewPartners => _currentUser?.canViewPartners ?? false;

  bool hasPermission(String perm) => _currentUser?.hasPermission(perm) ?? false;

  /// Feature 4: Called by QuickAccessScreen once the user has tapped a shortcut.
  void markQuickAccessShown() {
    if (_pendingQuickAccess) {
      _pendingQuickAccess = false;
      notifyListeners();
    }
  }

  /// Feature 2: Consume the last route once it has been used for restoration,
  /// so subsequent builds don't try to re-navigate.
  void clearLastRoute() {
    if (_lastRoute != null) {
      _lastRoute = null;
      // No notifyListeners — purely internal state, no rebuild needed.
    }
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionType = prefs.getString('session_type');
    final sessionId = prefs.getInt('session_id');
    _lastRoute = prefs.getString('last_route');

    if (sessionType == null || sessionId == null) {
      _initialized = true;
      notifyListeners();
      return;
    }
    if (sessionType == 'user') {
      final dao = UserDao();
      final user = await dao.findById(sessionId);
      if (user != null && user.isActive) {
        _currentUser = user;
        _state = _roleToState(user.role);
        // Auto-login does NOT trigger quick access (skip it for returning sessions)
        _pendingQuickAccess = false;
      }
    } else if (sessionType == 'customer') {
      final dao = CustomerDao();
      final customer = await dao.findById(sessionId);
      if (customer != null && customer.isActive) {
        _currentCustomer = customer;
        _state = AuthState.customer;
        _pendingQuickAccess = false;
      }
    }
    _initialized = true;
    notifyListeners();
  }

  /// Feature 2: Save last navigated route for restore on re-open
  Future<void> saveLastRoute(String route) async {
    _lastRoute = route;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_route', route);
  }

  Future<String?> loginUser(String username, String password) async {
    try {
      final dao = UserDao();
      final user = await dao.findByUsername(username);
      if (user == null) {
        return 'اسم المستخدم غير موجود';
      }
      if (!user.isActive) {
        return 'الحساب موقوف، تواصل مع المدير';
      }
      if (!HashHelper.verifyPassword(password, user.passwordHash)) {
        return 'كلمة المرور غير صحيحة';
      }
      _currentUser = user;
      _currentCustomer = null;
      _viewingAsCustomer = false;
      _adminUser = null;
      _state = _roleToState(user.role);
      _pendingQuickAccess = false;
      await _saveSession('user', user.id!);
      notifyListeners();
      // Register FCM token for this user
      PushNotificationService().registerToken(userId: user.id);
      return null;
    } catch (e) {
      return 'خطأ في الاتصال بالسيرفر. تحقق من الإنترنت وأعد المحاولة';
    }
  }

  Future<String?> loginWithCode(String code, String expectedRole) async {
    try {
      print('AuthProvider.loginWithCode called with code="$code" expectedRole="$expectedRole"');
      final dao = UserDao();
      final users = await dao.findAllByLoginCode(code.trim());
      print('AuthProvider.loginWithCode: dao returned ${users.length} user(s)');
      if (users.isEmpty) {
        return 'كود الدخول غير صحيح';
      }

      final expectedRoleNormalized = expectedRole.trim().toLowerCase();
      User? user;
      if (expectedRoleNormalized.isNotEmpty) {
        User? adminUser;
        for (final candidate in users) {
          final candidateRole = candidate.role.trim().toLowerCase();
          if (candidateRole == expectedRoleNormalized) {
            user = candidate;
            break;
          }
          if (candidateRole == AppConstants.roleAdmin) {
            adminUser = candidate;
          }
        }
        user ??= adminUser;
        if (user == null) {
          return 'كود الدخول غير صحيح لهذا النوع من الحسابات';
        }
      } else {
        user = users.first;
      }

      if (!user.isActive) {
        return 'الحساب موقوف، تواصل مع المدير';
      }
      // Feature 3: check code expiry
      if (user.isCodeExpired) {
        return 'انتهت صلاحية كود الدخول (مؤقت). تواصل مع المدير للحصول على كود جديد';
      }
      _currentUser = user;
      _currentCustomer = null;
      _viewingAsCustomer = false;
      _adminUser = null;
      _state = _roleToState(user.role);
      _pendingQuickAccess = false;
      await _saveSession('user', user.id!);
      notifyListeners();
      // Register FCM token for this user
      PushNotificationService().registerToken(userId: user.id);
      return null;
    } catch (e) {
      return 'خطأ في الاتصال بالسيرفر. تحقق من الإنترنت وأعد المحاولة';
    }
  }

  Future<String?> loginCustomer(String code) async {
    try {
      print('AuthProvider.loginCustomer called with code="$code"');
      final dao = CustomerDao();
      final customer = await dao.findByLoginCode(code.trim());
      print('AuthProvider.loginCustomer: dao returned ${customer != null ? '1' : '0'}');
      if (customer == null) {
        return 'كود الدخول غير صحيح';
      }
      if (!customer.isActive) {
        return 'الحساب موقوف، تواصل مع المدير';
      }
      // Feature 12: block blacklisted customers
      if (customer.isBlacklisted) {
        return 'حسابك محظور. تواصل مع الإدارة لمزيد من المعلومات';
      }
      if (!customer.isApproved) {
        return 'لم يتم الموافقة على حسابك بعد. تواصل مع الإدارة';
      }
      _currentUser = null;
      _currentCustomer = customer;
      _viewingAsCustomer = false;
      _adminUser = null;
      _state = AuthState.customer;
      _pendingQuickAccess = false;
      await _saveSession('customer', customer.id!);
      notifyListeners();
      // Register FCM token for this customer
      PushNotificationService().registerToken(customerId: customer.id);
      return null;
    } catch (e) {
      return 'خطأ في الاتصال بالسيرفر. تحقق من الإنترنت وأعد المحاولة';
    }
  }

  Future<String?> registerCustomer({
    required String name,
    required String fullName,
    required String phone,
    required String whatsapp,
    required String email,
    required String homeAddress,
    required String workAddress,
    required String storeType,
  }) async {
    final dao = CustomerDao();
    final now = DateTime.now().toIso8601String();
    final customer = Customer(
      name: name,
      fullName: fullName,
      phone: phone,
      whatsapp: whatsapp,
      email: email,
      homeAddress: homeAddress,
      workAddress: workAddress,
      storeType: storeType,
      isApproved: false,
      createdAt: now,
    );
    await dao.insert(customer);
    return null;
  }

  void viewAsCustomer(Customer customer) {
    _adminUser = _currentUser;
    _currentCustomer = customer;
    _viewingAsCustomer = true;
    notifyListeners();
  }

  void exitCustomerView() {
    _currentUser = _adminUser;
    _currentCustomer = null;
    _viewingAsCustomer = false;
    _adminUser = null;
    _state = AuthState.admin;
    notifyListeners();
  }

  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    if (_currentUser == null) {
      return 'غير مسجل دخول';
    }
    if (!HashHelper.verifyPassword(
        currentPassword, _currentUser!.passwordHash)) {
      return 'كلمة المرور الحالية غير صحيحة';
    }
    final dao = UserDao();
    final updated = _currentUser!.copyWith(
        passwordHash: HashHelper.hashPassword(newPassword),
        mustChangePassword: false);
    await dao.update(updated);
    _currentUser = updated;
    notifyListeners();
    return null;
  }

  Future<String?> changeMyLoginCode(String newCode) async {
    if (newCode.trim().length < 4) {
      return 'الكود يجب أن يكون 4 أحرف على الأقل';
    }
    if (_currentCustomer != null) {
      final dao = CustomerDao();
      await dao.updateLoginCode(_currentCustomer!.id!, newCode.trim());
      _currentCustomer = _currentCustomer!.copyWith(loginCode: newCode.trim());
      notifyListeners();
      return null;
    } else if (_currentUser != null) {
      final dao = UserDao();
      await dao.updateLoginCode(_currentUser!.id!, newCode.trim());
      _currentUser = _currentUser!.copyWith(loginCode: newCode.trim());
      notifyListeners();
      return null;
    }
    return 'غير مسجل دخول';
  }

  Future<String?> changeName(String newName) async {
    if (newName.trim().isEmpty) {
      return 'الاسم لا يمكن أن يكون فارغاً';
    }
    if (_currentCustomer != null) {
      final dao = CustomerDao();
      final updated = _currentCustomer!.copyWith(name: newName.trim());
      await dao.update(updated);
      _currentCustomer = updated;
      notifyListeners();
      return null;
    }
    return 'غير مسجل دخول';
  }

  Future<String?> changeUsername(String newUsername, String password) async {
    if (_currentUser == null) {
      return 'غير مسجل دخول';
    }
    if (!HashHelper.verifyPassword(password, _currentUser!.passwordHash)) {
      return 'كلمة المرور غير صحيحة';
    }
    final dao = UserDao();
    final existing = await dao.findByUsername(newUsername);
    if (existing != null && existing.id != _currentUser!.id) {
      return 'اسم المستخدم مستخدم بالفعل';
    }
    final updated = _currentUser!.copyWith(username: newUsername);
    await dao.update(updated);
    _currentUser = updated;
    notifyListeners();
    return null;
  }

  /// Quick access: bypass login and go directly to admin/manager/partner dashboard.
  /// This is intentional for trusted single-device environments.
  void quickLoginAsRole(String role) {
    final fakeUser = User(
      id: 0,
      name: role == AppConstants.roleAdmin
          ? 'أدمن (وصول سريع)'
          : role == AppConstants.roleManager
              ? 'مدير (وصول سريع)'
              : 'شريك (وصول سريع)',
      username: 'quick_access',
      passwordHash: '',
      role: role,
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    );
    _currentUser = fakeUser;
    _state = _roleToState(role);
    _pendingQuickAccess = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _viewingAsCustomer = false;
    _adminUser = null;
    _currentUser = null;
    _currentCustomer = null;
    _state = AuthState.unauthenticated;
    _lastRoute = null;
    _pendingQuickAccess = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_type');
    await prefs.remove('session_id');
    await prefs.remove('last_route');
    notifyListeners();
  }

  Future<void> _saveSession(String type, int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_type', type);
    await prefs.setInt('session_id', id);
  }

  AuthState _roleToState(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return AuthState.admin;
      case AppConstants.roleManager:
        return AuthState.manager;
      case AppConstants.rolePartner:
        return AuthState.partner;
      case AppConstants.roleEmployee:
        return AuthState.employee;
      default:
        return AuthState.admin;
    }
  }
}
