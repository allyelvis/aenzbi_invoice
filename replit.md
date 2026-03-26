# Aenzbi Invoice App

A full-featured Flutter web application for invoice and inventory management, backed by PostgreSQL.

## Architecture

- **Frontend**: Flutter 3.16.7 (web), served as static files by the Node.js server
- **Backend**: Node.js + Express API server (`server/index.js`) on port 5000
- **Database**: Replit PostgreSQL (via `pg` package, env vars: DATABASE_URL, PGHOST, etc.)
- **API**: RESTful JSON API at `/api/...` — same origin as the Flutter web app
- **Flutter HTTP**: `dart:html HttpRequest` (no external pub packages)

## Features

### Dashboard
- 8 KPI stat cards: Revenue, Outstanding, Overdue, Inventory Value, Customers, Suppliers, Total Invoices, Low Stock
- Monthly revenue bar chart (last 12 months)
- Recent invoices list
- Low stock alerts

### Invoice Management
- Create/edit/delete invoices with auto-numbered IDs (prefix configurable in Settings)
- Dynamic line items, tax rate, subtotal/total breakdown
- Status: Draft → Sent → Paid / Overdue (auto-detected from due date)
- Filter by status, quick mark-as actions
- **Print / Export PDF** — opens styled invoice in new tab and triggers browser print

### Purchase Orders
- Create/edit/delete purchase orders with auto-numbered IDs (PO prefix)
- Supplier picker + freetext name, line items with unit cost
- Status: Draft → Ordered → Received / Cancelled
- Expected delivery date tracking
- Print / Export PDF functionality

### Inventory Management
- Add/edit/delete items with SKU, category, supplier link, cost/selling price, stock
- Sort by name, price, stock, value — filter by category or supplier
- Low stock / out-of-stock visual indicators, profit margin display
- Summary bar: total items, value, low/out of stock counts

### Customer Management
- Add/edit/delete customers (name, company, email, phone, address)
- Search by name, company, email, phone

### Supplier / Vendor Management
- Add/edit/delete suppliers (company, contact, email, phone, address, website, tax ID, payment terms)
- Search and detail view

### Settings
- Company information (name, address, email, phone — used in printed documents)
- Multi-currency support: 23 currencies including USD, EUR, GBP, BIF, KES, NGN, ZAR, RWF, UGX, INR, etc.
- Invoice & PO number prefix configuration
- Default tax rate

## Project Structure

```
server/
  index.js                 # Express API server + Flutter static file serving
  package.json

aenzbi_invoice/
  build_serve.sh           # Self-healing startup: restores pub cache, builds, starts server
  lib/
    main.dart              # 7-tab navigation shell
    api/
      api_client.dart      # HTTP client using dart:html HttpRequest
    models/
      inventory_item.dart  
      customer.dart        
      invoice.dart         # Invoice + InvoiceLineItem
      supplier.dart        
      purchase_order.dart  # PurchaseOrder + PurchaseItem (NEW)
      app_settings.dart    # Settings model with currency list (NEW)
    database/
      database_helper.dart # All CRUD + analytics via API calls
    services/
      currency_service.dart  # Singleton for currency formatting (NEW)
      print_service.dart     # HTML print via dart:js (NEW)
    screens/
      dashboard_screen.dart
      inventory_screen.dart
      add_edit_item_screen.dart
      invoice_screen.dart
      add_edit_invoice_screen.dart
      customer_screen.dart
      add_edit_customer_screen.dart
      supplier_screen.dart
      add_edit_supplier_screen.dart
      purchase_screen.dart          # (NEW)
      add_edit_purchase_screen.dart # (NEW)
      settings_screen.dart          # (NEW)
```

## Startup

The workflow runs `cd aenzbi_invoice && bash build_serve.sh` which:
1. Detects and restores missing pub cache packages via curl (works around env-reset TLS issue)
2. Runs `flutter pub get --offline` if packages were restored
3. Runs `flutter build web`
4. Runs `npm install --production` in `server/`
5. Starts `node server/index.js` which serves both the API and Flutter web on port 5000

## Database Schema

Tables in PostgreSQL:
- `inventory_items` — full inventory with supplier link
- `customers`
- `suppliers`
- `invoices` — items stored as JSONB array
- `purchase_orders` — items stored as JSONB array
- `app_settings` — key/value store for all settings including invoice_counter, po_counter, currency, company info

## Critical Notes

- **NEVER use `--web-renderer html`** — crashes dart2js in Flutter 3.16.7 and wipes pub cache
- pub.dev TLS fails on env reset; `build_serve.sh` auto-restores 21 packages via curl
- The server normalizes PostgreSQL snake_case columns to camelCase JSON to match Flutter model `fromMap()` keys
