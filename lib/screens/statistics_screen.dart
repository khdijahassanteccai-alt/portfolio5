import 'package:excel/excel.dart' hide Border;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../utils/app_theme.dart';
import 'expenses_screen.dart';
import 'month_detail_screen.dart';

final _revNf2 = NumberFormat('#,##0.##', 'en_US');

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  late TabController _tabCtrl;

  int _selectedYear = DateTime.now().year;
  Map<String, List<int>> _monthlyData = {};
  Map<String, int> _totals = {};
  List<double> _monthlyRevenue = List.filled(12, 0);
  double _totalRevenue = 0;
  List<double> _monthlyExpenses = List.filled(12, 0);
  double _totalExpenses = 0;
  List<Map<String, dynamic>> _topDiagnoses = [];
  bool _loading = true;
  bool _exporting = false;

  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final doctorId = _auth.currentDoctorId;
    final results = await Future.wait([
      _db.getMonthlyStats(doctorId: doctorId, year: _selectedYear),
      _db.getStats(doctorId: doctorId),
      _db.getMonthlyRevenue(doctorId: doctorId, year: _selectedYear),
      _db.getTotalRevenue(doctorId: doctorId),
      _db.getTopDiagnoses(doctorId: doctorId),
      _db.getMonthlyExpenses(doctorId: doctorId, year: _selectedYear),
      _db.getTotalExpenses(doctorId: doctorId),
    ]);
    if (mounted) {
      setState(() {
        _monthlyData   = results[0] as Map<String, List<int>>;
        _totals        = results[1] as Map<String, int>;
        _monthlyRevenue  = results[2] as List<double>;
        _totalRevenue    = results[3] as double;
        _topDiagnoses    = results[4] as List<Map<String, dynamic>>;
        _monthlyExpenses = results[5] as List<double>;
        _totalExpenses   = results[6] as double;
        _loading = false;
      });
    }
  }

  // ─── Excel export ─────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final excel = Excel.createExcel();

      // Sheet 1: monthly activity + financials
      final s1 = excel['الإحصائيات الشهرية'];
      try { excel.delete('Sheet1'); } catch (_) {}
      s1.appendRow([
        TextCellValue('الشهر'),
        TextCellValue('المواعيد'),
        TextCellValue('المرضى'),
        TextCellValue('الوصفات'),
        TextCellValue('الإيرادات (د.ع)'),
        TextCellValue('المصاريف (د.ع)'),
        TextCellValue('صافي الربح (د.ع)'),
      ]);
      for (int i = 0; i < 12; i++) {
        final rev = _monthlyRevenue[i];
        final exp = _monthlyExpenses[i];
        s1.appendRow([
          TextCellValue(_monthNames[i]),
          IntCellValue((_monthlyData['appointments'] ?? List.filled(12, 0))[i]),
          IntCellValue((_monthlyData['patients'] ?? List.filled(12, 0))[i]),
          IntCellValue((_monthlyData['prescriptions'] ?? List.filled(12, 0))[i]),
          DoubleCellValue(rev),
          DoubleCellValue(exp),
          DoubleCellValue(rev - exp),
        ]);
      }

      // Sheet 2: top diagnoses
      if (_topDiagnoses.isNotEmpty) {
        final s2 = excel['أكثر الأمراض شيوعاً'];
        s2.appendRow([TextCellValue('التشخيص'), TextCellValue('العدد')]);
        for (final d in _topDiagnoses) {
          s2.appendRow([
            TextCellValue(d['diagnosis'] as String),
            IntCellValue(d['count'] as int),
          ]);
        }
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل إنشاء الملف');

      final fileName = 'statistics_$_selectedYear.xlsx';
      const mimeType =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop: save to Downloads (or Documents as fallback) and open
        Directory? saveDir;
        try {
          saveDir = await getDownloadsDirectory();
        } catch (_) {}
        saveDir ??= await getApplicationDocumentsDirectory();

        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('تم حفظ الملف: ${file.path}', style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'فتح',
              textColor: Colors.white,
              onPressed: () async {
                final uri = Uri.file(file.path);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
          ));
        }
      } else {
        // Android / iOS: share sheet
        final tmp = await getTemporaryDirectory();
        final file = File('${tmp.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: mimeType)],
          subject: 'إحصائيات عيادة $_selectedYear',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في التصدير: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.error,
        ));
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  // ─── PDF export ───────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final doctor = _auth.currentDoctor!;
      final bytes = await PdfService.generateStatisticsPdf(
        doctor: doctor,
        year: _selectedYear,
        monthNames: _monthNames,
        monthlyAppointments: _monthlyData['appointments'] ?? List.filled(12, 0),
        monthlyPatients: _monthlyData['patients'] ?? List.filled(12, 0),
        monthlyRevenue: _monthlyRevenue,
        totalRevenue: _totalRevenue,
        monthlyExpenses: _monthlyExpenses,
        totalExpenses: _totalExpenses,
        topDiagnoses: _topDiagnoses,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'statistics_$_selectedYear.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في التصدير: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.error,
        ));
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الإحصائيات', style: GoogleFonts.cairo()),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'تصدير Excel',
              onPressed: _exportExcel,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'تصدير PDF',
              onPressed: _exportPdf,
            ),
          ],
          DropdownButton<int>(
            value: _selectedYear,
            dropdownColor: AppTheme.primaryDark,
            style: GoogleFonts.cairo(color: Colors.white),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: List.generate(5, (i) {
              final y = DateTime.now().year - i;
              return DropdownMenuItem(value: y, child: Text('$y'));
            }),
            onChanged: (y) {
              if (y != null) {
                setState(() => _selectedYear = y);
                _loadData();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'النشاط'),
            Tab(text: 'الإيرادات'),
            Tab(text: 'الأمراض'),
            Tab(text: 'المالية'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildActivityTab(),
                _buildRevenueTab(),
                _buildDiagnosesTab(),
                _buildFinancialTab(),
              ],
            ),
    );
  }

  // ─── Tab 1: Activity ───────────────────────────────────────────────────────

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildBarChartCard(
            title: 'المواعيد الشهرية',
            data: _monthlyData['appointments'] ?? List.filled(12, 0),
            color: AppTheme.accent,
          ),
          const SizedBox(height: 16),
          _buildMonthlyTable(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
              title: 'المرضى',
              value: '${_totals['patients'] ?? 0}',
              icon: Icons.people_alt_outlined,
              color: AppTheme.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
              title: 'المواعيد',
              value: '${_totals['todayAppointments'] ?? 0}',
              icon: Icons.today_outlined,
              color: AppTheme.accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
              title: 'الوصفات',
              value: '${_totals['prescriptions'] ?? 0}',
              icon: Icons.description_outlined,
              color: AppTheme.success),
        ),
      ],
    );
  }

  Widget _buildBarChartCard({
    required String title,
    required List<int> data,
    required Color color,
  }) {
    final maxY = data.fold(0, (a, b) => a > b ? a : b);
    final maxYVal = maxY == 0 ? 5.0 : (maxY * 1.3).ceilToDouble();
    final currentMonth = DateTime.now().month - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                maxY: maxYVal,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppTheme.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                          style: GoogleFonts.cairo(
                              fontSize: 9, color: AppTheme.textSecondary)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx > 11) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_monthNames[idx].substring(0, 3),
                              style: GoogleFonts.cairo(
                                  fontSize: 9, color: AppTheme.textSecondary)),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: List.generate(12, (i) {
                  final isCurrent =
                      _selectedYear == DateTime.now().year && i == currentMonth;
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: data[i].toDouble(),
                      color: isCurrent ? color : color.withValues(alpha: 0.55),
                      width: 14,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ]);
                }),
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions) return;
                    final idx = response?.spot?.touchedBarGroupIndex;
                    if (idx != null && idx >= 0 && idx < 12) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MonthDetailScreen(
                            year: _selectedYear,
                            month: idx + 1,
                            doctorId: _auth.currentDoctorId,
                          ),
                        ),
                      );
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${_monthNames[group.x]}\n${rod.toY.toInt()}',
                      GoogleFonts.cairo(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تفاصيل شهرية',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('اضغط على أي شهر للتفاصيل اليومية',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            // Header row
            Container(
              decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: ['الشهر', 'المواعيد', 'المرضى', 'الوصفات']
                    .asMap()
                    .entries
                    .map((e) => Expanded(
                          flex: e.key == 0 ? 2 : 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Text(e.value,
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            // Data rows — tappable
            ...List.generate(12, (i) {
              final appts =
                  (_monthlyData['appointments'] ?? List.filled(12, 0))[i];
              final pats =
                  (_monthlyData['patients'] ?? List.filled(12, 0))[i];
              final presc =
                  (_monthlyData['prescriptions'] ?? List.filled(12, 0))[i];
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MonthDetailScreen(
                      year: _selectedYear,
                      month: i + 1,
                      doctorId: _auth.currentDoctorId,
                    ),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                      color: i % 2 == 0
                          ? Colors.transparent
                          : AppTheme.background),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: _tableCell(_monthNames[i], bold: true)),
                      Expanded(child: _tableCell('$appts')),
                      Expanded(child: _tableCell('$pats')),
                      Expanded(child: _tableCell('$presc')),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Text(text,
          style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }

  // ─── Tab 2: Revenue ────────────────────────────────────────────────────────

  Widget _buildRevenueTab() {
    final maxRev = _monthlyRevenue.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxRev == 0 ? 5.0 : (maxRev * 1.3);
    final currentMonth = DateTime.now().month - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Revenue summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.success, AppTheme.success.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 36),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إجمالي الإيرادات المحصّلة',
                        style: GoogleFonts.cairo(
                            color: Colors.white70, fontSize: 13)),
                    Text('${_revNf2.format(_totalRevenue)} د.ع',
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Monthly revenue bar chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الإيرادات الشهرية — $_selectedYear',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(BarChartData(
                      maxY: maxY,
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: AppTheme.divider, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (v, _) => Text(
                              v == 0 ? '0' : '${(v / 1000).toStringAsFixed(0)}k',
                              style: GoogleFonts.cairo(
                                  fontSize: 9, color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx > 11) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_monthNames[idx].substring(0, 3),
                                    style: GoogleFonts.cairo(
                                        fontSize: 9,
                                        color: AppTheme.textSecondary)),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: List.generate(12, (i) {
                        final isCurrent = _selectedYear == DateTime.now().year &&
                            i == currentMonth;
                        return BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: _monthlyRevenue[i],
                            color: isCurrent
                                ? AppTheme.success
                                : AppTheme.success.withValues(alpha: 0.55),
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ]);
                      }),
                      barTouchData: BarTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          final idx =
                              response?.spot?.touchedBarGroupIndex;
                          if (idx != null && idx >= 0 && idx < 12) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MonthDetailScreen(
                                  year: _selectedYear,
                                  month: idx + 1,
                                  doctorId: _auth.currentDoctorId,
                                ),
                              ),
                            );
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, __) =>
                              BarTooltipItem(
                            '${_monthNames[group.x]}\n${_revNf2.format(rod.toY)} د.ع',
                            GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Monthly revenue table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الإيرادات الشهرية التفصيلية',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(3),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4)),
                        children: ['الشهر', 'الإيرادات (د.ع)']
                            .map((h) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 4),
                                  child: Text(h,
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ))
                            .toList(),
                      ),
                      ...List.generate(12, (i) {
                        return TableRow(
                          decoration: BoxDecoration(
                              color: i % 2 == 0
                                  ? Colors.transparent
                                  : AppTheme.background),
                          children: [
                            _tableCell(_monthNames[i], bold: true),
                            _tableCell(_revNf2.format(_monthlyRevenue[i])),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 3: Diagnoses ──────────────────────────────────────────────────────

  Widget _buildDiagnosesTab() {
    if (_topDiagnoses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('لا توجد بيانات تشخيص',
                style: GoogleFonts.cairo(
                    color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('أضف وصفات طبية مع حقل التشخيص',
                style: GoogleFonts.cairo(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    final maxCount = _topDiagnoses.first['count'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart_outlined,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('أكثر الأمراض شيوعاً',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary)),
                    ],
                  ),
                  const Divider(height: 20),
                  ...List.generate(_topDiagnoses.length, (i) {
                    final d = _topDiagnoses[i];
                    final name = d['diagnosis'] as String;
                    final count = d['count'] as int;
                    final pct = maxCount > 0 ? count / maxCount : 0.0;
                    final colors = [
                      AppTheme.error,
                      AppTheme.warning,
                      AppTheme.primary,
                      AppTheme.accent,
                      AppTheme.success,
                    ];
                    final color = colors[i % colors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Text('${i + 1}',
                                    style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: color)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(name,
                                    style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ),
                              Text('$count مرة',
                                  style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: color,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor:
                                  color.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 4: Financial ─────────────────────────────────────────────────────

  Widget _buildFinancialTab() {
    final net = _totalRevenue - _totalExpenses;
    final netColor = net >= 0 ? AppTheme.success : AppTheme.error;

    // Grouped bar chart data
    final maxY = List.generate(12, (i) {
      final v = _monthlyRevenue[i] > _monthlyExpenses[i]
          ? _monthlyRevenue[i]
          : _monthlyExpenses[i];
      return v;
    }).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxY == 0 ? 5.0 : maxY * 1.3;
    final currentMonth = DateTime.now().month - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary cards row
          Row(
            children: [
              Expanded(
                child: _FinCard(
                    title: 'الإيرادات',
                    value: '${_revNf2.format(_totalRevenue)} د.ع',
                    color: AppTheme.success,
                    icon: Icons.trending_up_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FinCard(
                    title: 'المصاريف',
                    value: '${_revNf2.format(_totalExpenses)} د.ع',
                    color: AppTheme.error,
                    icon: Icons.trending_down_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: netColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: netColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                    net >= 0
                        ? Icons.account_balance_outlined
                        : Icons.warning_amber_rounded,
                    color: netColor,
                    size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('صافي الربح الإجمالي',
                        style: GoogleFonts.cairo(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    Text(
                      '${net >= 0 ? '' : '-'}${_revNf2.format(net.abs())} د.ع',
                      style: GoogleFonts.cairo(
                          color: netColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExpensesScreen()),
                  ).then((_) => _loadData()),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('المصاريف', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Comparison bar chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مقارنة الإيرادات والمصاريف — $_selectedYear',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Legend(AppTheme.success, 'إيرادات'),
                      const SizedBox(width: 16),
                      _Legend(AppTheme.error, 'مصاريف'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: BarChart(BarChartData(
                      maxY: chartMaxY,
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: AppTheme.divider, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (v, _) => Text(
                              v == 0
                                  ? '0'
                                  : '${(v / 1000).toStringAsFixed(0)}k',
                              style: GoogleFonts.cairo(
                                  fontSize: 9,
                                  color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx > 11) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                    _monthNames[idx].substring(0, 3),
                                    style: GoogleFonts.cairo(
                                        fontSize: 9,
                                        color: AppTheme.textSecondary)),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: List.generate(12, (i) {
                        final isCurrent =
                            _selectedYear == DateTime.now().year &&
                                i == currentMonth;
                        final alpha = isCurrent ? 1.0 : 0.55;
                        return BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            BarChartRodData(
                              toY: _monthlyRevenue[i],
                              color: AppTheme.success.withValues(alpha: alpha),
                              width: 9,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                            ),
                            BarChartRodData(
                              toY: _monthlyExpenses[i],
                              color: AppTheme.error.withValues(alpha: alpha),
                              width: 9,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                            ),
                          ],
                        );
                      }),
                      barTouchData: BarTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          final idx =
                              response?.spot?.touchedBarGroupIndex;
                          if (idx != null && idx >= 0 && idx < 12) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MonthDetailScreen(
                                  year: _selectedYear,
                                  month: idx + 1,
                                  doctorId: _auth.currentDoctorId,
                                ),
                              ),
                            );
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, rodIdx) {
                            final lbl =
                                rodIdx == 0 ? 'إيرادات' : 'مصاريف';
                            return BarTooltipItem(
                              '${_monthNames[group.x]}\n$lbl: ${_revNf2.format(rod.toY)} د.ع',
                              GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10),
                            );
                          },
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Monthly financial table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التفاصيل المالية الشهرية',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      children: ['الشهر', 'إيرادات', 'مصاريف', 'صافي']
                          .asMap()
                          .entries
                          .map((e) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 4),
                                  child: Text(e.value,
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  ...List.generate(12, (i) {
                    final rev = _monthlyRevenue[i];
                    final exp = _monthlyExpenses[i];
                    final n = rev - exp;
                    final nColor =
                        n >= 0 ? AppTheme.success : AppTheme.error;
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MonthDetailScreen(
                            year: _selectedYear,
                            month: i + 1,
                            doctorId: _auth.currentDoctorId,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                            color: i % 2 == 0
                                ? Colors.transparent
                                : AppTheme.background),
                        child: Row(
                          children: [
                            Expanded(
                                child: _tableCell(_monthNames[i],
                                    bold: true)),
                            Expanded(
                                child: _tableCell(
                                    _revNf2.format(rev))),
                            Expanded(
                                child: _tableCell(
                                    _revNf2.format(exp))),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7, horizontal: 4),
                                child: Text(
                                  '${n >= 0 ? '' : '-'}${_revNf2.format(n.abs())}',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: nColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────────

class _FinCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _FinCard(
      {required this.title,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  Text(value,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(title,
                style: GoogleFonts.cairo(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
