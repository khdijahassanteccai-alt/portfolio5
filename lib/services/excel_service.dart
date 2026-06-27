import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/appointment.dart';
import '../models/invoice.dart';
import '../models/patient.dart';

class ExcelService {
  // ─── Patients ─────────────────────────────────────────────────────────────

  static Future<void> exportPatients(List<Patient> patients) async {
    final excel = Excel.createExcel();
    final sheet = excel['المرضى'];
    try { excel.delete('Sheet1'); } catch (_) {}

    sheet.appendRow([
      TextCellValue('#'),
      TextCellValue('الاسم'),
      TextCellValue('الهاتف'),
      TextCellValue('الجنس'),
      TextCellValue('فصيلة الدم'),
      TextCellValue('تاريخ الميلاد'),
      TextCellValue('العنوان'),
    ]);

    for (final p in patients) {
      sheet.appendRow([
        IntCellValue(p.id ?? 0),
        TextCellValue(p.name),
        TextCellValue(p.phone),
        TextCellValue(p.gender),
        TextCellValue(p.bloodType),
        TextCellValue(p.birthDate),
        TextCellValue(p.address),
      ]);
    }

    await _saveAndShare(excel, 'patients.xlsx', 'قائمة المرضى');
  }

  // ─── Appointments ─────────────────────────────────────────────────────────

  static Future<void> exportAppointments(List<Appointment> appointments) async {
    final excel = Excel.createExcel();
    final sheet = excel['المواعيد'];
    try { excel.delete('Sheet1'); } catch (_) {}

    sheet.appendRow([
      TextCellValue('#'),
      TextCellValue('المريض'),
      TextCellValue('التاريخ'),
      TextCellValue('الوقت'),
      TextCellValue('النوع'),
      TextCellValue('الحالة'),
      TextCellValue('ملاحظات'),
    ]);

    for (final a in appointments) {
      sheet.appendRow([
        IntCellValue(a.id ?? 0),
        TextCellValue(a.patientName),
        TextCellValue(a.date),
        TextCellValue(a.time),
        TextCellValue(a.type),
        TextCellValue(a.statusLabel),
        TextCellValue(a.notes),
      ]);
    }

    await _saveAndShare(excel, 'appointments.xlsx', 'قائمة المواعيد');
  }

  // ─── Invoices ─────────────────────────────────────────────────────────────

  static Future<void> exportInvoices(List<Invoice> invoices) async {
    final excel = Excel.createExcel();
    final sheet = excel['الفواتير'];
    try { excel.delete('Sheet1'); } catch (_) {}

    sheet.appendRow([
      TextCellValue('#'),
      TextCellValue('المريض'),
      TextCellValue('التاريخ'),
      TextCellValue('المبلغ'),
      TextCellValue('الحالة'),
      TextCellValue('ملاحظات'),
    ]);

    for (final inv in invoices) {
      sheet.appendRow([
        IntCellValue(inv.id ?? 0),
        TextCellValue(inv.patientName),
        TextCellValue(inv.date),
        DoubleCellValue(inv.total),
        TextCellValue(inv.statusLabel),
        TextCellValue(inv.notes),
      ]);
    }

    await _saveAndShare(excel, 'invoices.xlsx', 'قائمة الفواتير');
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  static Future<void> _saveAndShare(
      Excel excel, String filename, String subject) async {
    final bytes = excel.save();
    if (bytes == null) throw Exception('فشل إنشاء ملف Excel');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ],
      subject: subject,
    );
  }
}
