import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_text_field.dart';

class AddEditPatientScreen extends StatefulWidget {
  final Patient? patient;
  const AddEditPatientScreen({super.key, this.patient});

  @override
  State<AddEditPatientScreen> createState() => _AddEditPatientScreenState();
}

class _AddEditPatientScreenState extends State<AddEditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  final _auth = AuthService();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _birthDateCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;
  // Medical record
  late TextEditingController _chronicCtrl;
  late TextEditingController _allergyCtrl;
  late TextEditingController _surgeriesCtrl;
  late TextEditingController _medsCtrl;
  late TextEditingController _historyCtrl;

  String _gender = 'ذكر';
  String _bloodType = 'A+';
  bool _saving = false;

  bool get isEditing => widget.patient != null;

  final _genders = ['ذكر', 'أنثى'];
  final _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'غير محدد'];

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _birthDateCtrl = TextEditingController(text: p?.birthDate ?? '');
    _addressCtrl = TextEditingController(text: p?.address ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    _chronicCtrl = TextEditingController(text: p?.chronicDiseases ?? '');
    _allergyCtrl = TextEditingController(text: p?.drugAllergies ?? '');
    _surgeriesCtrl = TextEditingController(text: p?.previousSurgeries ?? '');
    _medsCtrl = TextEditingController(text: p?.currentMedications ?? '');
    _historyCtrl = TextEditingController(text: p?.medicalHistory ?? '');
    _gender = p?.gender ?? 'ذكر';
    _bloodType = p?.bloodType ?? 'A+';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _birthDateCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _chronicCtrl.dispose();
    _allergyCtrl.dispose();
    _surgeriesCtrl.dispose();
    _medsCtrl.dispose();
    _historyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _birthDateCtrl.text = picked.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final now = DateTime.now().toIso8601String();
    final patient = Patient(
      id: widget.patient?.id,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      birthDate: _birthDateCtrl.text.trim(),
      gender: _gender,
      bloodType: _bloodType,
      address: _addressCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      createdAt: widget.patient?.createdAt ?? now,
      chronicDiseases: _chronicCtrl.text.trim(),
      drugAllergies: _allergyCtrl.text.trim(),
      previousSurgeries: _surgeriesCtrl.text.trim(),
      currentMedications: _medsCtrl.text.trim(),
      medicalHistory: _historyCtrl.text.trim(),
    );

    if (isEditing) {
      await _db.updatePatient(patient);
    } else {
      await _db.insertPatient(patient, doctorId: _auth.currentDoctorId);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing ? 'تم تحديث بيانات المريض' : 'تم إضافة المريض بنجاح',
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
          isEditing ? 'تعديل بيانات المريض' : 'إضافة مريض جديد',
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
              _buildSection(
                title: 'البيانات الأساسية',
                icon: Icons.person_outline,
                children: [
                  CustomTextField(
                    label: 'الاسم الكامل *',
                    controller: _nameCtrl,
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'الاسم مطلوب' : null,
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
                    label: 'تاريخ الميلاد',
                    controller: _birthDateCtrl,
                    prefixIcon: Icons.cake_outlined,
                    readOnly: true,
                    onTap: _pickDate,
                    suffix: const Icon(Icons.calendar_today,
                        size: 18, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'البيانات الطبية',
                icon: Icons.medical_information_outlined,
                children: [
                  _buildDropdown(
                    label: 'الجنس',
                    value: _gender,
                    items: _genders,
                    onChanged: (v) => setState(() => _gender = v!),
                    icon: Icons.wc_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildDropdown(
                    label: 'فصيلة الدم',
                    value: _bloodType,
                    items: _bloodTypes,
                    onChanged: (v) => setState(() => _bloodType = v!),
                    icon: Icons.bloodtype_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'معلومات إضافية',
                icon: Icons.info_outline,
                children: [
                  CustomTextField(
                    label: 'العنوان',
                    controller: _addressCtrl,
                    prefixIcon: Icons.home_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'ملاحظات',
                    controller: _notesCtrl,
                    prefixIcon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'الملف الطبي الإلكتروني',
                icon: Icons.medical_information_outlined,
                children: [
                  CustomTextField(
                    label: 'الأمراض المزمنة',
                    controller: _chronicCtrl,
                    prefixIcon: Icons.monitor_heart_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'الحساسية من الأدوية',
                    controller: _allergyCtrl,
                    prefixIcon: Icons.warning_amber_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'العمليات السابقة',
                    controller: _surgeriesCtrl,
                    prefixIcon: Icons.local_hospital_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'الأدوية الحالية',
                    controller: _medsCtrl,
                    prefixIcon: Icons.medication_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'التاريخ المرضي الكامل',
                    controller: _historyCtrl,
                    prefixIcon: Icons.history_edu_outlined,
                    maxLines: 4,
                  ),
                ],
              ),
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
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(
                    isEditing ? 'حفظ التعديلات' : 'إضافة المريض',
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: GoogleFonts.cairo()),
        );
      }).toList(),
    );
  }
}
