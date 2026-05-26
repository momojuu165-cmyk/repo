bool _parseBool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return defaultValue;
}

class Customer {
  final int? id;
  final String name;
  final String? fullName;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? homeAddress;
  final String? workAddress;
  final String? address;
  final String customerType;
  final String customerStatus;
  final String priceType;
  final int? groupId;
  final double balance;
  final int points;
  final String? loginCode;
  final String storeType;
  final bool isActive;
  final bool isApproved;
  final String createdAt;

  Customer({
    this.id,
    required this.name,
    this.fullName,
    this.phone,
    this.whatsapp,
    this.email,
    this.homeAddress,
    this.workAddress,
    this.address,
    this.customerType = 'regular',
    this.customerStatus = 'regular',
    this.priceType = 'retail',
    this.groupId,
    this.balance = 0.0,
    this.points = 0,
    this.loginCode,
    this.storeType = 'electrical',
    this.isActive = true,
    this.isApproved = false,
    required this.createdAt,
  });

  bool get isVip => customerStatus == 'vip';
  bool get isBlacklisted => customerStatus == 'blacklist';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'full_name': fullName,
        'phone': phone,
        'whatsapp': whatsapp,
        'email': email,
        'home_address': homeAddress,
        'work_address': workAddress,
        'address': address,
        'customer_type': customerType,
        'customer_status': customerStatus,
        'price_type': priceType,
        'group_id': groupId,
        'balance': balance,
        'points': points,
        'login_code': loginCode,
        'store_type': storeType,
        'is_active': isActive,
        'is_approved': isApproved,
        'created_at': createdAt,
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as int?,
        name: m['name'] as String,
        fullName: m['full_name'] as String?,
        phone: m['phone'] as String?,
        whatsapp: m['whatsapp'] as String?,
        email: m['email'] as String?,
        homeAddress: m['home_address'] as String?,
        workAddress: m['work_address'] as String?,
        address: m['address'] as String?,
        customerType: m['customer_type'] as String? ?? 'regular',
        customerStatus: m['customer_status'] as String? ?? 'regular',
        priceType: m['price_type'] as String? ?? 'retail',
        groupId: m['group_id'] as int?,
        balance: (m['balance'] as num? ?? 0).toDouble(),
        points: m['points'] as int? ?? 0,
        loginCode: m['login_code'] as String?,
        storeType: m['store_type'] as String? ?? 'electrical',
        isActive: _parseBool(m['is_active'], defaultValue: true),
        isApproved: _parseBool(m['is_approved']),
        createdAt: m['created_at'] as String,
      );

  Customer copyWith({
    int? id,
    String? name,
    String? fullName,
    String? phone,
    String? whatsapp,
    String? email,
    String? homeAddress,
    String? workAddress,
    String? address,
    String? customerType,
    String? customerStatus,
    String? priceType,
    int? groupId,
    double? balance,
    int? points,
    String? loginCode,
    String? storeType,
    bool? isActive,
    bool? isApproved,
    String? createdAt,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        whatsapp: whatsapp ?? this.whatsapp,
        email: email ?? this.email,
        homeAddress: homeAddress ?? this.homeAddress,
        workAddress: workAddress ?? this.workAddress,
        address: address ?? this.address,
        customerType: customerType ?? this.customerType,
        customerStatus: customerStatus ?? this.customerStatus,
        priceType: priceType ?? this.priceType,
        groupId: groupId ?? this.groupId,
        balance: balance ?? this.balance,
        points: points ?? this.points,
        loginCode: loginCode ?? this.loginCode,
        storeType: storeType ?? this.storeType,
        isActive: isActive ?? this.isActive,
        isApproved: isApproved ?? this.isApproved,
        createdAt: createdAt ?? this.createdAt,
      );
}
