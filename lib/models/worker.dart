class Worker {
  final String id;
  final String name;
  final String phone;
  final double monthlySalary;
  final bool active;

  const Worker({
    required this.id,
    required this.name,
    this.phone = '',
    this.monthlySalary = 0,
    this.active = true,
  });

  factory Worker.fromMap(String id, Map<String, dynamic> data) {
    return Worker(
      id: id,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      monthlySalary: (data['monthlySalary'] as num?)?.toDouble() ?? 0,
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'monthlySalary': monthlySalary,
      'active': active,
    };
  }

  Worker copyWith({
    String? name,
    String? phone,
    double? monthlySalary,
    bool? active,
  }) {
    return Worker(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      active: active ?? this.active,
    );
  }
}
