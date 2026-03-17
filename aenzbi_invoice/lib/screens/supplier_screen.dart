import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/supplier.dart';
import '../models/inventory_item.dart';
import 'add_edit_supplier_screen.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  List<Supplier> _suppliers = [];
  List<Supplier> _filtered = [];
  bool _loading = true;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    setState(() {
      _suppliers = suppliers;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _filtered = List.from(_suppliers);
    } else {
      final lower = _query.toLowerCase();
      _filtered = _suppliers.where((s) {
        return s.name.toLowerCase().contains(lower) ||
            s.company.toLowerCase().contains(lower) ||
            s.email.toLowerCase().contains(lower) ||
            s.phone.contains(lower) ||
            s.website.toLowerCase().contains(lower);
      }).toList();
    }
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditSupplierScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _navigateToEdit(Supplier supplier) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AddEditSupplierScreen(supplier: supplier)),
    );
    if (result == true) _load();
  }

  Future<void> _viewDetail(Supplier supplier) async {
    final items = await DatabaseHelper.instance.getItemsBySupplier(supplier.id);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierDetailSheet(supplier: supplier, items: items),
    );
  }

  Future<void> _delete(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text(
            'Delete "${supplier.displayName}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteSupplier(supplier.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Suppliers (${_suppliers.length})'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() { _query = v; _applyFilter(); }),
                    decoration: InputDecoration(
                      hintText: 'Search suppliers…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(
                                    () { _query = ''; _applyFilter(); });
                              })
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? _emptyState(cs)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _buildCard(_filtered[i], cs),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Supplier'),
      ),
    );
  }

  Widget _buildCard(Supplier supplier, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child: Text(supplier.initials,
              style: TextStyle(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(supplier.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (supplier.contactDisplay.isNotEmpty)
              Text(supplier.contactDisplay,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.7))),
            Row(
              children: [
                _paymentChip(supplier.paymentTerms, cs),
                const SizedBox(width: 6),
                if (supplier.email.isNotEmpty) ...[
                  Icon(Icons.email_outlined,
                      size: 11, color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(supplier.email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.6))),
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: supplier.contactDisplay.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'view') _viewDetail(supplier);
            if (v == 'edit') _navigateToEdit(supplier);
            if (v == 'delete') _delete(supplier);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'view', child: Text('View Details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => _viewDetail(supplier),
      ),
    );
  }

  Widget _paymentChip(String terms, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(terms,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.onTertiaryContainer)),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined,
              size: 72, color: cs.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _query.isNotEmpty ? 'No suppliers found' : 'No suppliers yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                ),
          ),
          if (_query.isEmpty) ...[
            const SizedBox(height: 8),
            Text('Tap + Add Supplier to get started',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.4))),
          ],
        ],
      ),
    );
  }
}

// ─── Detail bottom sheet ─────────────────────────────────────────────────────

class _SupplierDetailSheet extends StatelessWidget {
  final Supplier supplier;
  final List<InventoryItem> items;

  const _SupplierDetailSheet(
      {required this.supplier, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cs.secondaryContainer,
                    child: Text(supplier.initials,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: cs.onSecondaryContainer)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        if (supplier.contactDisplay.isNotEmpty)
                          Text(supplier.contactDisplay,
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _infoRow(context, Icons.local_shipping_outlined,
                  'Payment Terms', supplier.paymentTerms, cs),
              if (supplier.email.isNotEmpty)
                _infoRow(context, Icons.email_outlined,
                    'Email', supplier.email, cs),
              if (supplier.phone.isNotEmpty)
                _infoRow(context, Icons.phone_outlined,
                    'Phone', supplier.phone, cs),
              if (supplier.website.isNotEmpty)
                _infoRow(context, Icons.language_outlined,
                    'Website', supplier.website, cs),
              if (supplier.taxId.isNotEmpty)
                _infoRow(context, Icons.tag_outlined,
                    'Tax / VAT ID', supplier.taxId, cs),
              if (supplier.address.isNotEmpty)
                _infoRow(context, Icons.location_on_outlined,
                    'Address', supplier.address, cs),
              if (supplier.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Notes',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: cs.primary)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(supplier.notes,
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.8))),
                ),
              ],
              const SizedBox(height: 20),
              Text('Stocked Items (${items.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No inventory items linked to this supplier.',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.5))),
                )
              else
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 16,
                              color: cs.onSurface.withOpacity(0.5)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500))),
                          Text('${item.quantity} ${item.unit}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: item.isOutOfStock
                                      ? cs.error
                                      : item.isLowStock
                                          ? Colors.orange
                                          : cs.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label,
      String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.5))),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
