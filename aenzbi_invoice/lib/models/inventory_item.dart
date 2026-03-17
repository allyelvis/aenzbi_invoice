class InventoryItem {
  final String id;
  final String name;
  final String description;
  final String sku;
  final String category;
  final double price;
  final double costPrice;
  final int quantity;
  final int lowStockThreshold;
  final String unit;
  final String supplierId;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    this.description = '',
    this.sku = '',
    this.category = '',
    required this.price,
    this.costPrice = 0.0,
    required this.quantity,
    this.lowStockThreshold = 5,
    this.unit = 'pcs',
    this.supplierId = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => quantity <= lowStockThreshold;
  bool get isOutOfStock => quantity == 0;

  double get totalValue => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sku': sku,
      'category': category,
      'price': price,
      'costPrice': costPrice,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
      'supplierId': supplierId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InventoryItem.fromMap(Map<dynamic, dynamic> map) {
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      sku: (map['sku'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      price: (map['price'] as num).toDouble(),
      costPrice: ((map['costPrice'] as num?) ?? 0).toDouble(),
      quantity: map['quantity'] as int,
      lowStockThreshold: (map['lowStockThreshold'] as int?) ?? 5,
      unit: (map['unit'] as String?) ?? 'pcs',
      supplierId: (map['supplierId'] as String?) ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  InventoryItem copyWith({
    String? name,
    String? description,
    String? sku,
    String? category,
    double? price,
    double? costPrice,
    int? quantity,
    int? lowStockThreshold,
    String? unit,
    String? supplierId,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      unit: unit ?? this.unit,
      supplierId: supplierId ?? this.supplierId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
