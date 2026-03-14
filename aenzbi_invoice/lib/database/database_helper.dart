import 'dart:convert';
import '../models/inventory_item.dart';
import 'storage_backend.dart';

class DatabaseHelper {
  static const String _inventoryKey = 'inventory_items';
  static DatabaseHelper? _instance;

  DatabaseHelper._();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<void> init() async {
    await StorageBackend.init();
  }

  Future<List<InventoryItem>> getAllInventoryItems() async {
    final raw = StorageBackend.getString(_inventoryKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => InventoryItem.fromMap(e as Map))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<InventoryItem?> getInventoryItem(String id) async {
    final items = await getAllInventoryItems();
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    final items = await getAllInventoryItems();
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    await _persist(items);
  }

  Future<void> deleteInventoryItem(String id) async {
    final items = await getAllInventoryItems();
    items.removeWhere((i) => i.id == id);
    await _persist(items);
  }

  Future<List<InventoryItem>> searchInventoryItems(String query) async {
    final items = await getAllInventoryItems();
    final lower = query.toLowerCase();
    return items.where((item) {
      return item.name.toLowerCase().contains(lower) ||
          item.sku.toLowerCase().contains(lower) ||
          item.category.toLowerCase().contains(lower) ||
          item.description.toLowerCase().contains(lower);
    }).toList();
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    final items = await getAllInventoryItems();
    return items.where((item) => item.isLowStock).toList();
  }

  Future<Map<String, dynamic>> getInventorySummary() async {
    final items = await getAllInventoryItems();
    double totalValue = 0;
    int lowStockCount = 0;
    int outOfStockCount = 0;
    for (final item in items) {
      totalValue += item.totalValue;
      if (item.isOutOfStock) {
        outOfStockCount++;
      } else if (item.isLowStock) {
        lowStockCount++;
      }
    }
    return {
      'totalItems': items.length,
      'totalValue': totalValue,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
    };
  }

  Future<void> _persist(List<InventoryItem> items) async {
    final encoded = jsonEncode(items.map((i) => i.toMap()).toList());
    StorageBackend.setString(_inventoryKey, encoded);
  }
}
