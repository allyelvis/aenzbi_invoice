import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';
import '../services/currency_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  bool _saving = false;

  final _companyNameCtrl = TextEditingController();
  final _companyAddrCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _invPrefixCtrl = TextEditingController();
  final _poPrefixCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_companyNameCtrl,_companyAddrCtrl,_companyEmailCtrl,
      _companyPhoneCtrl,_invPrefixCtrl,_poPrefixCtrl,_taxCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await DatabaseHelper.instance.getSettings();
      setState(() {
        _settings = s;
        _companyNameCtrl.text = s.companyName;
        _companyAddrCtrl.text = s.companyAddress;
        _companyEmailCtrl.text = s.companyEmail;
        _companyPhoneCtrl.text = s.companyPhone;
        _invPrefixCtrl.text = s.invoicePrefix;
        _poPrefixCtrl.text = s.poPrefix;
        _taxCtrl.text = s.defaultTaxRate > 0 ? s.defaultTaxRate.toStringAsFixed(2) : '';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = _settings.copyWith(
        companyName: _companyNameCtrl.text.trim(),
        companyAddress: _companyAddrCtrl.text.trim(),
        companyEmail: _companyEmailCtrl.text.trim(),
        companyPhone: _companyPhoneCtrl.text.trim(),
        invoicePrefix: _invPrefixCtrl.text.trim().isEmpty ? 'INV' : _invPrefixCtrl.text.trim(),
        poPrefix: _poPrefixCtrl.text.trim().isEmpty ? 'PO' : _poPrefixCtrl.text.trim(),
        defaultTaxRate: double.tryParse(_taxCtrl.text) ?? 0,
      );
      await DatabaseHelper.instance.saveSettings(updated);
      setState(() { _settings = updated; _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _selectCurrency(Map<String, String> currency) async {
    final updated = _settings.copyWith(
      currencyCode: currency['code'],
      currencySymbol: currency['symbol'],
      currencyName: currency['name'],
    );
    setState(() => _settings = updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: cs.inversePrimary,
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _save, tooltip: 'Save'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader(cs, Icons.business, 'Company Information'),
                const SizedBox(height: 12),
                _field(_companyNameCtrl, 'Company Name', Icons.business_outlined),
                const SizedBox(height: 12),
                _field(_companyAddrCtrl, 'Address', Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_companyEmailCtrl, 'Email', Icons.email_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_companyPhoneCtrl, 'Phone', Icons.phone_outlined)),
                ]),
                const SizedBox(height: 24),
                _sectionHeader(cs, Icons.attach_money, 'Currency'),
                const SizedBox(height: 12),
                _CurrencyPicker(
                  selected: _settings.currencyCode,
                  onSelected: _selectCurrency,
                ),
                const SizedBox(height: 24),
                _sectionHeader(cs, Icons.receipt_long, 'Invoice & PO Settings'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_invPrefixCtrl, 'Invoice Prefix', Icons.tag,
                      hint: 'e.g. INV')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_poPrefixCtrl, 'PO Prefix', Icons.tag,
                      hint: 'e.g. PO')),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _taxCtrl,
                  decoration: InputDecoration(
                    labelText: 'Default Tax Rate (%)',
                    prefixIcon: const Icon(Icons.percent),
                    border: const OutlineInputBorder(),
                    helperText: 'Applied to new invoices and purchase orders',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Currency preview: ${CurrencyService.instance.format(1234.56)}',
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    )),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, IconData icon, String title) {
    return Row(children: [
      Icon(icon, size: 18, color: cs.primary),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary)),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, String? hint}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _CurrencyPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<Map<String, String>> onSelected;
  const _CurrencyPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencies = AppSettings.currencies;
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: currencies.any((c) => c['code'] == selected) ? selected : 'USD',
          decoration: const InputDecoration(
            labelText: 'Currency',
            prefixIcon: Icon(Icons.currency_exchange),
            border: OutlineInputBorder(),
          ),
          items: currencies.map((c) => DropdownMenuItem<String>(
            value: c['code'],
            child: Text('${c['symbol']}  ${c['code']} — ${c['name']}'),
          )).toList(),
          onChanged: (code) {
            if (code == null) return;
            final c = currencies.firstWhere((cur) => cur['code'] == code);
            onSelected(c.cast<String, String>());
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Selected: ${currencies.firstWhere((c) => c['code'] == selected, orElse: () => currencies[0])['name']}  (${currencies.firstWhere((c) => c['code'] == selected, orElse: () => currencies[0])['symbol']})',
            style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
          ),
        ),
      ],
    );
  }
}
