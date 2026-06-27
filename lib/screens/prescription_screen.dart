import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_text_field.dart';

class PrescriptionScreen extends StatefulWidget {
  final Patient patient;
  final Prescription? prescription;

  const PrescriptionScreen({
    super.key,
    required this.patient,
    this.prescription,
  });

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  final _auth = AuthService();
  bool _exportingPdf = false;

  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  List<_MedEntry> _medications = [];
  List<String> _medicineLibrary = [];
  bool _saving = false;
  bool get _isViewing => widget.prescription != null;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    if (_isViewing) {
      final p = widget.prescription!;
      _diagnosisCtrl.text = p.diagnosis;
      _notesCtrl.text = p.notes;
      _dateCtrl.text = p.date;
      _medications = p.medications
          .map((m) => _MedEntry.fromMedication(m))
          .toList();
    } else {
      _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
      _medications = [_MedEntry()];
    }
  }

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    _dateCtrl.dispose();
    for (var e in _medications) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    final meds = await _db.getMedicines(
        doctorId: _auth.currentDoctorId);
    if (mounted) setState(() => _medicineLibrary = meds);
  }

  Future<void> _addToLibrary(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _medicineLibrary.contains(trimmed)) return;
    await _db.insertMedicine(
        doctorId: _auth.currentDoctorId, name: trimmed);
    if (mounted) setState(() => _medicineLibrary = [..._medicineLibrary, trimmed]..sort());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medications.every((m) => m.nameCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إضافة دواء واحد على الأقل',
              style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final meds = _medications
        .where((m) => m.nameCtrl.text.trim().isNotEmpty)
        .map((m) => Medication(
              name: m.nameCtrl.text.trim(),
              dosage: m.dosageCtrl.text.trim(),
              frequency: m.frequencyCtrl.text.trim(),
              duration: m.durationCtrl.text.trim(),
              notes: m.notesCtrl.text.trim(),
            ))
        .toList();

    final prescription = Prescription(
      patientId: widget.patient.id!,
      patientName: widget.patient.name,
      date: _dateCtrl.text.trim(),
      diagnosis: _diagnosisCtrl.text.trim(),
      medications: meds,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    await _db.insertPrescription(prescription,
        doctorId: _auth.currentDoctorId);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الوصفة الطبية', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (widget.prescription == null) return;
    setState(() => _exportingPdf = true);
    try {
      final bytes = await PdfService.generatePrescriptionPdf(
        doctor: _auth.currentDoctor!,
        patient: widget.patient,
        prescription: widget.prescription!,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'prescription_${widget.prescription!.id}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تصدير الوصفة: $e',
                style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _exportingPdf = false);
  }

  void _addMedication() {
    setState(() => _medications.add(_MedEntry()));
  }

  void _removeMedication(int index) {
    setState(() {
      _medications[index].dispose();
      _medications.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isViewing ? 'وصفة طبية' : 'وصفة طبية جديدة',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          if (_isViewing) ...[
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: _exportingPdf ? null : _exportPdf,
              tooltip: 'طباعة',
            ),
            IconButton(
              icon: _exportingPdf
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _exportingPdf ? null : _exportPdf,
              tooltip: 'تصدير / مشاركة PDF',
            ),
          ],
          if (!_isViewing)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saving ? null : _save,
              tooltip: 'حفظ',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPatientInfo(),
              const SizedBox(height: 16),
              _buildDiagnosisCard(),
              const SizedBox(height: 16),
              _buildMedicationsCard(),
              const SizedBox(height: 16),
              _buildNotesCard(),
              const SizedBox(height: 28),
              if (!_isViewing)
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
                        : const Icon(Icons.save),
                    label: Text(
                      'حفظ الوصفة',
                      style: GoogleFonts.cairo(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Card(
      color: AppTheme.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              child: Text(
                widget.patient.name.isNotEmpty
                    ? widget.patient.name[0]
                    : '؟',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patient.name,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    'التاريخ: ${_dateCtrl.text}',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.local_hospital_outlined, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.medical_services_outlined,
              title: 'التشخيص',
            ),
            const SizedBox(height: 14),
            if (_isViewing)
              Text(
                _diagnosisCtrl.text,
                style: GoogleFonts.cairo(fontSize: 15),
              )
            else
              CustomTextField(
                label: 'التشخيص *',
                controller: _diagnosisCtrl,
                prefixIcon: Icons.notes_outlined,
                maxLines: 2,
                validator: (v) =>
                    v == null || v.isEmpty ? 'التشخيص مطلوب' : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'الأدوية',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
                const Spacer(),
                if (!_isViewing)
                  TextButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('إضافة', style: GoogleFonts.cairo()),
                  ),
              ],
            ),
            const Divider(height: 20),
            ...(_medications.asMap().entries.map((entry) {
              final i = entry.key;
              final med = entry.value;
              return _MedicationForm(
                entry: med,
                index: i + 1,
                isViewing: _isViewing,
                medicineLibrary: _medicineLibrary,
                onAddToLibrary: _addToLibrary,
                onRemove: _medications.length > 1
                    ? () => _removeMedication(i)
                    : null,
              );
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    if (_isViewing && _notesCtrl.text.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.notes_outlined,
              title: 'ملاحظات وتعليمات',
            ),
            const SizedBox(height: 14),
            if (_isViewing)
              Text(
                _notesCtrl.text,
                style: GoogleFonts.cairo(fontSize: 15),
              )
            else
              CustomTextField(
                label: 'ملاحظات وتعليمات للمريض',
                controller: _notesCtrl,
                prefixIcon: Icons.sticky_note_2_outlined,
                maxLines: 3,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _MedEntry {
  final TextEditingController nameCtrl;
  final TextEditingController dosageCtrl;
  final TextEditingController frequencyCtrl;
  final TextEditingController durationCtrl;
  final TextEditingController notesCtrl;

  _MedEntry()
      : nameCtrl = TextEditingController(),
        dosageCtrl = TextEditingController(),
        frequencyCtrl = TextEditingController(),
        durationCtrl = TextEditingController(),
        notesCtrl = TextEditingController();

  factory _MedEntry.fromMedication(Medication m) {
    final e = _MedEntry();
    e.nameCtrl.text = m.name;
    e.dosageCtrl.text = m.dosage;
    e.frequencyCtrl.text = m.frequency;
    e.durationCtrl.text = m.duration;
    e.notesCtrl.text = m.notes;
    return e;
  }

  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    frequencyCtrl.dispose();
    durationCtrl.dispose();
    notesCtrl.dispose();
  }
}

class _MedicationForm extends StatelessWidget {
  final _MedEntry entry;
  final int index;
  final bool isViewing;
  final List<String> medicineLibrary;
  final Future<void> Function(String) onAddToLibrary;
  final VoidCallback? onRemove;

  const _MedicationForm({
    required this.entry,
    required this.index,
    required this.isViewing,
    required this.medicineLibrary,
    required this.onAddToLibrary,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'دواء $index',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              if (!isViewing && onRemove != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.error),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isViewing) ...[
            _ViewRow('اسم الدواء', entry.nameCtrl.text),
            _ViewRow('الجرعة', entry.dosageCtrl.text),
            _ViewRow('التكرار', entry.frequencyCtrl.text),
            _ViewRow('المدة', entry.durationCtrl.text),
            if (entry.notesCtrl.text.isNotEmpty)
              _ViewRow('ملاحظات', entry.notesCtrl.text),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return medicineLibrary;
                      final q = textEditingValue.text.toLowerCase();
                      return medicineLibrary.where(
                          (m) => m.toLowerCase().contains(q));
                    },
                    onSelected: (s) => entry.nameCtrl.text = s,
                    fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                      ctrl.text = entry.nameCtrl.text;
                      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
                      ctrl.addListener(() => entry.nameCtrl.text = ctrl.text);
                      return TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          labelText: 'اسم الدواء *',
                          labelStyle: GoogleFonts.cairo(),
                          prefixIcon: const Icon(Icons.medication_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
                    optionsViewBuilder: (ctx, onSelected, options) =>
                        Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (_, i) {
                              final opt = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                title: Text(opt, style: GoogleFonts.cairo(fontSize: 13)),
                                onTap: () => onSelected(opt),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'إضافة للمكتبة',
                  child: IconButton(
                    onPressed: () => onAddToLibrary(entry.nameCtrl.text),
                    icon: Icon(Icons.add_circle_outline,
                        color: AppTheme.success),
                    padding: const EdgeInsets.only(top: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'الجرعة',
                    controller: entry.dosageCtrl,
                    hint: 'مثال: 500 مغ',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomTextField(
                    label: 'التكرار',
                    controller: entry.frequencyCtrl,
                    hint: 'مثال: 3 مرات يومياً',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CustomTextField(
              label: 'المدة',
              controller: entry.durationCtrl,
              prefixIcon: Icons.timer_outlined,
              hint: 'مثال: 7 أيام',
            ),
            const SizedBox(height: 10),
            CustomTextField(
              label: 'ملاحظات',
              controller: entry.notesCtrl,
              prefixIcon: Icons.info_outline,
              hint: 'مثال: تؤخذ بعد الأكل',
            ),
          ],
        ],
      ),
    );
  }

  Widget _ViewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
