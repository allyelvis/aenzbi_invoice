import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'screens/customer_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/modern_dashboard_screen.dart';
import 'screens/purchase_screen.dart';
import 'screens/quote_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/supplier_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await DatabaseHelper.instance.init();
  } catch (_) {}
  runApp(const AenzbiInvoiceApp());
}

class AenzbiInvoiceApp extends StatelessWidget {
  const AenzbiInvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aenzbi Business OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF18A98B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
        fontFamily: 'Arial',
        cardTheme: const CardTheme(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xFFE7EBF0)),
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class _Destination {
  final String group;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  const _Destination(this.group, this.label, this.icon, this.builder);
}

final _destinations = <_Destination>[
  _Destination('Overview', 'Dashboard', Icons.grid_view_rounded,
      (_) => const ModernDashboardScreen()),
  _Destination('Sales', 'Customers', Icons.people_alt_outlined,
      (_) => const CustomerScreen()),
  _Destination('Sales', 'Quotes', Icons.request_quote_outlined,
      (_) => const QuoteScreen()),
  _Destination('Sales', 'Sales Orders', Icons.shopping_bag_outlined,
      (_) => const _ModulePlaceholder(
          title: 'Sales orders',
          subtitle: 'Manage the order-to-delivery workflow.')),
  _Destination('Sales', 'Invoices', Icons.receipt_long_outlined,
      (_) => const InvoiceScreen()),
  _Destination('Sales', 'Payments', Icons.payments_outlined,
      (_) => const InvoiceScreen()),
  _Destination('Purchasing', 'Suppliers', Icons.storefront_outlined,
      (_) => const SupplierScreen()),
  _Destination('Purchasing', 'Purchase Orders', Icons.inventory_outlined,
      (_) => const PurchaseScreen()),
  _Destination('Purchasing', 'Purchases', Icons.local_mall_outlined,
      (_) => const _ModulePlaceholder(
          title: 'Purchases',
          subtitle: 'Track receiving, supplier balances, and costs.')),
  _Destination('Inventory', 'Products', Icons.category_outlined,
      (_) => const InventoryScreen()),
  _Destination('Inventory', 'Warehouses', Icons.warehouse_outlined,
      (_) => const _ModulePlaceholder(
          title: 'Warehouses',
          subtitle: 'Organize stock across locations and storage zones.')),
  _Destination('Inventory', 'Stock', Icons.layers_outlined,
      (_) => const InventoryScreen()),
  _Destination('Inventory', 'Stock Movements',
      Icons.swap_vert_circle_outlined, (_) => const _ModulePlaceholder(
          title: 'Stock movements',
          subtitle: 'Keep an immutable record of every stock change.')),
  _Destination('Inventory', 'Transfers', Icons.compare_arrows_rounded,
      (_) => const _ModulePlaceholder(
          title: 'Transfers',
          subtitle: 'Move stock between warehouses with full traceability.')),
  _Destination('Logistics', 'Deliveries', Icons.local_shipping_outlined,
      (_) => const _ModulePlaceholder(
          title: 'Deliveries',
          subtitle: 'Assign, dispatch, and complete customer deliveries.')),
  _Destination('Logistics', 'Routes', Icons.alt_route_rounded,
      (_) => const _ModulePlaceholder(
          title: 'Routes',
          subtitle: 'Plan multi-stop routes for your delivery team.')),
  _Destination('Logistics', 'Drivers', Icons.badge_outlined,
      (_) => const _ModulePlaceholder(
          title: 'Drivers',
          subtitle: 'Manage driver profiles and assigned work.')),
  _Destination('Logistics', 'Vehicles', Icons.directions_car_outlined,
      (_) => const _ModulePlaceholder(
          title: 'Vehicles',
          subtitle: 'Track vehicle readiness, mileage, and operating costs.')),
  _Destination('Logistics', 'Expenses',
      Icons.account_balance_wallet_outlined, (_) => const _ModulePlaceholder(
          title: 'Expenses',
          subtitle: 'Capture fuel, maintenance, shipping, and operating expenses.')),
  _Destination('Reports', 'Sales reports', Icons.trending_up_rounded,
      (_) => const ReportsScreen()),
  _Destination('Reports', 'Finance reports', Icons.analytics_outlined,
      (_) => const ReportsScreen()),
  _Destination('Reports', 'Inventory reports', Icons.bar_chart_rounded,
      (_) => const ReportsScreen()),
  _Destination('Reports', 'Logistics reports', Icons.route_outlined,
      (_) => const ReportsScreen()),
  _Destination('Administration', 'Users', Icons.manage_accounts_outlined,
      (_) => const _ModulePlaceholder(
          title: 'Users',
          subtitle: 'Invite team members and manage workspace access.')),
  _Destination('Administration', 'Roles & permissions',
      Icons.admin_panel_settings_outlined, (_) => const _ModulePlaceholder(
          title: 'Roles & permissions',
          subtitle: 'Control who can see and change business records.')),
  _Destination('Administration', 'Organization', Icons.business_outlined,
      (_) => const SettingsScreen()),
  _Destination('Administration', 'Settings', Icons.tune_outlined,
      (_) => const SettingsScreen()),
  _Destination('Administration', 'Audit logs', Icons.history_rounded,
      (_) => const _ModulePlaceholder(
          title: 'Audit logs',
          subtitle: 'Review important actions across your organization.')),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  late final List<Widget> _pages =
      _destinations.map((d) => d.builder(context)).toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final desktop = width >= 980;
    final compactDesktop = width >= 720 && width < 1180;

    return Scaffold(
      key: _scaffoldKey,
      drawer: desktop
          ? null
          : Drawer(
              width: 284,
              child: _Sidebar(
                selected: _selectedIndex,
                expanded: true,
                onSelect: (i) {
                  setState(() => _selectedIndex = i);
                  Navigator.of(context).pop();
                },
              ),
            ),
      body: Row(
        children: [
          if (desktop)
            _Sidebar(
              selected: _selectedIndex,
              expanded: _sidebarExpanded && !compactDesktop,
              onSelect: (i) => setState(() => _selectedIndex = i),
            ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  controller: _searchController,
                  onMenu: desktop
                      ? () => setState(
                          () => _sidebarExpanded = !_sidebarExpanded)
                      : () => _scaffoldKey.currentState?.openDrawer(),
                  onNotifications: () => _showNotifications(context),
                ),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: _pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: const SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFFFF0D6),
                  child: Icon(Icons.inventory_2_outlined,
                      color: Color(0xFFC87A12)),
                ),
                title: Text('Inventory is ready to monitor'),
                subtitle:
                    Text('Low-stock and movement alerts will appear here.'),
              ),
              Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFDDF7EF),
                  child: Icon(Icons.check, color: Color(0xFF159574)),
                ),
                title: Text('Workspace connected'),
                subtitle: Text('Your Aenzbi workspace is ready.'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selected;
  final bool expanded;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selected,
    required this.expanded,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const groups = [
      'Overview',
      'Sales',
      'Purchasing',
      'Inventory',
      'Logistics',
      'Reports',
      'Administration'
    ];
    final width = expanded ? 246.0 : 82.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: width,
      color: const Color(0xFF14243D),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(expanded ? 20 : 18, 22, 16, 26),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF26B899),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Colors.white, size: 21),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 11),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('aenzbi',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4)),
                        Text('BUSINESS OS',
                            style: TextStyle(
                                color: Color(0xFF86A0BC),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 10),
                children: [
                  for (final group in groups) ...[
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 13, 10, 7),
                        child: Text(
                          group.toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFF7188A4),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1),
                        ),
                      ),
                    ..._destinations
                        .asMap()
                        .entries
                        .where((entry) => entry.value.group == group)
                        .map((entry) => _SidebarItem(
                              destination: entry.value,
                              selected: selected == entry.key,
                              expanded: expanded,
                              onTap: () => onSelect(entry.key),
                            )),
                  ],
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(
                  expanded ? 12 : 10, 8, expanded ? 12 : 10, 12),
              padding: EdgeInsets.all(expanded ? 11 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C3150),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFFD9F4EC),
                    child: Text('AM',
                        style: TextStyle(
                            color: Color(0xFF147E69),
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amani M.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                          SizedBox(height: 2),
                          Text('Workspace admin',
                              style: TextStyle(
                                  color: Color(0xFF8BA0B8), fontSize: 10)),
                        ],
                      ),
                    ),
                    Icon(Icons.more_horiz,
                        color: Color(0xFF8BA0B8), size: 18),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _Destination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFF9AAEC3);
    return Tooltip(
      message: expanded ? '' : destination.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? const Color(0xFF216B69) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 11 : 14, vertical: 10),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(destination.icon, size: 18, color: foreground),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(destination.label,
                          style: TextStyle(
                              color: foreground,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                    if (selected)
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: Color(0xFFA7E2D2)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onMenu;
  final VoidCallback onNotifications;

  const _TopBar({
    required this.controller,
    required this.onMenu,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 620;
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDF2))),
      ),
      child: Row(
        children: [
          IconButton(
              onPressed: onMenu,
              icon:
                  const Icon(Icons.menu_rounded, color: Color(0xFF607086))),
          const SizedBox(width: 4),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 260 : 440),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search anything...',
                  hintStyle:
                      const TextStyle(color: Color(0xFF9AA8B7), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 19, color: Color(0xFF8190A2)),
                  suffixIcon: compact
                      ? null
                      : Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F5F7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('⌘ K',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF8290A0),
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7F9FB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
              onPressed: onNotifications,
              icon: const Badge(
                  smallSize: 7,
                  backgroundColor: Color(0xFFE76D63),
                  child: Icon(Icons.notifications_none_rounded,
                      color: Color(0xFF66778B), size: 22))),
          const SizedBox(width: 4),
          Container(
            height: 32,
            width: 1,
            color: const Color(0xFFE4E9EE),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFD9F4EC),
            child: Text('AM',
                style: TextStyle(
                    color: Color(0xFF147E69),
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
          if (!compact) ...[
            const SizedBox(width: 9),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amani M.',
                    style: TextStyle(
                        color: Color(0xFF24354A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text('Administrator',
                    style: TextStyle(color: Color(0xFF91A0B0), fontSize: 10)),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF8796A7), size: 18),
          ],
        ],
      ),
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ModulePlaceholder({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FB),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                        color: const Color(0xFFDDF7EF),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFF159574), size: 30),
                  ),
                  const SizedBox(height: 20),
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFF1E3045),
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF718095), fontSize: 14, height: 1.5)),
                  const SizedBox(height: 24),
                  const Chip(
                    avatar: Icon(Icons.construction_outlined,
                        size: 16, color: Color(0xFF159574)),
                    label: Text('Module workspace'),
                    backgroundColor: Color(0xFFF0FBF7),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}