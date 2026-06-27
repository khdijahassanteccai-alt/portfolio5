import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/visit.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class VisitHistoryTab extends StatefulWidget {
  final int patientId;
  const VisitHistoryTab({super.key, required this.patientId});

  @override
  State<VisitHistoryTab> createState() => _VisitHistoryTabState();
}

class _VisitHistoryTabState extends State<VisitHistoryTab> {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  List<Visit> _visits = [];
  bool _loading = true;

  static const _visitTypes = [
    'فحص عام',
    'مراجعة',
    'نتائج تحاليل',
    'نتائج أشعة',
    'متابعة علاج',
    'طارئ',
    'استشارة',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final visits = await _db.getVisitsByPatient(widget.patientId);
    if (mounted) setState(() { _visits = visits; _loading = false; });
  }

  Future<void> _showAddDialog() async {
    final dateCtrl = TextEditingController(
        text: DateTime.now().toIso8601String().substring(0, 10));
    final notesCtrl = TextEditingController();
    String selectedType = _visitTypes.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Text('إضافة زيارة',
                    style: GoogleFonts.cairo(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
                const SizedBox(height: 16),
                // Date
                TextFormField(
                  controller: dateCtrl,
                  readOnly: true,
                  style: GoogleFonts.cairo(),
                  decoration: InputDecoration(
                    labelText: 'تاريخ الزيارة',
                    labelStyle: GoogleFonts.cairo(),
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      dateCtrl.text = picked.toIso8601String().substring(0, 10);
                    }
                  },
                ),
                const SizedBox(height: 14),
                // Visit type
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'نوع الزيارة',
                    labelStyle: GoogleFonts.cairo(),
                    prefixIcon: const Icon(Icons.local_hospital_outlined),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      style: GoogleFonts.cairo(
                          color: Colors.black87, fontSize: 15),
                      items: _visitTypes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: GoogleFonts.cairo()),
                      )).toList(),
                      onChanged: (v) => setSheet(() => selectedType = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Notes
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: GoogleFonts.cairo(),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    labelStyle: GoogleFonts.cairo(),
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final doctorId = _auth.currentDoctor?.id ?? 1;
                    final visit = Visit(
                      patientId: widget.patientId,
                      doctorId: doctorId,
                      visitDate: dateCtrl.text.trim(),
                      visitType: selectedType,
                      notes: notesCtrl.text.trim(),
                      createdAt: DateTime.now().toIso8601String(),
                    );
                    await _db.insertVisit(visit);
                    if (mounted) Navigator.pop(context);
                    _load();
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text('حفظ الزيارة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ],
            ),
          );
        }),
      ),
    );

    dateCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _delete(Visit v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الزيارة', style: GoogleFonts.cairo()),
        content: Text('هل تريد حذف هذه الزيارة؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('حذف', style: GoogleFonts.cairo(color: AppTheme.error))),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteVisit(id: v.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.timeline, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('${_visits.length} زيارة',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('إضافة زيارة', style: GoogleFonts.cairo(fontSize: 13)),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
        ),
        if (_visits.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('لا توجد زيارات مسجّلة',
                      style: GoogleFonts.cairo(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _visits.length,
              itemBuilder: (_, i) => _VisitTile(
                visit: _visits[i],
                isFirst: i == 0,
                isLast: i == _visits.length - 1,
                onDelete: () => _delete(_visits[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _VisitTile extends StatelessWidget {
  final Visit visit;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onDelete;

  const _VisitTile({
    required this.visit,
    required this.isFirst,
    required this.isLast,
    required this.onDelete,
  });

  Color get _typeColor {
    switch (visit.visitType) {
      case 'فحص عام': return AppTheme.primary;
      case 'مراجعة': return AppTheme.accent;
      case 'نتائج تحاليل': return Colors.purple;
      case 'نتائج أشعة': return Colors.indigo;
      case 'متابعة علاج': return AppTheme.success;
      case 'طارئ': return AppTheme.error;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 12, color: AppTheme.divider),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: _typeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: _typeColor.withValues(alpha: 0.3), blurRadius: 4)],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppTheme.divider)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(visit.visitType,
                              style: GoogleFonts.cairo(
                                  fontSize: 12, fontWeight: FontWeight.bold,
                                  color: _typeColor)),
                        ),
                        const Spacer(),
                        Text(visit.visitDate,
                            style: GoogleFonts.cairo(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onDelete,
                          child: Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.error.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                    if (visit.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(visit.notes,
                          style: GoogleFonts.cairo(
                              fontSize: 13, color: AppTheme.textPrimary)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
