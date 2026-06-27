class Expense {
  final int? id;
  final int doctorId;
  final String category;
  final double amount;
  final String description;
  final String date; // YYYY-MM-DD
  final String createdAt;

  static const defaultCategories = [
    'إيجار',
    'كهرباء',
    'رواتب الموظفين',
    'مستلزمات طبية',
    'صيانة',
    'أخرى',
  ];

  const Expense({
    this.id,
    required this.doctorId,
    required this.category,
    required this.amount,
    this.description = '',
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'doctorId': doctorId,
        'category': category,
        'amount': amount,
        'description': description,
        'date': date,
        'createdAt': createdAt,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as int?,
        doctorId: m['doctorId'] as int? ?? 1,
        category: m['category'] as String? ?? 'أخرى',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        description: m['description'] as String? ?? '',
        date: m['date'] as String,
        createdAt: m['createdAt'] as String,
      );
}
