import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import '../models/queue_entry.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _db = DatabaseHelper();
  final _auth = AuthService();

  List<QueueEntry> _queue = [];
  bool _loading = true;
  bool _calling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries =
        await _db.getQueueForToday(doctorId: _auth.currentDoctorId);
    if (mounted) setState(() { _queue = entries; _loading = false; });
  }

  // ─── Derived state ────────────────────────────────────────────────────────

  List<QueueEntry> get _waiting =>
      _queue.where((e) => e.status == 'waiting').toList();
  List<QueueEntry> get _done =>
      _queue.where((e) => e.status == 'done').toList();
  QueueEntry? get _serving =>
      _queue.where((e) => e.status == 'serving').firstOrNull;

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _callNext() async {
    setState(() => _calling = true);
    await _db.callNextPatient(doctorId: _auth.currentDoctorId);
    await _load();
    setState(() => _calling = false);
  }

  Future<void> _removeEntry(QueueEntry e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إزالة من القائمة', style: GoogleFonts.cairo()),
        content: Text('هل تريد إزالة "${e.patientName}"؟',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('إزالة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.removeFromQueue(id: e.id!);
      _load();
    }
  }

  Future<void> _showAddDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddToQueueSheet(
        db: _db,
        doctorId: _auth.currentDoctorId,
        onAdded: _load,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('قائمة الانتظار', style: GoogleFonts.cairo()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: Text('إضافة للانتظار', style: GoogleFonts.cairo()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildCurrentServing()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المنتظرون (${_waiting.length})',
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimary),
                          ),
                          if (_done.isNotEmpty)
                            Text('تم كشف ${_done.length}',
                                style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  if (_waiting.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _WaitingCard(
                          entry: _waiting[i],
                          onRemove: () => _removeEntry(_waiting[i]),
                          onServe: () async {
                            await _db.updateQueueStatus(
                                id: _waiting[i].id!,
                                status: 'serving');
                            // if someone already serving, move them to done first
                            if (_serving != null) {
                              await _db.updateQueueStatus(
                                  id: _serving!.id!, status: 'done');
                            }
                            _load();
                          },
                        ),
                        childCount: _waiting.length,
                      ),
                    ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _CountBadge(
              label: 'منتظر',
              count: _waiting.length,
              color: AppTheme.warning,
              icon: Icons.hourglass_top_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CountBadge(
              label: 'تحت الكشف',
              count: _serving != null ? 1 : 0,
              color: AppTheme.primary,
              icon: Icons.medical_services_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CountBadge(
              label: 'تم',
              count: _done.length,
              color: AppTheme.success,
              icon: Icons.check_circle_outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentServing() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Call next button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_calling || (_waiting.isEmpty && _serving == null))
                  ? null
                  : _callNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor:
                    AppTheme.primary.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _calling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.skip_next_rounded, size: 24),
              label: Text(
                _serving == null ? 'استدعاء أول مريض' : 'استدعاء التالي',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Current serving card
          if (_serving != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${_serving!.sequenceNumber}',
                        style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تحت الكشف الآن',
                            style: GoogleFonts.cairo(
                                color: Colors.white70, fontSize: 12)),
                        Text(_serving!.patientName,
                            style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 28),
                    tooltip: 'إنهاء الكشف',
                    onPressed: () async {
                      await _db.updateQueueStatus(
                          id: _serving!.id!, status: 'done');
                      _load();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('لا يوجد مرضى في الانتظار',
              style: GoogleFonts.cairo(
                  color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text('اضغط + لإضافة مريض للقائمة',
              style: GoogleFonts.cairo(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Count badge ──────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _CountBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text('$count',
              style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Waiting patient card ─────────────────────────────────────────────────────

class _WaitingCard extends StatelessWidget {
  final QueueEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onServe;

  const _WaitingCard({
    required this.entry,
    required this.onRemove,
    required this.onServe,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${entry.sequenceNumber}',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.warning),
            ),
          ),
        ),
        title: Text(entry.patientName,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(
          'أُضيف ${entry.createdAt.substring(11, 16)}',
          style: GoogleFonts.cairo(
              fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Serve now button
            IconButton(
              icon: Icon(Icons.medical_services_outlined,
                  color: AppTheme.primary, size: 20),
              tooltip: 'استدعاء مباشر',
              onPressed: onServe,
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.close,
                  color: AppTheme.error, size: 20),
              tooltip: 'إزالة',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add to queue bottom sheet ────────────────────────────────────────────────

class _AddToQueueSheet extends StatefulWidget {
  final DatabaseHelper db;
  final int doctorId;
  final VoidCallback onAdded;

  const _AddToQueueSheet({
    required this.db,
    required this.doctorId,
    required this.onAdded,
  });

  @override
  State<_AddToQueueSheet> createState() => _AddToQueueSheetState();
}

class _AddToQueueSheetState extends State<_AddToQueueSheet> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Patient> _searchResults = [];
  Patient? _selectedPatient;
  bool _adding = false;
  bool _searching = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final auth = AuthService();
    final results =
        await widget.db.searchPatients(q, doctorId: auth.currentDoctorId);
    if (mounted) setState(() { _searchResults = results; _searching = false; });
  }

  Future<void> _add() async {
    final name = _selectedPatient?.name ?? _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('أدخل اسم المريض', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    setState(() => _adding = true);
    await widget.db.addToQueue(
      doctorId: widget.doctorId,
      patientName: name,
      patientId: _selectedPatient?.id,
    );
    if (mounted) {
      Navigator.pop(context);
      widget.onAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(16, 20, 16, 16 + bottomPad),
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
          Text('إضافة لقائمة الانتظار',
              style: GoogleFonts.cairo(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Search existing patients
          TextField(
            controller: _searchCtrl,
            onChanged: _search,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              hintText: 'بحث في المرضى المسجّلين...',
              hintStyle: GoogleFonts.cairo(
                  color: AppTheme.textSecondary),
              prefixIcon: _searching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ))
                  : const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchResults = [];
                          _selectedPatient = null;
                        });
                      })
                  : null,
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _searchResults[i];
                  final selected = _selectedPatient?.id == p.id;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    selectedTileColor:
                        AppTheme.primary.withValues(alpha: 0.08),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        p.name.isNotEmpty ? p.name[0] : '؟',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(p.name, style: GoogleFonts.cairo()),
                    subtitle: p.phone.isNotEmpty
                        ? Text(p.phone,
                            style: GoogleFonts.cairo(fontSize: 11))
                        : null,
                    trailing: selected
                        ? Icon(Icons.check_circle,
                            color: AppTheme.primary, size: 18)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedPatient =
                            selected ? null : p;
                        if (!selected) {
                          _searchCtrl.text = p.name;
                        }
                        _searchResults = [];
                      });
                    },
                  );
                },
              ),
            ),

          // Or quick name
          if (_selectedPatient == null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('أو أدخل اسماً سريعاً',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppTheme.textSecondary)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                hintText: 'اسم المريض',
                hintStyle: GoogleFonts.cairo(
                    color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
          ],

          // Selected patient chip
          if (_selectedPatient != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.check_circle,
                    color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مريض مسجّل: ${_selectedPatient!.name}',
                    style: GoogleFonts.cairo(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() {
                    _selectedPatient = null;
                    _searchCtrl.clear();
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _adding ? null : _add,
              icon: _adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add),
              label: Text('إضافة للانتظار',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
