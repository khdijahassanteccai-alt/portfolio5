import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../services/excel_service.dart';
import '../services/theme_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/app_theme.dart';
import 'register_doctor_screen.dart';
import 'login_screen.dart';

class DoctorSettingsScreen extends StatefulWidget {
  const DoctorSettingsScreen({super.key});

  @override
  State<DoctorSettingsScreen> createState() => _DoctorSettingsScreenState();
}

class _DoctorSettingsScreenState extends State<DoctorSettingsScreen> {
  final _auth = AuthService();
  final _theme = ThemeService();
  final _db = DatabaseHelper();
  bool _exporting = false;

  // WhatsApp settings
  final _waPhoneCtrl = TextEditingController();
  final _waTemplateCtrl = TextEditingController();
  final _waCountryCtrl = TextEditingController();
  bool _waSaving = false;

  // Signature
  String? _signaturePath;
  static const _keySignature = 'doctor_signature_path';

  // Clinic logo
  String? _logoPath;
  static const _keyLogo = 'clinic_logo_path';

  @override
  void initState() {
    super.initState();
    _loadWaSettings();
    _loadSignature();
    _loadLogo();
  }

  @override
  void dispose() {
    _waPhoneCtrl.dispose();
    _waTemplateCtrl.dispose();
    _waCountryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogo() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyLogo);
    if (mounted) setState(() => _logoPath = path);
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;
      final srcPath = result.files.single.path!;
      final dir = await getApplicationSupportDirectory();
      final dest = File('${dir.path}/clinic_logo.png');
      await File(srcPath).copy(dest.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLogo, dest.path);
      if (mounted) setState(() => _logoPath = dest.path);
    } catch (_) {}
  }

  Future<void> _clearLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLogo);
    if (mounted) setState(() => _logoPath = null);
  }

  Future<void> _loadSignature() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keySignature);
    if (mounted) setState(() => _signaturePath = path);
  }

  Future<void> _openSignaturePad() async {
    final ctrl = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('رسم التوقيع',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ارسم توقيعك بالإصبع أو الماوس في المساحة أدناه',
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Signature(
                        controller: ctrl,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => ctrl.clear(),
                icon: const Icon(Icons.refresh_outlined, size: 18),
                label: Text('مسح', style: GoogleFonts.cairo()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (ctrl.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('الرجاء رسم التوقيع أولاً',
                          style: GoogleFonts.cairo()),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                    ));
                    return;
                  }
                  final bytes = await ctrl.toPngBytes(
                      height: 300, width: 700);
                  if (bytes == null) return;
                  final dir = await getApplicationSupportDirectory();
                  final dest =
                      File('${dir.path}/doctor_signature.png');
                  await dest.writeAsBytes(bytes);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_keySignature, dest.path);
                  if (mounted) {
                    setState(() => _signaturePath = dest.path);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text('حفظ التوقيع',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }),
    );

    ctrl.dispose();
  }

  Future<void> _clearSignature() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySignature);
    if (mounted) setState(() => _signaturePath = null);
  }

  Future<void> _loadWaSettings() async {
    final phone = await WhatsAppService.getClinicPhone();
    final template = await WhatsAppService.getMessageTemplate();
    final countryCode = await WhatsAppService.getCountryCode();
    if (mounted) {
      setState(() {
        _waPhoneCtrl.text = phone;
        _waTemplateCtrl.text =
            template == WhatsAppService.defaultTemplate ? '' : template;
        _waCountryCtrl.text = countryCode;
      });
    }
  }

  Future<void> _saveWaSettings() async {
    setState(() => _waSaving = true);
    await WhatsAppService.saveClinicPhone(_waPhoneCtrl.text);
    final template = _waTemplateCtrl.text.trim().isEmpty
        ? WhatsAppService.defaultTemplate
        : _waTemplateCtrl.text.trim();
    await WhatsAppService.saveMessageTemplate(template);
    final code = _waCountryCtrl.text.trim().isEmpty
        ? WhatsAppService.defaultCountryCode
        : _waCountryCtrl.text.trim();
    await WhatsAppService.saveCountryCode(code);
    if (mounted) {
      setState(() => _waSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('تم حفظ إعدادات واتساب', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _exportExcel(String type) async {
    setState(() => _exporting = true);
    try {
      final doctorId = _auth.currentDoctorId;
      switch (type) {
        case 'patients':
          final patients = await _db.getAllPatients(doctorId: doctorId);
          await ExcelService.exportPatients(patients);
          break;
        case 'appointments':
          final appointments =
              await _db.getAllAppointments(doctorId: doctorId);
          await ExcelService.exportAppointments(appointments);
          break;
        case 'invoices':
          final invoices = await _db.getAllInvoices(doctorId: doctorId);
          await ExcelService.exportInvoices(invoices);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في التصدير: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسجيل الخروج', style: GoogleFonts.cairo()),
        content: Text('هل تريد تسجيل الخروج؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('خروج', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _auth.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _auth.currentDoctor;

    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات الحساب', style: GoogleFonts.cairo()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── Doctor profile ───────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        doctor?.name.isNotEmpty == true
                            ? doctor!.name[0]
                            : 'د',
                        style: GoogleFonts.cairo(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'د. ${doctor?.name ?? ''}',
                      style: GoogleFonts.cairo(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (doctor?.specialty.isNotEmpty == true)
                      Text(
                        doctor!.specialty,
                        style: GoogleFonts.cairo(
                            color: AppTheme.textSecondary, fontSize: 15),
                      ),
                    if (doctor?.clinicName.isNotEmpty == true)
                      Text(
                        doctor!.clinicName,
                        style: GoogleFonts.cairo(
                            color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    if (doctor?.phone.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              doctor!.phone,
                              style: GoogleFonts.cairo(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Color theme picker ───────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.palette_outlined,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'لون التطبيق',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primary),
                      ),
                    ]),
                    const Divider(height: 20),
                    ValueListenableBuilder<int>(
                      valueListenable: _theme.colorIndex,
                      builder: (_, currentIndex, __) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(
                          ThemeService.presets.length,
                          (i) => _ColorSwatch(
                            preset: ThemeService.presets[i],
                            isSelected: i == currentIndex,
                            onTap: () => _theme.setColor(i),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Excel export ─────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.table_chart_outlined,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'تصدير البيانات Excel',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primary),
                      ),
                    ]),
                    const Divider(height: 20),
                    if (_exporting)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _ExcelBtn(
                              label: 'المرضى',
                              icon: Icons.people_outline,
                              onTap: () => _exportExcel('patients'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ExcelBtn(
                              label: 'المواعيد',
                              icon: Icons.calendar_today_outlined,
                              onTap: () => _exportExcel('appointments'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ExcelBtn(
                              label: 'الفواتير',
                              icon: Icons.receipt_long_outlined,
                              onTap: () => _exportExcel('invoices'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Clinic Logo ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.image_outlined,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('شعار العيادة (اللوغو)',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary)),
                    ]),
                    const Divider(height: 20),
                    Text(
                      'يظهر الشعار في ترويسة الوصفات الطبية المطبوعة.',
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    if (_logoPath != null &&
                        File(_logoPath!).existsSync()) ...[
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_logoPath!),
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: Text(
                              _logoPath != null ? 'تغيير الشعار' : 'رفع صورة الشعار',
                              style: GoogleFonts.cairo(),
                            ),
                          ),
                        ),
                        if (_logoPath != null) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _clearLogo,
                            icon: Icon(Icons.delete_outline, color: AppTheme.error),
                            tooltip: 'حذف الشعار',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Signature pad ────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.draw_outlined,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('توقيع الطبيب الإلكتروني',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary)),
                    ]),
                    const Divider(height: 20),
                    Text(
                      'يظهر التوقيع تلقائياً في أسفل الوصفات والتقارير المطبوعة.',
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    if (_signaturePath != null &&
                        File(_signaturePath!).existsSync()) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.file(
                          File(_signaturePath!),
                          height: 70,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openSignaturePad,
                            icon: const Icon(Icons.draw_outlined, size: 18),
                            label: Text(
                              _signaturePath != null
                                  ? 'إعادة رسم التوقيع'
                                  : 'رسم التوقيع',
                              style: GoogleFonts.cairo(),
                            ),
                          ),
                        ),
                        if (_signaturePath != null) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _clearSignature,
                            icon: Icon(Icons.delete_outline,
                                color: AppTheme.error),
                            tooltip: 'حذف التوقيع',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── WhatsApp settings ────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.chat_outlined,
                          color: Color(0xFF25D366), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'إعدادات واتساب',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF25D366)),
                      ),
                    ]),
                    const Divider(height: 20),

                    // Disclaimer banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'واتساب لا يدعم الإرسال التلقائي الكامل. '
                              'سيُفتح واتساب مع الرسالة جاهزة، '
                              'وأنت تضغط "إرسال" لكل مريض.',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: Colors.orange[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Country code
                    Text('رمز الدولة (افتراضي: 964 العراق)',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _waCountryCtrl,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cairo(),
                      decoration: InputDecoration(
                        hintText: WhatsAppService.defaultCountryCode,
                        hintStyle: GoogleFonts.cairo(
                            color: AppTheme.textSecondary),
                        prefixIcon: const Icon(Icons.public_outlined,
                            color: Color(0xFF25D366)),
                        helperText:
                            'يُضاف تلقائياً للأرقام التي تبدأ بصفر',
                        helperStyle: GoogleFonts.cairo(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Clinic WhatsApp number
                    Text('رقم واتساب العيادة (مع رمز الدولة)',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _waPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cairo(),
                      decoration: InputDecoration(
                        hintText: 'مثال: 9647801234567',
                        hintStyle: GoogleFonts.cairo(
                            color: AppTheme.textSecondary),
                        prefixIcon: const Icon(Icons.phone_outlined,
                            color: Color(0xFF25D366)),
                        helperText:
                            'مثال: 964 للعراق ثم رقم الهاتف بدون صفر',
                        helperStyle: GoogleFonts.cairo(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Message template
                    Text('نص الرسالة الجاهزة',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _waTemplateCtrl,
                      maxLines: 4,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.cairo(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: WhatsAppService.defaultTemplate,
                        hintStyle: GoogleFonts.cairo(
                            color: AppTheme.textSecondary,
                            fontSize: 12),
                        alignLabelWithHint: true,
                        helperText:
                            'اتركه فارغاً للرسالة الافتراضية',
                        helperStyle: GoogleFonts.cairo(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Variables hint
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المتغيرات المتاحة:',
                              style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 4),
                          _varHint('{اسم_المريض}',
                              'اسم المريض'),
                          _varHint('{التاريخ}',
                              'تاريخ الموعد'),
                          _varHint('{الوقت}',
                              'وقت الموعد'),
                          _varHint('{اسم_العيادة}',
                              'اسم العيادة'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _waSaving ? null : _saveWaSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                        ),
                        icon: _waSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text('حفظ إعدادات واتساب',
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Account actions ──────────────────────────────────────────
            Card(
              child: Column(
                children: [
                  _tile(
                    icon: Icons.edit_outlined,
                    title: 'تعديل البيانات الشخصية',
                    onTap: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RegisterDoctorScreen(doctor: doctor),
                        ),
                      );
                      if (updated == true) {
                        await _auth.tryAutoLogin();
                        setState(() {});
                      }
                    },
                  ),
                  _divider(),
                  _tile(
                    icon: Icons.logout,
                    title: 'تسجيل الخروج',
                    color: AppTheme.error,
                    onTap: _logout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.verified_outlined,
                    color: AppTheme.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'التطبيق مرخص',
                  style: GoogleFonts.cairo(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.primary),
      title: Text(title,
          style: GoogleFonts.cairo(
              color: color, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 56, endIndent: 16);

  Widget _varHint(String variable, String desc) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(variable,
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary)),
        ),
        const SizedBox(width: 6),
        Text('← $desc',
            style: GoogleFonts.cairo(
                fontSize: 11, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

// ─── Excel export button ──────────────────────────────────────────────────────

class _ExcelBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ExcelBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF217346).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF217346).withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF217346), size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF217346)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Color swatch widget ──────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final AppColorPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: preset.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: preset.primary.withValues(alpha: 0.5),
                  blurRadius: isSelected ? 10 : 4,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            preset.name,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? preset.primary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
