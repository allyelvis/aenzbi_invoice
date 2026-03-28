import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quote.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../database/database_helper.dart';

class AddEditQuoteScreen extends StatefulWidget {
  final Quote? quote;
  const AddEditQuoteScreen({super.key, this.quote});
  @override State<AddEditQuoteScreen> createState() => _AddEditQuoteScreenState();
}

class _AddEditQuoteScreenState extends State<AddEditQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerNameCtrl;
  late final TextEditingController _customerEmailCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _taxCtrl;
  late DateTime _quoteDate;
  late DateTime _validUntil;
  late QuoteStatus _status;
  late List<InvoiceLineItem> _items;
  bool _saving = false;
  List<Customer> _customers = [];
  List<InventoryItem> _inventoryItems = [];

  bool get _isEditing => widget.quote != null;

  @override
  void initState() {
    super.initState();
    final q = widget.quote;
    _customerNameCtrl = TextEditingController(text: q?.customerName ?? '');
    _customerEmailCtrl = TextEditingController(text: q?.customerEmail ?? '');
    _notesCtrl = TextEditingController(text: q?.notes ?? '');
    _taxCtrl = TextEditingController(
        text: q != null ? q.taxRate.toStringAsFixed(1) : '0.0');
    _quoteDate = q?.quoteDate ?? DateTime.now();
    _validUntil = q?.validUntil ??
        DateTime.now().add(const Duration(days: 30));
    _status = q?.status ?? QuoteStatus.draft;
    _items = q != null ? List.from(q.items) : [];
    _loadRelated();
  }

  Future<void> _loadRelated() async {
    final customers = await DatabaseHelper.instance.getAllCustomers();
    final items = await DatabaseHelper.instance.getAllInventoryItems();
    if (mounted) setState(() { _customers = customers; _inventoryItems = items; });
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose(); _customerEmailCtrl.dispose();
    _notesCtrl.dispose(); _taxCtrl.dispose();
    super.dispose();
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now * 1000 + now.hashCode).abs().toRadixString(16).padLeft(16, '0');
  }

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.total);
  double get _taxRate => double.tryParse(_taxCtrl.text) ?? 0;
  double get _taxAmount => _subtotal * _taxRate / 100;
  double get _total => _subtotal + _taxAmount;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one line item')));
      return;
    }
    setState(() => _saving = true);
    try {
      String quoteNumber;
      if (_isEditing) {
        quoteNumber = widget.quote!.quoteNumber;
      } else {
        quoteNumber = await DatabaseHelper.instance.getNextQuoteNumber();
      }
      final quote = Quote(
        id: _isEditing ? widget.quote!.id : _generateId(),
        quoteNumber: quoteNumber,
        customerId: '',
        customerName: _customerNameCtrl.text.trim(),
        customerEmail: _customerEmailCtrl.text.trim(),
        items: _items,
        status: _status,
        quoteDate: _quoteDate,
        validUntil: _validUntil,
        taxRate: _taxRate,
        notes: _notesCtrl.text.trim(),
      );
      await DatabaseHelper.instance.saveQuote(quote);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving quote: $e')));
      }
    }
  }

  void _addItem() => setState(() => _items.add(InvoiceLineItem(
        id: _generateId(), description: '', quantity: 1, unitPrice: 0)));

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  void _updateItem(int index, InvoiceLineItem item) =>
      setState(() => _items[index] = item);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Quote' : 'New Quote'),
        backgroundColor: cs.inversePrimary,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20)),
              child: const Text('Save'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard(context, 'Client', [
              _customerAutocomplete(cs),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerEmailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
            ]),
            const SizedBox(height: 12),
            _sectionCard(context, 'Quote Details', [
              Row(children: [
                Expanded(child: _datePicker('Quote Date', _quoteDate,
                    (d) => setState(() => _quoteDate = d))),
                const SizedBox(width: 12),
                Expanded(child: _datePicker('Valid Until', _validUntil,
                    (d) => setState(() => _validUntil = d))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DropdownButtonFormField<QuoteStatus>(
                  value: _status,
                  decoration: const InputDecoration(
                      labelText: 'Status', border: OutlineInputBorder()),
                  items: QuoteStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _taxCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tax Rate (%)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                )),
              ]),
            ]),
            const SizedBox(height: 12),
            _buildLineItems(cs),
            const SizedBox(height: 12),
            _buildTotals(cs),
            const SizedBox(height: 12),
            _sectionCard(context, 'Notes', [
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _customerAutocomplete(ColorScheme cs) {
    return Autocomplete<Customer>(
      initialValue: TextEditingValue(text: _customerNameCtrl.text),
      optionsBuilder: (v) => v.text.isEmpty
          ? const []
          : _customers.where((c) =>
              c.name.toLowerCase().contains(v.text.toLowerCase()) ||
              c.company.toLowerCase().contains(v.text.toLowerCase())),
      displayStringForOption: (c) => c.name,
      onSelected: (c) {
        _customerNameCtrl.text = c.name;
        _customerEmailCtrl.text = c.email;
      },
      fieldViewBuilder: (context, ctrl, fn, onSubmit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctrl.text != _customerNameCtrl.text) {
            ctrl.text = _customerNameCtrl.text;
          }
        });
        return TextFormField(
          controller: ctrl,
          focusNode: fn,
          decoration: const InputDecoration(
              labelText: 'Customer Name *', border: OutlineInputBorder()),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
          onChanged: (v) => _customerNameCtrl.text = v,
        );
      },
    );
  }

  Widget _buildLineItems(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Line Items',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.tonal(
                onPressed: _addItem,
                child: const Row(children: [
                  Icon(Icons.add, size: 16), SizedBox(width: 4), Text('Add'),
                ]),
              ),
            ]),
            if (_items.isNotEmpty) ...[
              const Divider(height: 20),
              ..._items.asMap().entries.map((e) =>
                  _LineItemRow(
                    index: e.key,
                    item: e.value,
                    inventoryItems: _inventoryItems,
                    onChanged: (item) => _updateItem(e.key, item),
                    onRemove: () => _removeItem(e.key),
                  )),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No items yet. Tap Add.',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.4)))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _totalRow('Subtotal', _subtotal, cs),
          if (_taxRate > 0)
            _totalRow('Tax (${_taxRate.toStringAsFixed(1)}%)', _taxAmount, cs),
          const Divider(),
          _totalRow('Total', _total, cs, bold: true),
        ]),
      ),
    );
  }

  Widget _totalRow(String label, double amount, ColorScheme cs, {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text('\$${amount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? cs.primary : null)),
      ]),
    );

  Widget _sectionCard(BuildContext context, String title, List<Widget> children) =>
    Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ])));

  Widget _datePicker(String label, DateTime value, Function(DateTime) onPick) =>
    InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context, initialDate: value,
          firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        child: Text(
          '${value.day.toString().padLeft(2,'0')}/${value.month.toString().padLeft(2,'0')}/${value.year}',
          style: const TextStyle(fontSize: 14)),
      ),
    );
}

