import 'package:flutter/material.dart';
import '../models/purchase_order.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';
import '../services/currency_service.dart';
import '../services/print_service.dart';
import 'add_edit_purchase_screen.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});
  @override State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  List<PurchaseOrder> _all = [];
  List<PurchaseOrder> _filtered = [];
  bool _loading = true;
  PurchaseOrderStatus? _statusFilter;
  AppSettings _settings = const AppSettings();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await DatabaseHelper.instance.getAllPurchaseOrders();
      final settings = await DatabaseHelper.instance.getSettings();
      setState(() {
        _all = orders;
        _settings = settings;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  void _applyFilter() {
    _filtered = _statusFilter == null
        ? List.from(_all)
        : _all.where((o) => o.status == _statusFilter).toList();
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => const AddEditPurchaseScreen()));
    if (result == true) _load();
  }

  Future<void> _navigateToEdit(PurchaseOrder po) async {
    final result = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => AddEditPurchaseScreen(order: po)));
    if (result == true) _load();
  }

  Future<void> _delete(PurchaseOrder po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Order'),
        content: Text('Delete ${po.poNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deletePurchaseOrder(po.id);
      _load();
    }
  }

  Future<void> _markAs(PurchaseOrder po, PurchaseOrderStatus status) async {
    await DatabaseHelper.instance.savePurchaseOrder(po.copyWith(status: status));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = CurrencyService.instance;
    final totalOrdered = _all.fold<double>(0, (s, o) =>
      o.status == PurchaseOrderStatus.ordered ? s + o.total : s);
    final totalReceived = _all.fold<double>(0, (s, o) =>
      o.status == PurchaseOrderStatus.received ? s + o.total : s);

    return Scaffold(
      appBar: AppBar(
        title: Text('Purchases (${_all.length})'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _sumTile(cs, Icons.shopping_cart_outlined, cur.compact(totalOrdered), 'Ordered', Colors.blue),
                  Container(height: 30, width: 1, color: Colors.black12),
                  _sumTile(cs, Icons.check_circle_outline, cur.compact(totalReceived), 'Received', Colors.green),
                  Container(height: 30, width: 1, color: Colors.black12),
                  _sumTile(cs, Icons.receipt_long_outlined, '${_all.length}', 'Total POs', cs.primary),
                ]),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(children: [
                  FilterChip(label: const Text('All'), selected: _statusFilter == null,
                    onSelected: (_) => setState(() { _statusFilter = null; _applyFilter(); })),
                  ...PurchaseOrderStatus.values.map((s) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: _statusFilter == s,
                      onSelected: (_) => setState(() {
                        _statusFilter = _statusFilter == s ? null : s;
                        _applyFilter();
                      }),
                    ),
                  )),
                ]),
              ),
              Expanded(child: _filtered.isEmpty
                  ? _emptyState(cs)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildCard(_filtered[i], cs),
                    )),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add),
        label: const Text('New PO'),
      ),
    );
  }

  Widget _sumTile(ColorScheme cs, IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
    ]);
  }

  Widget _buildCard(PurchaseOrder po, ColorScheme cs) {
    final statusColor = _statusColor(po.status, cs);
    final cur = CurrencyService.instance;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _navigateToEdit(po),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(po.poNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(po.supplierName,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(cur.format(po.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(po.status.label,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: cs.onSurface.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text(_fmtDate(po.orderDate),
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
              if (po.expectedDate != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.local_shipping_outlined, size: 12, color: cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text('ETA: ${_fmtDate(po.expectedDate!)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero, iconSize: 18,
                onSelected: (v) {
                  if (v == 'edit') _navigateToEdit(po);
                  if (v == 'print') PrintService.printPurchaseOrder(po, _settings);
                  if (v == 'ordered') _markAs(po, PurchaseOrderStatus.ordered);
                  if (v == 'received') _markAs(po, PurchaseOrderStatus.received);
                  if (v == 'cancelled') _markAs(po, PurchaseOrderStatus.cancelled);
                  if (v == 'draft') _markAs(po, PurchaseOrderStatus.draft);
                  if (v == 'delete') _delete(po);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'print', child: ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.print_outlined, size: 18),
                    title: Text('Print / Export'),
                  )),
                  const PopupMenuDivider(),
                  if (po.status != PurchaseOrderStatus.ordered)
                    const PopupMenuItem(value: 'ordered', child: Text('Mark as Ordered')),
                  if (po.status != PurchaseOrderStatus.received)
                    const PopupMenuItem(value: 'received', child: Text('Mark as Received')),
                  if (po.status != PurchaseOrderStatus.draft)
                    const PopupMenuItem(value: 'draft', child: Text('Revert to Draft')),
                  if (po.status != PurchaseOrderStatus.cancelled)
                    const PopupMenuItem(value: 'cancelled', child: Text('Cancel Order')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Color _statusColor(PurchaseOrderStatus s, ColorScheme cs) {
    switch (s) {
      case PurchaseOrderStatus.ordered: return Colors.blue;
      case PurchaseOrderStatus.received: return Colors.green;
      case PurchaseOrderStatus.cancelled: return cs.error;
      case PurchaseOrderStatus.draft: return cs.onSurface.withOpacity(0.5);
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _emptyState(ColorScheme cs) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.shopping_cart_outlined, size: 72, color: cs.onSurface.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text(_statusFilter != null ? 'No ${_statusFilter!.label} orders' : 'No purchase orders yet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.5))),
      const SizedBox(height: 8),
      if (_statusFilter == null)
        Text('Tap + New PO to create your first purchase order',
            style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.4))),
    ],
  ));
}
