import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/quote.dart';
import '../models/app_settings.dart';
import '../services/currency_service.dart';
import '../services/print_service.dart';
import 'add_edit_quote_screen.dart';

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});
  @override State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  List<Quote> _all = [];
  List<Quote> _filtered = [];
  bool _loading = true;
  QuoteStatus? _statusFilter;
  AppSettings _settings = const AppSettings();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      DatabaseHelper.instance.getAllQuotes(),
      DatabaseHelper.instance.getSettings(),
    ]);
    setState(() {
      _all = results[0] as List<Quote>;
      _settings = results[1] as AppSettings;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    _filtered = _statusFilter == null
        ? List.from(_all)
        : _all.where((q) => q.status == _statusFilter).toList();
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const AddEditQuoteScreen()));
    if (result == true) _load();
  }

  Future<void> _navigateToEdit(Quote quote) async {
    final result = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => AddEditQuoteScreen(quote: quote)));
    if (result == true) _load();
  }

  Future<void> _delete(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quote'),
        content: Text('Delete ${quote.quoteNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteQuote(quote.id);
      _load();
    }
  }

  Future<void> _convert(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Invoice'),
        content: Text(
            'Convert ${quote.quoteNumber} to a new invoice? The quote will be marked as converted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await DatabaseHelper.instance.convertQuoteToInvoice(quote.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Converted to Invoice ${result['invoiceNumber']}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _markAs(Quote quote, QuoteStatus status) async {
    await DatabaseHelper.instance.saveQuote(quote.copyWith(status: status));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Quotes & Estimates (${_all.length})'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildSummaryBar(cs),
              _buildFilterChips(cs),
              Expanded(
                child: _filtered.isEmpty
                    ? _emptyState(cs)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _buildCard(_filtered[i], cs),
                      ),
              ),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add),
        label: const Text('New Quote'),
      ),
    );
  }

  Widget _buildSummaryBar(ColorScheme cs) {
    final cur = CurrencyService.instance;
    final total = _all.fold<double>(0, (s, q) => s + q.total);
    final accepted = _all.where((q) => q.status == QuoteStatus.accepted).length;
    final pending = _all.where((q) =>
        q.status == QuoteStatus.draft || q.status == QuoteStatus.sent).length;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _stat(cs, cur.compact(total), 'Total Value', Colors.indigo),
        _vDiv(),
        _stat(cs, '$accepted', 'Accepted', Colors.green),
        _vDiv(),
        _stat(cs, '$pending', 'Pending', Colors.orange),
      ]),
    );
  }

  Widget _vDiv() => Container(height: 30, width: 1, color: Colors.black12);
  Widget _stat(ColorScheme cs, String val, String label, Color color) =>
    Column(children: [
      Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
    ]);

  Widget _buildFilterChips(ColorScheme cs) {
    final filters = <QuoteStatus?>[null, ...QuoteStatus.values];
    final labels = ['All', ...QuoteStatus.values.map((s) => s.label)];
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

  Widget _buildCard(Quote quote, ColorScheme cs) {
    final cur = CurrencyService.instance;
    final sc = _statusColor(quote.status, cs);
    final expiring = quote.status == QuoteStatus.sent &&
        quote.daysUntilExpiry >= 0 && quote.daysUntilExpiry <= 7;
    final expired = quote.isExpired;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _navigateToEdit(quote),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(quote.quoteNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (expiring) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text('Expires in ${quote.daysUntilExpiry}d',
                            style: const TextStyle(fontSize: 10, color: Colors.orange,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (expired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Expired',
                            style: TextStyle(fontSize: 10, color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(quote.customerName,
                      style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13)),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(cur.format(quote.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sc.withOpacity(0.3))),
                  child: Text(quote.status.label,
                      style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12,
                  color: cs.onSurface.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text('Valid until: ${_fmt(quote.validUntil)}',
                  style: TextStyle(fontSize: 12,
                      color: expired ? cs.error : cs.onSurface.withOpacity(0.6),
                      fontWeight: expired ? FontWeight.w600 : FontWeight.normal)),
              const Spacer(),
              // Convert button for eligible quotes
              if (quote.status == QuoteStatus.accepted ||
                  quote.status == QuoteStatus.draft ||
                  quote.status == QuoteStatus.sent)
                Tooltip(
                  message: 'Convert to Invoice',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _convert(quote),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(children: [
                        Icon(Icons.transform, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 3),
                        Text('Invoice', style: TextStyle(
                            fontSize: 11, color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onSelected: (v) {
                  if (v == 'edit') _navigateToEdit(quote);
                  if (v == 'print') PrintService.printQuote(quote, _settings);
                  if (v == 'convert') _convert(quote);
                  if (v == 'accept') _markAs(quote, QuoteStatus.accepted);
                  if (v == 'send') _markAs(quote, QuoteStatus.sent);
                  if (v == 'reject') _markAs(quote, QuoteStatus.rejected);
                  if (v == 'delete') _delete(quote);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined, size: 18), title: Text('Edit'))),
                  const PopupMenuItem(value: 'convert', child: ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.transform, size: 18, color: Colors.green),
                    title: Text('Convert to Invoice'))),
                  const PopupMenuItem(value: 'print', child: ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.print_outlined, size: 18),
                    title: Text('Print / Export PDF'))),
                  const PopupMenuDivider(),
                  if (quote.status != QuoteStatus.sent)
                    const PopupMenuItem(value: 'send', child: Text('Mark as Sent')),
                  if (quote.status != QuoteStatus.accepted)
                    const PopupMenuItem(value: 'accept', child: Text('Mark as Accepted')),
                  if (quote.status != QuoteStatus.rejected)
                    const PopupMenuItem(value: 'reject', child: Text('Mark as Rejected')),
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

  Color _statusColor(QuoteStatus s, ColorScheme cs) {
    switch (s) {
      case QuoteStatus.accepted: return Colors.green;
      case QuoteStatus.rejected: return cs.error;
      case QuoteStatus.sent: return Colors.blue;
      case QuoteStatus.converted: return Colors.purple;
      case QuoteStatus.draft: return cs.onSurface.withOpacity(0.5);
    }
  }

  String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  Widget _emptyState(ColorScheme cs) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.description_outlined, size: 72, color: cs.onSurface.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text(_statusFilter != null
          ? 'No ${_statusFilter!.label.toLowerCase()} quotes'
          : 'No quotes yet',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: cs.onSurface.withOpacity(0.5))),
      if (_statusFilter == null) ...[
        const SizedBox(height: 8),
        Text('Tap + New Quote to create an estimate',
            style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.4))),
      ],
    ]),
  );
}
