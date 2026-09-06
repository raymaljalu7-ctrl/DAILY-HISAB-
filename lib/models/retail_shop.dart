
class RetailShop {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double commissionPerBox;
  final bool active;

  const RetailShop({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.commissionPerBox = 0,
    this.active = true,
  });

  factory RetailShop.fromMap(String id, Map<String, dynamic> data) {
    return RetailShop(
      id: id,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      commissionPerBox:
          (data['commissionPerBox'] as num?)?.toDouble() ?? 0,
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'commissionPerBox': commissionPerBox,
      'active': active,
    };
  }

  RetailShop copyWith({
    String? name,
    String? phone,
    String? address,
    double? commissionPerBox,
    bool? active,
  }) {
    return RetailShop(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      commissionPerBox: commissionPerBox ?? this.commissionPerBox,
      active: active ?? this.active,
    );
  }
}
