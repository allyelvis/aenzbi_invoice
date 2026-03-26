import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/inventory_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _monthly = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getDashboardSummary();
    final monthly = await DatabaseHelper.instance.getMonthlyRevenue();
    setState(() {
      _data = data;
      _monthly = monthly;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsGrid(cs),
                  const SizedBox(height: 20),
                  _buildRevenueChart(cs),
                  const SizedBox(height: 20),
                  _buildRecentInvoices(cs),
                  const SizedBox(height: 20),
                  _buildLowStockAlerts(cs),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid(ColorScheme cs) {
    final paid = (_data['totalPaid'] ?? 0.0) as double;
    final outstanding = (_data['totalOutstanding'] ?? 0.0) as double;
    final overdue = (_data['totalOverdue'] ?? 0.0) as double;
    final invValue = (_data['totalValue'] ?? 0.0) as double;
    final customers = _data['customerCount'] ?? 0;
    final suppliers = _data['supplierCount'] ?? 0;
    final totalInvoices = _data['totalInvoices'] ?? 0;
    final lowStock = (_data['lowStockCount'] ?? 0) + (_data['outOfStockCount'] ?? 0);

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          label: 'Revenue',
          value: '\$${_compact(paid)}',
          icon: Icons.trending_up,
          color: Colors.green,
        ),
        _StatCard(
          label: 'Outstanding',
          value: '\$${_compact(outstanding)}',
          icon: Icons.pending_actions,
          color: Colors.blue,
        ),
        _StatCard(
          label: 'Overdue',
          value: '\$${_compact(overdue)}',
          icon: Icons.warning_amber,
          color: overdue > 0 ? Colors.red : cs.onSurface.withOpacity(0.4),
        ),
        _StatCard(
          label: 'Inventory',
          value: '\$${_compact(invValue)}',
          icon: Icons.inventory_2,
          color: cs.primary,
        ),
        _StatCard(
          label: 'Customers',
          value: '$customers',
          icon: Icons.people,
          color: Colors.purple,
        ),
        _StatCard(
          label: 'Suppliers',
          value: '$suppliers',
          icon: Icons.store,
          color: Colors.teal,
        ),
        _StatCard(
          label: 'Invoices',
          value: '$totalInvoices',
          icon: Icons.receipt_long,
          color: Colors.indigo,
        ),
        _StatCard(
          label: 'Low Stock',
          value: '$lowStock',
          icon: Icons.warning_outlined,
          color: lowStock > 0 ? Colors.orange : cs.onSurface.withOpacity(0.4),
        ),
      ],
    );
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(2);
  }

  Widget _buildRevenueChart(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly Revenue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: _monthly.isEmpty
                  ? Center(
                      child: Text('No data yet',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4))),
                    )
                  : _BarChart(data: _monthly, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentInvoices(ColorScheme cs) {
    final invoices =
        (_data['recentInvoices'] as List?)?.cast<Invoice>() ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Recent Invoices',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                const Spacer(),
              ],
            ),
            if (invoices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No invoices yet',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.4))),
                ),
              )
            else
              ...invoices.map((inv) => _InvoiceTile(invoice: inv, cs: cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlerts(ColorScheme cs) {
    final items =
        (_data['lowStockItems'] as List?)?.cast<InventoryItem>() ?? [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('Low Stock Alerts',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: item.isOutOfStock
                        ? cs.errorContainer
                        : Colors.orange.shade100,
                    child: Text(
                      item.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: item.isOutOfStock
                            ? cs.error
                            : Colors.orange,
                      ),
                    ),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(fontSize: 13)),
                  trailing: Text(
                    item.isOutOfStock
                        ? 'Out of stock'
                        : '${item.quantity} left',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isOutOfStock ? cs.error : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bar Chart ───────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final Color color;

  const _BarChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal = data
        .map((d) => (d['revenue'] as double))
        .fold<double>(0, math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((d) {
        final revenue = d['revenue'] as double;
        final month = d['month'] as DateTime;
        final ratio = maxVal > 0 ? revenue / maxVal : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (revenue > 0)
                  Text(
                    revenue >= 1000
                        ? '\$${(revenue / 1000).toStringAsFixed(1)}k'
                        : '\$${revenue.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 9, color: color),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  height: math.max(4, 110 * ratio),
                  decoration: BoxDecoration(
                    color: revenue > 0
                        ? color
                        : color.withOpacity(0.15),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _monthLabel(month.month),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _monthLabel(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month - 1];
  }
}

// ─── Invoice Tile ─────────────────────────────────────────────────────────────

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final ColorScheme cs;

  const _InvoiceTile({required this.invoice, required this.cs});

  @override
  Widget build(BuildContext context) {
    final status = invoice.effectiveStatus;
    final statusColor = _statusColor(status, cs);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.invoiceNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(invoice.customerName,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${invoice.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
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
}
