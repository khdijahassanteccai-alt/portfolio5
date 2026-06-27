class Doctor {
  final int? id;
  final String name;
  final String specialty;
  final String phone;
  final String clinicName;
  final String address;
  final String username;
  final String password;
  final String createdAt;

  Doctor({
    this.id,
    required this.name,
    required this.specialty,
    required this.phone,
    required this.clinicName,
    this.address = '',
    required this.username,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'specialty': specialty,
        'phone': phone,
        'clinicName': clinicName,
        'address': address,
        'username': username,
        'password': password,
        'createdAt': createdAt,
      };

  factory Doctor.fromMap(Map<String, dynamic> map) => Doctor(
        id: map['id'],
        name: map['name'] ?? '',
        specialty: map['specialty'] ?? '',
        phone: map['phone'] ?? '',
        clinicName: map['clinicName'] ?? '',
        address: map['address'] ?? '',
        username: map['username'] ?? '',
        password: map['password'] ?? '',
        createdAt: map['createdAt'] ?? '',
      );

  Doctor copyWith({
    int? id,
    String? name,
    String? specialty,
    String? phone,
    String? clinicName,
    String? address,
    String? username,
    String? password,
    String? createdAt,
  }) =>
      Doctor(
        id: id ?? this.id,
        name: name ?? this.name,
        specialty: specialty ?? this.specialty,
        phone: phone ?? this.phone,
        clinicName: clinicName ?? this.clinicName,
        address: address ?? this.address,
        username: username ?? this.username,
        password: password ?? this.password,
        createdAt: createdAt ?? this.createdAt,
      );
}
