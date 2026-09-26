import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/inventory_item.dart';
import '../models/invoice.dart';
import '../services/currency_service.dart';
import 'add_edit_invoice_screen.dart';
import 'add_edit_item_screen.dart';

class ModernDashboardScreen extends StatefulWidget {
  const ModernDashboardScreen({super.key});

  @override
  State<ModernDashboardScreen> createState() => _ModernDashboardScreenState();
}

class _ModernDashboardScreenState extends State<ModernDashboardScreen> {
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _monthly = [];
  bool _loading = true;
  String _period = 'This month';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getDashboardSummary(),
        DatabaseHelper.instance.getMonthlyRevenue(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as Map<String, dynamic>;
        _monthly = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FB),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: const Color(0xFF159574),
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1050;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 28, wide ? 32 : 20, 36),
                    children: [
                      _buildHeader(context, wide),
                      const SizedBox(height: 26),
                      _buildKpis(wide),
                      const SizedBox(height: 22),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _buildRevenueCard()),
                            const SizedBox(width: 20),
                            Expanded(flex: 4, child: _buildQuickActions()),
                          ],
                        )
                      else ...[
                        _buildRevenueCard(),
                        const SizedBox(height: 20),
                        _buildQuickActions(),
                      ],
                      const SizedBox(height: 22),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _buildRecentInvoices()),
                            const SizedBox(width: 20),
                            Expanded(flex: 4, child: _buildLowStock()),
                          ],
                        )
                      else ...[
                        _buildRecentInvoices(),
                        const SizedBox(height: 20),
                        _buildLowStock(),
                      ],
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, bool wide) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting, Amani',
                  style: const TextStyle(
                      color: Color(0xFF1D3047),
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('Here is what is happening across your business today.',
                  style: TextStyle(color: Color(0xFF7C8B9B), fontSize: 13)),
            ],
          ),
        ),
        if (wide) ...[
          _buildPeriodPicker(),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _newInvoice,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New invoice'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF159574),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9))),
          ),
        ],
      ],
    );
  }

  Widget _buildPeriodPicker() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE2E8EE))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _period,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Color(0xFF8190A2)),
          style: const TextStyle(
              color: Color(0xFF3D4E62),
              fontSize: 12,
              fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'Today', child: Text('Today')),
            DropdownMenuItem(value: 'This week', child: Text('This week')),
            DropdownMenuItem(value: 'This month', child: Text('This month')),
            DropdownMenuItem(value: 'This quarter', child: Text('This quarter')),
            DropdownMenuItem(value: 'This year', child: Text('This year')),
          ],
          onChanged: (value) => setState(() => _period = value ?? _period),
        ),
      ),
    );
  }

  Widget _buildKpis(bool wide) {
    final cur = CurrencyService.instance;
    final cards = [
      _KpiData('Revenue collected', cur.compact(_number('totalPaid')),
          'Paid invoices', Icons.trending_up_rounded, const Color(0xFF159574), '+12.8%'),
      _KpiData('Outstanding', cur.compact(_number('totalOutstanding')),
          'Awaiting payment', Icons.schedule_rounded, const Color(0xFF3F78C5), '+4.2%'),
      _KpiData('Inventory value', cur.compact(_number('totalValue')),
          '${_number('totalItems').toInt()} products', Icons.inventory_2_outlined, const Color(0xFF8A62C8), 'Healthy'),
      _KpiData('Overdue', cur.compact(_number('totalOverdue')),
          '${_number('totalInvoices').toInt()} invoices total', Icons.warning_amber_rounded,
          const Color(0xFFD88931), _number('totalOverdue') > 0 ? 'Review' : 'Clear'),
    ];
    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 142,
      ),
      itemBuilder: (_, index) => _KpiCard(data: cards[index]),
    );
  }

  double _number(String key) {
    final value = _data[key];
    return value is num ? value.toDouble() : 0;
  }

  Widget _buildRevenueCard() {
    final cur = CurrencyService.instance;
    final max = _monthly.isEmpty
        ? 0.0
        : _monthly
            .map((entry) => (entry['revenue'] as num).toDouble())
            .fold<double>(0, math.max);
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Revenue overview',
                          style: TextStyle(
                              color: Color(0xFF21344B),
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('Paid invoice revenue over the last 12 months',
                          style: TextStyle(
                              color: Color(0xFF8A98A8), fontSize: 11)),
                    ],
                  ),
                ),
                Text(cur.compact(_number('totalPaid')),
                    style: const TextStyle(
                        color: Color(0xFF159574),
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 190,
              child: _monthly.isEmpty
                  ? _EmptyChart()
                  : _RevenueBars(data: _monthly, max: max),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _ActionData('Create invoice', Icons.receipt_long_outlined, const Color(0xFF159574), _newInvoice),
      _ActionData('Add product', Icons.add_box_outlined, const Color(0xFF3F78C5), _addProduct),
      _ActionData('Receive stock', Icons.move_to_inbox_outlined, const Color(0xFF8A62C8), () => _showComingSoon('Receive stock')),
      _ActionData('Record payment', Icons.payments_outlined, const Color(0xFFD88931), () => _showComingSoon('Record payment')),
    ];
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick actions',
                style: TextStyle(
                    color: Color(0xFF21344B),
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Common tasks, one click away',
                style: TextStyle(color: Color(0xFF8A98A8), fontSize: 11)),
            const SizedBox(height: 15),
            ...actions.map((action) => _ActionTile(data: action)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentInvoices() {
    final invoices =
        (_data['recentInvoices'] as List?)?.whereType<Invoice>().toList() ?? [];
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Recent invoices',
                      style: TextStyle(
                          color: Color(0xFF21344B),
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => _showComingSoon('Invoices'),
                  child: const Text('View all',
                      style: TextStyle(
                          color: Color(0xFF159574),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: _EmptyBlock(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices yet',
                    subtitle: 'Create your first invoice to see activity here.'),
              )
            else
              _InvoiceTable(invoices: invoices),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStock() {
    final items = (_data['lowStockItems'] as List?)
            ?.whereType<InventoryItem>()
            .toList() ??
        [];
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Stock watch',
                      style: TextStyle(
                          color: Color(0xFF21344B),
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF3DE),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('${items.length} alerts',
                      style: const TextStyle(
                          color: Color(0xFFC47A18),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: _EmptyBlock(
                    icon: Icons.inventory_2_outlined,
                    title: 'All stock levels look good',
                    subtitle: 'Low-stock alerts will appear here.'),
              )
            else
              ...items.take(4).map((item) => _StockRow(item: item)),
          ],
        ),
      ),
    );
  }

  Future<void> _newInvoice() async {
    final result = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const AddEditInvoiceScreen()));
    if (result == true) _load();
  }

  Future<void> _addProduct() async {
    final result = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const AddEditItemScreen()));
    if (result == true) _load();
  }

  void _showComingSoon(String module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$module workspace is ready for your next workflow.'),
          behavior: SnackBarBehavior.floating),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final String trend;

  const _KpiData(
      this.title, this.value, this.caption, this.icon, this.color, this.trend);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                      color: data.color.withOpacity(.11),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(data.icon, color: data.color, size: 18),
                ),
                const Spacer(),
                Text(data.trend,
                    style: TextStyle(
                        color: data.trend == 'Review'
                            ? const Color(0xFFD88931)
                            : const Color(0xFF159574),
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            Text(data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF21344B),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4)),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(data.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF627287),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text('· ${data.caption}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF9AA7B6), fontSize: 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EBF0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x071A3148), blurRadius: 16, offset: Offset(0, 5))
        ],
      ),
      child: child,
    );
  }
}

