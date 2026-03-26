const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.use(express.json());

// ─── Schema ──────────────────────────────────────────────────────────────────
async function initSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS inventory_items (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL DEFAULT '',
      sku TEXT NOT NULL DEFAULT '',
      category TEXT NOT NULL DEFAULT '',
      price NUMERIC(14,4) NOT NULL DEFAULT 0,
      cost_price NUMERIC(14,4) NOT NULL DEFAULT 0,
      quantity INTEGER NOT NULL DEFAULT 0,
      low_stock_threshold INTEGER NOT NULL DEFAULT 5,
      unit TEXT NOT NULL DEFAULT 'pcs',
      supplier_id TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT '',
      email TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      company TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS suppliers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT '',
      company TEXT NOT NULL DEFAULT '',
      email TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      website TEXT NOT NULL DEFAULT '',
      tax_id TEXT NOT NULL DEFAULT '',
      payment_terms TEXT NOT NULL DEFAULT 'Net 30',
      notes TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS invoices (
      id TEXT PRIMARY KEY,
      invoice_number TEXT NOT NULL,
      customer_id TEXT,
      customer_name TEXT NOT NULL DEFAULT '',
      customer_email TEXT NOT NULL DEFAULT '',
      items JSONB NOT NULL DEFAULT '[]',
      status TEXT NOT NULL DEFAULT 'draft',
      invoice_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      due_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      notes TEXT NOT NULL DEFAULT '',
      tax_rate NUMERIC(7,4) NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS purchase_orders (
      id TEXT PRIMARY KEY,
      po_number TEXT NOT NULL,
      supplier_id TEXT,
      supplier_name TEXT NOT NULL DEFAULT '',
      items JSONB NOT NULL DEFAULT '[]',
      status TEXT NOT NULL DEFAULT 'draft',
      order_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expected_date TIMESTAMPTZ,
      notes TEXT NOT NULL DEFAULT '',
      tax_rate NUMERIC(7,4) NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL DEFAULT ''
    );
  `);
  console.log('Database schema ready');
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
function rowToInventoryItem(r) {
  return {
    id: r.id, name: r.name, description: r.description,
    sku: r.sku, category: r.category,
    price: parseFloat(r.price), costPrice: parseFloat(r.cost_price),
    quantity: parseInt(r.quantity), lowStockThreshold: parseInt(r.low_stock_threshold),
    unit: r.unit, supplierId: r.supplier_id,
    createdAt: r.created_at, updatedAt: r.updated_at,
  };
}
function rowToCustomer(r) {
  return {
    id: r.id, name: r.name, email: r.email, phone: r.phone,
    company: r.company, address: r.address, createdAt: r.created_at,
  };
}
function rowToSupplier(r) {
  return {
    id: r.id, name: r.name, company: r.company, email: r.email,
    phone: r.phone, address: r.address, website: r.website,
    taxId: r.tax_id, paymentTerms: r.payment_terms, notes: r.notes,
    createdAt: r.created_at,
  };
}
function rowToInvoice(r) {
  return {
    id: r.id, invoiceNumber: r.invoice_number,
    customerId: r.customer_id, customerName: r.customer_name,
    customerEmail: r.customer_email,
    items: r.items,
    status: r.status,
    invoiceDate: r.invoice_date, dueDate: r.due_date,
    notes: r.notes, taxRate: parseFloat(r.tax_rate),
    createdAt: r.created_at,
  };
}
function rowToPurchaseOrder(r) {
  return {
    id: r.id, poNumber: r.po_number,
    supplierId: r.supplier_id, supplierName: r.supplier_name,
    items: r.items, status: r.status,
    orderDate: r.order_date,
    expectedDate: r.expected_date || null,
    notes: r.notes, taxRate: parseFloat(r.tax_rate),
    createdAt: r.created_at,
  };
}

async function nextNumber(key, prefix) {
  const res = await pool.query(
    'INSERT INTO app_settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO NOTHING RETURNING value',
    [key, '0']
  );
  const cur = await pool.query('SELECT value FROM app_settings WHERE key=$1', [key]);
  const n = (parseInt(cur.rows[0]?.value || '0') + 1);
  await pool.query('UPDATE app_settings SET value=$1 WHERE key=$2', [n.toString(), key]);
  return `${prefix}-${String(n).padStart(4, '0')}`;
}

// ─── Inventory ────────────────────────────────────────────────────────────────
app.get('/api/inventory', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM inventory_items ORDER BY name');
    res.json(r.rows.map(rowToInventoryItem));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/inventory', async (req, res) => {
  const d = req.body;
  try {
    await pool.query(`
      INSERT INTO inventory_items(id,name,description,sku,category,price,cost_price,quantity,
        low_stock_threshold,unit,supplier_id,created_at,updated_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
      ON CONFLICT(id) DO UPDATE SET
        name=EXCLUDED.name, description=EXCLUDED.description, sku=EXCLUDED.sku,
        category=EXCLUDED.category, price=EXCLUDED.price, cost_price=EXCLUDED.cost_price,
        quantity=EXCLUDED.quantity, low_stock_threshold=EXCLUDED.low_stock_threshold,
        unit=EXCLUDED.unit, supplier_id=EXCLUDED.supplier_id, updated_at=NOW()
    `, [d.id,d.name,d.description||'',d.sku||'',d.category||'',
        d.price,d.costPrice||0,d.quantity,d.lowStockThreshold||5,
        d.unit||'pcs',d.supplierId||'',d.createdAt||new Date(),d.updatedAt||new Date()]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/inventory/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM inventory_items WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Customers ───────────────────────────────────────────────────────────────
app.get('/api/customers', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM customers ORDER BY name');
    res.json(r.rows.map(rowToCustomer));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/customers', async (req, res) => {
  const d = req.body;
  try {
    await pool.query(`
      INSERT INTO customers(id,name,email,phone,company,address,created_at)
      VALUES($1,$2,$3,$4,$5,$6,$7)
      ON CONFLICT(id) DO UPDATE SET
        name=EXCLUDED.name, email=EXCLUDED.email, phone=EXCLUDED.phone,
        company=EXCLUDED.company, address=EXCLUDED.address
    `, [d.id,d.name,d.email||'',d.phone||'',d.company||'',d.address||'',d.createdAt||new Date()]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/customers/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM customers WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Suppliers ────────────────────────────────────────────────────────────────
app.get('/api/suppliers', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM suppliers ORDER BY COALESCE(NULLIF(company,\'\'),name)');
    res.json(r.rows.map(rowToSupplier));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/suppliers', async (req, res) => {
  const d = req.body;
  try {
    await pool.query(`
      INSERT INTO suppliers(id,name,company,email,phone,address,website,tax_id,payment_terms,notes,created_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
      ON CONFLICT(id) DO UPDATE SET
        name=EXCLUDED.name, company=EXCLUDED.company, email=EXCLUDED.email,
        phone=EXCLUDED.phone, address=EXCLUDED.address, website=EXCLUDED.website,
        tax_id=EXCLUDED.tax_id, payment_terms=EXCLUDED.payment_terms, notes=EXCLUDED.notes
    `, [d.id,d.name,d.company||'',d.email||'',d.phone||'',d.address||'',
        d.website||'',d.taxId||'',d.paymentTerms||'Net 30',d.notes||'',d.createdAt||new Date()]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/suppliers/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM suppliers WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Invoices ─────────────────────────────────────────────────────────────────
app.get('/api/invoices', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM invoices ORDER BY created_at DESC');
    res.json(r.rows.map(rowToInvoice));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/invoices/next-number', async (req, res) => {
  try {
    const prefRes = await pool.query("SELECT value FROM app_settings WHERE key='invoicePrefix'");
    const prefix = prefRes.rows[0]?.value || 'INV';
    const num = await nextNumber('invoice_counter', prefix);
    res.json({ number: num });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/invoices', async (req, res) => {
  const d = req.body;
  try {
    await pool.query(`
      INSERT INTO invoices(id,invoice_number,customer_id,customer_name,customer_email,
        items,status,invoice_date,due_date,notes,tax_rate,created_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
      ON CONFLICT(id) DO UPDATE SET
        customer_id=EXCLUDED.customer_id, customer_name=EXCLUDED.customer_name,
        customer_email=EXCLUDED.customer_email, items=EXCLUDED.items,
        status=EXCLUDED.status, invoice_date=EXCLUDED.invoice_date,
        due_date=EXCLUDED.due_date, notes=EXCLUDED.notes, tax_rate=EXCLUDED.tax_rate
    `, [d.id,d.invoiceNumber,d.customerId||null,d.customerName,d.customerEmail||'',
        JSON.stringify(d.items||[]),d.status||'draft',
        d.invoiceDate||new Date(),d.dueDate||new Date(),
        d.notes||'',d.taxRate||0,d.createdAt||new Date()]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/invoices/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM invoices WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Purchase Orders ──────────────────────────────────────────────────────────
app.get('/api/purchases', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM purchase_orders ORDER BY created_at DESC');
    res.json(r.rows.map(rowToPurchaseOrder));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/purchases/next-number', async (req, res) => {
  try {
    const prefRes = await pool.query("SELECT value FROM app_settings WHERE key='poPrefix'");
    const prefix = prefRes.rows[0]?.value || 'PO';
    const num = await nextNumber('po_counter', prefix);
    res.json({ number: num });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/purchases', async (req, res) => {
  const d = req.body;
  try {
    await pool.query(`
      INSERT INTO purchase_orders(id,po_number,supplier_id,supplier_name,items,status,
        order_date,expected_date,notes,tax_rate,created_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
      ON CONFLICT(id) DO UPDATE SET
        supplier_id=EXCLUDED.supplier_id, supplier_name=EXCLUDED.supplier_name,
        items=EXCLUDED.items, status=EXCLUDED.status, order_date=EXCLUDED.order_date,
        expected_date=EXCLUDED.expected_date, notes=EXCLUDED.notes, tax_rate=EXCLUDED.tax_rate
    `, [d.id,d.poNumber,d.supplierId||null,d.supplierName,
        JSON.stringify(d.items||[]),d.status||'draft',
        d.orderDate||new Date(),d.expectedDate||null,
        d.notes||'',d.taxRate||0,d.createdAt||new Date()]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/purchases/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM purchase_orders WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Settings ─────────────────────────────────────────────────────────────────
app.get('/api/settings', async (req, res) => {
  try {
    const r = await pool.query('SELECT key, value FROM app_settings');
    const map = {};
    r.rows.forEach(row => map[row.key] = row.value);
    res.json(map);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/settings', async (req, res) => {
  const entries = Object.entries(req.body);
  try {
    for (const [k, v] of entries) {
      await pool.query(
        'INSERT INTO app_settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value',
        [k, String(v)]
      );
    }
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Dashboard ────────────────────────────────────────────────────────────────
app.get('/api/dashboard', async (req, res) => {
  try {
    const [inv, cust, supp, invCount, poCount] = await Promise.all([
      pool.query('SELECT SUM(price*quantity) as val, COUNT(*) as total, SUM(CASE WHEN quantity=0 THEN 1 ELSE 0 END) as out_of_stock, SUM(CASE WHEN quantity>0 AND quantity<=low_stock_threshold THEN 1 ELSE 0 END) as low_stock FROM inventory_items'),
      pool.query('SELECT COUNT(*) as cnt FROM customers'),
      pool.query('SELECT COUNT(*) as cnt FROM suppliers'),
      pool.query("SELECT COUNT(*) as total, SUM(CASE WHEN status='paid' THEN (SELECT SUM((item->>'quantity')::numeric*(item->>'unitPrice')::numeric) FROM jsonb_array_elements(items) item)*(1+tax_rate/100) ELSE 0 END) as paid, SUM(CASE WHEN status='draft' OR status='sent' THEN (SELECT SUM((item->>'quantity')::numeric*(item->>'unitPrice')::numeric) FROM jsonb_array_elements(items) item)*(1+tax_rate/100) ELSE 0 END) as outstanding FROM invoices"),
      pool.query('SELECT COUNT(*) as cnt FROM purchase_orders'),
    ]);
    const overdueRes = await pool.query("SELECT SUM((SELECT SUM((item->>'quantity')::numeric*(item->>'unitPrice')::numeric) FROM jsonb_array_elements(items) item)*(1+tax_rate/100)) as overdue FROM invoices WHERE status='sent' AND due_date < NOW()");
    const recentRes = await pool.query('SELECT * FROM invoices ORDER BY created_at DESC LIMIT 5');
    const lowStockRes = await pool.query('SELECT * FROM inventory_items WHERE quantity <= low_stock_threshold ORDER BY quantity ASC LIMIT 10');
    res.json({
      totalValue: parseFloat(inv.rows[0].val || 0),
      totalItems: parseInt(inv.rows[0].total || 0),
      outOfStockCount: parseInt(inv.rows[0].out_of_stock || 0),
      lowStockCount: parseInt(inv.rows[0].low_stock || 0),
      customerCount: parseInt(cust.rows[0].cnt || 0),
      supplierCount: parseInt(supp.rows[0].cnt || 0),
      totalInvoices: parseInt(invCount.rows[0].total || 0),
      totalPaid: parseFloat(invCount.rows[0].paid || 0),
      totalOutstanding: parseFloat(invCount.rows[0].outstanding || 0),
      totalOverdue: parseFloat(overdueRes.rows[0].overdue || 0),
      totalPurchaseOrders: parseInt(poCount.rows[0].cnt || 0),
      recentInvoices: recentRes.rows.map(rowToInvoice),
      lowStockItems: lowStockRes.rows.map(rowToInventoryItem),
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Monthly Revenue ──────────────────────────────────────────────────────────
app.get('/api/dashboard/monthly', async (req, res) => {
  try {
    const r = await pool.query(`
      SELECT date_trunc('month', invoice_date) as month,
             SUM((SELECT SUM((item->>'quantity')::numeric*(item->>'unitPrice')::numeric)
                  FROM jsonb_array_elements(items) item)*(1+tax_rate/100)) as revenue
      FROM invoices WHERE status='paid'
      GROUP BY month ORDER BY month DESC LIMIT 12
    `);
    res.json(r.rows.map(row => ({
      month: row.month,
      revenue: parseFloat(row.revenue || 0),
    })).reverse());
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Invoice/PO Summary ───────────────────────────────────────────────────────
app.get('/api/invoices/summary', async (req, res) => {
  try {
    const r = await pool.query(`
      SELECT
        SUM(CASE WHEN status='paid' THEN subtotal ELSE 0 END) as paid,
        SUM(CASE WHEN status IN ('draft','sent') AND NOT (status='sent' AND due_date < NOW()) THEN subtotal ELSE 0 END) as outstanding,
        SUM(CASE WHEN status='sent' AND due_date < NOW() THEN subtotal ELSE 0 END) as overdue
      FROM (
        SELECT status, due_date,
          (SELECT SUM((item->>'quantity')::numeric*(item->>'unitPrice')::numeric)
           FROM jsonb_array_elements(items) item)*(1+tax_rate/100) as subtotal
        FROM invoices
      ) t
    `);
    res.json({
      totalPaid: parseFloat(r.rows[0].paid || 0),
      totalOutstanding: parseFloat(r.rows[0].outstanding || 0),
      totalOverdue: parseFloat(r.rows[0].overdue || 0),
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Serve Flutter Web ────────────────────────────────────────────────────────
const webDir = path.join(__dirname, '../aenzbi_invoice/build/web');
app.use(express.static(webDir));
app.use((req, res) => {
  res.sendFile(path.join(webDir, 'index.html'));
});

// ─── Start ────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
initSchema()
  .then(() => app.listen(PORT, '0.0.0.0', () => console.log(`Server on port ${PORT}`)))
  .catch(err => { console.error('Schema init failed:', err); process.exit(1); });
