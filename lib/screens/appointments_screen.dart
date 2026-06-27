import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/appointment.dart';
import '../services/auth_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/app_theme.dart';
import 'add_appointment_screen.dart';
import 'patient_profile_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AppointmentsScreen({super.key, this.onBack});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  List<Appointment> _all = [];

  List<Appointment> _filtered = [];
  bool _loading = true;
  String _filterStatus = 'all';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final statuses = ['all', 'pending', 'completed', 'cancelled'];
        setState(() => _filterStatus = statuses[_tabCtrl.index]);
        _applyFilter();
      }
    });
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendWhatsApp(Appointment a) async {
    final patient = await _db.getPatientById(a.patientId);
    final rawPhone = patient?.phone.trim() ?? '';
    if (rawPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('لا يوجد رقم هاتف لهذا المريض',
            style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final clinicName = _auth.currentDoctor?.clinicName.isNotEmpty == true
        ? _auth.currentDoctor!.clinicName
        : 'العيادة';

    final template = await WhatsAppService.getMessageTemplate();
    final message = WhatsAppService.buildMessage(
      template: template,
      patientName: patient?.name ?? a.patientName,
      date: a.date,
      time: a.time,
      clinicName: clinicName,
    );

    final opened = await WhatsAppService.send(
      patientPhone: rawPhone,
      message: message,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('تعذر فتح واتساب', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _loadAppointments() async {
    final appointments =
        await _db.getAllAppointments(doctorId: _auth.currentDoctorId);
    if (mounted) {
      setState(() {
        _all = appointments;
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _filterStatus == 'all'
          ? _all
          : _all.where((a) => a.status == _filterStatus).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'الرئيسية',
              )
            : null,
        title: Text('المواعيد', style: GoogleFonts.cairo()),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'معلق'),
            Tab(text: 'مكتمل'),
            Tab(text: 'ملغي'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
          );
          _loadAppointments();
        },
        icon: const Icon(Icons.add),
        label: Text('موعد جديد', style: GoogleFonts.cairo()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAppointments,
              child: _filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _AppointmentItem(
                        appointment: _filtered[i],
                        onDelete: () async {
                          await _db.deleteAppointment(_filtered[i].id!);
                          _loadAppointments();
                        },
                        onStatusChange: (status) async {
                          await _db.updateAppointmentStatus(
                              _filtered[i].id!, status);
                          _loadAppointments();
                        },
                        onPatientTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientProfileScreen(
                                patientId: _filtered[i].patientId,
                              ),
                            ),
                          ).then((_) => _loadAppointments());
                        },
                        onWhatsApp: () => _sendWhatsApp(_filtered[i]),
                      ),
                    ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد مواعيد',
            style:
                GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط + لإضافة موعد جديد',
            style:
                GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AppointmentItem extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onDelete;
  final void Function(String) onStatusChange;
  final VoidCallback onPatientTap;
  final VoidCallback onWhatsApp;

  const _AppointmentItem({
    required this.appointment,
    required this.onDelete,
    required this.onStatusChange,
    required this.onPatientTap,
    required this.onWhatsApp,
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
                GestureDetector(
                  onTap: onPatientTap,
                  child: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      appointment.patientName.isNotEmpty
                          ? appointment.patientName[0]
                          : '؟',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onPatientTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          appointment.type,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    appointment.date,
                    style: GoogleFonts.cairo(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_outlined,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    appointment.time,
                    style: GoogleFonts.cairo(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (appointment.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                appointment.notes,
                style: GoogleFonts.cairo(
                    fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (appointment.status == 'pending') ...[
                  _Chip(
                    label: 'مكتمل',
                    color: AppTheme.success,
                    onTap: () => onStatusChange('completed'),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: 'ملغي',
                    color: AppTheme.error,
                    onTap: () => onStatusChange('cancelled'),
                  ),
                ] else
                  _Chip(
                    label: 'إعادة تفعيل',
                    color: AppTheme.warning,
                    onTap: () => onStatusChange('pending'),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chat_outlined,
                      color: Color(0xFF25D366), size: 22),
                  onPressed: onWhatsApp,
                  tooltip: 'تذكير واتساب',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 20),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
