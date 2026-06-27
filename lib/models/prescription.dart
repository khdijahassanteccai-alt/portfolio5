class Medication {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String notes;

  Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'notes': notes,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      duration: map['duration'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}

class Prescription {
  final int? id;
  final int patientId;
  final String patientName;
  final String date;
  final String diagnosis;
  final List<Medication> medications;
  final String notes;
  final String createdAt;

  Prescription({
    this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.diagnosis,
    required this.medications,
    required this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'date': date,
      'diagnosis': diagnosis,
      'medications': medications.map((m) => m.toMap()).toList().toString(),
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: map['id'],
      patientId: map['patientId'] ?? 0,
      patientName: map['patientName'] ?? '',
      date: map['date'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      medications: _parseMedications(map['medications'] ?? ''),
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }

  static List<Medication> _parseMedications(String raw) {
    // Simple parsing - stored as pipe-separated records
    if (raw.isEmpty) return [];
    try {
      final parts = raw.split('|||');
      return parts.where((p) => p.isNotEmpty).map((p) {
        final fields = p.split('|');
        return Medication(
          name: fields.length > 0 ? fields[0] : '',
          dosage: fields.length > 1 ? fields[1] : '',
          frequency: fields.length > 2 ? fields[2] : '',
          duration: fields.length > 3 ? fields[3] : '',
          notes: fields.length > 4 ? fields[4] : '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static String medicationsToString(List<Medication> meds) {
    return meds.map((m) {
      return '${m.name}|${m.dosage}|${m.frequency}|${m.duration}|${m.notes}';
    }).join('|||');
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'date': date,
      'diagnosis': diagnosis,
      'medications': medicationsToString(medications),
      'notes': notes,
      'createdAt': createdAt,
    };
  }
}
