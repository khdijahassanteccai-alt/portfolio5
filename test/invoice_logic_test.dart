import 'package:flutter_test/flutter_test.dart';
import 'package:doctor/models/invoice.dart';

void main() {
  group('InvoiceItem - حساب المجموع', () {
    test('السعر × الكمية صحيح', () {
      final item = InvoiceItem(name: 'كشف', price: 15000, quantity: 2);
      expect(item.total, equals(30000.0));
    });

    test('كمية 1 تُعيد السعر مباشرة', () {
      final item = InvoiceItem(name: 'تحليل', price: 25000, quantity: 1);
      expect(item.total, equals(25000.0));
    });

    test('سعر صفر يُعيد صفراً', () {
      final item = InvoiceItem(name: 'مجاني', price: 0, quantity: 5);
      expect(item.total, equals(0.0));
    });
  });

  group('InvoiceItem - تسلسل النص وإعادة التحليل', () {
    test('listToString ثم listFromString يُعيد نفس البيانات', () {
      final items = [
        InvoiceItem(name: 'كشف', price: 15000, quantity: 1),
        InvoiceItem(name: 'أشعة', price: 40000, quantity: 2),
        InvoiceItem(name: 'دواء', price: 5000, quantity: 3),
      ];

      final encoded = InvoiceItem.listToString(items);
      final decoded = InvoiceItem.listFromString(encoded);

      expect(decoded.length, equals(3));
      expect(decoded[0].name, equals('كشف'));
      expect(decoded[0].price, equals(15000));
      expect(decoded[1].name, equals('أشعة'));
      expect(decoded[1].quantity, equals(2));
      expect(decoded[2].total, equals(15000.0)); // 5000 × 3
    });

    test('قائمة فارغة تُعيد سلسلة فارغة ثم قائمة فارغة', () {
      final encoded = InvoiceItem.listToString([]);
      expect(encoded, equals(''));
      final decoded = InvoiceItem.listFromString(encoded);
      expect(decoded, isEmpty);
    });
  });

  group('منطق مجموع الفاتورة', () {
    test('مجموع عناصر متعددة صحيح', () {
      final items = [
        InvoiceItem(name: 'كشف', price: 15000, quantity: 1),   // 15000
        InvoiceItem(name: 'أشعة', price: 40000, quantity: 1),  // 40000
        InvoiceItem(name: 'دواء', price: 5000, quantity: 3),   // 15000
      ];

      final total = items.fold<double>(0, (sum, i) => sum + i.total);
      expect(total, equals(70000.0));
    });

    test('statusLabel صحيح للفاتورة المدفوعة والغير مدفوعة', () {
      final paid = Invoice(
        doctorId: 1, patientId: 1, patientName: 'أ',
        date: '2026-01-01', items: [], total: 0,
        status: 'paid', notes: '', createdAt: '2026-01-01',
      );
      final unpaid = paid.copyWith(status: 'unpaid');

      expect(paid.statusLabel, equals('مدفوعة'));
      expect(unpaid.statusLabel, equals('غير مدفوعة'));
    });

    test('مجموع الفواتير المدفوعة فقط من قائمة مختلطة', () {
      final invoices = [
        _makeInvoice(total: 50000, status: 'paid'),
        _makeInvoice(total: 30000, status: 'paid'),
        _makeInvoice(total: 20000, status: 'unpaid'),
        _makeInvoice(total: 10000, status: 'unpaid'),
      ];

      final paidTotal = invoices
          .where((inv) => inv.status == 'paid')
          .fold<double>(0, (sum, inv) => sum + inv.total);

      expect(paidTotal, equals(80000.0));
    });
  });
}

Invoice _makeInvoice({required double total, required String status}) {
  return Invoice(
    doctorId: 1,
    patientId: 1,
    patientName: 'اختبار',
    date: '2026-06-22',
    items: [],
    total: total,
    status: status,
    notes: '',
    createdAt: '2026-06-22',
  );
}

extension on Invoice {
  Invoice copyWith({String? status}) => Invoice(
        id: id,
        doctorId: doctorId,
        patientId: patientId,
        patientName: patientName,
        date: date,
        items: items,
        total: total,
        status: status ?? this.status,
        notes: notes,
        createdAt: createdAt,
      );
}
