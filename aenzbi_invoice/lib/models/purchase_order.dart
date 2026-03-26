enum PurchaseOrderStatus { draft, ordered, received, cancelled }

extension PurchaseOrderStatusExt on PurchaseOrderStatus {
  String get label {
    switch (this) {
      case PurchaseOrderStatus.draft: return 'Draft';
      case PurchaseOrderStatus.ordered: return 'Ordered';
      case PurchaseOrderStatus.received: return 'Received';
      case PurchaseOrderStatus.cancelled: return 'Cancelled';
    }
  }

  String get value => name;

  static PurchaseOrderStatus fromString(String s) {
    switch (s) {
      case 'ordered': return PurchaseOrderStatus.ordered;
      case 'received': return PurchaseOrderStatus.received;
      case 'cancelled': return PurchaseOrderStatus.cancelled;
      default: return PurchaseOrderStatus.draft;
    }
  }
}

class PurchaseItem {
  final String description;
  final double quantity;
  final double unitCost;

  const PurchaseItem({
    required this.description,
    required this.quantity,
    required this.unitCost,
  });

  double get total => quantity * unitCost;

  Map<String, dynamic> toMap() => {
        'description': description,
        'quantity': quantity,
        'unitCost': unitCost,
      };

  factory PurchaseItem.fromMap(Map<dynamic, dynamic> map) => PurchaseItem(
        description: map['description'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unitCost: (map['unitCost'] as num).toDouble(),
      );

  PurchaseItem copyWith({String? description, double? quantity, double? unitCost}) =>
      PurchaseItem(
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
      );
}

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String? supplierId;
  final String supplierName;
  final List<PurchaseItem> items;
  final PurchaseOrderStatus status;
  final DateTime orderDate;
  final DateTime? expectedDate;
  final String notes;
  final double taxRate;
  final DateTime createdAt;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    this.supplierId,
    required this.supplierName,
    required this.items,
    this.status = PurchaseOrderStatus.draft,
    DateTime? orderDate,
    this.expectedDate,
    this.notes = '',
    this.taxRate = 0.0,
    DateTime? createdAt,
  })  : orderDate = orderDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  double get subtotal => items.fold(0, (s, i) => s + i.total);
  double get taxAmount => subtotal * taxRate / 100;
  double get total => subtotal + taxAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'poNumber': poNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'items': items.map((i) => i.toMap()).toList(),
        'status': status.value,
        'orderDate': orderDate.toIso8601String(),
        'expectedDate': expectedDate?.toIso8601String(),
        'notes': notes,
        'taxRate': taxRate,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PurchaseOrder.fromMap(Map<dynamic, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return PurchaseOrder(
      id: map['id'] as String,
      poNumber: map['poNumber'] as String,
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String,
      items: rawItems.map((e) => PurchaseItem.fromMap(e as Map)).toList(),
      status: PurchaseOrderStatusExt.fromString(map['status'] as String),
      orderDate: DateTime.parse(map['orderDate'] as String),
      expectedDate: map['expectedDate'] != null
          ? DateTime.parse(map['expectedDate'] as String)
          : null,
      notes: (map['notes'] as String?) ?? '',
      taxRate: ((map['taxRate'] as num?) ?? 0).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  PurchaseOrder copyWith({
    String? supplierId,
    String? supplierName,
    List<PurchaseItem>? items,
    PurchaseOrderStatus? status,
    DateTime? orderDate,
    DateTime? expectedDate,
    String? notes,
    double? taxRate,
  }) =>
      PurchaseOrder(
        id: id,
        poNumber: poNumber,
        supplierId: supplierId ?? this.supplierId,
        supplierName: supplierName ?? this.supplierName,
        items: items ?? this.items,
        status: status ?? this.status,
        orderDate: orderDate ?? this.orderDate,
        expectedDate: expectedDate ?? this.expectedDate,
        notes: notes ?? this.notes,
        taxRate: taxRate ?? this.taxRate,
        createdAt: createdAt,
      );
}
