class Patient {
  final int? id;
  final String name;
  final String phone;
  final String birthDate;
  final String gender;
  final String bloodType;
  final String address;
  final String notes;
  final String createdAt;
  // ─── Medical record ───────────────────────────────────────────────────────
  final String chronicDiseases;
  final String drugAllergies;
  final String previousSurgeries;
  final String currentMedications;
  final String medicalHistory;

  Patient({
    this.id,
    required this.name,
    required this.phone,
    required this.birthDate,
    required this.gender,
    required this.bloodType,
    required this.address,
    required this.notes,
    required this.createdAt,
    this.chronicDiseases = '',
    this.drugAllergies = '',
    this.previousSurgeries = '',
    this.currentMedications = '',
    this.medicalHistory = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'birthDate': birthDate,
      'gender': gender,
      'bloodType': bloodType,
      'address': address,
      'notes': notes,
      'createdAt': createdAt,
      'chronicDiseases': chronicDiseases,
      'drugAllergies': drugAllergies,
      'previousSurgeries': previousSurgeries,
      'currentMedications': currentMedications,
      'medicalHistory': medicalHistory,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      birthDate: map['birthDate'] ?? '',
      gender: map['gender'] ?? '',
      bloodType: map['bloodType'] ?? '',
      address: map['address'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] ?? '',
      chronicDiseases: map['chronicDiseases'] ?? '',
      drugAllergies: map['drugAllergies'] ?? '',
      previousSurgeries: map['previousSurgeries'] ?? '',
      currentMedications: map['currentMedications'] ?? '',
      medicalHistory: map['medicalHistory'] ?? '',
    );
  }

  Patient copyWith({
    int? id,
    String? name,
    String? phone,
    String? birthDate,
    String? gender,
    String? bloodType,
    String? address,
    String? notes,
    String? createdAt,
    String? chronicDiseases,
    String? drugAllergies,
    String? previousSurgeries,
    String? currentMedications,
    String? medicalHistory,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      chronicDiseases: chronicDiseases ?? this.chronicDiseases,
      drugAllergies: drugAllergies ?? this.drugAllergies,
      previousSurgeries: previousSurgeries ?? this.previousSurgeries,
      currentMedications: currentMedications ?? this.currentMedications,
      medicalHistory: medicalHistory ?? this.medicalHistory,
    );
  }

  int get age {
    if (birthDate.isEmpty) return 0;
    try {
      final birth = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 0;
    }
  }
}
