# Aenzbi Invoice App

A full-featured Flutter web application for invoice and inventory management.

## Architecture

- **Framework**: Flutter 3.16.7 (web)
- **Storage**: Browser localStorage via `dart:html` with in-memory fallback
- **Serialization**: `dart:convert` JSON (no external packages)

## Features

### Dashboard
- KPI cards: Revenue, Outstanding, Inventory Value, Customer Count
- Monthly revenue bar chart (last 6 months, CustomPainter)
- Recent invoices list (last 5)
- Low stock alerts

### Invoice Management
- Create/edit/delete invoices with auto-numbered IDs (INV-YYYY-NNNN)
- Dynamic line items — pick from inventory or enter manually
- Tax rate calculation with subtotal/total breakdown
- Status tracking: Draft → Sent → Paid / Overdue (auto-detected)
- Filter by status, quick mark-as actions

### Customer Management
- Add/edit/delete customers
- Fields: name, company, email, phone, address
- Search by name, company, email, phone
- Customer picker when creating invoices

### Inventory Management
- Add/edit/delete items with full metadata
- Sort by name, price, stock, or total value
- Filter by category with chip selectors
- Low stock / out-of-stock visual indicators
- Summary bar: total items, value, low/out of stock counts

## Project Structure

```
aenzbi_invoice/lib/
  main.dart                          # App + 4-tab navigation shell
  models/
    inventory_item.dart              # Item model
    customer.dart                    # Customer model
    invoice.dart                     # Invoice + InvoiceLineItem models
  database/
    database_helper.dart             # All CRUD + analytics queries
    storage_backend.dart             # localStorage with memory fallback
  screens/
    dashboard_screen.dart            # Dashboard with chart
    inventory_screen.dart            # Inventory list + search/sort/filter
    add_edit_item_screen.dart        # Item form
    invoice_screen.dart              # Invoice list + status filter
    add_edit_invoice_screen.dart     # Invoice form with line items
    customer_screen.dart             # Customer list + search
    add_edit_customer_screen.dart    # Customer form
```

## Running the App

```bash
cd aenzbi_invoice && flutter build web && npx --yes serve build/web -p 5000 -s
```

## Package Management Note

pub.dev TLS fails in this environment. Manually seed cache:
```bash
curl -L "https://pub.dev/packages/<name>/versions/<version>.tar.gz" -o /tmp/pkg.tar.gz
mkdir -p ~/.pub-cache/hosted/pub.dev/<name>-<version>
tar -xzf /tmp/pkg.tar.gz -C ~/.pub-cache/hosted/pub.dev/<name>-<version>
flutter pub get --offline
```
