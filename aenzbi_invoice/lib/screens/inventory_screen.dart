import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import '../models/supplier.dart';
import '../database/database_helper.dart';
import 'add_edit_item_screen.dart';

enum _SortOption { name, priceLow, priceHigh, stockLow, stockHigh, value }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  List<InventoryItem> _filtered = [];
  Map<String, dynamic> _summary = {};
  Map<String, Supplier> _supplierMap = {};
  bool _loading = true;
  String _searchQuery = '';
  String? _categoryFilter;
  String? _supplierFilter;
  _SortOption _sortOption = _SortOption.name;
  List<String> _categories = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final items = await DatabaseHelper.instance.getAllInventoryItems();
      final summary = await DatabaseHelper.instance.getInventorySummary();
      final suppliers = await DatabaseHelper.instance.getAllSuppliers();
      final supplierMap = {for (final s in suppliers) s.id: s};
      final cats = items
          .map((i) => i.category)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _items = items;
        _categories = cats;
        _summary = summary;
        _supplierMap = supplierMap;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    var result = List<InventoryItem>.from(_items);
    if (_searchQuery.isNotEmpty) {
      final lower = _searchQuery.toLowerCase();
      result = result
          .where((item) =>
              item.name.toLowerCase().contains(lower) ||
              item.sku.toLowerCase().contains(lower) ||
              item.category.toLowerCase().contains(lower) ||
              item.description.toLowerCase().contains(lower) ||
              (_supplierMap[item.supplierId]
                          ?.displayName
                          .toLowerCase()
                          .contains(lower) ??
                      false))
          .toList();
    }
    if (_categoryFilter != null) {
      result = result.where((i) => i.category == _categoryFilter).toList();
    }
    if (_supplierFilter != null) {
      result =
          result.where((i) => i.supplierId == _supplierFilter).toList();
    }
    switch (_sortOption) {
      case _SortOption.name:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortOption.priceLow:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SortOption.priceHigh:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortOption.stockLow:
        result.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case _SortOption.stockHigh:
        result.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case _SortOption.value:
        result.sort((a, b) => b.totalValue.compareTo(a.totalValue));
        break;
    }
    _filtered = result;
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
    );
    if (result == true) _loadData();
  }

  Future<void> _navigateToEdit(InventoryItem item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteInventoryItem(item.id);
      _loadData();
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sort By',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ..._SortOption.values.map((opt) => RadioListTile<_SortOption>(
                value: opt,
                groupValue: _sortOption,
                title: Text(_sortLabel(opt)),
                onChanged: (v) {
                  setState(() { _sortOption = v!; _applyFilter(); });
                  Navigator.pop(ctx);
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _sortLabel(_SortOption opt) {
    switch (opt) {
      case _SortOption.name: return 'Name (A–Z)';
      case _SortOption.priceLow: return 'Price (low to high)';
      case _SortOption.priceHigh: return 'Price (high to low)';
      case _SortOption.stockLow: return 'Stock (low to high)';
      case _SortOption.stockHigh: return 'Stock (high to low)';
      case _SortOption.value: return 'Total Value (high to low)';
    }
  }

  // Suppliers that have at least one item
  List<Supplier> get _linkedSuppliers {
    final ids = _items
        .where((i) => i.supplierId.isNotEmpty)
        .map((i) => i.supplierId)
        .toSet();
    return ids
        .map((id) => _supplierMap[id])
        .whereType<Supplier>()
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory (${_items.length})'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortSheet,
            tooltip: 'Sort',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryBar(cs),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() { _searchQuery = v; _applyFilter(); }),
                    decoration: InputDecoration(
                      hintText: 'Search by name, SKU, supplier…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(
                                    () { _searchQuery = ''; _applyFilter(); });
                              })
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                if (_categories.isNotEmpty || _linkedSuppliers.isNotEmpty)
                  _buildFilterChips(cs),
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState(cs)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _buildItemCard(_filtered[i], cs),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme cs) {
    final suppliers = _linkedSuppliers;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _categoryFilter == null && _supplierFilter == null,
            onSelected: (_) => setState(() {
              _categoryFilter = null;
              _supplierFilter = null;
              _applyFilter();
            }),
          ),
          ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: _categoryFilter == cat,
                  onSelected: (_) => setState(() {
                    _categoryFilter = _categoryFilter == cat ? null : cat;
                    _supplierFilter = null;
                    _applyFilter();
                  }),
                ),
              )),
          if (suppliers.isNotEmpty)
            ...suppliers.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.store_outlined, size: 14),
                    label: Text(s.displayName),
                    selected: _supplierFilter == s.id,
                    onSelected: (_) => setState(() {
                      _supplierFilter =
                          _supplierFilter == s.id ? null : s.id;
                      _categoryFilter = null;
                      _applyFilter();
                    }),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(ColorScheme cs) {
    final total = _summary['totalItems'] ?? 0;
    final value = (_summary['totalValue'] ?? 0.0) as double;
    final low = _summary['lowStockCount'] ?? 0;
    final out = _summary['outOfStockCount'] ?? 0;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryTile(cs, Icons.inventory_2, '$total', 'Items'),
          _divider(),
          _summaryTile(cs, Icons.attach_money,
              '\$${_compactValue(value)}', 'Value'),
          _divider(),
          _summaryTile(cs, Icons.warning_amber, '$low', 'Low Stock',
              color: low > 0 ? Colors.orange : null),
          _divider(),
          _summaryTile(cs, Icons.remove_shopping_cart, '$out', 'Out',
              color: out > 0 ? cs.error : null),
        ],
      ),
    );
  }

  String _compactValue(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(2);
  }

  Widget _divider() =>
      Container(height: 30, width: 1, color: Colors.black12);

  Widget _summaryTile(ColorScheme cs, IconData icon, String value,
      String label, {Color? color}) {
    final c = color ?? cs.onPrimaryContainer;
    return Column(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: c)),
        Text(label,
            style: TextStyle(fontSize: 10, color: c.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildItemCard(InventoryItem item, ColorScheme cs) {
    Color stockColor = cs.onSurface;
    String stockLabel = '${item.quantity} ${item.unit}';
    if (item.isOutOfStock) {
      stockColor = cs.error;
      stockLabel = 'Out of stock';
    } else if (item.isLowStock) {
      stockColor = Colors.orange;
      stockLabel = 'Low: ${item.quantity} ${item.unit}';
    }

    final supplier = item.supplierId.isNotEmpty
        ? _supplierMap[item.supplierId]
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _navigateToEdit(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Text(
                  item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (item.sku.isNotEmpty ||
                        item.category.isNotEmpty ||
                        supplier != null)
                      Text(
                        [
                          if (item.sku.isNotEmpty) 'SKU: ${item.sku}',
                          if (item.category.isNotEmpty) item.category,
                          if (supplier != null) supplier.displayName,
                        ].join(' • '),
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.6)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(stockLabel,
                            style: TextStyle(
                                color: stockColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text('\$${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                    if (item.costPrice > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Cost: \$${item.costPrice.toStringAsFixed(2)}  '
                        'Margin: ${item.price > 0 ? (((item.price - item.costPrice) / item.price) * 100).toStringAsFixed(0) : 0}%',
                        style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _navigateToEdit(item);
                  if (v == 'delete') _deleteItem(item);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72, color: cs.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ||
                    _categoryFilter != null ||
                    _supplierFilter != null
                ? 'No items match your filters'
                : 'No inventory items yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty &&
              _categoryFilter == null &&
              _supplierFilter == null)
            Text('Tap + Add Item to get started',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.4))),
        ],
      ),
    );
  }
}
