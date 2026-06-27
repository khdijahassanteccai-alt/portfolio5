import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../utils/app_theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  bool _loading = false;

  Future<void> _exportBackupPdf() async {
    setState(() => _loading = true);
    try {
      final doctorId = _auth.currentDoctorId;
      final doctor = _auth.currentDoctor!;

      final patients = await _db.getAllPatients(doctorId: doctorId);
      final appointments = await _db.getAllAppointments(doctorId: doctorId);
      final prescriptions = await _db.getAllPrescriptions(doctorId: doctorId);
      final invoices = await _db.getAllInvoices(doctorId: doctorId);

      final bytes = await PdfService.generateBackupPdf(
        doctor: doctor,
        patients: patients,
        appointments: appointments,
        prescriptions: prescriptions,
        invoices: invoices,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'backup_${doctor.name}_${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تصدير النسخة الاحتياطية: $e',
                style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _auth.currentDoctor;

    return Scaffold(
      appBar: AppBar(
          title: Text('النسخ الاحتياطي', style: GoogleFonts.cairo())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.backup_outlined,
                      size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'نسخ احتياطي لبياناتك',
                    style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قم بتصدير كافة بيانات عيادتك كملف PDF\nشامل للمرضى والمواعيد والوصفات والفواتير',
                    style: GoogleFonts.cairo(
                        fontSize: 13, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('محتوى النسخة الاحتياطية',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary)),
                    ]),
                    const Divider(height: 20),
                    _infoRow(Icons.person_outline, 'بيانات جميع المرضى'),
                    _infoRow(Icons.calendar_today_outlined,
                        'سجل المواعيد كاملاً'),
                    _infoRow(Icons.description_outlined,
                        'الوصفات الطبية بالتفصيل'),
                    _infoRow(Icons.receipt_long_outlined,
                        'الفواتير والمبالغ'),
                    _infoRow(Icons.local_hospital_outlined,
                        'بيانات الطبيب: ${doctor?.name ?? ''}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: AppTheme.warning.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined,
                        color: AppTheme.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ينصح بعمل نسخة احتياطية بشكل دوري لحماية بياناتك',
                        style: GoogleFonts.cairo(
                            fontSize: 13, color: AppTheme.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _exportBackupPdf,
                icon: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 24),
                label: Text(
                  _loading ? 'جاري التصدير...' : 'تصدير نسخة احتياطية PDF',
                  style: GoogleFonts.cairo(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'سيتم فتح الملف للمعاينة والمشاركة عبر واتساب أو البريد أو الحفظ',
              style: GoogleFonts.cairo(
                  fontSize: 12, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.cairo(fontSize: 14, color: AppTheme.textPrimary)),
      ]),
    );
  }
}
