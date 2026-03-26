import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../api/api_client.dart';
import '../services/currency_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: cs.inversePrimary,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Sales'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory'),
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Purchases'),
            Tab(icon: Icon(Icons.summarize_outlined), text: 'Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _SalesReport(),
          _InventoryReport(),
          _PurchasesReport(),
          _SummaryReport(),
        ],
      ),
    );
  }
}

// ─── Sales Report ─────────────────────────────────────────────────────────────

class _SalesReport extends StatefulWidget {
  const _SalesReport();
  @override State<_SalesReport> createState() => _SalesReportState();
}

class _SalesReportState extends State<_SalesReport>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiClient.get('/reports/sales') as Map<dynamic, dynamic>;
      setState(() { _data = d.cast<String, dynamic>(); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorView(_error!, _load);
    final cs = Theme.of(context).colorScheme;
    final cur = CurrencyService.instance;
    final monthly = (_data!['monthly'] as List<dynamic>? ?? [])
        .cast<Map<dynamic, dynamic>>();
    final byCustomer = (_data!['byCustomer'] as List<dynamic>? ?? [])
        .cast<Map<dynamic, dynamic>>();
    final byStatus = (_data!['byStatus'] as List<dynamic>? ?? [])
        .cast<Map<dynamic, dynamic>>();

    final totalRev = monthly.fold<double>(0, (s, m) => s + (m['paid'] as num).toDouble());
    final totalInv = monthly.fold<double>(0, (s, m) => s + (m['total'] as num).toDouble());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status summary row
          _statRow(cs, [
            _StatItem('Total Invoiced', cur.format(totalInv), Icons.receipt_long, Colors.blue),
            _StatItem('Revenue Collected', cur.format(totalRev), Icons.trending_up, Colors.green),
          ]),
          const SizedBox(height: 16),
          // Monthly bar chart
          _card(context, 'Monthly Revenue (last 12 months)',
            monthly.isEmpty
                ? _empty('No invoice data yet')
                : SizedBox(height: 200, child: _RevenueBarChart(monthly: monthly)),
          ),
          const SizedBox(height: 16),
          // Status breakdown
          if (byStatus.isNotEmpty) ...[
            _card(context, 'Invoice Status Breakdown',
              _StatusBreakdown(data: byStatus, cs: cs)),
            const SizedBox(height: 16),
          ],
          // Top customers
          _card(context, 'Top Customers by Revenue',
            byCustomer.isEmpty
                ? _empty('No customer data')
                : _CustomerTable(rows: byCustomer, cs: cs),
          ),
        ],
      ),
    );
  }
}

// ─── Inventory Report ─────────────────────────────────────────────────────────

class _InventoryReport extends StatefulWidget {
  const _InventoryReport();
  @override State<_InventoryReport> createState() => _InventoryReportState();
}

class _InventoryReportState extends State<_InventoryReport>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiClient.get('/reports/inventory') as Map<dynamic, dynamic>;
      setState(() { _data = d.cast<String, dynamic>(); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorView(_error!, _load);
    final cs = Theme.of(context).colorScheme;
    final cur = CurrencyService.instance;
    final summary = _data!['summary'] as Map<dynamic, dynamic>? ?? {};
    final byCategory = (_data!['byCategory'] as List<dynamic>? ?? [])
        .cast<Map<dynamic, dynamic>>();
    final lowStock = (_data!['lowStockItems'] as List<dynamic>? ?? [])
        .cast<Map<dynamic, dynamic>>();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statRow(cs, [
            _StatItem('Total Items', '${summary['totalItems'] ?? 0}', Icons.inventory_2, cs.primary),
            _StatItem('Total Value', cur.compact((summary['totalValue'] as num?)?.toDouble() ?? 0),
                Icons.attach_money, Colors.green),
          ]),
          const SizedBox(height: 16),
          _card(context, 'Stock Value by Category',
            byCategory.isEmpty
                ? _empty('No inventory data')
                : _CategoryTable(rows: byCategory, cs: cs)),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 16),
            _card(context, 'Low & Out-of-Stock Items (${lowStock.length})',
              _LowStockTable(rows: lowStock, cs: cs)),
          ],
        ],
      ),
    );
  }
}

