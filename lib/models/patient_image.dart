class PatientImage {
  final int? id;
  final int patientId;
  final String imagePath;
  final String category; // 'أشعة'|'تحليل'|'قبل العلاج'|'بعد العلاج'|'أخرى'
  final String description;
  final String createdAt;
  final int doctorId;

  static const categories = [
    'أشعة',
    'تحليل',
    'قبل العلاج',
    'بعد العلاج',
    'أخرى',
  ];

  const PatientImage({
    this.id,
    required this.patientId,
    required this.imagePath,
    required this.category,
    this.description = '',
    required this.createdAt,
    required this.doctorId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'patientId': patientId,
        'imagePath': imagePath,
        'category': category,
        'description': description,
        'createdAt': createdAt,
        'doctorId': doctorId,
      };

  factory PatientImage.fromMap(Map<String, dynamic> m) => PatientImage(
        id: m['id'] as int?,
        patientId: m['patientId'] as int,
        imagePath: m['imagePath'] as String,
        category: m['category'] as String? ?? 'أخرى',
        description: m['description'] as String? ?? '',
        createdAt: m['createdAt'] as String,
        doctorId: m['doctorId'] as int? ?? 1,
      );
}
