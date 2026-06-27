class Visit {
  final int? id;
  final int patientId;
  final int doctorId;
  final String visitDate;
  final String visitType;
  final String notes;
  final String createdAt;

  Visit({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.visitDate,
    required this.visitType,
    this.notes = '',
    required this.createdAt,
  });

  factory Visit.fromMap(Map<String, dynamic> m) => Visit(
        id: m['id'] as int?,
        patientId: m['patientId'] as int,
        doctorId: m['doctorId'] as int,
        visitDate: m['visitDate'] as String,
        visitType: m['visitType'] as String,
        notes: (m['notes'] as String?) ?? '',
        createdAt: m['createdAt'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'patientId': patientId,
        'doctorId': doctorId,
        'visitDate': visitDate,
        'visitType': visitType,
        'notes': notes,
        'createdAt': createdAt,
      };
}
