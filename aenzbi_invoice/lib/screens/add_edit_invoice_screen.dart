import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../database/database_helper.dart';

class AddEditInvoiceScreen extends StatefulWidget {
  final Invoice? invoice;
  const AddEditInvoiceScreen({super.key, this.invoice});

  @override
  State<AddEditInvoiceScreen> createState() => _AddEditInvoiceScreenState();
}

class _AddEditInvoiceScreenState extends State<AddEditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerNameCtrl;
  late final TextEditingController _customerEmailCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _taxCtrl;
  late DateTime _invoiceDate;
  late DateTime _dueDate;
  late InvoiceStatus _status;
  late List<InvoiceLineItem> _items;
  bool _saving = false;
  List<Customer> _customers = [];
  List<InventoryItem> _inventoryItems = [];

  bool get _isEditing => widget.invoice != null;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    _customerNameCtrl = TextEditingController(text: inv?.customerName ?? '');
    _customerEmailCtrl = TextEditingController(text: inv?.customerEmail ?? '');
    _notesCtrl = TextEditingController(text: inv?.notes ?? '');
    _taxCtrl = TextEditingController(
        text: inv != null ? inv.taxRate.toStringAsFixed(1) : '0.0');
    _invoiceDate = inv?.invoiceDate ?? DateTime.now();
    _dueDate = inv?.dueDate ?? DateTime.now().add(const Duration(days: 30));
    _status = inv?.status ?? InvoiceStatus.draft;
    _items = inv != null ? List.from(inv.items) : [];
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
      final Invoice invoice;
      if (_isEditing) {
        invoice = widget.invoice!.copyWith(
          customerName: _customerNameCtrl.text.trim(),
          customerEmail: _customerEmailCtrl.text.trim(),
          items: _items,
          status: _status,
          invoiceDate: _invoiceDate,
          dueDate: _dueDate,
          notes: _notesCtrl.text.trim(),
          taxRate: _taxRate,
        );
      } else {
        final number = await DatabaseHelper.instance.getNextInvoiceNumber();
        invoice = Invoice(
          id: _generateId(),
          invoiceNumber: number,
          customerName: _customerNameCtrl.text.trim(),
          customerEmail: _customerEmailCtrl.text.trim(),
          items: _items,
          status: _status,
          invoiceDate: _invoiceDate,
          dueDate: _dueDate,
          notes: _notesCtrl.text.trim(),
          taxRate: _taxRate,
        );
      }
      await DatabaseHelper.instance.saveInvoice(invoice);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addLineItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LineItemSheet(
        inventoryItems: _inventoryItems,
        onAdd: (item) {
          setState(() => _items.add(item));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _editLineItem(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LineItemSheet(
        existing: _items[index],
        inventoryItems: _inventoryItems,
        onAdd: (item) {
          setState(() => _items[index] = item);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _selectCustomer() async {
    if (_customers.isEmpty) return;
    final selected = await showDialog<Customer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Customer'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _customers.length,
            itemBuilder: (_, i) => ListTile(
              leading: CircleAvatar(
                child: Text(_customers[i].initials,
                    style: const TextStyle(fontSize: 12)),
              ),
              title: Text(_customers[i].name),
              subtitle: _customers[i].company.isNotEmpty
                  ? Text(_customers[i].company)
                  : null,
              onTap: () => Navigator.pop(ctx, _customers[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        _customerNameCtrl.text = selected.name;
        _customerEmailCtrl.text = selected.email;
      });
    }
  }

  Future<void> _pickDate(bool isDue) async {
    final initial = isDue ? _dueDate : _invoiceDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => isDue ? _dueDate = picked : _invoiceDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Invoice' : 'New Invoice'),
        backgroundColor: cs.inversePrimary,
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel(context, 'Customer'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                ),
                if (_customers.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: _selectCustomer,
                    icon: const Icon(Icons.people_outline),
                    tooltip: 'Pick from contacts',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'Invoice Details'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _DateField(
                  label: 'Invoice Date',
                  date: _invoiceDate,
                  onTap: () => _pickDate(false),
                )),
                const SizedBox(width: 12),
                Expanded(child: _DateField(
                  label: 'Due Date',
                  date: _dueDate,
                  onTap: () => _pickDate(true),
                )),
              ],
            ),
            const SizedBox(height: 12),
            _StatusDropdown(
              value: _status,
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _sectionLabel(context, 'Line Items'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addLineItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('No items yet. Tap Add Item.',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                onReorder: (oldIdx, newIdx) {
                  if (newIdx > oldIdx) newIdx--;
                  setState(() {
                    final item = _items.removeAt(oldIdx);
                    _items.insert(newIdx, item);
                  });
                },
                itemBuilder: (_, i) => _LineItemTile(
                  key: ValueKey(i),
                  item: _items[i],
                  index: i,
                  cs: cs,
                  onEdit: () => _editLineItem(i),
                  onDelete: () => setState(() => _items.removeAt(i)),
                ),
              ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'Tax & Notes'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _taxCtrl,
              decoration: const InputDecoration(
                labelText: 'Tax Rate (%)',
                prefixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _buildTotals(cs),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Update Invoice' : 'Create Invoice'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', _subtotal, cs),
          if (_taxRate > 0)
            _totalRow('Tax (${_taxRate.toStringAsFixed(1)}%)',
                _taxAmount, cs),
          const Divider(),
          _totalRow('Total', _total, cs, bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, ColorScheme cs,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
          Text('\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 18 : 14,
                  color: bold ? cs.primary : null)),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateField(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          border: const OutlineInputBorder(),
        ),
        child: Text('${date.day}/${date.month}/${date.year}',
            style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final InvoiceStatus value;
  final ValueChanged<InvoiceStatus?> onChanged;
  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<InvoiceStatus>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Status',
        prefixIcon: Icon(Icons.flag_outlined),
        border: OutlineInputBorder(),
      ),
      items: InvoiceStatus.values.map((s) {
        return DropdownMenuItem(value: s, child: Text(s.label));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _LineItemTile extends StatelessWidget {
  final InvoiceLineItem item;
  final int index;
  final ColorScheme cs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LineItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.cs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: Colors.grey),
        ),
        title: Text(item.description,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(
            '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\$${item.total.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    fontSize: 14)),
            const SizedBox(width: 4),
            IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
            IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline,
                    size: 18, color: cs.error),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ],
        ),
      ),
    );
  }
}

class _LineItemSheet extends StatefulWidget {
  final InvoiceLineItem? existing;
  final List<InventoryItem> inventoryItems;
  final ValueChanged<InvoiceLineItem> onAdd;

  const _LineItemSheet({
    this.existing,
    required this.inventoryItems,
    required this.onAdd,
  });

  @override
  State<_LineItemSheet> createState() => _LineItemSheetState();
}

class _LineItemSheetState extends State<_LineItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _qtyCtrl = TextEditingController(
        text: widget.existing != null
            ? widget.existing!.quantity.toString()
            : '1');
    _priceCtrl = TextEditingController(
        text: widget.existing != null
            ? widget.existing!.unitPrice.toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _descCtrl.dispose(); _qtyCtrl.dispose(); _priceCtrl.dispose();
    super.dispose();
  }

  void _pickFromInventory() async {
    if (widget.inventoryItems.isEmpty) return;
    final picked = await showDialog<InventoryItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select from Inventory'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.inventoryItems.length,
            itemBuilder: (_, i) {
              final item = widget.inventoryItems[i];
              return ListTile(
                title: Text(item.name),
                subtitle: Text('\$${item.price.toStringAsFixed(2)} per ${item.unit}'),
                trailing: Text('${item.quantity} in stock',
                    style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, item),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _descCtrl.text = picked.name;
        _priceCtrl.text = picked.price.toStringAsFixed(2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNew = widget.existing == null;
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isNew ? 'Add Line Item' : 'Edit Line Item',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const Spacer(),
                if (widget.inventoryItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: _pickFromInventory,
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('From Inventory'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d*'))
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price *',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.onAdd(InvoiceLineItem(
                    description: _descCtrl.text.trim(),
                    quantity: double.parse(_qtyCtrl.text),
                    unitPrice: double.parse(_priceCtrl.text),
                  ));
                },
                child: Text(isNew ? 'Add' : 'Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
