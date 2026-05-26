class PriceList {
  final int? id;
  final String name;
  final String? companyName;
  final bool isFree;
  final double discountRate;

  PriceList({
    this.id,
    required this.name,
    this.companyName,
    this.isFree = true,
    this.discountRate = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'company_name': companyName,
        'is_free': isFree ? 1 : 0,
        'discount_rate': discountRate,
      };

  factory PriceList.fromMap(Map<String, dynamic> m) => PriceList(
        id: m['id'] as int?,
        name: m['name'] as String,
        companyName: m['company_name'] as String?,
        isFree: (m['is_free'] as int? ?? 1) == 1,
        discountRate: (m['discount_rate'] as num? ?? 0).toDouble(),
      );
}

class PriceListItem {
  final int? id;
  final int priceListId;
  final int itemId;
  final double customPrice;

  PriceListItem({
    this.id,
    required this.priceListId,
    required this.itemId,
    required this.customPrice,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'price_list_id': priceListId,
        'item_id': itemId,
        'custom_price': customPrice,
      };

  factory PriceListItem.fromMap(Map<String, dynamic> m) => PriceListItem(
        id: m['id'] as int?,
        priceListId: m['price_list_id'] as int,
        itemId: m['item_id'] as int,
        customPrice: (m['custom_price'] as num).toDouble(),
      );
}
