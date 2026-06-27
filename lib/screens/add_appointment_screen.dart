import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/appointment.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_text_field.dart';

class AddAppointmentScreen extends StatefulWidget {
  final int? patientId;
  const AddAppointmentScreen({super.key, this.patientId});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  final _auth = AuthService();

  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Patient> _patients = [];
  Patient? _selectedPatient;
  String _type = 'كشف';
  bool _saving = false;
  bool _loadingPatients = true;

  final _appointmentTypes = [
    'كشف', 'متابعة', 'استشارة', 'تحاليل', 'أشعة',
    'إجراء طبي', 'طوارئ', 'أخرى'
  ];

  @override
  void initState() {
    super.initState();
    _loadPatients();
    final now = DateTime.now();
    _dateCtrl.text = now.toIso8601String().substring(0, 10);
    _timeCtrl.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    final patients =
        await _db.getAllPatients(doctorId: _auth.currentDoctorId);
    if (mounted) {
      setState(() {
        _patients = patients;
        if (widget.patientId != null) {
          _selectedPatient = patients
              .where((p) => p.id == widget.patientId)
              .firstOrNull;
        }
        _loadingPatients = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateCtrl.text = picked.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _timeCtrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء اختيار مريض', style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final appointment = Appointment(
      patientId: _selectedPatient!.id!,
      patientName: _selectedPatient!.name,
      date: _dateCtrl.text.trim(),
      time: _timeCtrl.text.trim(),
      type: _type,
      status: 'pending',
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    final appointmentId = await _db.insertAppointment(appointment,
        doctorId: _auth.currentDoctorId);

    // Schedule reminder notification 1 hour before
    try {
      final dateParts = _dateCtrl.text.trim().split('-');
      final timeParts = _timeCtrl.text.trim().split(':');
      if (dateParts.length == 3 && timeParts.length == 2) {
        final appointmentDateTime = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
        await NotificationService().scheduleAppointmentReminder(
          appointmentId: appointmentId,
          patientName: _selectedPatient!.name,
          appointmentDateTime: appointmentDateTime,
        );
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حجز الموعد بنجاح', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إضافة موعد', style: GoogleFonts.cairo()),
      ),
      body: _loadingPatients
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPatientSelector(),
                    const SizedBox(height: 16),
                    _buildDateTimeCard(),
                    const SizedBox(height: 16),
                    _buildDetailsCard(),
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
                            : const Icon(Icons.check),
                        label: Text(
                          'حجز الموعد',
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

  Widget _buildPatientSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'اختيار المريض',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (_patients.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'لا يوجد مرضى مسجلين. يرجى إضافة مريض أولاً.',
                  style: GoogleFonts.cairo(color: Colors.orange[800]),
                ),
              )
            else
              DropdownButtonFormField<Patient>(
                value: _selectedPatient,
                hint: Text('اختر مريضاً', style: GoogleFonts.cairo()),
                onChanged: (p) => setState(() => _selectedPatient = p),
                validator: (v) => v == null ? 'الرجاء اختيار مريض' : null,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
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
                ),
                isExpanded: true,
                items: _patients.map((p) {
                  return DropdownMenuItem<Patient>(
                    value: p,
                    child: Text(
                      '${p.name}  ${p.phone.isNotEmpty ? '· ${p.phone}' : ''}',
                      style: GoogleFonts.cairo(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'التاريخ والوقت',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'التاريخ',
                    controller: _dateCtrl,
                    prefixIcon: Icons.calendar_today_outlined,
                    readOnly: true,
                    onTap: _pickDate,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'الوقت',
                    controller: _timeCtrl,
                    prefixIcon: Icons.access_time_outlined,
                    readOnly: true,
                    onTap: _pickTime,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'تفاصيل الموعد',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            DropdownButtonFormField<String>(
              value: _type,
              onChanged: (v) => setState(() => _type = v!),
              decoration: InputDecoration(
                labelText: 'نوع الزيارة',
                labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.category_outlined),
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
              ),
              items: _appointmentTypes.map((t) {
                return DropdownMenuItem<String>(
                  value: t,
                  child: Text(t, style: GoogleFonts.cairo()),
                );
              }).toList(),
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
      ),
    );
  }
}
