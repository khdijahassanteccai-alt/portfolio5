import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/appointment.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/info_card.dart';
import 'patients_list_screen.dart';
import 'appointments_screen.dart';
import 'add_appointment_screen.dart';
import 'add_edit_patient_screen.dart';
import 'statistics_screen.dart';
import 'backup_screen.dart';
import 'expenses_screen.dart';
import 'invoice_screen.dart';
import 'doctor_settings_screen.dart';
import 'queue_screen.dart';

final _revNf = NumberFormat('#,##0.##', 'en_US');

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const _DashboardHome(),
      PatientsListScreen(onBack: () => setState(() => _currentIndex = 0)),
      AppointmentsScreen(onBack: () => setState(() => _currentIndex = 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        iconSize: 20,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            activeIcon: const Icon(Icons.people),
            label: 'المرضى',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today_outlined),
            activeIcon: const Icon(Icons.calendar_today),
            label: 'المواعيد',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DashboardHome extends StatefulWidget {
  const _DashboardHome();

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  Map<String, int> _stats = {};
  List<Appointment> _todayAppointments = [];
  double _totalRevenue = 0;
  int _waitingCount = 0;
  int _tomorrowCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final doctorId = _auth.currentDoctorId;
    final stats = await _db.getStats(doctorId: doctorId);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayAppts =
        await _db.getAppointmentsByDate(today, doctorId: doctorId);
    final revenue = await _db.getTotalRevenue(doctorId: doctorId);
    final waiting = await _db.getWaitingCount(doctorId: doctorId);
    final tomorrow =
        await _db.getTomorrowAppointmentsCount(doctorId: doctorId);
    if (mounted) {
      setState(() {
        _stats = stats;
        _todayAppointments = todayAppts;
        _totalRevenue = revenue;
        _waitingCount = waiting;
        _tomorrowCount = tomorrow;
        _loading = false;
      });
    }
  }

  String _todayDate() {
    final now = DateTime.now();
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    const days = [
      '', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
      'الجمعة', 'السبت', 'الأحد'
    ];
    return '${days[now.weekday]}، ${now.day} ${months[now.month]} ${now.year}';
  }

  // ── Greeting ──────────────────────────────────────────────────────────────

  Widget _buildGreeting(String doctorName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً',
                    style: GoogleFonts.cairo(
                        color: Colors.white70, fontSize: 12)),
                Text(
                  doctorName.isNotEmpty ? 'د. $doctorName' : 'لوحة التحكم',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Text(_todayDate(),
                    style: GoogleFonts.cairo(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services_outlined,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  // ── Appointment banner ────────────────────────────────────────────────────

  Widget _buildAppointmentBanner() {
    final todayCount = _todayAppointments.length;
    if (todayCount == 0 && _tomorrowCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_note_outlined,
                color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppTheme.textPrimary),
                children: [
                  const TextSpan(text: 'لديك '),
                  TextSpan(
                    text: '$todayCount',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                        fontSize: 13),
                  ),
                  const TextSpan(text: ' موعد اليوم'),
                  if (_tomorrowCount > 0) ...[
                    const TextSpan(text: '، و'),
                    TextSpan(
                      text: '$_tomorrowCount',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          fontSize: 13),
                    ),
                    const TextSpan(text: ' غداً'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats grid ────────────────────────────────────────────────────────────

  Widget _buildStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 4.8,
      children: [
        StatCard(
          title: 'إجمالي المرضى',
          value: '${_stats['patients'] ?? 0}',
          icon: Icons.people_alt_outlined,
          color: AppTheme.primary,
          onTap: () {
            final s = context.findAncestorStateOfType<_DashboardScreenState>();
            s?.setState(() => s._currentIndex = 1);
          },
        ),
        StatCard(
          title: 'مواعيد اليوم',
          value: '${_stats['todayAppointments'] ?? 0}',
          icon: Icons.today_outlined,
          color: AppTheme.accent,
          onTap: () {
            final s = context.findAncestorStateOfType<_DashboardScreenState>();
            s?.setState(() => s._currentIndex = 2);
          },
        ),
        StatCard(
          title: 'مواعيد معلقة',
          value: '${_stats['pendingAppointments'] ?? 0}',
          icon: Icons.pending_actions_outlined,
          color: AppTheme.warning,
        ),
        StatCard(
          title: 'الفواتير',
          value: '${_stats['invoices'] ?? 0}',
          icon: Icons.receipt_long_outlined,
          color: AppTheme.success,
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const InvoicesListScreen()));
            _loadData();
          },
        ),
      ],
    );
  }

  // ── Revenue card ──────────────────────────────────────────────────────────

  Widget _buildRevenueCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InvoicesListScreen()));
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.success,
              AppTheme.success.withValues(alpha: 0.75)
            ],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي الإيرادات المحصّلة',
                      style: GoogleFonts.cairo(
                          color: Colors.white70, fontSize: 11)),
                  Text(
                    '${_revNf.format(_totalRevenue)} د.ع',
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.1),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios,
                color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Actions section (primary + tools + queue) ─────────────────────────────

  Widget _buildActionsSection(BuildContext context) {
    final hasWaiting = _waitingCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إجراءات سريعة',
            style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),

        // Primary actions: إضافة مريض + إضافة موعد
        Row(children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.person_add_outlined,
              label: 'إضافة مريض',
              color: AppTheme.primary,
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddEditPatientScreen()));
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBtn(
              icon: Icons.calendar_month_outlined,
              label: 'إضافة موعد',
              color: AppTheme.accent,
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddAppointmentScreen()));
                _loadData();
              },
            ),
          ),
        ]),
        const SizedBox(height: 8),

        // Tool actions: 4-column row
        Row(children: [
          Expanded(
            child: _ToolBtn(
              icon: Icons.queue_outlined,
              label: 'الانتظار',
              color: hasWaiting ? AppTheme.warning : AppTheme.primary,
              badge: hasWaiting ? '$_waitingCount' : null,
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const QueueScreen()));
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ToolBtn(
              icon: Icons.bar_chart_outlined,
              label: 'الإحصائيات',
              color: AppTheme.primary,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StatisticsScreen())),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ToolBtn(
              icon: Icons.money_off_outlined,
              label: 'المصاريف',
              color: AppTheme.error,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExpensesScreen())),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ToolBtn(
              icon: Icons.backup_outlined,
              label: 'نسخ احتياطي',
              color: AppTheme.success,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BackupScreen())),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Today's appointments ──────────────────────────────────────────────────

  Widget _buildTodayAppointments(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('مواعيد اليوم',
                style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            TextButton(
              onPressed: () {
                final s =
                    context.findAncestorStateOfType<_DashboardScreenState>();
                s?.setState(() => s._currentIndex = 2);
              },
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('عرض الكل',
                  style: GoogleFonts.cairo(
                      color: AppTheme.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_todayAppointments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available,
                        size: 36, color: Colors.grey[400]),
                    const SizedBox(height: 6),
                    Text('لا توجد مواعيد اليوم',
                        style: GoogleFonts.cairo(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          )
        else
          ...(_todayAppointments
              .map((a) => _AppointmentTile(
                    appointment: a,
                    onStatusChanged: _loadData,
                  ))),
      ],
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final doctor = _auth.currentDoctor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          doctor?.clinicName.isNotEmpty == true
              ? doctor!.clinicName
              : 'عيادة الدكتور',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'إعدادات الحساب',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DoctorSettingsScreen()),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGreeting(doctor?.name ?? ''),
                    const SizedBox(height: 6),
                    _buildAppointmentBanner(),
                    const SizedBox(height: 8),
                    _buildStats(),
                    const SizedBox(height: 8),
                    _buildRevenueCard(context),
                    const SizedBox(height: 8),
                    _buildActionsSection(context),
                    const SizedBox(height: 12),
                    _buildTodayAppointments(context),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Action button (2-column primary) ────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.cairo(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── Tool button (4-column compact) ──────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (badge != null)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge!,
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── Appointment tile ─────────────────────────────────────────────────────────

class _AppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onStatusChanged;

  const _AppointmentTile({
    required this.appointment,
    required this.onStatusChanged,
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
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Text(
            appointment.time.substring(0, 5),
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
        title: Text(appointment.patientName,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(appointment.type,
            style: GoogleFonts.cairo(fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor().withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            appointment.statusLabel,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: _statusColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
