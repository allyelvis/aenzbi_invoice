import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/supplier_screen.dart';
import 'screens/purchase_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

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
      title: 'Aenzbi Invoice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFFF5F6FF),
          indicatorColor: Color(0xFFD0D4F7),
          selectedIconTheme: IconThemeData(color: Color(0xFF3F51B5)),
          unselectedIconTheme: IconThemeData(color: Colors.black54),
          selectedLabelTextStyle: TextStyle(
            color: Color(0xFF3F51B5), fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelTextStyle: TextStyle(
            color: Colors.black54, fontSize: 12),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ─── Destinations config ──────────────────────────────────────────────────────

class _Dest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  const _Dest(this.label, this.icon, this.selectedIcon, this.page);
}

const _destinations = <_Dest>[
  _Dest('Dashboard',  Icons.dashboard_outlined,       Icons.dashboard,          DashboardScreen()),
  _Dest('Inventory',  Icons.inventory_2_outlined,     Icons.inventory_2,        InventoryScreen()),
  _Dest('Invoices',   Icons.receipt_long_outlined,    Icons.receipt_long,       InvoiceScreen()),
  _Dest('Purchases',  Icons.shopping_cart_outlined,   Icons.shopping_cart,      PurchaseScreen()),
  _Dest('Customers',  Icons.people_outline,           Icons.people,             CustomerScreen()),
  _Dest('Suppliers',  Icons.store_outlined,           Icons.store,              SupplierScreen()),
  _Dest('Reports',    Icons.bar_chart_outlined,       Icons.bar_chart,          ReportsScreen()),
  _Dest('Settings',   Icons.settings_outlined,        Icons.settings,           SettingsScreen()),
];

// ─── Main Shell ───────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static final List<Widget> _pages =
      _destinations.map((d) => d.page).toList();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final useRail = width >= 640;
    final extended = width >= 1100;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            _AppRail(
              selected: _selectedIndex,
              extended: extended,
              onSelect: (i) => setState(() => _selectedIndex = i),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _pages),
            ),
          ],
        ),
      );
    }

    // Mobile: bottom navigation
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        selected: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ─── Navigation Rail ──────────────────────────────────────────────────────────

class _AppRail extends StatelessWidget {
  final int selected;
  final bool extended;
  final ValueChanged<int> onSelect;
  const _AppRail({
    required this.selected,
    required this.extended,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return NavigationRail(
      selectedIndex: selected,
      extended: extended,
      onDestinationSelected: onSelect,
      backgroundColor: const Color(0xFFF5F6FF),
      minWidth: 72,
      minExtendedWidth: 200,
      leading: Padding(
        padding: EdgeInsets.symmetric(
            vertical: 16, horizontal: extended ? 16 : 8),
        child: extended
            ? Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Flexible(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aenzbi', style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, color: cs.primary)),
                    Text('Invoice', style: TextStyle(
                        fontSize: 11, color: cs.primary.withOpacity(0.7))),
                  ],
                )),
              ])
            : Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: cs.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
              ),
      ),
      groupAlignment: -1,
      destinations: [
        // Main group
        ..._destinations.take(6).map((d) => NavigationRailDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.selectedIcon),
          label: Text(d.label),
        )),
        // Divider separator handled via custom padding
        NavigationRailDestination(
          icon: const Icon(Icons.bar_chart_outlined),
          selectedIcon: const Icon(Icons.bar_chart),
          label: const Text('Reports'),
          padding: const EdgeInsets.only(top: 8),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: const Text('Settings'),
        ),
      ],
    );
  }
}

// ─── Bottom Navigation (mobile) ───────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _BottomNav({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // On mobile show only 5 primary tabs; Reports & Settings go into a "More" bottom sheet
    const primary = [0, 1, 2, 3, 4]; // Dashboard, Inventory, Invoices, Purchases, Customers

    int displayIndex = primary.contains(selected) ? primary.indexOf(selected) : 4;
    const moreIndex = 5; // "More" button index in the bottom bar

    return NavigationBar(
      selectedIndex: displayIndex < 5 ? displayIndex : moreIndex,
      onDestinationSelected: (i) {
        if (i < 5) {
          onSelect(primary[i]);
        } else {
          _showMoreSheet(context);
        }
      },
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        ..._destinations.take(5).map((d) => NavigationDestination(
          icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label)),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          ..._destinations.skip(5).map((d) => ListTile(
            leading: Icon(d.icon),
            title: Text(d.label),
            onTap: () {
              Navigator.pop(context);
              final i = _destinations.indexOf(d);
              if (i >= 0) onSelect(i);
            },
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
