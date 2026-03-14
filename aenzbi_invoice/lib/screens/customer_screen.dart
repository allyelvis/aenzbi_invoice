import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/customer.dart';
import 'add_edit_customer_screen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  bool _loading = true;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final customers = await DatabaseHelper.instance.getAllCustomers();
    setState(() {
      _customers = customers;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _filtered = List.from(_customers);
    } else {
      final lower = _query.toLowerCase();
      _filtered = _customers.where((c) {
        return c.name.toLowerCase().contains(lower) ||
            c.company.toLowerCase().contains(lower) ||
            c.email.toLowerCase().contains(lower) ||
            c.phone.contains(lower);
      }).toList();
    }
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditCustomerScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _navigateToEdit(Customer customer) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AddEditCustomerScreen(customer: customer)),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Delete "${customer.name}"? This cannot be undone.'),
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
      await DatabaseHelper.instance.deleteCustomer(customer.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Customers (${_customers.length})'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() { _query = v; _applyFilter(); }),
                    decoration: InputDecoration(
                      hintText: 'Search customers…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() { _query = ''; _applyFilter(); });
                              })
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
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
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
    );
  }

  Widget _buildCard(Customer customer, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(customer.initials,
              style: TextStyle(
                  color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
        ),
        title: Text(customer.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.company.isNotEmpty)
              Text(customer.company,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
            Row(
              children: [
                if (customer.email.isNotEmpty) ...[
                  Icon(Icons.email_outlined,
                      size: 12, color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(customer.email,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.6))),
                  ),
                ],
                if (customer.email.isNotEmpty && customer.phone.isNotEmpty)
                  const Text('  •  ',
                      style: TextStyle(fontSize: 11)),
                if (customer.phone.isNotEmpty) ...[
                  Icon(Icons.phone_outlined,
                      size: 12, color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(customer.phone,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.6))),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: customer.company.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _navigateToEdit(customer);
            if (v == 'delete') _delete(customer);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => _navigateToEdit(customer),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 72, color: cs.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _query.isNotEmpty ? 'No customers found' : 'No customers yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                ),
          ),
          if (_query.isEmpty) ...[
            const SizedBox(height: 8),
            Text('Tap + Add Customer to get started',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withOpacity(0.4))),
          ],
        ],
      ),
    );
  }
}
