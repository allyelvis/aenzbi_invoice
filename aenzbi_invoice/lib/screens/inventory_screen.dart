import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import '../database/database_helper.dart';
import 'add_edit_item_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  List<InventoryItem> _filtered = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String _searchQuery = '';
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
      setState(() {
        _items = items;
        _summary = summary;
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
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_items);
    } else {
      final lower = _searchQuery.toLowerCase();
      _filtered = _items.where((item) {
        return item.name.toLowerCase().contains(lower) ||
            item.sku.toLowerCase().contains(lower) ||
            item.category.toLowerCase().contains(lower);
      }).toList();
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilter();
    });
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
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
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
                _buildSummaryBar(colorScheme),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search by name, SKU, category…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _buildItemCard(_filtered[i], colorScheme),
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
              '\$${value.toStringAsFixed(2)}', 'Value'),
          _divider(),
          _summaryTile(
              cs,
              Icons.warning_amber,
              '$low',
              'Low Stock',
              color: low > 0 ? Colors.orange : null),
          _divider(),
          _summaryTile(
              cs,
              Icons.remove_shopping_cart,
              '$out',
              'Out',
              color: out > 0 ? cs.error : null),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 30,
        width: 1,
        color: Colors.black12,
      );

  Widget _summaryTile(ColorScheme cs, IconData icon, String value, String label,
      {Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color ?? cs.onPrimaryContainer),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color ?? cs.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: (color ?? cs.onPrimaryContainer).withOpacity(0.7),
          ),
        ),
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
            style: TextStyle(
                color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.sku.isNotEmpty || item.category.isNotEmpty)
              Text(
                [if (item.sku.isNotEmpty) 'SKU: ${item.sku}',
                  if (item.category.isNotEmpty) item.category]
                    .join(' • '),
                style: const TextStyle(fontSize: 12),
              ),
            Row(
              children: [
                Text(
                  stockLabel,
                  style: TextStyle(
                      color: stockColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '\$${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _navigateToEdit(item);
            if (v == 'delete') _deleteItem(item);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => _navigateToEdit(item),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No items match your search'
                : 'No inventory items yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              'Tap + Add Item to get started',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  ),
            ),
        ],
      ),
    );
  }
}
