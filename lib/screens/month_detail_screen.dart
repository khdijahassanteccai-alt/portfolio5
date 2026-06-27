import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../utils/app_theme.dart';

final _nf = NumberFormat('#,##0.##', 'en_US');

// Weekday abbreviations — Dart: Monday=1 … Sunday=7
const _wdAbbr = ['', 'اث', 'ثلا', 'أرب', 'خم', 'جم', 'سب', 'أح'];

const _monthNames = [
  '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

// Column flex weights (total = 16)
const _fDay = 3;
const _fApt = 2;
const _fPat = 2;
const _fRev = 3;
const _fExp = 3;
const _fNet = 3;

class MonthDetailScreen extends StatefulWidget {
  final int year;
  final int month;
  final int doctorId;

  const MonthDetailScreen({
    super.key,
    required this.year,
    required this.month,
    required this.doctorId,
  });

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _days = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final active = await _db.getDailyStats(
      doctorId: widget.doctorId,
      year: widget.year,
      month: widget.month,
    );

    // Index by 2-digit day string ('01' … '31')
    final byDay = {for (final d in active) d['day'] as String: d};

    // Generate every day of the month, including zeros
    final lastDay = DateTime(widget.year, widget.month + 1, 0).day;
    final all = List.generate(lastDay, (i) {
      final ds = (i + 1).toString().padLeft(2, '0');
      return byDay[ds] ??
          {
            'day': ds,
            'appointments': 0,
            'patients': 0,
            'revenue': 0.0,
            'expenses': 0.0,
          };
    });

    if (mounted) setState(() { _days = all; _loading = false; });
  }

  // ── Month totals ───────────────────────────────────────────────────────────

  int get _totalAppts =>
      _days.fold(0, (s, d) => s + (d['appointments'] as int));
  int get _totalPats =>
      _days.fold(0, (s, d) => s + (d['patients'] as int));
  double get _totalRev =>
      _days.fold(0.0, (s, d) => s + (d['revenue'] as double));
  double get _totalExp =>
      _days.fold(0.0, (s, d) => s + (d['expenses'] as double));
  double get _net => _totalRev - _totalExp;

  // ── Summary header ─────────────────────────────────────────────────────────

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SumStat('المواعيد', '$_totalAppts',
                  Icons.calendar_today_outlined),
              _SumStat('المرضى الجدد', '$_totalPats',
                  Icons.people_alt_outlined),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SumStat('الإيرادات', '${_nf.format(_totalRev)} د.ع',
                  Icons.account_balance_wallet_outlined),
              _SumStat('المصاريف', '${_nf.format(_totalExp)} د.ع',
                  Icons.money_off_outlined,
                  valueColor: Colors.white70),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _net >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'صافي الربح: ${_nf.format(_net.abs())} د.ع'
                '${_net < 0 ? '  (خسارة)' : ''}',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Table column headers ───────────────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          _HCell('اليوم', _fDay),
          _HCell('مواعيد', _fApt),
          _HCell('مرضى', _fPat),
          _HCell('إيرادات', _fRev),
          _HCell('مصاريف', _fExp),
          _HCell('الصافي', _fNet),
        ],
      ),
    );
  }

  // ── Totals footer row ──────────────────────────────────────────────────────

  Widget _buildTotalsRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        border: Border(
          top: BorderSide(color: AppTheme.primary, width: 1.5),
          left: BorderSide(color: AppTheme.divider),
          right: BorderSide(color: AppTheme.divider),
          bottom: BorderSide(color: AppTheme.divider),
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _fDay,
            child: Text('الإجمالي',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
          ),
          _TotCell('$_totalAppts', _fApt, AppTheme.accent),
          _TotCell('$_totalPats', _fPat, AppTheme.primary),
          _TotCell(_nf.format(_totalRev), _fRev, AppTheme.success),
          _TotCell(_nf.format(_totalExp), _fExp, AppTheme.error),
          _TotCell(
            '${_net >= 0 ? '+' : ''}${_nf.format(_net)}',
            _fNet,
            _net >= 0 ? AppTheme.success : AppTheme.error,
          ),
        ],
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = '${_monthNames[widget.month]} ${widget.year}';
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل $title', style: GoogleFonts.cairo()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummary(),
                _buildTableHeader(),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        vertical: BorderSide(color: AppTheme.divider),
                      ),
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _days.length + 1,
                      itemBuilder: (_, i) {
                        if (i == _days.length) return _buildTotalsRow();
                        return _DayRow(
                          day: _days[i],
                          year: widget.year,
                          month: widget.month,
                          isOdd: i.isOdd,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Summary stat helper ───────────────────────────────────────────────────────

class _SumStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _SumStat(this.label, this.value, this.icon, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.cairo(
                        color: Colors.white60, fontSize: 10)),
                Text(value,
                    style: GoogleFonts.cairo(
                        color: valueColor ?? Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Table header cell ─────────────────────────────────────────────────────────

class _HCell extends StatelessWidget {
  final String label;
  final int flex;
  const _HCell(this.label, this.flex);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(label,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Totals footer cell ────────────────────────────────────────────────────────

class _TotCell extends StatelessWidget {
  final String text;
  final int flex;
  final Color color;
  const _TotCell(this.text, this.flex, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }
}

// ─── Day row ───────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final Map<String, dynamic> day;
  final int year;
  final int month;
  final bool isOdd;

  const _DayRow({
    required this.day,
    required this.year,
    required this.month,
    required this.isOdd,
  });

  static String _fmt(double v) => v > 0 ? _nf.format(v) : '—';

  @override
  Widget build(BuildContext context) {
    final dayNum = int.parse(day['day'] as String);
    final appts = day['appointments'] as int;
    final pats = day['patients'] as int;
    final rev = day['revenue'] as double;
    final exp = day['expenses'] as double;
    final net = rev - exp;
    final isActive = appts > 0 || pats > 0 || rev > 0 || exp > 0;

    final dt = DateTime(year, month, dayNum);
    final weekday = _wdAbbr[dt.weekday];
    final isFriday = dt.weekday == 5;

    // Subtle background: active days get a tinted row, odd rows slightly grey
    final Color bg;
    if (isActive) {
      bg = AppTheme.primary.withValues(alpha: 0.05);
    } else if (isOdd) {
      bg = Colors.grey.withValues(alpha: 0.03);
    } else {
      bg = Colors.transparent;
    }

    final Color dimText =
        AppTheme.textSecondary.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Day number + weekday ──
          Expanded(
            flex: _fDay,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$dayNum',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: isActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isFriday
                        ? AppTheme.accent
                        : isActive
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                    height: 1,
                  ),
                ),
                Text(weekday,
                    style: GoogleFonts.cairo(
                        fontSize: 9,
                        color: isFriday
                            ? AppTheme.accent.withValues(alpha: 0.7)
                            : AppTheme.textSecondary.withValues(alpha: 0.6))),
              ],
            ),
          ),

          // ── Appointments ──
          Expanded(
            flex: _fApt,
            child: Text(
              appts > 0 ? '$appts' : '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight:
                    appts > 0 ? FontWeight.bold : FontWeight.normal,
                color: appts > 0 ? AppTheme.accent : dimText,
              ),
            ),
          ),

          // ── Patients ──
          Expanded(
            flex: _fPat,
            child: Text(
              pats > 0 ? '$pats' : '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight:
                    pats > 0 ? FontWeight.bold : FontWeight.normal,
                color: pats > 0 ? AppTheme.primary : dimText,
              ),
            ),
          ),

          // ── Revenue ──
          Expanded(
            flex: _fRev,
            child: Text(
              _fmt(rev),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight:
                    rev > 0 ? FontWeight.w600 : FontWeight.normal,
                color: rev > 0 ? AppTheme.success : dimText,
              ),
            ),
          ),

          // ── Expenses ──
          Expanded(
            flex: _fExp,
            child: Text(
              _fmt(exp),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight:
                    exp > 0 ? FontWeight.w600 : FontWeight.normal,
                color: exp > 0 ? AppTheme.error : dimText,
              ),
            ),
          ),

          // ── Net profit ──
          Expanded(
            flex: _fNet,
            child: isActive
                ? Text(
                    '${net >= 0 ? '+' : ''}${_nf.format(net)}',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: net >= 0 ? AppTheme.success : AppTheme.error,
                    ),
                  )
                : Text('—',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: dimText)),
          ),
        ],
      ),
    );
  }
}
