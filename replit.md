# Aenzbi Invoice App

A Flutter web application for invoice and inventory management.

## Architecture

- **Framework**: Flutter 3.16.7 (web)
- **Storage**: Browser localStorage via `dart:html` (no external packages)
- **Serialization**: `dart:convert` JSON

## Project Structure

```
aenzbi_invoice/
  lib/
    main.dart                     # App entry point + navigation shell
    models/
      inventory_item.dart         # InventoryItem data model
    database/
      database_helper.dart        # CRUD operations for inventory
      storage_backend.dart        # localStorage backend (dart:html)
    screens/
      inventory_screen.dart       # Inventory list with summary stats
      add_edit_item_screen.dart   # Add/edit item form
```

## Features

### Inventory Management
- Add, edit, delete inventory items
- Fields: name, description, SKU, category, price, cost price, quantity, unit, low-stock threshold
- Real-time summary: total items, total value, low stock count, out-of-stock count
- Search by name, SKU, or category
- Low stock / out-of-stock visual indicators
- Data persisted to browser localStorage

### Navigation
- Bottom navigation bar with Inventory and Dashboard tabs
- Dashboard tab is a placeholder for future development

## Running the App

The app builds with `flutter build web` and is served via `npx serve`.

**Workflow command:**
```
cd aenzbi_invoice && flutter build web && npx --yes serve build/web -p 5000 -s
```

## Package Management Note

The pub.dev TLS connection fails in this Replit environment. Packages must be 
manually downloaded and cached:

```bash
curl -L "https://pub.dev/packages/<name>/versions/<version>.tar.gz" -o /tmp/pkg.tar.gz
mkdir -p ~/.pub-cache/hosted/pub.dev/<name>-<version>
tar -xzf /tmp/pkg.tar.gz -C ~/.pub-cache/hosted/pub.dev/<name>-<version>
flutter pub get --offline
```
