enum InvoiceStatus { draft, sent, paid, overdue }

extension InvoiceStatusExt on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
    }
  }

  String get value => name;

  static InvoiceStatus fromString(String s) {
    switch (s) {
      case 'sent':
        return InvoiceStatus.sent;
      case 'paid':
        return InvoiceStatus.paid;
      case 'overdue':
        return InvoiceStatus.overdue;
      default:
        return InvoiceStatus.draft;
    }
  }
}

class InvoiceLineItem {
  final String description;
  final double quantity;
  final double unitPrice;

  const InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory InvoiceLineItem.fromMap(Map<dynamic, dynamic> map) => InvoiceLineItem(
        description: map['description'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unitPrice'] as num).toDouble(),
      );

  InvoiceLineItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
  }) =>
      InvoiceLineItem(
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String customerName;
  final String customerEmail;
  final List<InvoiceLineItem> items;
  final InvoiceStatus status;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String notes;
  final double taxRate;
  final DateTime createdAt;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.customerName,
    this.customerEmail = '',
    required this.items,
    this.status = InvoiceStatus.draft,
    DateTime? invoiceDate,
    DateTime? dueDate,
    this.notes = '',
    this.taxRate = 0.0,
    DateTime? createdAt,
  })  : invoiceDate = invoiceDate ?? DateTime.now(),
        dueDate = dueDate ??
            DateTime.now().add(const Duration(days: 30)),
        createdAt = createdAt ?? DateTime.now();

  double get subtotal => items.fold(0, (sum, i) => sum + i.total);
  double get taxAmount => subtotal * taxRate / 100;
  double get total => subtotal + taxAmount;

  bool get isOverdue =>
      status == InvoiceStatus.sent &&
      dueDate.isBefore(DateTime.now());

  InvoiceStatus get effectiveStatus => isOverdue ? InvoiceStatus.overdue : status;

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'items': items.map((i) => i.toMap()).toList(),
        'status': status.value,
        'invoiceDate': invoiceDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'notes': notes,
        'taxRate': taxRate,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Invoice.fromMap(Map<dynamic, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return Invoice(
      id: map['id'] as String,
      invoiceNumber: map['invoiceNumber'] as String,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String,
      customerEmail: (map['customerEmail'] as String?) ?? '',
      items: rawItems
          .map((e) => InvoiceLineItem.fromMap(e as Map))
          .toList(),
      status: InvoiceStatusExt.fromString(map['status'] as String),
      invoiceDate: DateTime.parse(map['invoiceDate'] as String),
      dueDate: DateTime.parse(map['dueDate'] as String),
      notes: (map['notes'] as String?) ?? '',
      taxRate: ((map['taxRate'] as num?) ?? 0).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Invoice copyWith({
    String? customerId,
    String? customerName,
    String? customerEmail,
    List<InvoiceLineItem>? items,
    InvoiceStatus? status,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? notes,
    double? taxRate,
  }) =>
      Invoice(
        id: id,
        invoiceNumber: invoiceNumber,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        customerEmail: customerEmail ?? this.customerEmail,
        items: items ?? this.items,
        status: status ?? this.status,
        invoiceDate: invoiceDate ?? this.invoiceDate,
        dueDate: dueDate ?? this.dueDate,
        notes: notes ?? this.notes,
        taxRate: taxRate ?? this.taxRate,
        createdAt: createdAt,
      );
}
