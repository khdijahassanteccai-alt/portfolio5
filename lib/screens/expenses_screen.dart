import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

final _nf = NumberFormat('#,##0.##', 'en_US');

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _db = DatabaseHelper();
  final _auth = AuthService();

  List<Expense> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doctorId = _auth.currentDoctorId;
    final list = await _db.getExpenses(doctorId: doctorId);
    if (mounted) {
      setState(() {
        _expenses = list;
        _loading = false;
      });
    }
  }

  double get _total => _expenses.fold(0, (s, e) => s + e.amount);

  // Groups by YYYY-MM
  Map<String, List<Expense>> get _grouped {
    final map = <String, List<Expense>>{};
    for (final e in _expenses) {
      final key = e.date.substring(0, 7);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  Future<void> _showAddDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddExpenseSheet(
        onSave: (cat, amt, desc, dt) async {
          final doctorId = _auth.currentDoctorId;
          await _db.insertExpense(
            doctorId: doctorId,
            category: cat,
            amount: amt,
            description: desc,
            date: dt,
          );
          if (mounted) _loadData();
        },
      ),
    );
  }

  Future<void> _deleteExpense(Expense exp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف المصروف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل تريد حذف هذا المصروف؟', style: GoogleFonts.cairo()),
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
    if (ok != true) return;
    await _db.deleteExpense(id: exp.id!);
    if (mounted) _loadData();
  }

  static const _monthNames = [
    '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  String _monthLabel(String key) {
    final parts = key.split('-');
    return '${_monthNames[int.parse(parts[1])]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مصاريف العيادة', style: GoogleFonts.cairo()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: Text('إضافة مصروف', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.error,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Total banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.error, AppTheme.error.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.money_off_outlined,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إجمالي المصاريف',
                              style: GoogleFonts.cairo(
                                  color: Colors.white70, fontSize: 12)),
                          Text('${_nf.format(_total)} د.ع',
                              style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Expense list
                Expanded(
                  child: _expenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money_off_outlined,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('لا توجد مصاريف مسجّلة',
                                  style: GoogleFonts.cairo(
                                      color: AppTheme.textSecondary,
                                      fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _grouped.keys.length,
                          itemBuilder: (_, i) {
                            final key =
                                _grouped.keys.toList(growable: false)[i];
                            final items = _grouped[key]!;
                            final monthTotal =
                                items.fold(0.0, (s, e) => s + e.amount);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  child: Row(
                                    children: [
                                      Text(_monthLabel(key),
                                          style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppTheme.primary)),
                                      const Spacer(),
                                      Text('${_nf.format(monthTotal)} د.ع',
                                          style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.error)),
                                    ],
                                  ),
                                ),
                                ...items.map((exp) => _ExpenseCard(
                                      expense: exp,
                                      onDelete: () => _deleteExpense(exp),
                                    )),
                                const SizedBox(height: 4),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Expense card ──────────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDelete;

  const _ExpenseCard({required this.expense, required this.onDelete});

  static const _catColors = {
    'إيجار': Color(0xFF6A4C93),
    'كهرباء': Color(0xFFF6AE2D),
    'رواتب الموظفين': Color(0xFF2D7DD2),
    'مستلزمات طبية': Color(0xFF3BB273),
    'صيانة': Color(0xFFE84855),
    'أخرى': Color(0xFF8D99AE),
  };

  @override
  Widget build(BuildContext context) {
    final color = _catColors[expense.category] ?? AppTheme.accent;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payments_outlined, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.category,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (expense.description.isNotEmpty)
                    Text(expense.description,
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  Text(expense.date,
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_nf.format(expense.amount)} د.ع',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.error)),
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

// ─── Add expense bottom sheet ─────────────────────────────────────────────────

class _AddExpenseSheet extends StatefulWidget {
  final Future<void> Function(
      String category, double amount, String description, String date) onSave;

  const _AddExpenseSheet({required this.onSave});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  String _selectedCategory = Expense.defaultCategories.first;
  bool _customMode = false;
  final _customCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late String _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now().toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _save() async {
    final cat = _customMode ? _customCtrl.text.trim() : _selectedCategory;
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (cat.isEmpty || amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('يرجى إدخال النوع والمبلغ', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(cat, amt, _descCtrl.text.trim(), _date);
    if (mounted) Navigator.pop(context);
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('إضافة مصروف',
                  style: GoogleFonts.cairo(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              // Category
              Text('نوع المصروف',
                  style: GoogleFonts.cairo(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...Expense.defaultCategories.map((cat) => ChoiceChip(
                        label: Text(cat, style: GoogleFonts.cairo(fontSize: 12)),
                        selected: !_customMode && _selectedCategory == cat,
                        onSelected: (v) {
                          if (v) { setState(() {
                            _selectedCategory = cat;
                            _customMode = false;
                          }); }
                        },
                      )),
                  ChoiceChip(
                    label: Text('مخصص...', style: GoogleFonts.cairo(fontSize: 12)),
                    selected: _customMode,
                    onSelected: (v) => setState(() => _customMode = v),
                  ),
                ],
              ),
              if (_customMode) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customCtrl,
                  decoration: InputDecoration(
                    labelText: 'اكتب نوع المصروف',
                    labelStyle: GoogleFonts.cairo(),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: GoogleFonts.cairo(),
                  textDirection: TextDirection.rtl,
                ),
              ],
              const SizedBox(height: 14),
              // Amount
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'المبلغ (د.ع)',
                  labelStyle: GoogleFonts.cairo(),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: GoogleFonts.cairo(),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              // Description
              TextField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: 'وصف (اختياري)',
                  labelStyle: GoogleFonts.cairo(),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: GoogleFonts.cairo(),
                maxLines: 2,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              // Date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text('التاريخ: $_date',
                          style: GoogleFonts.cairo(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('حفظ',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
