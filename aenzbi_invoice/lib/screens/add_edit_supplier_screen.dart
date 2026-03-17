import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../database/database_helper.dart';

class AddEditSupplierScreen extends StatefulWidget {
  final Supplier? supplier;
  const AddEditSupplierScreen({super.key, this.supplier});

  @override
  State<AddEditSupplierScreen> createState() => _AddEditSupplierScreenState();
}

class _AddEditSupplierScreenState extends State<AddEditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _taxIdCtrl;
  late final TextEditingController _notesCtrl;
  late String _paymentTerms;
  bool _saving = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _companyCtrl = TextEditingController(text: s?.company ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _websiteCtrl = TextEditingController(text: s?.website ?? '');
    _taxIdCtrl = TextEditingController(text: s?.taxId ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _paymentTerms = s?.paymentTerms ?? 'Net 30';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _taxIdCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now * 1000 + now.hashCode).abs().toRadixString(16).padLeft(16, '0');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final supplier = _isEditing
          ? widget.supplier!.copyWith(
              name: _nameCtrl.text.trim(),
              company: _companyCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              address: _addressCtrl.text.trim(),
              website: _websiteCtrl.text.trim(),
              taxId: _taxIdCtrl.text.trim(),
              paymentTerms: _paymentTerms,
              notes: _notesCtrl.text.trim(),
            )
          : Supplier(
              id: _generateId(),
              name: _nameCtrl.text.trim(),
              company: _companyCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              address: _addressCtrl.text.trim(),
              website: _websiteCtrl.text.trim(),
              taxId: _taxIdCtrl.text.trim(),
              paymentTerms: _paymentTerms,
              notes: _notesCtrl.text.trim(),
            );
      await DatabaseHelper.instance.saveSupplier(supplier);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Supplier' : 'Add Supplier'),
        backgroundColor: cs.inversePrimary,
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(context, 'Vendor Information'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _companyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Company / Vendor Name *',
                  prefixIcon: Icon(Icons.store_outlined),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact Person *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _websiteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  prefixIcon: Icon(Icons.language_outlined),
                  hintText: 'https://example.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, 'Financial Details'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _taxIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tax / VAT ID',
                        prefixIcon: Icon(Icons.tag_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentTerms,
                      decoration: const InputDecoration(
                        labelText: 'Payment Terms',
                        prefixIcon: Icon(Icons.schedule_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: Supplier.paymentTermsOptions
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _paymentTerms = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, 'Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, 'Notes'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Internal notes (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(
                      _isEditing ? 'Update Supplier' : 'Add Supplier'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
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
