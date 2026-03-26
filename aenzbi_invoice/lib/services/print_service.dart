// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:convert';
import '../models/invoice.dart';
import '../models/purchase_order.dart';
import '../models/app_settings.dart';
import 'currency_service.dart';

class PrintService {
  static void printInvoice(Invoice invoice, AppSettings settings) {
    final content = _invoiceHtml(invoice, settings);
    _openPrint(content);
  }

  static void printPurchaseOrder(PurchaseOrder po, AppSettings settings) {
    final content = _poHtml(po, settings);
    _openPrint(content);
  }

  static void _openPrint(String htmlContent) {
    final encoded = jsonEncode(htmlContent);
    js.context.callMethod('eval', ['''
      (function() {
        var w = window.open('', '_blank');
        if (!w) return;
        w.document.write($encoded);
        w.document.close();
        setTimeout(function(){ w.print(); }, 300);
      })();
    ''']);
  }

  static String _css() => '''
    <style>
      * { box-sizing: border-box; margin: 0; padding: 0; }
      body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 13px; color: #1a1a1a; background: #fff; }
      .page { max-width: 800px; margin: 0 auto; padding: 40px; }
      .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 32px; }
      .company { max-width: 50%; }
      .company h1 { font-size: 22px; font-weight: 700; color: #3F51B5; margin-bottom: 4px; }
      .company p { color: #555; font-size: 12px; line-height: 1.5; }
      .doc-info { text-align: right; }
      .doc-info h2 { font-size: 26px; font-weight: 700; color: #3F51B5; letter-spacing: 1px; }
      .doc-info .number { font-size: 16px; font-weight: 600; color: #333; margin: 4px 0; }
      .doc-info .date { font-size: 12px; color: #666; }
      .divider { border: none; border-top: 2px solid #3F51B5; margin: 20px 0; }
      .bill-ship { display: flex; gap: 40px; margin-bottom: 28px; }
      .bill-ship > div { flex: 1; }
      .bill-ship h3 { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: #3F51B5; margin-bottom: 6px; }
      .bill-ship p { font-size: 13px; line-height: 1.6; color: #333; }
      table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
      thead tr { background: #3F51B5; color: white; }
      thead th { padding: 10px 12px; text-align: left; font-size: 12px; font-weight: 600; }
      thead th.right { text-align: right; }
      tbody tr { border-bottom: 1px solid #eee; }
      tbody tr:nth-child(even) { background: #f8f9ff; }
      tbody td { padding: 9px 12px; font-size: 13px; }
      tbody td.right { text-align: right; }
      .totals { display: flex; justify-content: flex-end; margin-bottom: 24px; }
      .totals-box { width: 260px; }
      .totals-row { display: flex; justify-content: space-between; padding: 5px 0; font-size: 13px; color: #444; }
      .totals-row.total { font-size: 16px; font-weight: 700; color: #3F51B5; border-top: 2px solid #3F51B5; padding-top: 8px; margin-top: 4px; }
      .status-badge { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 11px; font-weight: 700; text-transform: uppercase; }
      .status-draft { background: #eee; color: #666; }
      .status-sent { background: #e3f2fd; color: #1565c0; }
      .status-paid { background: #e8f5e9; color: #2e7d32; }
      .status-overdue { background: #ffebee; color: #c62828; }
      .status-ordered { background: #e3f2fd; color: #1565c0; }
      .status-received { background: #e8f5e9; color: #2e7d32; }
      .status-cancelled { background: #ffebee; color: #c62828; }
      .notes { background: #f8f9ff; border-left: 3px solid #3F51B5; padding: 12px 16px; border-radius: 0 4px 4px 0; margin-bottom: 24px; }
      .notes h4 { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #3F51B5; margin-bottom: 4px; }
      .notes p { font-size: 13px; color: #444; line-height: 1.5; }
      .footer { text-align: center; color: #aaa; font-size: 11px; border-top: 1px solid #eee; padding-top: 16px; }
      @media print {
        body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        .page { padding: 24px; }
      }
    </style>
  ''';

  static String _statusBadge(String status) =>
      '<span class="status-badge status-$status">$status</span>';

