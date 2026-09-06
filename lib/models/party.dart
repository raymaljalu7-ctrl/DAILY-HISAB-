class Party {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double openingBalance;
  final String openingType;
  final bool active;

  const Party({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.openingBalance = 0,
    this.openingType = 'Receivable',
    this.active = true,
  });

  factory Party.fromMap(String id, Map<String, dynamic> data) {
    return Party(
      id: id,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      openingBalance: (data['openingBalance'] as num?)?.toDouble() ??
          (data['opening'] as num?)?.toDouble() ??
          0,
      openingType: data['openingType']?.toString() ?? 'Receivable',
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'openingBalance': openingBalance,
      'openingType': openingType,
      'active': active,
    };
  }

  Party copyWith({
    String? name,
    String? phone,
    String? address,
    double? openingBalance,
    String? openingType,
    bool? active,
  }) {
    return Party(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      openingBalance: openingBalance ?? this.openingBalance,
      openingType: openingType ?? this.openingType,
      active: active ?? this.active,
    );
  }
}
