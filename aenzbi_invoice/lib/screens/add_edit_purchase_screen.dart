import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../database/database_helper.dart';
import '../services/currency_service.dart';

class AddEditPurchaseScreen extends StatefulWidget {
  final PurchaseOrder? order;
  const AddEditPurchaseScreen({super.key, this.order});
  @override State<AddEditPurchaseScreen> createState() => _AddEditPurchaseScreenState();
}

class _AddEditPurchaseScreenState extends State<AddEditPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool get _isEditing => widget.order != null;

  late TextEditingController _poNumberCtrl;
  late TextEditingController _supplierNameCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _taxCtrl;
  PurchaseOrderStatus _status = PurchaseOrderStatus.draft;
  String? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  DateTime? _expectedDate;
  List<Supplier> _suppliers = [];
  List<_ItemRow> _itemRows = [_ItemRow()];

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _poNumberCtrl = TextEditingController(text: o?.poNumber ?? '');
    _supplierNameCtrl = TextEditingController(text: o?.supplierName ?? '');
    _notesCtrl = TextEditingController(text: o?.notes ?? '');
    _taxCtrl = TextEditingController(
        text: o != null && o.taxRate > 0 ? o.taxRate.toStringAsFixed(2) : '');
    _status = o?.status ?? PurchaseOrderStatus.draft;
    _selectedSupplierId = o?.supplierId;
    _orderDate = o?.orderDate ?? DateTime.now();
    _expectedDate = o?.expectedDate;
    if (o != null && o.items.isNotEmpty) {
      _itemRows = o.items.map((i) => _ItemRow.fromItem(i)).toList();
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    String poNumber = _poNumberCtrl.text;
    if (!_isEditing || poNumber.isEmpty) {
      poNumber = await DatabaseHelper.instance.getNextPONumber();
    }
    if (mounted) setState(() {
      _suppliers = suppliers;
      if (_poNumberCtrl.text.isEmpty) _poNumberCtrl.text = poNumber;
    });
  }

  @override
  void dispose() {
    for (final c in [_poNumberCtrl, _supplierNameCtrl, _notesCtrl, _taxCtrl]) c.dispose();
    for (final r in _itemRows) r.dispose();
    super.dispose();
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now * 1000 + now.hashCode).abs().toRadixString(16).padLeft(16, '0');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final items = _itemRows
        .where((r) => r.description.text.trim().isNotEmpty)
        .map((r) => PurchaseItem(
              description: r.description.text.trim(),
              quantity: double.tryParse(r.qty.text) ?? 1,
              unitCost: double.tryParse(r.cost.text) ?? 0,
            ))
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final po = _isEditing
          ? widget.order!.copyWith(
              supplierName: _supplierNameCtrl.text.trim(),
              supplierId: _selectedSupplierId,
              items: items, status: _status,
              orderDate: _orderDate, expectedDate: _expectedDate,
              notes: _notesCtrl.text.trim(),
              taxRate: double.tryParse(_taxCtrl.text) ?? 0,
            )
          : PurchaseOrder(
              id: _generateId(),
              poNumber: _poNumberCtrl.text.trim(),
              supplierName: _supplierNameCtrl.text.trim(),
              supplierId: _selectedSupplierId,
              items: items, status: _status,
              orderDate: _orderDate, expectedDate: _expectedDate,
              notes: _notesCtrl.text.trim(),
              taxRate: double.tryParse(_taxCtrl.text) ?? 0,
            );
      await DatabaseHelper.instance.savePurchaseOrder(po);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate(bool isExpected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpected ? (_expectedDate ?? DateTime.now().add(const Duration(days: 14))) : _orderDate,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isExpected) _expectedDate = picked;
        else _orderDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = CurrencyService.instance;
    final subtotal = _itemRows.fold<double>(
      0, (s, r) => s + (double.tryParse(r.qty.text) ?? 0) * (double.tryParse(r.cost.text) ?? 0));
    final tax = subtotal * (double.tryParse(_taxCtrl.text) ?? 0) / 100;
    final total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Purchase Order' : 'New Purchase Order'),
        backgroundColor: cs.inversePrimary,
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _save, tooltip: 'Save'),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // PO Number & Status
            Row(children: [
              Expanded(child: TextFormField(
                controller: _poNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'PO Number *', prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<PurchaseOrderStatus>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status', prefixIcon: Icon(Icons.flag_outlined),
                  border: OutlineInputBorder()),
                items: PurchaseOrderStatus.values.map((s) => DropdownMenuItem(
                  value: s, child: Text(s.label))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              )),
            ]),
            const SizedBox(height: 12),
            // Supplier
            DropdownButtonFormField<String?>(
              value: _selectedSupplierId,
              decoration: const InputDecoration(
                labelText: 'Supplier', prefixIcon: Icon(Icons.store_outlined),
                border: OutlineInputBorder()),
              hint: const Text('Select supplier (or type below)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— None —')),
                ..._suppliers.map((s) => DropdownMenuItem<String?>(
                  value: s.id,
                  child: Text(s.displayName, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) {
                setState(() => _selectedSupplierId = v);
                if (v != null) {
                  final sup = _suppliers.firstWhere((s) => s.id == v, orElse: () => _suppliers.first);
                  _supplierNameCtrl.text = sup.displayName;
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplierNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Supplier Name *', prefixIcon: Icon(Icons.person_outlined),
                border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            // Dates
            Row(children: [
              Expanded(child: InkWell(
                onTap: () => _pickDate(false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Order Date', prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder()),
                  child: Text(_fmtDate(_orderDate)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: InkWell(
                onTap: () => _pickDate(true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Expected Date (opt)',
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: _expectedDate != null
                        ? IconButton(icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _expectedDate = null))
                        : null,
                  ),
                  child: Text(_expectedDate != null ? _fmtDate(_expectedDate!) : 'Not set',
                      style: TextStyle(color: _expectedDate == null
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4) : null)),
                ),
              )),
            ]),
            const SizedBox(height: 20),
            // Items header
            Row(children: [
              Text('Items', style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 15, color: cs.primary)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Line'),
                onPressed: () => setState(() => _itemRows.add(_ItemRow())),
              ),
            ]),
            const SizedBox(height: 8),
            ..._itemRows.asMap().entries.map((e) => _buildItemRow(e.key, e.value, cs)),
            const SizedBox(height: 16),
            // Tax
            Row(children: [
              Expanded(child: TextFormField(
                controller: _taxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tax Rate (%)', prefixIcon: Icon(Icons.percent),
                  border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 12),
              Expanded(child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Subtotal: ${cur.format(subtotal)}',
                      style: const TextStyle(fontSize: 12)),
                  if (tax > 0) Text('Tax: ${cur.format(tax)}',
                      style: const TextStyle(fontSize: 12)),
                  Text('Total: ${cur.format(total)}',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: cs.primary, fontSize: 14)),
                ]),
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes', prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update PO' : 'Create PO'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int idx, _ItemRow row, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(flex: 4, child: TextField(
          controller: row.description,
          decoration: InputDecoration(
            labelText: 'Description',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: _itemRows.length > 1
                ? IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => setState(() { row.dispose(); _itemRows.removeAt(idx); }))
                : null,
          ),
          onChanged: (_) => setState(() {}),
        )),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: TextField(
          controller: row.qty,
          decoration: const InputDecoration(
            labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          onChanged: (_) => setState(() {}),
        )),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: TextField(
          controller: row.cost,
          decoration: const InputDecoration(
            labelText: 'Unit Cost', border: OutlineInputBorder(), isDense: true),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          onChanged: (_) => setState(() {}),
        )),
      ]),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

class _ItemRow {
  final TextEditingController description;
  final TextEditingController qty;
  final TextEditingController cost;

  _ItemRow()
      : description = TextEditingController(),
        qty = TextEditingController(text: '1'),
        cost = TextEditingController();

  _ItemRow.fromItem(PurchaseItem item)
      : description = TextEditingController(text: item.description),
        qty = TextEditingController(text: item.quantity.toStringAsFixed(
            item.quantity == item.quantity.roundToDouble() ? 0 : 2)),
        cost = TextEditingController(text: item.unitCost.toStringAsFixed(2));

  void dispose() {
    description.dispose();
    qty.dispose();
    cost.dispose();
  }
}