  static String _fmt(double v) => CurrencyService.instance.format(v);
  static String _date(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  static String _invoiceHtml(Invoice invoice, AppSettings settings) {
    final items = invoice.items.map((item) => '''
      <tr>
        <td>${_esc(item.description)}</td>
        <td class="right">${item.quantity.toStringAsFixed(2)}</td>
        <td class="right">${_fmt(item.unitPrice)}</td>
        <td class="right">${_fmt(item.total)}</td>
      </tr>
    ''').join('');

    final status = invoice.effectiveStatus.name;
    final companyBlock = settings.companyName.isNotEmpty
        ? '<h1>${_esc(settings.companyName)}</h1>'
          '<p>${_esc(settings.companyAddress)}<br>'
          '${_esc(settings.companyEmail)}'
          '${settings.companyPhone.isNotEmpty ? '<br>${_esc(settings.companyPhone)}' : ''}</p>'
        : '<h1>Aenzbi Invoice</h1>';

    return '''<!DOCTYPE html><html><head><meta charset="utf-8">
      <title>Invoice ${_esc(invoice.invoiceNumber)}</title>${_css()}</head><body>
      <div class="page">
        <div class="header">
          <div class="company">$companyBlock</div>
          <div class="doc-info">
            <h2>INVOICE</h2>
            <div class="number">${_esc(invoice.invoiceNumber)}</div>
            ${_statusBadge(status)}
            <div class="date" style="margin-top:8px">
              Date: ${_date(invoice.invoiceDate)}<br>
              Due: ${_date(invoice.dueDate)}
            </div>
          </div>
        </div>
        <hr class="divider">
        <div class="bill-ship">
          <div>
            <h3>Bill To</h3>
            <p><strong>${_esc(invoice.customerName)}</strong><br>
            ${_esc(invoice.customerEmail)}</p>
          </div>
        </div>
        <table>
          <thead><tr>
            <th>Description</th>
            <th class="right">Qty</th>
            <th class="right">Unit Price</th>
            <th class="right">Total</th>
          </tr></thead>
          <tbody>$items</tbody>
        </table>
        <div class="totals"><div class="totals-box">
          <div class="totals-row"><span>Subtotal</span><span>${_fmt(invoice.subtotal)}</span></div>
          ${invoice.taxRate > 0 ? '<div class="totals-row"><span>Tax (${invoice.taxRate.toStringAsFixed(1)}%)</span><span>${_fmt(invoice.taxAmount)}</span></div>' : ''}
          <div class="totals-row total"><span>Total</span><span>${_fmt(invoice.total)}</span></div>
        </div></div>
        ${invoice.notes.isNotEmpty ? '<div class="notes"><h4>Notes</h4><p>${_esc(invoice.notes)}</p></div>' : ''}
        <div class="footer">Thank you for your business!</div>
      </div></body></html>''';
  }

  static String _poHtml(PurchaseOrder po, AppSettings settings) {
    final items = po.items.map((item) => '''
      <tr>
        <td>${_esc(item.description)}</td>
        <td class="right">${item.quantity.toStringAsFixed(2)}</td>
        <td class="right">${_fmt(item.unitCost)}</td>
        <td class="right">${_fmt(item.total)}</td>
      </tr>
    ''').join('');

    final status = po.status.name;
    final companyBlock = settings.companyName.isNotEmpty
        ? '<h1>${_esc(settings.companyName)}</h1>'
        : '<h1>Aenzbi Invoice</h1>';

    return '''<!DOCTYPE html><html><head><meta charset="utf-8">
      <title>Purchase Order ${_esc(po.poNumber)}</title>${_css()}</head><body>
      <div class="page">
        <div class="header">
          <div class="company">$companyBlock</div>
          <div class="doc-info">
            <h2>PURCHASE ORDER</h2>
            <div class="number">${_esc(po.poNumber)}</div>
            ${_statusBadge(status)}
            <div class="date" style="margin-top:8px">
              Order Date: ${_date(po.orderDate)}
              ${po.expectedDate != null ? '<br>Expected: ${_date(po.expectedDate!)}' : ''}
            </div>
          </div>
        </div>
        <hr class="divider">
        <div class="bill-ship">
          <div>
            <h3>Supplier</h3>
            <p><strong>${_esc(po.supplierName)}</strong></p>
          </div>
        </div>
        <table>
          <thead><tr>
            <th>Description</th>
            <th class="right">Qty</th>
            <th class="right">Unit Cost</th>
            <th class="right">Total</th>
          </tr></thead>
          <tbody>$items</tbody>
        </table>
        <div class="totals"><div class="totals-box">
          <div class="totals-row"><span>Subtotal</span><span>${_fmt(po.subtotal)}</span></div>
          ${po.taxRate > 0 ? '<div class="totals-row"><span>Tax (${po.taxRate.toStringAsFixed(1)}%)</span><span>${_fmt(po.taxAmount)}</span></div>' : ''}
          <div class="totals-row total"><span>Total</span><span>${_fmt(po.total)}</span></div>
        </div></div>
        ${po.notes.isNotEmpty ? '<div class="notes"><h4>Notes</h4><p>${_esc(po.notes)}</p></div>' : ''}
        <div class="footer">Generated by Aenzbi Invoice</div>
      </div></body></html>''';
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