// ─── Purchases Report ─────────────────────────────────────────────────────────

class _PurchasesReport extends StatefulWidget {
  const _PurchasesReport();
  @override State<_PurchasesReport> createState() => _PurchasesReportState();
}

class _PurchasesReportState extends State<_PurchasesReport>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiClient.get('/reports/purchases') as Map<dynamic, dynamic>;
      setState(() { _data = d.cast<String, dynamic>(); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorView(_error!, _load);
    final cs = Theme.of(context).colorScheme;
    final cur = CurrencyService.instance;
    final bySupplier = (_data!['bySupplier'] as List<dynamic>? ?? [])
        .cast<Map<dynamic, dynamic>>();
    final byStatus = (_data!['byStatus'] as List<dynamic>? ?? [])
        .cast<Map<dynamic, dynamic>>();
    final monthly = (_data!['monthly'] as List<dynamic>? ?? [])
        .cast<Map<dynamic, dynamic>>();

    final totalOrdered = byStatus.fold<double>(
        0, (s, r) => s + (r['total'] as num).toDouble());
    final totalReceived = byStatus
        .where((r) => r['status'] == 'received')
        .fold<double>(0, (s, r) => s + (r['total'] as num).toDouble());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statRow(cs, [
            _StatItem('Total Ordered', cur.format(totalOrdered), Icons.shopping_cart, Colors.blue),
            _StatItem('Total Received', cur.format(totalReceived), Icons.check_circle_outline, Colors.green),
          ]),
          const SizedBox(height: 16),
          if (monthly.isNotEmpty) ...[
            _card(context, 'Monthly Purchase Spend',
                SizedBox(height: 200, child: _PurchaseBarChart(monthly: monthly))),
            const SizedBox(height: 16),
          ],
          if (byStatus.isNotEmpty) ...[
            _card(context, 'PO Status Breakdown',
                _POStatusBreakdown(data: byStatus, cs: cs)),
            const SizedBox(height: 16),
          ],
          _card(context, 'Spending by Supplier',
            bySupplier.isEmpty
                ? _empty('No purchase orders yet')
                : _SupplierTable(rows: bySupplier, cs: cs)),
        ],
      ),
    );
  }
}

// ─── Summary / P&L Report ────────────────────────────────────────────────────

class _SummaryReport extends StatefulWidget {
  const _SummaryReport();
  @override State<_SummaryReport> createState() => _SummaryReportState();
}

