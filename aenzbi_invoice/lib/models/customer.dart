class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String address;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.company = '',
    this.address = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayName => company.isNotEmpty ? '$name ($company)' : name;
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'company': company,
        'address': address,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Customer.fromMap(Map<dynamic, dynamic> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        email: (map['email'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
        company: (map['company'] as String?) ?? '',
        address: (map['address'] as String?) ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Customer copyWith({
    String? name,
    String? email,
    String? phone,
    String? company,
    String? address,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        company: company ?? this.company,
        address: address ?? this.address,
        createdAt: createdAt,
      );
}
