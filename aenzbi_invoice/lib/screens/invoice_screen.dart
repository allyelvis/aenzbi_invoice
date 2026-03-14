import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import 'add_edit_invoice_screen.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  List<Invoice> _all = [];
  List<Invoice> _filtered = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  InvoiceStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final invoices = await DatabaseHelper.instance.getAllInvoices();
    final summary = await DatabaseHelper.instance.getInvoiceSummary();
    setState(() {
      _all = invoices;
      _summary = summary;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    if (_statusFilter == null) {
      _filtered = List.from(_all);
    } else {
      _filtered = _all
          .where((i) => i.effectiveStatus == _statusFilter)
          .toList();
    }
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditInvoiceScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _navigateToEdit(Invoice invoice) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditInvoiceScreen(invoice: invoice)),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text('Delete ${invoice.invoiceNumber}? This cannot be undone.'),
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
      await DatabaseHelper.instance.deleteInvoice(invoice.id);
      _load();
    }
  }

  Future<void> _markAs(Invoice invoice, InvoiceStatus status) async {
    await DatabaseHelper.instance.saveInvoice(invoice.copyWith(status: status));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoices (${_all.length})'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryBar(cs),
                _buildFilterChips(cs),
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
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
    );
  }

  Widget _buildSummaryBar(ColorScheme cs) {
    final paid = (_summary['totalPaid'] ?? 0.0) as double;
    final outstanding = (_summary['totalOutstanding'] ?? 0.0) as double;
    final overdue = (_summary['totalOverdue'] ?? 0.0) as double;

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
          _summaryTile(cs, Icons.check_circle_outline, '\$${paid.toStringAsFixed(2)}', 'Paid', Colors.green),
          _vDivider(),
          _summaryTile(cs, Icons.pending_outlined, '\$${outstanding.toStringAsFixed(2)}', 'Pending', Colors.blue),
          _vDivider(),
          _summaryTile(cs, Icons.warning_outlined, '\$${overdue.toStringAsFixed(2)}', 'Overdue', overdue > 0 ? cs.error : null),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(height: 30, width: 1, color: Colors.black12);

  Widget _summaryTile(ColorScheme cs, IconData icon, String value,
      String label, Color? color) {
    final c = color ?? cs.onPrimaryContainer;
    return Column(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: c)),
        Text(label,
            style: TextStyle(fontSize: 10, color: c.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildFilterChips(ColorScheme cs) {
    final filters = <InvoiceStatus?>[
      null, InvoiceStatus.draft, InvoiceStatus.sent,
      InvoiceStatus.paid, InvoiceStatus.overdue,
    ];
    final labels = ['All', 'Draft', 'Sent', 'Paid', 'Overdue'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = _statusFilter == filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (_) => setState(() {
                _statusFilter = filters[i];
                _applyFilter();
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCard(Invoice invoice, ColorScheme cs) {
    final status = invoice.effectiveStatus;
    final statusColor = _statusColor(status, cs);
    final isOverdue = status == InvoiceStatus.overdue;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _navigateToEdit(invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invoice.invoiceNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(invoice.customerName,
                            style: TextStyle(
                                color: cs.onSurface.withOpacity(0.7),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${invoice.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(invoice.dueDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? cs.error
                          : cs.onSurface.withOpacity(0.6),
                      fontWeight:
                          isOverdue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onSelected: (v) {
                      if (v == 'edit') _navigateToEdit(invoice);
                      if (v == 'mark_sent') _markAs(invoice, InvoiceStatus.sent);
                      if (v == 'mark_paid') _markAs(invoice, InvoiceStatus.paid);
                      if (v == 'mark_draft') _markAs(invoice, InvoiceStatus.draft);
                      if (v == 'delete') _delete(invoice);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (status != InvoiceStatus.sent)
                        const PopupMenuItem(value: 'mark_sent', child: Text('Mark as Sent')),
                      if (status != InvoiceStatus.paid)
                        const PopupMenuItem(value: 'mark_paid', child: Text('Mark as Paid')),
                      if (status != InvoiceStatus.draft)
                        const PopupMenuItem(value: 'mark_draft', child: Text('Revert to Draft')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(InvoiceStatus status, ColorScheme cs) {
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.overdue:
        return cs.error;
      case InvoiceStatus.sent:
        return Colors.blue;
      case InvoiceStatus.draft:
        return cs.onSurface.withOpacity(0.5);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 72, color: cs.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _statusFilter != null
                ? 'No ${_statusFilter!.label.toLowerCase()} invoices'
                : 'No invoices yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                ),
          ),
          if (_statusFilter == null) ...[
            const SizedBox(height: 8),
            Text('Tap + New Invoice to get started',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.4))),
          ],
        ],
      ),
    );
  }
}