class _SummaryReportState extends State<_SummaryReport>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiClient.get('/reports/summary') as Map<dynamic, dynamic>;
      setState(() { _data = d.cast<String, dynamic>(); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorView(_error!, _load);
    final cs = Theme.of(context).colorScheme;
    final cur = CurrencyService.instance;
    final d = _data!;

    final revenue = (d['revenue'] as num?)?.toDouble() ?? 0;
    final outstanding = (d['outstanding'] as num?)?.toDouble() ?? 0;
    final overdue = (d['overdue'] as num?)?.toDouble() ?? 0;
    final ordered = (d['totalOrdered'] as num?)?.toDouble() ?? 0;
    final received = (d['totalReceived'] as num?)?.toDouble() ?? 0;
    final net = (d['netPosition'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Net position card
          Card(
            color: net >= 0 ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      net >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: net >= 0 ? Colors.green : cs.error, size: 28),
                    const SizedBox(width: 8),
                    Text('Net Position',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    cur.format(net.abs()),
                    style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold,
                      color: net >= 0 ? Colors.green.shade700 : cs.error),
                  ),
                  Text(
                    net >= 0 ? 'Revenue exceeds purchases' : 'Purchases exceed revenue',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Revenue section
          _sectionLabel(context, 'Revenue', cs.primary),
          const SizedBox(height: 8),
          _metricsGrid(cs, [
            _MetricRow('Collected Revenue', cur.format(revenue), Colors.green, Icons.check_circle_outline),
            _MetricRow('Outstanding', cur.format(outstanding), Colors.blue, Icons.pending_outlined),
            _MetricRow('Overdue', cur.format(overdue), overdue > 0 ? cs.error : Colors.grey, Icons.warning_outlined),
            _MetricRow('Total Invoices', '${d['totalInvoices'] ?? 0}', cs.primary, Icons.receipt_long),
          ]),
          const SizedBox(height: 16),
          // Purchases section
          _sectionLabel(context, 'Purchases', Colors.teal),
          const SizedBox(height: 8),
          _metricsGrid(cs, [
            _MetricRow('Total Ordered', cur.format(ordered), Colors.blue, Icons.shopping_cart_outlined),
            _MetricRow('Total Received', cur.format(received), Colors.green, Icons.local_shipping_outlined),
            _MetricRow('Pending Payables', cur.format(ordered - received), Colors.orange, Icons.pending_outlined),
            _MetricRow('Total POs', '${d['totalPOs'] ?? 0}', Colors.teal, Icons.receipt_outlined),
          ]),
          const SizedBox(height: 16),
          // Business stats
          _sectionLabel(context, 'Business', Colors.purple),
          const SizedBox(height: 8),
          _metricsGrid(cs, [
            _MetricRow('Customers', '${d['customers'] ?? 0}', Colors.purple, Icons.people_outline),
            _MetricRow('Suppliers', '${d['suppliers'] ?? 0}', Colors.teal, Icons.store_outlined),
            _MetricRow('Invoice Rate',
              d['totalInvoices'] != null && d['totalInvoices'] > 0
                ? '${((d['paidInvoices'] as num) / (d['totalInvoices'] as num) * 100).toStringAsFixed(0)}%'
                : 'N/A',
              Colors.indigo, Icons.percent),
            _MetricRow('Avg Invoice',
              d['totalInvoices'] != null && (d['totalInvoices'] as num) > 0
                ? cur.format((revenue + outstanding + overdue) / (d['totalInvoices'] as num))
                : cur.format(0),
              Colors.orange, Icons.analytics_outlined),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text, Color color) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _metricsGrid(ColorScheme cs, List<_MetricRow> rows) {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5, crossAxisSpacing: 8, mainAxisSpacing: 8,
      children: rows.map((r) => _MetricCard(metric: r)).toList(),
    );
  }
}

// ─── Chart Widgets ────────────────────────────────────────────────────────────

class _RevenueBarChart extends StatelessWidget {
  final List<Map<dynamic, dynamic>> monthly;
  const _RevenueBarChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (monthly.isEmpty) return const SizedBox.shrink();
    final maxVal = monthly
        .map((m) => (m['total'] as num).toDouble())
        .fold<double>(0, math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: monthly.map((m) {
        final total = (m['total'] as num).toDouble();
        final paid = (m['paid'] as num).toDouble();
        final date = DateTime.parse(m['month'] as String);
        final ratio = maxVal > 0 ? total / maxVal : 0.0;
        final paidRatio = total > 0 ? paid / total : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (total > 0)
                  Text(_compact(total),
                      style: TextStyle(fontSize: 8, color: cs.primary),
                      textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Stack(alignment: Alignment.bottomCenter, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    height: math.max(4.0, 140.0 * ratio),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    height: math.max(2.0, 140.0 * ratio * paidRatio),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(_monthShort(date.month),
                    style: TextStyle(fontSize: 9,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  String _monthShort(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

class _PurchaseBarChart extends StatelessWidget {
  final List<Map<dynamic, dynamic>> monthly;
  const _PurchaseBarChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (monthly.isEmpty) return const SizedBox.shrink();
    final maxVal = monthly
        .map((m) => (m['total'] as num).toDouble())
        .fold<double>(0, math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: monthly.map((m) {
        final total = (m['total'] as num).toDouble();
        final date = DateTime.parse(m['month'] as String);
        final ratio = maxVal > 0 ? total / maxVal : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (total > 0)
                  Text(_compact(total),
                      style: const TextStyle(fontSize: 8, color: Colors.teal),
                      textAlign: TextAlign.center),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  height: math.max(4.0, 140.0 * ratio),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_monthShort(date.month),
                    style: TextStyle(fontSize: 9,
                        color: cs.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  String _monthShort(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

// ─── Table Widgets ────────────────────────────────────────────────────────────

class _CustomerTable extends StatelessWidget {
  final List<Map<dynamic, dynamic>> rows;
  final ColorScheme cs;
  const _CustomerTable({required this.rows, required this.cs});

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyService.instance;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
      },
      children: [
        _headerRow(['Customer', '#', 'Invoiced', 'Paid']),
        ...rows.map((r) => TableRow(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)))),
          children: [
            _cell(r['customerName'] as String? ?? '—', bold: true),
            _cell('${r['invoiceCount'] ?? 0}'),
            _cell(cur.compact((r['totalInvoiced'] as num?)?.toDouble() ?? 0)),
            _cell(cur.compact((r['totalPaid'] as num?)?.toDouble() ?? 0),
                color: Colors.green.shade700),
          ],
        )),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
    decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 1.5))),
    children: labels.map((l) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    )).toList(),
  );

  Widget _cell(String text, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text, style: TextStyle(fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color)),
      );
}

class _CategoryTable extends StatelessWidget {
  final List<Map<dynamic, dynamic>> rows;
  final ColorScheme cs;
  const _CategoryTable({required this.rows, required this.cs});

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyService.instance;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3), 1: FlexColumnWidth(1),
        2: FlexColumnWidth(2), 3: FlexColumnWidth(1),
      },
      children: [
        _headerRow(['Category', 'Items', 'Value', 'Low']),
        ...rows.map((r) => TableRow(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)))),
          children: [
            _cell(r['category'] as String? ?? '—', bold: true),
            _cell('${r['itemCount'] ?? 0}'),
            _cell(cur.compact((r['totalValue'] as num?)?.toDouble() ?? 0)),
            _cell('${(r['outOfStock'] as num? ?? 0) + (r['lowStock'] as num? ?? 0)}',
                color: ((r['outOfStock'] as num?)?.toInt() ?? 0) > 0
                    ? cs.error : Colors.orange),
          ],
        )),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
    decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 1.5))),
    children: labels.map((l) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    )).toList(),
  );

  Widget _cell(String text, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text, style: TextStyle(fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color)),
      );
}

