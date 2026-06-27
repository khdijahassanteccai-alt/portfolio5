class QueueEntry {
  final int? id;
  final int doctorId;
  final String patientName;
  final int? patientId;
  final int sequenceNumber;
  final String status; // 'waiting' | 'serving' | 'done'
  final String date;   // YYYY-MM-DD
  final String createdAt;

  const QueueEntry({
    this.id,
    required this.doctorId,
    required this.patientName,
    this.patientId,
    required this.sequenceNumber,
    this.status = 'waiting',
    required this.date,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case 'serving':
        return 'تحت الكشف';
      case 'done':
        return 'تم';
      default:
        return 'منتظر';
    }
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'doctorId': doctorId,
        'patientName': patientName,
        'patientId': patientId,
        'sequenceNumber': sequenceNumber,
        'status': status,
        'date': date,
        'createdAt': createdAt,
      };

  factory QueueEntry.fromMap(Map<String, dynamic> m) => QueueEntry(
        id: m['id'] as int?,
        doctorId: m['doctorId'] as int? ?? 1,
        patientName: m['patientName'] as String,
        patientId: m['patientId'] as int?,
        sequenceNumber: m['sequenceNumber'] as int,
        status: m['status'] as String? ?? 'waiting',
        date: m['date'] as String,
        createdAt: m['createdAt'] as String,
      );

  QueueEntry copyWith({String? status}) => QueueEntry(
        id: id,
        doctorId: doctorId,
        patientName: patientName,
        patientId: patientId,
        sequenceNumber: sequenceNumber,
        status: status ?? this.status,
        date: date,
        createdAt: createdAt,
      );
}
