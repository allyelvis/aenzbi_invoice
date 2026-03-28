class Payment {
  final String id;
  final String invoiceId;
  final double amount;
  final DateTime paymentDate;
  final String method;
  final String reference;
  final String notes;

  const Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    this.method = 'cash',
    this.reference = '',
    this.notes = '',
  });

  static const methods = [
    'Cash',
    'Bank Transfer',
    'Mobile Money',
    'Cheque',
    'Credit Card',
    'Other',
  ];

  factory Payment.fromMap(Map<dynamic, dynamic> m) => Payment(
        id: m['id'] as String,
        invoiceId: m['invoiceId'] as String? ?? m['invoice_id'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        paymentDate: _parseDate(m['paymentDate'] ?? m['payment_date']),
        method: m['method'] as String? ?? 'Cash',
        reference: m['reference'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
      );

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceId': invoiceId,
        'amount': amount,
        'paymentDate':
            '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}',
        'method': method,
        'reference': reference,
        'notes': notes,
      };
}
