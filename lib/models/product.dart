
class Product {
  final String id;
  final String name;
  final String unit;
  final double defaultMrp;
  final bool active;

  const Product({
    required this.id,
    required this.name,
    this.unit = 'Box',
    this.defaultMrp = 0,
    this.active = true,
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name']?.toString() ?? '',
      unit: data['unit']?.toString() ?? 'Box',
      defaultMrp: (data['defaultMrp'] as num?)?.toDouble() ?? 0,
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'defaultMrp': defaultMrp,
      'active': active,
    };
  }

  Product copyWith({
    String? name,
    String? unit,
    double? defaultMrp,
    bool? active,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      defaultMrp: defaultMrp ?? this.defaultMrp,
      active: active ?? this.active,
    );
  }
}
