import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/doctor.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_text_field.dart';

class RegisterDoctorScreen extends StatefulWidget {
  final Doctor? doctor;
  const RegisterDoctorScreen({super.key, this.doctor});

  @override
  State<RegisterDoctorScreen> createState() => _RegisterDoctorScreenState();
}

class _RegisterDoctorScreenState extends State<RegisterDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _specialtyCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _clinicCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmCtrl;

  bool _saving = false;
  bool _obscurePass = true;
  bool get _isEditing => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _specialtyCtrl = TextEditingController(text: d?.specialty ?? '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _clinicCtrl = TextEditingController(text: d?.clinicName ?? '');
    _addressCtrl = TextEditingController(text: d?.address ?? '');
    _usernameCtrl = TextEditingController(text: d?.username ?? '');
    _passwordCtrl = TextEditingController(text: d?.password ?? '');
    _confirmCtrl = TextEditingController(text: d?.password ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _specialtyCtrl, _phoneCtrl, _clinicCtrl, _addressCtrl,
      _usernameCtrl, _passwordCtrl, _confirmCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    if (!_isEditing) {
      final exists = await _db.usernameExists(_usernameCtrl.text.trim());
      if (exists) {
        setState(() => _saving = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('اسم المستخدم مستخدم بالفعل',
                style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    final doctor = Doctor(
      id: widget.doctor?.id,
      name: _nameCtrl.text.trim(),
      specialty: _specialtyCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      clinicName: _clinicCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      createdAt: widget.doctor?.createdAt ?? DateTime.now().toIso8601String(),
    );

    if (_isEditing) {
      await _db.updateDoctor(doctor);
    } else {
      await _db.insertDoctor(doctor);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing ? 'تم تحديث بيانات الطبيب' : 'تم إنشاء الحساب بنجاح',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل البيانات' : 'إنشاء حساب جديد',
          style: GoogleFonts.cairo(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section('معلومات العيادة', Icons.local_hospital_outlined, [
                CustomTextField(
                  label: 'اسم الطبيب *',
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'التخصص',
                  controller: _specialtyCtrl,
                  prefixIcon: Icons.medical_services_outlined,
                  hint: 'مثال: طب عام، أطفال، باطنية',
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'اسم العيادة',
                  controller: _clinicCtrl,
                  prefixIcon: Icons.business_outlined,
                  hint: 'مثال: عيادة الدكتور أحمد',
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'رقم الهاتف',
                  controller: _phoneCtrl,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'عنوان العيادة',
                  controller: _addressCtrl,
                  prefixIcon: Icons.location_on_outlined,
                  hint: 'مثال: شارع المتنبي، بغداد',
                ),
              ]),
              const SizedBox(height: 16),
              _section('بيانات الدخول', Icons.lock_outline, [
                CustomTextField(
                  label: 'اسم المستخدم *',
                  controller: _usernameCtrl,
                  prefixIcon: Icons.alternate_email,
                  readOnly: _isEditing,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'اسم المستخدم مطلوب';
                    if (v.contains(' ')) return 'لا يجب أن يحتوي على مسافات';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'كلمة المرور *',
                  controller: _passwordCtrl,
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePass,
                  suffix: GestureDetector(
                    onTap: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    child: Icon(
                      _obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'كلمة المرور مطلوبة';
                    if (v.length < 4) return 'يجب أن تكون 4 أحرف على الأقل';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'تأكيد كلمة المرور *',
                  controller: _confirmCtrl,
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePass,
                  validator: (v) => v != _passwordCtrl.text
                      ? 'كلمة المرور غير متطابقة'
                      : null,
                ),
              ]),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isEditing ? 'حفظ التعديلات' : 'إنشاء الحساب',
                    style: GoogleFonts.cairo(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary)),
            ]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
