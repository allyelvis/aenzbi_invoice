import 'invoice.dart';

enum QuoteStatus {
  draft,
  sent,
  accepted,
  rejected,
  converted;

  String get label => name[0].toUpperCase() + name.substring(1);
}

class Quote {
  final String id;
  final String quoteNumber;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final List<InvoiceLineItem> items;
  final QuoteStatus status;
  final DateTime quoteDate;
  final DateTime validUntil;
  final double taxRate;
  final String notes;
  final String? convertedInvoiceId;

  const Quote({
    required this.id,
    required this.quoteNumber,
    this.customerId = '',
    required this.customerName,
    this.customerEmail = '',
    required this.items,
    this.status = QuoteStatus.draft,
    required this.quoteDate,
    required this.validUntil,
    this.taxRate = 0.0,
    this.notes = '',
    this.convertedInvoiceId,
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.total);
  double get taxAmount => subtotal * taxRate / 100;
  double get total => subtotal + taxAmount;

  bool get isExpired =>
      validUntil.isBefore(DateTime.now()) &&
      status != QuoteStatus.converted &&
      status != QuoteStatus.accepted;

  int get daysUntilExpiry =>
      validUntil.difference(DateTime.now()).inDays;

  factory Quote.fromMap(Map<dynamic, dynamic> m) {
    final rawItems = m['items'];
    List<InvoiceLineItem> items = [];
    if (rawItems is List) {
      items = rawItems
          .map((e) => InvoiceLineItem.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    }
    return Quote(
      id: m['id'] as String,
      quoteNumber: m['quoteNumber'] as String? ?? '',
      customerId: m['customerId'] as String? ?? '',
      customerName: m['customerName'] as String? ?? '',
      customerEmail: m['customerEmail'] as String? ?? '',
      items: items,
      status: _parseStatus(m['status'] as String? ?? 'draft'),
      quoteDate: _parseDate(m['quoteDate']),
      validUntil: _parseDate(m['validUntil']),
      taxRate: (m['taxRate'] as num?)?.toDouble() ?? 0.0,
      notes: m['notes'] as String? ?? '',
      convertedInvoiceId: m['convertedInvoiceId'] as String?,
    );
  }

  static QuoteStatus _parseStatus(String s) {
    return QuoteStatus.values.firstWhere((e) => e.name == s,
        orElse: () => QuoteStatus.draft);
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'quoteNumber': quoteNumber,
        'customerId': customerId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'items': items.map((i) => i.toMap()).toList(),
        'status': status.name,
        'quoteDate': quoteDate.toIso8601String(),
        'validUntil': validUntil.toIso8601String(),
        'taxRate': taxRate,
        'notes': notes,
      };

  Quote copyWith({
    String? id, String? quoteNumber, String? customerId,
    String? customerName, String? customerEmail,
    List<InvoiceLineItem>? items, QuoteStatus? status,
    DateTime? quoteDate, DateTime? validUntil,
    double? taxRate, String? notes, String? convertedInvoiceId,
  }) =>
      Quote(
        id: id ?? this.id,
        quoteNumber: quoteNumber ?? this.quoteNumber,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        customerEmail: customerEmail ?? this.customerEmail,
        items: items ?? this.items,
        status: status ?? this.status,
        quoteDate: quoteDate ?? this.quoteDate,
        validUntil: validUntil ?? this.validUntil,
        taxRate: taxRate ?? this.taxRate,
        notes: notes ?? this.notes,
        convertedInvoiceId: convertedInvoiceId ?? this.convertedInvoiceId,
      );
}
