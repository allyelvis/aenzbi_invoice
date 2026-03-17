import 'dart:convert';
import '../models/inventory_item.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/supplier.dart';
import 'storage_backend.dart';

class DatabaseHelper {
  static const String _inventoryKey = 'inventory_items';
  static const String _customersKey = 'customers';
  static const String _invoicesKey = 'invoices';
  static const String _invoiceCounterKey = 'invoice_counter';
  static const String _suppliersKey = 'suppliers';
  static DatabaseHelper? _instance;

  DatabaseHelper._();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<void> init() async {
    await StorageBackend.init();
  }

  // ─── Inventory ───────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getAllInventoryItems() async {
    final raw = StorageBackend.getString(_inventoryKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => InventoryItem.fromMap(e as Map)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    final items = await getAllInventoryItems();
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) items[idx] = item; else items.add(item);
    StorageBackend.setString(_inventoryKey,
        jsonEncode(items.map((i) => i.toMap()).toList()));
  }

  Future<void> deleteInventoryItem(String id) async {
    final items = await getAllInventoryItems();
    items.removeWhere((i) => i.id == id);
    StorageBackend.setString(_inventoryKey,
        jsonEncode(items.map((i) => i.toMap()).toList()));
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
    final raw = StorageBackend.getString(_customersKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Customer.fromMap(e as Map)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Customer?> getCustomer(String id) async {
    final customers = await getAllCustomers();
    try { return customers.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }

  Future<void> saveCustomer(Customer customer) async {
    final customers = await getAllCustomers();
    final idx = customers.indexWhere((c) => c.id == customer.id);
    if (idx >= 0) customers[idx] = customer; else customers.add(customer);
    StorageBackend.setString(_customersKey,
        jsonEncode(customers.map((c) => c.toMap()).toList()));
  }

  Future<void> deleteCustomer(String id) async {
    final customers = await getAllCustomers();
    customers.removeWhere((c) => c.id == id);
    StorageBackend.setString(_customersKey,
        jsonEncode(customers.map((c) => c.toMap()).toList()));
  }

  // ─── Suppliers ───────────────────────────────────────────────────────────

  Future<List<Supplier>> getAllSuppliers() async {
    final raw = StorageBackend.getString(_suppliersKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Supplier.fromMap(e as Map)).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  Future<Supplier?> getSupplier(String id) async {
    final suppliers = await getAllSuppliers();
    try { return suppliers.firstWhere((s) => s.id == id); } catch (_) { return null; }
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final suppliers = await getAllSuppliers();
    final idx = suppliers.indexWhere((s) => s.id == supplier.id);
    if (idx >= 0) suppliers[idx] = supplier; else suppliers.add(supplier);
    StorageBackend.setString(_suppliersKey,
        jsonEncode(suppliers.map((s) => s.toMap()).toList()));
  }

  Future<void> deleteSupplier(String id) async {
    final suppliers = await getAllSuppliers();
    suppliers.removeWhere((s) => s.id == id);
    StorageBackend.setString(_suppliersKey,
        jsonEncode(suppliers.map((s) => s.toMap()).toList()));
  }

  Future<List<InventoryItem>> getItemsBySupplier(String supplierId) async {
    final items = await getAllInventoryItems();
    return items.where((i) => i.supplierId == supplierId).toList();
  }

  // ─── Invoices ────────────────────────────────────────────────────────────

  Future<List<Invoice>> getAllInvoices() async {
    final raw = StorageBackend.getString(_invoicesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Invoice.fromMap(e as Map)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveInvoice(Invoice invoice) async {
    final invoices = await getAllInvoices();
    final idx = invoices.indexWhere((i) => i.id == invoice.id);
    if (idx >= 0) invoices[idx] = invoice; else invoices.add(invoice);
    StorageBackend.setString(_invoicesKey,
        jsonEncode(invoices.map((i) => i.toMap()).toList()));
  }

  Future<void> deleteInvoice(String id) async {
    final invoices = await getAllInvoices();
    invoices.removeWhere((i) => i.id == id);
    StorageBackend.setString(_invoicesKey,
        jsonEncode(invoices.map((i) => i.toMap()).toList()));
  }

  Future<String> getNextInvoiceNumber() async {
    final raw = StorageBackend.getString(_invoiceCounterKey);
    int counter = raw != null ? (int.tryParse(raw) ?? 0) : 0;
    counter++;
    StorageBackend.setString(_invoiceCounterKey, counter.toString());
    final year = DateTime.now().year;
    return 'INV-$year-${counter.toString().padLeft(4, '0')}';
  }

  Future<Map<String, dynamic>> getInvoiceSummary() async {
    final invoices = await getAllInvoices();
    double totalPaid = 0, totalOutstanding = 0, totalOverdue = 0;
    int paidCount = 0, outstandingCount = 0, overdueCount = 0, draftCount = 0;
    for (final inv in invoices) {
      final effective = inv.effectiveStatus;
      if (effective == InvoiceStatus.paid) {
        totalPaid += inv.total;
        paidCount++;
      } else if (effective == InvoiceStatus.overdue) {
        totalOverdue += inv.total;
        overdueCount++;
      } else if (effective == InvoiceStatus.sent) {
        totalOutstanding += inv.total;
        outstandingCount++;
      } else {
        draftCount++;
      }
    }
    return {
      'totalPaid': totalPaid,
      'totalOutstanding': totalOutstanding,
      'totalOverdue': totalOverdue,
      'paidCount': paidCount,
      'outstandingCount': outstandingCount,
      'overdueCount': overdueCount,
      'draftCount': draftCount,
      'totalInvoices': invoices.length,
    };
  }

  Future<List<Map<String, dynamic>>> getMonthlyRevenue({int months = 6}) async {
    final invoices = await getAllInvoices();
    final now = DateTime.now();
    return List.generate(months, (i) {
      final month = DateTime(now.year, now.month - (months - 1 - i), 1);
      final paid = invoices.where((inv) =>
          inv.effectiveStatus == InvoiceStatus.paid &&
          inv.invoiceDate.year == month.year &&
          inv.invoiceDate.month == month.month);
      return {
        'month': month,
        'revenue': paid.fold<double>(0, (sum, inv) => sum + inv.total),
      };
    });
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final invSummary = await getInventorySummary();
    final invSumm = await getInvoiceSummary();
    final customers = await getAllCustomers();
    final suppliers = await getAllSuppliers();
    final recentInvoices = (await getAllInvoices()).take(5).toList();
    final lowStock = (await getAllInventoryItems())
        .where((i) => i.isLowStock)
        .toList();
    return {
      ...invSummary,
      ...invSumm,
      'customerCount': customers.length,
      'supplierCount': suppliers.length,
      'recentInvoices': recentInvoices,
      'lowStockItems': lowStock,
    };
  }
}
