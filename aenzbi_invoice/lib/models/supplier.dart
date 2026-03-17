class Supplier {
  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String address;
  final String website;
  final String taxId;
  final String paymentTerms;
  final String notes;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.company = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.website = '',
    this.taxId = '',
    this.paymentTerms = 'Net 30',
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayName => company.isNotEmpty ? company : name;
  String get contactDisplay => company.isNotEmpty ? name : '';

  String get initials {
    final target = company.isNotEmpty ? company : name;
    final parts = target.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return target.isNotEmpty ? target[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'company': company,
        'email': email,
        'phone': phone,
        'address': address,
        'website': website,
        'taxId': taxId,
        'paymentTerms': paymentTerms,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Supplier.fromMap(Map<dynamic, dynamic> map) => Supplier(
        id: map['id'] as String,
        name: map['name'] as String,
        company: (map['company'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
        address: (map['address'] as String?) ?? '',
        website: (map['website'] as String?) ?? '',
        taxId: (map['taxId'] as String?) ?? '',
        paymentTerms: (map['paymentTerms'] as String?) ?? 'Net 30',
        notes: (map['notes'] as String?) ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Supplier copyWith({
    String? name,
    String? company,
    String? email,
    String? phone,
    String? address,
    String? website,
    String? taxId,
    String? paymentTerms,
    String? notes,
  }) =>
      Supplier(
        id: id,
        name: name ?? this.name,
        company: company ?? this.company,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        website: website ?? this.website,
        taxId: taxId ?? this.taxId,
        paymentTerms: paymentTerms ?? this.paymentTerms,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  static const List<String> paymentTermsOptions = [
    'Immediate',
    'Net 7',
    'Net 15',
    'Net 30',
    'Net 45',
    'Net 60',
    'Net 90',
    'Custom',
  ];
}
