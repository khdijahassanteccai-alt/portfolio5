class Appointment {
  final int? id;
  final int patientId;
  final String patientName;
  final String date;
  final String time;
  final String type;
  final String status;
  final String notes;
  final String createdAt;

  Appointment({
    this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.time,
    required this.type,
    required this.status,
    required this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'date': date,
      'time': time,
      'type': type,
      'status': status,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'],
      patientId: map['patientId'] ?? 0,
      patientName: map['patientName'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      type: map['type'] ?? '',
      status: map['status'] ?? 'pending',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }

  Appointment copyWith({
    int? id,
    int? patientId,
    String? patientName,
    String? date,
    String? time,
    String? type,
    String? status,
    String? notes,
    String? createdAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      date: date ?? this.date,
      time: time ?? this.time,
      type: type ?? this.type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'قيد الانتظار';
    }
  }
}