// ─── Line Item Row ────────────────────────────────────────────────────────────

class _LineItemRow extends StatefulWidget {
  final int index;
  final InvoiceLineItem item;
  final List<InventoryItem> inventoryItems;
  final Function(InvoiceLineItem) onChanged;
  final VoidCallback onRemove;

  const _LineItemRow({
    required this.index, required this.item,
    required this.inventoryItems, required this.onChanged,
    required this.onRemove,
  });

  @override State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.item.description);
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toStringAsFixed(0));
    _priceCtrl = TextEditingController(text: widget.item.unitPrice.toStringAsFixed(2));
  }

  @override
  void dispose() { _descCtrl.dispose(); _qtyCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }

  void _notify() {
    widget.onChanged(InvoiceLineItem(
      id: widget.item.id,
      description: _descCtrl.text,
      quantity: double.tryParse(_qtyCtrl.text) ?? 1,
      unitPrice: double.tryParse(_priceCtrl.text) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            Text('#${widget.index + 1}',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.red),
              onPressed: widget.onRemove, padding: EdgeInsets.zero,
              constraints: const BoxConstraints()),
          ]),
          Autocomplete<InventoryItem>(
            optionsBuilder: (v) => v.text.isEmpty
                ? const []
                : widget.inventoryItems.where((i) =>
                    i.name.toLowerCase().contains(v.text.toLowerCase())),
            displayStringForOption: (i) => i.name,
            onSelected: (i) {
              _descCtrl.text = i.name;
              _priceCtrl.text = i.price.toStringAsFixed(2);
              _notify();
            },
            fieldViewBuilder: (context, ctrl, fn, _) {
              if (ctrl.text.isEmpty && _descCtrl.text.isNotEmpty) ctrl.text = _descCtrl.text;
              return TextFormField(
                controller: ctrl, focusNode: fn,
                decoration: const InputDecoration(labelText: 'Description *',
                    border: OutlineInputBorder(), isDense: true),
                onChanged: (v) { _descCtrl.text = v; _notify(); },
              );
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 2, child: TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(labelText: 'Qty',
                  border: OutlineInputBorder(), isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (_) => _notify(),
            )),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: 'Unit Price',
                  border: OutlineInputBorder(), isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (_) => _notify(),
            )),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total', style: TextStyle(fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                Text('\$${((double.tryParse(_qtyCtrl.text) ?? 1) * (double.tryParse(_priceCtrl.text) ?? 0)).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            )),
          ]),
        ]),
      ),
    );
  }
}
