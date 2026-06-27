import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:doctor/database/database_helper.dart';
import 'package:doctor/models/patient.dart';
import 'package:doctor/models/appointment.dart';
import 'package:doctor/models/invoice.dart';
import 'helpers/test_db_helper.dart';

void main() {
  late Database db;
  late DatabaseHelper helper;
  const doctorId = 1;

  setUp(() async {
    db = await openTestDb();
    helper = DatabaseHelper();
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Patients ────────────────────────────────────────────────────────────────

  group('المرضى', () {
    test('إضافة مريض واسترجاعه', () async {
      final patient = Patient(
        name: 'علي حسن',
        phone: '07711111111',
        birthDate: '1990-05-15',
        gender: 'ذكر',
        bloodType: 'A+',
        address: 'بغداد',
        notes: '',
        createdAt: '2026-01-01',
      );

      final id = await helper.insertPatient(patient, doctorId: doctorId);
      expect(id, greaterThan(0));

      final fetched = await helper.getPatientById(id);
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('علي حسن'));
      expect(fetched.phone, equals('07711111111'));
      expect(fetched.bloodType, equals('A+'));
    });

    test('تعديل بيانات مريض', () async {
      final patient = Patient(
        name: 'سارة أحمد',
        phone: '07722222222',
        birthDate: '1985-03-20',
        gender: 'أنثى',
        bloodType: 'B+',
        address: 'الموصل',
        notes: '',
        createdAt: '2026-01-01',
      );
      final id = await helper.insertPatient(patient, doctorId: doctorId);

      final updated = patient.copyWith(id: id, name: 'سارة محمد', address: 'أربيل');
      await helper.updatePatient(updated);

      final fetched = await helper.getPatientById(id);
      expect(fetched!.name, equals('سارة محمد'));
      expect(fetched.address, equals('أربيل'));
      expect(fetched.phone, equals('07722222222')); // لم يتغير
    });

    test('حذف مريض', () async {
      final patient = Patient(
        name: 'محمد خالد',
        phone: '07733333333',
        birthDate: '2000-01-01',
        gender: 'ذكر',
        bloodType: 'O-',
        address: '',
        notes: '',
        createdAt: '2026-01-01',
      );
      final id = await helper.insertPatient(patient, doctorId: doctorId);

      await helper.deletePatient(id);

      final fetched = await helper.getPatientById(id);
      expect(fetched, isNull);
    });

    test('قائمة المرضى تعيد فقط مرضى الطبيب الصحيح', () async {
      final p1 = Patient(name: 'مريض-1', phone: '', birthDate: '', gender: '',
          bloodType: '', address: '', notes: '', createdAt: '2026-01-01');
      final p2 = Patient(name: 'مريض-2', phone: '', birthDate: '', gender: '',
          bloodType: '', address: '', notes: '', createdAt: '2026-01-01');

      await helper.insertPatient(p1, doctorId: doctorId);
      await helper.insertPatient(p2, doctorId: 99); // طبيب آخر

      final list = await helper.getAllPatients(doctorId: doctorId);
      expect(list.length, equals(1));
      expect(list.first.name, equals('مريض-1'));
    });
  });

  // ─── Appointments ─────────────────────────────────────────────────────────────

  group('المواعيد', () {
    test('إضافة موعد وربطه بمريض', () async {
      final patient = Patient(
        name: 'فاطمة علي',
        phone: '07744444444',
        birthDate: '1995-07-10',
        gender: 'أنثى',
        bloodType: 'AB+',
        address: 'البصرة',
        notes: '',
        createdAt: '2026-01-01',
      );
      final patientId = await helper.insertPatient(patient, doctorId: doctorId);

      final appointment = Appointment(
        patientId: patientId,
        patientName: 'فاطمة علي',
        date: '2026-06-25',
        time: '10:00',
        type: 'كشف',
        status: 'pending',
        notes: '',
        createdAt: '2026-01-01',
      );
      final apptId = await helper.insertAppointment(appointment, doctorId: doctorId);
      expect(apptId, greaterThan(0));

      final byPatient = await helper.getAppointmentsByPatient(patientId);
      expect(byPatient.length, equals(1));
      expect(byPatient.first.patientId, equals(patientId));
      expect(byPatient.first.date, equals('2026-06-25'));
      expect(byPatient.first.time, equals('10:00'));
    });

    test('تغيير حالة الموعد', () async {
      final apptId = await helper.insertAppointment(
        Appointment(
          patientId: 1,
          patientName: 'اختبار',
          date: '2026-06-30',
          time: '09:00',
          type: 'متابعة',
          status: 'pending',
          notes: '',
          createdAt: '2026-01-01',
        ),
        doctorId: doctorId,
      );

      await helper.updateAppointmentStatus(apptId, 'completed');

      final appts = await helper.getAllAppointments(doctorId: doctorId);
      expect(appts.first.status, equals('completed'));
    });

    test('حذف المريض يحذف مواعيده تلقائياً', () async {
      final pid = await helper.insertPatient(
        Patient(name: 'حذف تسلسلي', phone: '', birthDate: '',
            gender: '', bloodType: '', address: '', notes: '', createdAt: '2026-01-01'),
        doctorId: doctorId,
      );
      await helper.insertAppointment(
        Appointment(patientId: pid, patientName: 'حذف تسلسلي',
            date: '2026-07-01', time: '08:00', type: 'كشف',
            status: 'pending', notes: '', createdAt: '2026-01-01'),
        doctorId: doctorId,
      );

      await helper.deletePatient(pid);

      final appts = await helper.getAppointmentsByPatient(pid);
      expect(appts, isEmpty);
    });
  });

  // ─── Invoices & Revenue ───────────────────────────────────────────────────────

  group('الفواتير والإيرادات', () {
    test('إضافة فاتورة واسترجاعها', () async {
      final invoice = Invoice(
        doctorId: doctorId,
        patientId: 1,
        patientName: 'اختبار فاتورة',
        date: '2026-06-22',
        items: [InvoiceItem(name: 'كشف', price: 15000, quantity: 1)],
        total: 15000,
        status: 'paid',
        notes: '',
        createdAt: '2026-06-22',
      );

      final id = await helper.insertInvoice(invoice);
      expect(id, greaterThan(0));

      final list = await helper.getAllInvoices(doctorId: doctorId);
      expect(list.length, equals(1));
      expect(list.first.total, equals(15000));
      expect(list.first.status, equals('paid'));
    });

    test('getTotalRevenue يجمع الفواتير المدفوعة فقط', () async {
      await helper.insertInvoice(Invoice(
        doctorId: doctorId, patientId: 1, patientName: 'أ',
        date: '2026-06-01', items: [], total: 50000,
        status: 'paid', notes: '', createdAt: '2026-06-01',
      ));
      await helper.insertInvoice(Invoice(
        doctorId: doctorId, patientId: 1, patientName: 'ب',
        date: '2026-06-02', items: [], total: 30000,
        status: 'paid', notes: '', createdAt: '2026-06-02',
      ));
      await helper.insertInvoice(Invoice(
        doctorId: doctorId, patientId: 1, patientName: 'ج',
        date: '2026-06-03', items: [], total: 20000,
        status: 'unpaid', notes: '', createdAt: '2026-06-03', // غير مدفوعة
      ));

      final revenue = await helper.getTotalRevenue(doctorId: doctorId);
      expect(revenue, equals(80000.0)); // 50000 + 30000 فقط
    });

    test('getTotalRevenue يُعيد صفر إذا لا توجد فواتير مدفوعة', () async {
      final revenue = await helper.getTotalRevenue(doctorId: doctorId);
      expect(revenue, equals(0.0));
    });

    test('getTotalRevenue لا يشمل فواتير طبيب آخر', () async {
      await helper.insertInvoice(Invoice(
        doctorId: doctorId, patientId: 1, patientName: 'أ',
        date: '2026-06-01', items: [], total: 100000,
        status: 'paid', notes: '', createdAt: '2026-06-01',
      ));
      await helper.insertInvoice(Invoice(
        doctorId: 99, patientId: 1, patientName: 'ب', // طبيب آخر
        date: '2026-06-01', items: [], total: 999999,
        status: 'paid', notes: '', createdAt: '2026-06-01',
      ));

      final revenue = await helper.getTotalRevenue(doctorId: doctorId);
      expect(revenue, equals(100000.0));
    });
  });
}
