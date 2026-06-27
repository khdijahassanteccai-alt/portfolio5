class InvoiceItem {
  final String name;
  final double price;
  final int quantity;

  InvoiceItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;

  static String listToString(List<InvoiceItem> items) {
    return items
        .map((i) => '${i.name}|${i.price}|${i.quantity}')
        .join('|||');
  }

  static List<InvoiceItem> listFromString(String raw) {
    if (raw.isEmpty) return [];
    return raw.split('|||').where((s) => s.isNotEmpty).map((s) {
      final parts = s.split('|');
      return InvoiceItem(
        name: parts.length > 0 ? parts[0] : '',
        price: parts.length > 1 ? double.tryParse(parts[1]) ?? 0.0 : 0.0,
        quantity: parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1,
      );
    }).toList();
  }
}

class Invoice {
  final int? id;
  final int doctorId;
  final int patientId;
  final String patientName;
  final String date;
  final List<InvoiceItem> items;
  final double total;
  final String status;
  final String notes;
  final String createdAt;

  Invoice({
    this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.items,
    required this.total,
    required this.status,
    required this.notes,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'unpaid':
        return 'غير مدفوعة';
      default:
        return 'غير مدفوعة';
    }
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'doctorId': doctorId,
        'patientId': patientId,
        'patientName': patientName,
        'date': date,
        'items': InvoiceItem.listToString(items),
        'total': total,
        'status': status,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'],
        doctorId: map['doctorId'] ?? 1,
        patientId: map['patientId'] ?? 0,
        patientName: map['patientName'] ?? '',
        date: map['date'] ?? '',
        items: InvoiceItem.listFromString(map['items'] ?? ''),
        total: (map['total'] as num?)?.toDouble() ?? 0.0,
        status: map['status'] ?? 'unpaid',
        notes: map['notes'] ?? '',
        createdAt: map['createdAt'] ?? '',
      );
}
