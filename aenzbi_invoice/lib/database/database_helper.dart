import '../models/inventory_item.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/supplier.dart';
import '../models/purchase_order.dart';
import '../models/app_settings.dart';
import '../api/api_client.dart';
import '../services/currency_service.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  DatabaseHelper._();
  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<void> init() async {
    try {
      final settings = await getSettings();
      CurrencyService.instance.update(settings);
    } catch (_) {}
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = (now * 1000 + now.hashCode).abs();
    return rand.toRadixString(16).padLeft(16, '0');
  }

  // ─── Inventory ───────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getAllInventoryItems() async {
    final list = await ApiClient.get('/inventory') as List<dynamic>;
    return list.map((e) => InventoryItem.fromMap(e as Map)).toList();
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    await ApiClient.post('/inventory', item.toMap());
  }

  Future<void> deleteInventoryItem(String id) async {
    await ApiClient.delete('/inventory/$id');
  }

  Future<Map<String, dynamic>> getInventorySummary() async {
    final items = await getAllInventoryItems();
    double totalValue = 0;
    int lowStockCount = 0, outOfStockCount = 0;
    for (final item in items) {
      totalValue += item.totalValue;
      if (item.isOutOfStock) outOfStockCount++;
      else if (item.isLowStock) lowStockCount++;
    }
    return {
      'totalItems': items.length,
      'totalValue': totalValue,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
    };
  }

  // ─── Customers ───────────────────────────────────────────────────────────

  Future<List<Customer>> getAllCustomers() async {
    final list = await ApiClient.get('/customers') as List<dynamic>;
    return list.map((e) => Customer.fromMap(e as Map)).toList();
  }

  Future<Customer?> getCustomer(String id) async {
    final customers = await getAllCustomers();
    try { return customers.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }

  Future<void> saveCustomer(Customer customer) async {
    await ApiClient.post('/customers', customer.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    await ApiClient.delete('/customers/$id');
  }

  // ─── Suppliers ───────────────────────────────────────────────────────────

  Future<List<Supplier>> getAllSuppliers() async {
    final list = await ApiClient.get('/suppliers') as List<dynamic>;
    return list.map((e) => Supplier.fromMap(e as Map)).toList();
  }

  Future<Supplier?> getSupplier(String id) async {
    final suppliers = await getAllSuppliers();
    try { return suppliers.firstWhere((s) => s.id == id); } catch (_) { return null; }
  }

  Future<void> saveSupplier(Supplier supplier) async {
    await ApiClient.post('/suppliers', supplier.toMap());
  }

  Future<void> deleteSupplier(String id) async {
    await ApiClient.delete('/suppliers/$id');
  }

  Future<List<InventoryItem>> getItemsBySupplier(String supplierId) async {
    final items = await getAllInventoryItems();
    return items.where((i) => i.supplierId == supplierId).toList();
  }

  // ─── Invoices ────────────────────────────────────────────────────────────

  Future<List<Invoice>> getAllInvoices() async {
    final list = await ApiClient.get('/invoices') as List<dynamic>;
    return list.map((e) => Invoice.fromMap(e as Map)).toList();
  }

  Future<String> getNextInvoiceNumber() async {
    final res = await ApiClient.get('/invoices/next-number') as Map<dynamic, dynamic>;
    return res['number'] as String;
  }

  Future<void> saveInvoice(Invoice invoice) async {
    await ApiClient.post('/invoices', invoice.toMap());
  }

  Future<void> deleteInvoice(String id) async {
    await ApiClient.delete('/invoices/$id');
  }

  Future<Map<String, dynamic>> getInvoiceSummary() async {
    final res = await ApiClient.get('/invoices/summary') as Map<dynamic, dynamic>;
    return {
      'totalPaid': (res['totalPaid'] as num?)?.toDouble() ?? 0.0,
      'totalOutstanding': (res['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
      'totalOverdue': (res['totalOverdue'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ─── Purchase Orders ──────────────────────────────────────────────────────

  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    final list = await ApiClient.get('/purchases') as List<dynamic>;
    return list.map((e) => PurchaseOrder.fromMap(e as Map)).toList();
  }

  Future<String> getNextPONumber() async {
    final res = await ApiClient.get('/purchases/next-number') as Map<dynamic, dynamic>;
    return res['number'] as String;
  }

  Future<void> savePurchaseOrder(PurchaseOrder po) async {
    await ApiClient.post('/purchases', po.toMap());
  }

  Future<void> deletePurchaseOrder(String id) async {
    await ApiClient.delete('/purchases/$id');
  }

  // ─── Settings ────────────────────────────────────────────────────────────

  Future<AppSettings> getSettings() async {
    final res = await ApiClient.get('/settings') as Map<dynamic, dynamic>;
    final map = res.map((k, v) => MapEntry(k.toString(), v.toString()));
    return AppSettings.fromSettingsMap(map);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final map = settings.toSettingsMap();
    await ApiClient.post('/settings', map.map((k, v) => MapEntry(k, v as dynamic)));
    CurrencyService.instance.update(settings);
  }

  // ─── Dashboard ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final res = await ApiClient.get('/dashboard') as Map<dynamic, dynamic>;
    final recent = (res['recentInvoices'] as List<dynamic>? ?? [])
        .map((e) => Invoice.fromMap(e as Map))
        .toList();
    final lowStock = (res['lowStockItems'] as List<dynamic>? ?? [])
        .map((e) => InventoryItem.fromMap(e as Map))
        .toList();
    return {
      'totalPaid': (res['totalPaid'] as num?)?.toDouble() ?? 0.0,
      'totalOutstanding': (res['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
      'totalOverdue': (res['totalOverdue'] as num?)?.toDouble() ?? 0.0,
      'totalValue': (res['totalValue'] as num?)?.toDouble() ?? 0.0,
      'customerCount': (res['customerCount'] as num?)?.toInt() ?? 0,
      'supplierCount': (res['supplierCount'] as num?)?.toInt() ?? 0,
      'totalInvoices': (res['totalInvoices'] as num?)?.toInt() ?? 0,
      'totalPurchaseOrders': (res['totalPurchaseOrders'] as num?)?.toInt() ?? 0,
      'lowStockCount': (res['lowStockCount'] as num?)?.toInt() ?? 0,
      'outOfStockCount': (res['outOfStockCount'] as num?)?.toInt() ?? 0,
      'recentInvoices': recent,
      'lowStockItems': lowStock,
    };
  }

  Future<List<Map<String, dynamic>>> getMonthlyRevenue() async {
    final list = await ApiClient.get('/dashboard/monthly') as List<dynamic>;
    return list.map((e) {
      final m = e as Map<dynamic, dynamic>;
      return {
        'month': DateTime.parse(m['month'] as String),
        'revenue': (m['revenue'] as num).toDouble(),
      };
    }).toList();
  }
}