class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionData(this.label, this.icon, this.color, this.onTap);
}

class _ActionTile extends StatelessWidget {
  final _ActionData data;
  const _ActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: data.onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                      color: data.color.withOpacity(.11),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(data.icon, color: data.color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(data.label,
                        style: const TextStyle(
                            color: Color(0xFF415269),
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF9BA8B7), size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.stacked_line_chart_rounded,
            color: const Color(0xFF159574).withOpacity(.25), size: 34),
        const SizedBox(height: 8),
        const Text('Paid revenue will appear after your first payment',
            style: TextStyle(color: Color(0xFF95A1B0), fontSize: 11)),
      ],
    );
  }
}

class _RevenueBars extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double max;
  const _RevenueBars({required this.data, required this.max});

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyService.instance;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((entry) {
        final value = (entry['revenue'] as num).toDouble();
        final month = entry['month'] as DateTime;
        final ratio = max > 0 ? value / max : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (value > 0)
                  Text(cur.compact(value),
                      style: const TextStyle(
                          color: Color(0xFF159574),
                          fontSize: 8,
                          fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  height: math.max(5, 128 * ratio),
                  decoration: BoxDecoration(
                    color: value > 0
                        ? const Color(0xFF46C7A7)
                        : const Color(0xFFE4F5F0),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(5)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_month(month.month),
                    style: const TextStyle(
                        color: Color(0xFF8A98A8),
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _month(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[month - 1];
  }
}

class _InvoiceTable extends StatelessWidget {
  final List<Invoice> invoices;
  const _InvoiceTable({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyService.instance;
    return Column(
      children: [
        const Divider(color: Color(0xFFEAEFF3)),
        ...invoices.take(5).map((invoice) {
          final status = invoice.effectiveStatus;
          final color = _statusColor(status);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFEAF6F2),
                  child: Text(
                    invoice.customerName.isEmpty
                        ? '?'
                        : invoice.customerName[0].toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF159574),
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice.invoiceNumber,
                          style: const TextStyle(
                              color: Color(0xFF33465C),
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(invoice.customerName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF8A98A8), fontSize: 10)),
                    ],
                  ),
                ),
                Text(cur.format(invoice.total),
                    style: const TextStyle(
                        color: Color(0xFF33465C),
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                      color: color.withOpacity(.1),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(status.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _statusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const Color(0xFF159574);
      case InvoiceStatus.overdue:
        return const Color(0xFFD65E57);
      case InvoiceStatus.sent:
        return const Color(0xFF3F78C5);
      case InvoiceStatus.draft:
        return const Color(0xFF8A98A8);
    }
  }
}

class _StockRow extends StatelessWidget {
  final InventoryItem item;
  const _StockRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isOutOfStock
        ? const Color(0xFFD65E57)
        : const Color(0xFFD88931);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.inventory_2_outlined, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF415269),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(item.sku.isEmpty ? item.category : item.sku,
                    style: const TextStyle(
                        color: Color(0xFF99A5B2), fontSize: 9)),
              ],
            ),
          ),
          Text(item.isOutOfStock ? 'Out of stock' : '${item.quantity} left',
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyBlock(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: const Color(0xFFB6C1CC)),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF68788B),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFA0ACB9), fontSize: 10)),
      ],
    );
  }
}