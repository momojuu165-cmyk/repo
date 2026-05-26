import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/item_group.dart';
import '../models/warehouse.dart';
import '../database/daos/item_dao.dart';

class InventoryProvider extends ChangeNotifier {
  final ItemDao _dao = ItemDao();

  List<Item> _items = [];
  List<ItemGroup> _groups = [];
  List<Warehouse> _warehouses = [];
  bool _loading = false;

  List<Item> get items => _items;
  List<ItemGroup> get groups => _groups;
  List<Warehouse> get warehouses => _warehouses;
  bool get loading => _loading;

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    _items = await _dao.getAll();
    _groups = await _dao.getAllGroups();
    _warehouses = await _dao.getAllWarehouses();
    _loading = false;
    notifyListeners();
  }

  Future<void> loadItems() async {
    _items = await _dao.getAll();
    notifyListeners();
  }

  Future<List<Item>> search(String query) => _dao.search(query);
  Future<Item?> getByBarcode(String barcode) => _dao.findByBarcode(barcode);
  Future<Item?> getById(int id) => _dao.findById(id);

  Future<int> addItem(Item item) async {
    final id = await _dao.insert(item);
    await loadItems();
    return id;
  }

  Future<void> updateItem(Item item) async {
    await _dao.update(item);
    await loadItems();
  }

  Future<void> toggleBlocked(int id, bool blocked) async {
    await _dao.toggleBlocked(id, blocked);
    await loadItems();
  }

  Future<void> adjustQuantity(int id, double delta) async {
    await _dao.updateQuantity(id, delta);
    await loadItems();
  }

  Future<int> addGroup(ItemGroup group) async {
    final id = await _dao.insertGroup(group);
    _groups = await _dao.getAllGroups();
    notifyListeners();
    return id;
  }

  Future<int> addWarehouse(Warehouse w) async {
    final id = await _dao.insertWarehouse(w);
    _warehouses = await _dao.getAllWarehouses();
    notifyListeners();
    return id;
  }

  Future<void> transferItems({
    required int fromId,
    required int toId,
    required int itemId,
    required double qty,
    int? employeeId,
    String? notes,
  }) async {
    await _dao.transferBetweenWarehouses(
      fromId: fromId,
      toId: toId,
      itemId: itemId,
      qty: qty,
      employeeId: employeeId,
      notes: notes,
    );
    await loadItems();
  }

  String groupName(int? groupId) {
    if (groupId == null) return 'عام';
    try {
      return _groups.firstWhere((g) => g.id == groupId).name;
    } catch (_) {
      return 'غير محدد';
    }
  }

  String warehouseName(int? warehouseId) {
    if (warehouseId == null) return 'غير محدد';
    try {
      return _warehouses.firstWhere((w) => w.id == warehouseId).name;
    } catch (_) {
      return 'غير محدد';
    }
  }
}
