import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'add_edit_patient_screen.dart';
import 'patient_profile_screen.dart';

class PatientsListScreen extends StatefulWidget {
  final bool openAdd;
  final VoidCallback? onBack;
  const PatientsListScreen({super.key, this.openAdd = false, this.onBack});

  @override
  State<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends State<PatientsListScreen> {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  List<Patient> _patients = [];
  List<Patient> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAddPatient());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    final patients =
        await _db.getAllPatients(doctorId: _auth.currentDoctorId);
    if (mounted) {
      setState(() {
        _patients = patients;
        _filtered = patients;
        _loading = false;
      });
    }
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _filtered = _patients);
      return;
    }
    final results = await _db.searchPatients(q,
        doctorId: _auth.currentDoctorId);
    if (mounted) setState(() => _filtered = results);
  }

  Future<void> _openAddPatient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditPatientScreen()),
    );
    _loadPatients();
  }

  Future<void> _deletePatient(Patient patient) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف المريض', style: GoogleFonts.cairo()),
        content: Text(
          'هل أنت متأكد من حذف "${patient.name}"؟\nسيتم حذف جميع مواعيده ووصفاته أيضاً.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deletePatient(patient.id!);
      _loadPatients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('تم حذف المريض', style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المرضى', style: GoogleFonts.cairo()),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'الرئيسية',
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPatient,
        icon: const Icon(Icons.person_add),
        label: Text('مريض جديد', style: GoogleFonts.cairo()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) => _search(q),
              textDirection: TextDirection.rtl,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف أو رقم الملف...',
                hintStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadPatients,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _PatientCard(
                                patient: _filtered[i],
                                onDelete: () => _deletePatient(_filtered[i]),
                                onRefresh: _loadPatients,
                              ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchCtrl.text.isEmpty
                ? 'لا يوجد مرضى\nاضغط + لإضافة مريض جديد'
                : 'لا توجد نتائج للبحث',
            style:
                GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  const _PatientCard({
    required this.patient,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientProfileScreen(patientId: patient.id!),
            ),
          );
          onRefresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  patient.name.isNotEmpty ? patient.name[0] : '؟',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
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
                      patient.name,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          patient.phone.isEmpty ? 'لا يوجد' : patient.phone,
                          style: GoogleFonts.cairo(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        if (patient.age > 0) ...[
                          const Icon(Icons.cake_outlined,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${patient.age} سنة',
                            style: GoogleFonts.cairo(
                                fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    if (patient.bloodType.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'فصيلة: ${patient.bloodType}',
                          style: GoogleFonts.cairo(
                              fontSize: 12, color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddEditPatientScreen(patient: patient),
                      ),
                    ).then((_) => onRefresh());
                  } else if (v == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('تعديل', style: GoogleFonts.cairo()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Text('حذف',
                            style: GoogleFonts.cairo(color: AppTheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
