import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';
import '../models/invoice.dart';
import '../models/patient_image.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../utils/app_theme.dart';
import '../widgets/info_card.dart';
import 'add_edit_patient_screen.dart';
import 'add_appointment_screen.dart';
import 'prescription_screen.dart';
import 'invoice_screen.dart';
import 'visit_history_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  final int patientId;
  const PatientProfileScreen({super.key, required this.patientId});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  Patient? _patient;
  List<Appointment> _appointments = [];
  List<Prescription> _prescriptions = [];
  List<Invoice> _invoices = [];
  List<PatientImage> _images = [];
  bool _loading = true;
  bool _exportingPdf = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final doctorId = _auth.currentDoctor?.id ?? 1;
    final patient = await _db.getPatientById(widget.patientId);
    final appointments =
        await _db.getAppointmentsByPatient(widget.patientId);
    final prescriptions =
        await _db.getPrescriptionsByPatient(widget.patientId);
    final invoices =
        await _db.getInvoicesByPatient(widget.patientId);
    final images = await _db.getPatientImages(
      patientId: widget.patientId,
      doctorId: doctorId,
    );
    if (mounted) {
      setState(() {
        _patient = patient;
        _appointments = appointments;
        _prescriptions = prescriptions;
        _invoices = invoices;
        _images = images;
        _loading = false;
      });
    }
  }

  Future<void> _exportPatientPdf() async {
    if (_patient == null) return;
    setState(() => _exportingPdf = true);
    try {
      final bytes = await PdfService.generatePatientReportPdf(
        doctor: _auth.currentDoctor!,
        patient: _patient!,
        appointments: _appointments,
        prescriptions: _prescriptions,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'patient_${_patient!.id}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في تصدير الملف: $e',
                  style: GoogleFonts.cairo()),
              backgroundColor: AppTheme.error),
        );
      }
    }
    if (mounted) setState(() => _exportingPdf = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_patient == null) {
      return Scaffold(
        appBar: AppBar(title: Text('خطأ', style: GoogleFonts.cairo())),
        body: Center(
            child: Text('المريض غير موجود', style: GoogleFonts.cairo())),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            title:
                Text(_patient!.name, style: GoogleFonts.cairo(fontSize: 18)),
            actions: [
              IconButton(
                icon: _exportingPdf
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined),
                onPressed: _exportingPdf ? null : _exportPatientPdf,
                tooltip: 'تصدير ملف المريض PDF',
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddEditPatientScreen(patient: _patient),
                    ),
                  );
                  _loadData();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              isScrollable: true,
              tabs: const [
                Tab(text: 'الملف', icon: Icon(Icons.person_outline, size: 16)),
                Tab(text: 'المواعيد', icon: Icon(Icons.calendar_today_outlined, size: 16)),
                Tab(text: 'الوصفات', icon: Icon(Icons.description_outlined, size: 16)),
                Tab(text: 'التاريخ', icon: Icon(Icons.history_outlined, size: 16)),
                Tab(text: 'الطبي', icon: Icon(Icons.medical_information_outlined, size: 16)),
                Tab(text: 'الصور', icon: Icon(Icons.photo_library_outlined, size: 16)),
                Tab(text: 'الزيارات', icon: Icon(Icons.timeline_outlined, size: 16)),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildProfileTab(),
            _buildAppointmentsTab(),
            _buildPrescriptionsTab(),
            _buildHistoryTab(),
            _buildMedicalRecordTab(),
            _buildImagesTab(),
            VisitHistoryTab(patientId: widget.patientId),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryDark, AppTheme.primary],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                _patient!.name.isNotEmpty ? _patient!.name[0] : '؟',
                style: GoogleFonts.cairo(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _patient!.name,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_patient!.age > 0)
                  _InfoChip('${_patient!.age} سنة'),
                if (_patient!.gender.isNotEmpty)
                  _InfoChip(_patient!.gender),
                if (_patient!.bloodType.isNotEmpty)
                  _InfoChip(_patient!.bloodType),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _InfoChip(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('معلومات الاتصال'),
                  InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'رقم الهاتف',
                    value: _patient!.phone,
                  ),
                  InfoRow(
                    icon: Icons.home_outlined,
                    label: 'العنوان',
                    value: _patient!.address,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('المعلومات الطبية'),
                  InfoRow(
                    icon: Icons.cake_outlined,
                    label: 'تاريخ الميلاد',
                    value: _patient!.birthDate,
                  ),
                  InfoRow(
                    icon: Icons.wc_outlined,
                    label: 'الجنس',
                    value: _patient!.gender,
                  ),
                  InfoRow(
                    icon: Icons.bloodtype_outlined,
                    label: 'فصيلة الدم',
                    value: _patient!.bloodType,
                    iconColor: Colors.red,
                  ),
                ],
              ),
            ),
          ),
          if (_patient!.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('ملاحظات'),
                    Text(
                      _patient!.notes,
                      style: GoogleFonts.cairo(
                          fontSize: 15, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatMiniCard(
                  label: 'المواعيد',
                  value: '${_appointments.length}',
                  icon: Icons.calendar_today_outlined,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  label: 'الوصفات',
                  value: '${_prescriptions.length}',
                  icon: Icons.description_outlined,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  label: 'الفواتير',
                  value: '${_invoices.length}',
                  icon: Icons.receipt_long_outlined,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.receipt_long_outlined,
                  color: AppTheme.primary),
              title: Text('فواتير المريض',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              subtitle: Text('${_invoices.length} فاتورة',
                  style: GoogleFonts.cairo(
                      fontSize: 13, color: AppTheme.textSecondary)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddInvoiceScreen(patientId: _patient!.id!),
                  ),
                );
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return _appointments.isEmpty
        ? _buildEmptyState(
            'لا توجد مواعيد',
            Icons.calendar_today_outlined,
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _appointments.length,
            itemBuilder: (_, i) {
              final a = _appointments[i];
              return _AppointmentCard(
                appointment: a,
                onDelete: () async {
                  await _db.deleteAppointment(a.id!);
                  _loadData();
                },
                onStatusChange: (status) async {
                  await _db.updateAppointmentStatus(a.id!, status);
                  _loadData();
                },
              );
            },
          );
  }

  Widget _buildPrescriptionsTab() {
    return _prescriptions.isEmpty
        ? _buildEmptyState(
            'لا توجد وصفات طبية',
            Icons.description_outlined,
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _prescriptions.length,
            itemBuilder: (_, i) {
              final p = _prescriptions[i];
              return _PrescriptionCard(
                prescription: p,
                onDelete: () async {
                  await _db.deletePrescription(p.id!);
                  _loadData();
                },
                onView: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrescriptionScreen(
                        prescription: p,
                        patient: _patient!,
                      ),
                    ),
                  );
                },
              );
            },
          );
  }

  // Combined medical history — appointments + prescriptions sorted by date
  Widget _buildHistoryTab() {
    final List<_HistoryItem> items = [
      ..._appointments.map((a) => _HistoryItem(
            date: a.date,
            type: 'appointment',
            title: a.type,
            subtitle: '${a.time}  ·  ${a.statusLabel}',
            notes: a.notes,
            statusColor: a.status == 'completed'
                ? AppTheme.success
                : a.status == 'cancelled'
                    ? AppTheme.error
                    : AppTheme.warning,
          )),
      ..._prescriptions.map((p) => _HistoryItem(
            date: p.date,
            type: 'prescription',
            title: p.diagnosis,
            subtitle: '${p.medications.length} دواء',
            notes: p.notes,
            statusColor: AppTheme.success,
          )),
    ];
    items.sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return _buildEmptyState('لا يوجد تاريخ طبي', Icons.history_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _HistoryTile(item: items[i]),
    );
  }

  Widget _buildMedicalRecordTab() {
    final p = _patient!;
    final hasData = p.chronicDiseases.isNotEmpty ||
        p.drugAllergies.isNotEmpty ||
        p.previousSurgeries.isNotEmpty ||
        p.currentMedications.isNotEmpty ||
        p.medicalHistory.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!hasData)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.medical_information_outlined,
                          size: 52, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text('لا توجد بيانات طبية',
                          style: GoogleFonts.cairo(
                              color: AppTheme.textSecondary, fontSize: 15)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    AddEditPatientScreen(patient: _patient)),
                          );
                          _loadData();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text('إضافة الملف الطبي',
                            style: GoogleFonts.cairo()),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            _MedSection(
              icon: Icons.monitor_heart_outlined,
              color: AppTheme.error,
              title: 'الأمراض المزمنة',
              value: p.chronicDiseases,
            ),
            _MedSection(
              icon: Icons.warning_amber_outlined,
              color: AppTheme.warning,
              title: 'الحساسية من الأدوية',
              value: p.drugAllergies,
            ),
            _MedSection(
              icon: Icons.local_hospital_outlined,
              color: AppTheme.accent,
              title: 'العمليات السابقة',
              value: p.previousSurgeries,
            ),
            _MedSection(
              icon: Icons.medication_outlined,
              color: AppTheme.success,
              title: 'الأدوية الحالية',
              value: p.currentMedications,
            ),
            _MedSection(
              icon: Icons.history_edu_outlined,
              color: AppTheme.primary,
              title: 'التاريخ المرضي الكامل',
              value: p.medicalHistory,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AddEditPatientScreen(patient: _patient)),
                );
                _loadData();
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text('تعديل الملف الطبي', style: GoogleFonts.cairo()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (context, _) {
        if (_tabCtrl.index == 1) {
          return FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddAppointmentScreen(patientId: widget.patientId),
                ),
              );
              _loadData();
            },
            icon: const Icon(Icons.add),
            label: Text('موعد جديد', style: GoogleFonts.cairo()),
          );
        } else if (_tabCtrl.index == 2) {
          return FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrescriptionScreen(
                    patient: _patient!,
                  ),
                ),
              );
              _loadData();
            },
            icon: const Icon(Icons.add),
            label: Text('وصفة جديدة', style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.success,
          );
        } else if (_tabCtrl.index == 5) {
          return FloatingActionButton.extended(
            onPressed: _pickAndAddImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('إضافة صورة', style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.accent,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            text,
            style: GoogleFonts.cairo(
                color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ─── Images tab ───────────────────────────────────────────────────────────────

  Widget _buildImagesTab() {
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('لا توجد صور طبية',
                style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('اضغط + لإضافة صورة',
                style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    // Group by category in preferred order
    final grouped = <String, List<PatientImage>>{};
    for (final img in _images) {
      grouped.putIfAbsent(img.category, () => []).add(img);
    }
    final sortedKeys = [
      ...PatientImage.categories.where(grouped.containsKey),
      ...grouped.keys.where((k) => !PatientImage.categories.contains(k)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final cat in sortedKeys) ...[
            _SectionTitle(cat),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: grouped[cat]!.length,
              itemBuilder: (_, i) {
                final img = grouped[cat]![i];
                return _ImageThumbnailTile(
                  image: img,
                  onTap: () => _openImageDetail(img),
                  onDelete: () => _deleteImage(img),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndAddImage() async {
    String? pickedPath;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      pickedPath = result?.files.single.path;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر فتح معرض الصور: $e',
                style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }
    if (pickedPath == null || !mounted) return;

    final meta = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ImageMetaSheet(),
    );
    if (meta == null || !mounted) return;

    // Copy file into the app support directory so it persists safely
    final appDir = await getApplicationSupportDirectory();
    final imagesDir =
        Directory('${appDir.path}/patient_images/${widget.patientId}');
    await imagesDir.create(recursive: true);

    final dotIdx = pickedPath.lastIndexOf('.');
    final ext =
        dotIdx != -1 ? pickedPath.substring(dotIdx).toLowerCase() : '.jpg';
    final destPath =
        '${imagesDir.path}/${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(pickedPath).copy(destPath);

    final doctorId = _auth.currentDoctor?.id ?? 1;
    await _db.addPatientImage(
      patientId: widget.patientId,
      imagePath: destPath,
      category: meta['category']!,
      description: meta['description'] ?? '',
      doctorId: doctorId,
    );

    if (mounted) _loadData();
  }

  Future<void> _deleteImage(PatientImage img) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الصورة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل تريد حذف هذه الصورة نهائياً؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await File(img.imagePath).delete();
    } catch (_) {}
    await _db.deletePatientImage(id: img.id!);
    if (mounted) _loadData();
  }

  void _openImageDetail(PatientImage img) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ImageDetailScreen(image: img)),
    );
  }
}

// ─── Medical section card ─────────────────────────────────────────────────────

class _MedSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _MedSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: GoogleFonts.cairo(
                          fontSize: 14, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History ──────────────────────────────────────────────────────────────────

class _HistoryItem {
  final String date;
  final String type; // 'appointment' | 'prescription'
  final String title;
  final String subtitle;
  final String notes;
  final Color statusColor;

  const _HistoryItem({
    required this.date,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.notes,
    required this.statusColor,
  });
}

class _HistoryTile extends StatelessWidget {
  final _HistoryItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isAppt = item.type == 'appointment';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAppt
                        ? Icons.calendar_today_outlined
                        : Icons.description_outlined,
                    color: item.statusColor,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Text(
                        item.date,
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAppt ? 'موعد · ${item.subtitle}' : 'وصفة · ${item.subtitle}',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: item.statusColor),
                    ),
                  ),
                  if (item.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.notes,
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onDelete;
  final void Function(String) onStatusChange;

  const _AppointmentCard({
    required this.appointment,
    required this.onDelete,
    required this.onStatusChange,
  });

  Color _statusColor() {
    switch (appointment.status) {
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${appointment.date}  ${appointment.time}',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.statusLabel,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: _statusColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              appointment.type,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (appointment.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                appointment.notes,
                style: GoogleFonts.cairo(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (appointment.status == 'pending') ...[
                  _ActionBtn(
                    label: 'مكتمل',
                    color: AppTheme.success,
                    onTap: () => onStatusChange('completed'),
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    label: 'ملغي',
                    color: AppTheme.error,
                    onTap: () => onStatusChange('cancelled'),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
              color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  final VoidCallback onDelete;
  final VoidCallback onView;

  const _PrescriptionCard({
    required this.prescription,
    required this.onDelete,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_outlined,
                    color: AppTheme.success),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prescription.diagnosis,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${prescription.date}  ·  ${prescription.medications.length} دواء',
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Image thumbnail tile ─────────────────────────────────────────────────────

class _ImageThumbnailTile extends StatelessWidget {
  final PatientImage image;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ImageThumbnailTile({
    required this.image,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(image.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: Icon(Icons.broken_image_outlined, color: Colors.grey[400]),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-screen image viewer ─────────────────────────────────────────────────

class _ImageDetailScreen extends StatelessWidget {
  final PatientImage image;
  const _ImageDetailScreen({required this.image});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(image.category,
              style: GoogleFonts.cairo(color: Colors.white)),
        ),
        body: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(image.imagePath),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            if (image.description.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black87,
                child: Text(
                  image.description,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Image metadata bottom sheet ─────────────────────────────────────────────

class _ImageMetaSheet extends StatefulWidget {
  const _ImageMetaSheet();

  @override
  State<_ImageMetaSheet> createState() => _ImageMetaSheetState();
}

class _ImageMetaSheetState extends State<_ImageMetaSheet> {
  String _selectedCategory = 'أخرى';
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تفاصيل الصورة',
              style: GoogleFonts.cairo(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'نوع الصورة',
              style: GoogleFonts.cairo(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PatientImage.categories
                  .map((cat) => ChoiceChip(
                        label: Text(cat, style: GoogleFonts.cairo(fontSize: 13)),
                        selected: _selectedCategory == cat,
                        onSelected: (v) {
                          if (v) setState(() => _selectedCategory = cat);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'وصف الصورة (اختياري)',
                labelStyle: GoogleFonts.cairo(),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: GoogleFonts.cairo(),
              maxLines: 2,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, {
                  'category': _selectedCategory,
                  'description': _descCtrl.text.trim(),
                }),
                child: Text('حفظ',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