class _LowStockTable extends StatelessWidget {
  final List<Map<dynamic, dynamic>> rows;
  final ColorScheme cs;
  const _LowStockTable({required this.rows, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1),
      },
      children: [
        _headerRow(['Item', 'Category', 'Qty']),
        ...rows.map((r) {
          final qty = (r['quantity'] as num?)?.toInt() ?? 0;
          final isOut = qty == 0;
          return TableRow(
            decoration: BoxDecoration(
                color: isOut ? cs.errorContainer.withOpacity(0.2) : Colors.orange.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)))),
            children: [
              _cell(r['name'] as String? ?? '—', bold: true),
              _cell(r['category'] as String? ?? '—'),
              _cell(isOut ? 'OUT' : '$qty ${r['unit'] ?? ''}',
                  color: isOut ? cs.error : Colors.orange),
            ],
          );
        }),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
    decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 1.5))),
    children: labels.map((l) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    )).toList(),
  );

  Widget _cell(String text, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text, style: TextStyle(fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color)),
      );
}

class _SupplierTable extends StatelessWidget {
  final List<Map<dynamic, dynamic>> rows;
  final ColorScheme cs;
  const _SupplierTable({required this.rows, required this.cs});

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyService.instance;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3), 1: FlexColumnWidth(1),
        2: FlexColumnWidth(2), 3: FlexColumnWidth(2),
      },
      children: [
        _headerRow(['Supplier', 'POs', 'Total', 'Received']),
        ...rows.map((r) => TableRow(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)))),
          children: [
            _cell(r['supplierName'] as String? ?? '—', bold: true),
            _cell('${r['poCount'] ?? 0}'),
            _cell(cur.compact((r['totalValue'] as num?)?.toDouble() ?? 0)),
            _cell(cur.compact((r['receivedValue'] as num?)?.toDouble() ?? 0),
                color: Colors.green.shade700),
          ],
        )),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
    decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 1.5))),
    children: labels.map((l) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    )).toList(),
  );

  Widget _cell(String text, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text, style: TextStyle(fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color)),
      );
}

