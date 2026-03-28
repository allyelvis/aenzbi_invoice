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
    CREATE TABLE IF NOT EXISTS payments (
      id TEXT PRIMARY KEY,
      invoice_id TEXT NOT NULL,
      amount NUMERIC(15,2) NOT NULL DEFAULT 0,
      payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
      method TEXT NOT NULL DEFAULT 'cash',
      reference TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ DEFAULT NOW()
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

// ─── Payments ─────────────────────────────────────────────────────────────────

app.get('/api/payments', async (req, res) => {
  try {
    const { invoiceId } = req.query;
    const r = await pool.query(
      'SELECT * FROM payments WHERE invoice_id=$1 ORDER BY payment_date DESC, created_at DESC',
      [invoiceId]
    );
    res.json(r.rows.map(p => ({
      id: p.id, invoiceId: p.invoice_id,
      amount: parseFloat(p.amount),
      paymentDate: p.payment_date,
      method: p.method, reference: p.reference, notes: p.notes,
    })));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/payments', async (req, res) => {
  try {
    const { id, invoiceId, amount, paymentDate, method, reference, notes } = req.body;
    await pool.query(
      `INSERT INTO payments(id,invoice_id,amount,payment_date,method,reference,notes)
       VALUES($1,$2,$3,$4,$5,$6,$7)
       ON CONFLICT(id) DO UPDATE SET
         amount=$3,payment_date=$4,method=$5,reference=$6,notes=$7`,
      [id, invoiceId, amount, paymentDate, method || 'cash', reference || '', notes || '']
    );
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/payments/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM payments WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/invoices/payments-totals', async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT invoice_id, SUM(amount) as total FROM payments GROUP BY invoice_id'
    );
    const map = {};
    for (const row of r.rows) map[row.invoice_id] = parseFloat(row.total);
    res.json(map);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Reports ─────────────────────────────────────────────────────────────────

// Helper: compute invoice total inline
const invTotal = `
  COALESCE(
    (SELECT SUM((item->>'quantity')::numeric*(item->>'unitPrice')::numeric)
     FROM jsonb_array_elements(items) item), 0
  ) * (1 + tax_rate/100.0)
`;

app.get('/api/reports/sales', async (req, res) => {
  try {
    const [monthly, byCustomer, byStatus] = await Promise.all([
      pool.query(`
        SELECT date_trunc('month', invoice_date) as month,
               COUNT(*) as invoice_count,
               SUM(${invTotal}) as total,
               SUM(CASE WHEN status='paid' THEN ${invTotal} ELSE 0 END) as paid
        FROM invoices
        WHERE invoice_date >= NOW() - INTERVAL '12 months'
        GROUP BY month ORDER BY month ASC
      `),
      pool.query(`
        SELECT customer_name,
               COUNT(*) as invoice_count,
               SUM(${invTotal}) as total_invoiced,
               SUM(CASE WHEN status='paid' THEN ${invTotal} ELSE 0 END) as total_paid
        FROM invoices
        GROUP BY customer_name ORDER BY total_invoiced DESC LIMIT 10
      `),
      pool.query(`
        SELECT status, COUNT(*) as count, SUM(${invTotal}) as total
        FROM invoices GROUP BY status
      `),
    ]);
    res.json({
      monthly: monthly.rows.map(r => ({
        month: r.month, invoiceCount: parseInt(r.invoice_count),
        total: parseFloat(r.total || 0), paid: parseFloat(r.paid || 0),
      })),
      byCustomer: byCustomer.rows.map(r => ({
        customerName: r.customer_name, invoiceCount: parseInt(r.invoice_count),
        totalInvoiced: parseFloat(r.total_invoiced || 0),
        totalPaid: parseFloat(r.total_paid || 0),
      })),
      byStatus: byStatus.rows.map(r => ({
        status: r.status, count: parseInt(r.count),
        total: parseFloat(r.total || 0),
      })),
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/reports/inventory', async (req, res) => {
  try {
    const [byCategory, lowStock, summary] = await Promise.all([
      pool.query(`
        SELECT COALESCE(NULLIF(category,''),'Uncategorised') as category,
               COUNT(*) as item_count,
               SUM(price*quantity) as total_value,
               SUM(quantity) as total_qty,
               SUM(CASE WHEN quantity=0 THEN 1 ELSE 0 END) as out_of_stock,
               SUM(CASE WHEN quantity>0 AND quantity<=low_stock_threshold THEN 1 ELSE 0 END) as low_stock
        FROM inventory_items
        GROUP BY category ORDER BY total_value DESC
      `),
      pool.query(`
        SELECT id, name, category, quantity, low_stock_threshold, unit, price
        FROM inventory_items
        WHERE quantity <= low_stock_threshold
        ORDER BY quantity ASC LIMIT 20
      `),
      pool.query(`
        SELECT COUNT(*) as total_items,
               SUM(price*quantity) as total_value,
               SUM(quantity) as total_units,
               SUM(CASE WHEN quantity=0 THEN price*0 ELSE cost_price*quantity END) as total_cost
        FROM inventory_items
      `),
    ]);
    res.json({
      byCategory: byCategory.rows.map(r => ({
        category: r.category, itemCount: parseInt(r.item_count),
        totalValue: parseFloat(r.total_value || 0),
        totalQty: parseInt(r.total_qty || 0),
        outOfStock: parseInt(r.out_of_stock || 0),
        lowStock: parseInt(r.low_stock || 0),
      })),
      lowStockItems: lowStock.rows,
      summary: {
        totalItems: parseInt(summary.rows[0].total_items || 0),
        totalValue: parseFloat(summary.rows[0].total_value || 0),
        totalUnits: parseInt(summary.rows[0].total_units || 0),
        totalCost: parseFloat(summary.rows[0].total_cost || 0),
      },
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

const poTotal = `
  COALESCE(
    (SELECT SUM((item->>'quantity')::numeric*(item->>'unitCost')::numeric)
     FROM jsonb_array_elements(items) item), 0
  ) * (1 + tax_rate/100.0)
`;

app.get('/api/reports/purchases', async (req, res) => {
  try {
    const [bySupplier, byStatus, monthly] = await Promise.all([
      pool.query(`
        SELECT supplier_name,
               COUNT(*) as po_count,
               SUM(${poTotal}) as total_value,
               SUM(CASE WHEN status='received' THEN ${poTotal} ELSE 0 END) as received_value
        FROM purchase_orders
        GROUP BY supplier_name ORDER BY total_value DESC LIMIT 10
      `),
      pool.query(`
        SELECT status, COUNT(*) as count, SUM(${poTotal}) as total
        FROM purchase_orders GROUP BY status
      `),
      pool.query(`
        SELECT date_trunc('month', order_date) as month,
               COUNT(*) as po_count,
               SUM(${poTotal}) as total
        FROM purchase_orders
        WHERE order_date >= NOW() - INTERVAL '12 months'
        GROUP BY month ORDER BY month ASC
      `),
    ]);
    res.json({
      bySupplier: bySupplier.rows.map(r => ({
        supplierName: r.supplier_name, poCount: parseInt(r.po_count),
        totalValue: parseFloat(r.total_value || 0),
        receivedValue: parseFloat(r.received_value || 0),
      })),
      byStatus: byStatus.rows.map(r => ({
        status: r.status, count: parseInt(r.count),
        total: parseFloat(r.total || 0),
      })),
      monthly: monthly.rows.map(r => ({
        month: r.month, poCount: parseInt(r.po_count),
        total: parseFloat(r.total || 0),
      })),
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/reports/aging', async (req, res) => {
  try {
    const invTot = `
      COALESCE(
        (SELECT SUM((item->>'quantity')::numeric*(item->>'unitPrice')::numeric)
         FROM jsonb_array_elements(items) item), 0
      ) * (1 + tax_rate/100.0)
    `;
    const r = await pool.query(`
      SELECT i.id, i.invoice_number, i.customer_name, i.due_date, i.invoice_date,
             i.status,
             ${invTot} as total,
             COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.invoice_id=i.id), 0) as paid,
             EXTRACT(DAY FROM NOW() - i.due_date)::integer as days_overdue
      FROM invoices i
      WHERE i.status NOT IN ('paid')
      ORDER BY days_overdue DESC
    `);
    res.json(r.rows.map(row => ({
      id: row.id,
      invoiceNumber: row.invoice_number,
      customerName: row.customer_name,
      dueDate: row.due_date,
      invoiceDate: row.invoice_date,
      status: row.status,
      total: parseFloat(row.total || 0),
      paid: parseFloat(row.paid || 0),
      balance: parseFloat(row.total || 0) - parseFloat(row.paid || 0),
      daysOverdue: parseInt(row.days_overdue || 0),
      ageGroup: parseInt(row.days_overdue || 0) <= 0 ? 'Current'
              : parseInt(row.days_overdue) <= 30 ? '1–30 days'
              : parseInt(row.days_overdue) <= 60 ? '31–60 days'
              : parseInt(row.days_overdue) <= 90 ? '61–90 days'
              : '90+ days',
    })));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/reports/summary', async (req, res) => {
  try {
    const [inv, po, cust, supp] = await Promise.all([
      pool.query(`
        SELECT
          SUM(CASE WHEN status='paid' THEN ${invTotal} ELSE 0 END) as revenue,
          SUM(CASE WHEN status IN('draft','sent') AND NOT (status='sent' AND due_date<NOW()) THEN ${invTotal} ELSE 0 END) as outstanding,
          SUM(CASE WHEN status='sent' AND due_date<NOW() THEN ${invTotal} ELSE 0 END) as overdue,
          COUNT(*) as total_invoices,
          COUNT(CASE WHEN status='paid' THEN 1 END) as paid_count
        FROM invoices
      `),
      pool.query(`
        SELECT
          SUM(${poTotal}) as total_ordered,
          SUM(CASE WHEN status='received' THEN ${poTotal} ELSE 0 END) as total_received,
          COUNT(*) as total_pos
        FROM purchase_orders
      `),
      pool.query('SELECT COUNT(*) as cnt FROM customers'),
      pool.query('SELECT COUNT(*) as cnt FROM suppliers'),
    ]);
    const r = inv.rows[0], p = po.rows[0];
    res.json({
      revenue: parseFloat(r.revenue || 0),
      outstanding: parseFloat(r.outstanding || 0),
      overdue: parseFloat(r.overdue || 0),
      totalInvoices: parseInt(r.total_invoices || 0),
      paidInvoices: parseInt(r.paid_count || 0),
      totalOrdered: parseFloat(p.total_ordered || 0),
      totalReceived: parseFloat(p.total_received || 0),
      totalPOs: parseInt(p.total_pos || 0),
      customers: parseInt(cust.rows[0].cnt || 0),
      suppliers: parseInt(supp.rows[0].cnt || 0),
      netPosition: parseFloat(r.revenue || 0) - parseFloat(p.total_received || 0),
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