class _StatusBreakdown extends StatelessWidget {
  final List<Map<dynamic, dynamic>> data;
  final ColorScheme cs;
  const _StatusBreakdown({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyService.instance;
    return Row(
      children: data.map((r) {
        final status = r['status'] as String? ?? '';
        final color = _statusColor(status, cs);
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(children: [
              Text(status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text('${r['count'] ?? 0}', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: color)),
              Text(cur.compact((r['total'] as num?)?.toDouble() ?? 0),
                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Color _statusColor(String s, ColorScheme cs) {
    switch (s) {
      case 'paid': return Colors.green;
      case 'overdue': return cs.error;
      case 'sent': return Colors.blue;
      default: return cs.onSurface.withOpacity(0.5);
    }
  }
}

class _POStatusBreakdown extends StatelessWidget {
  final List<Map<dynamic, dynamic>> data;
  final ColorScheme cs;
  const _POStatusBreakdown({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyService.instance;
    return Row(
      children: data.map((r) {
        final status = r['status'] as String? ?? '';
        final color = _statusColor(status, cs);
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(children: [
              Text(status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text('${r['count'] ?? 0}', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: color)),
              Text(cur.compact((r['total'] as num?)?.toDouble() ?? 0),
                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Color _statusColor(String s, ColorScheme cs) {
    switch (s) {
      case 'received': return Colors.green;
      case 'ordered': return Colors.blue;
      case 'cancelled': return cs.error;
      default: return cs.onSurface.withOpacity(0.5);
    }
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricRow metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: metric.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, size: 16, color: metric.color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(metric.value,
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 14, color: metric.color),
                  overflow: TextOverflow.ellipsis),
              Text(metric.label,
                  style: TextStyle(fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _MetricRow {
  final String label, value;
  final Color color;
  final IconData icon;
  const _MetricRow(this.label, this.value, this.color, this.icon);
}

Widget _statRow(ColorScheme cs, List<_StatItem> items) {
  return Row(children: items.map((item) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 16, color: item.color),
              ),
            ]),
            const SizedBox(height: 8),
            Text(item.value,
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 16, color: item.color),
                overflow: TextOverflow.ellipsis),
            Text(item.label,
                style: TextStyle(fontSize: 11,
                    color: Colors.grey.shade600)),
          ],
        ),
      ),
    ),
  )).toList());
}

Widget _card(BuildContext context, String title, Widget child) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

Widget _empty(String msg) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 20),
  child: Center(child: Text(msg,
      style: const TextStyle(color: Colors.grey, fontSize: 13))),
);

Widget _errorView(String error, VoidCallback retry) => Center(
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.red),
    const SizedBox(height: 8),
    Text('Error loading data', style: const TextStyle(fontSize: 14)),
    const SizedBox(height: 4),
    Text(error, style: const TextStyle(fontSize: 11, color: Colors.grey),
        textAlign: TextAlign.center),
    const SizedBox(height: 16),
    FilledButton(onPressed: retry, child: const Text('Retry')),
  ]),
);
