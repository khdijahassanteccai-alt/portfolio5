import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_text_field.dart';

final _nf = NumberFormat('#,##0.##', 'en_US');
String _fmtAmount(double v) => '${_nf.format(v)} د.ع';

// ─── Invoices List ────────────────────────────────────────────────────────────

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  List<Invoice> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final invoices =
        await _db.getAllInvoices(doctorId: _auth.currentDoctorId);
    if (mounted) setState(() { _invoices = invoices; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('الفواتير', style: GoogleFonts.cairo())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddInvoiceScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: Text('فاتورة جديدة', style: GoogleFonts.cairo()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('لا توجد فواتير',
                          style: GoogleFonts.cairo(
                              color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _invoices.length,
                    itemBuilder: (_, i) => _InvoiceTile(
                      invoice: _invoices[i],
                      onDelete: () async {
                        await _db.deleteInvoice(_invoices[i].id!);
                        _load();
                      },
                      onView: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceDetailScreen(
                                invoice: _invoices[i]),
                          ),
                        );
                        _load();
                      },
                    ),
                  ),
                ),
    );
  }
}

// ─── Invoice Tile ─────────────────────────────────────────────────────────────

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onDelete;
  final VoidCallback onView;

  const _InvoiceTile(
      {required this.invoice,
      required this.onDelete,
      required this.onView});

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.status == 'paid';
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
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_outlined,
                    color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.patientName,
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '${invoice.date}  ·  ${_fmtAmount(invoice.total)}',
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPaid
                              ? AppTheme.success
                              : AppTheme.warning)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      invoice.statusLabel,
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPaid
                              ? AppTheme.success
                              : AppTheme.warning),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.error, size: 18),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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

// ─── Add Invoice ──────────────────────────────────────────────────────────────

class AddInvoiceScreen extends StatefulWidget {
  final int? patientId;
  const AddInvoiceScreen({super.key, this.patientId});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  final _auth = AuthService();

  final _dateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  List<_ItemEntry> _items = [_ItemEntry()];
  List<Patient> _patients = [];
  Patient? _selectedPatient;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
    _loadPatients();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    for (final e in _items) { e.dispose(); }
    super.dispose();
  }

  Future<void> _loadPatients() async {
    final patients =
        await _db.getAllPatients(doctorId: _auth.currentDoctorId);
    if (mounted) {
      setState(() {
        _patients = patients;
        if (widget.patientId != null) {
          _selectedPatient = patients
              .where((p) => p.id == widget.patientId)
              .firstOrNull;
        }
      });
    }
  }

  double get _total =>
      _items.fold(0.0, (sum, e) {
        final price = double.tryParse(e.priceCtrl.text) ?? 0;
        final qty = int.tryParse(e.qtyCtrl.text) ?? 1;
        return sum + price * qty;
      });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('الرجاء اختيار مريض', style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);

    final invoiceItems = _items
        .where((e) => e.nameCtrl.text.isNotEmpty)
        .map((e) => InvoiceItem(
              name: e.nameCtrl.text.trim(),
              price: double.tryParse(e.priceCtrl.text) ?? 0,
              quantity: int.tryParse(e.qtyCtrl.text) ?? 1,
            ))
        .toList();

    final invoice = Invoice(
      doctorId: _auth.currentDoctorId,
      patientId: _selectedPatient!.id!,
      patientName: _selectedPatient!.name,
      date: _dateCtrl.text,
      items: invoiceItems,
      total: _total,
      status: 'unpaid',
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    final id = await _db.insertInvoice(invoice);
    final savedInvoice = Invoice(
      id: id,
      doctorId: invoice.doctorId,
      patientId: invoice.patientId,
      patientName: invoice.patientName,
      date: invoice.date,
      items: invoice.items,
      total: invoice.total,
      status: invoice.status,
      notes: invoice.notes,
      createdAt: invoice.createdAt,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(invoice: savedInvoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('فاتورة جديدة', style: GoogleFonts.cairo())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _patientCard(),
              const SizedBox(height: 16),
              _dateCard(),
              const SizedBox(height: 16),
              _itemsCard(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomTextField(
                    label: 'ملاحظات',
                    controller: _notesCtrl,
                    prefixIcon: Icons.notes_outlined,
                    maxLines: 2,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text('حفظ الفاتورة',
                      style: GoogleFonts.cairo(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _patientCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('المريض', Icons.person_outline),
            const Divider(height: 20),
            DropdownButtonFormField<Patient>(
              value: _selectedPatient,
              hint: Text('اختر المريض', style: GoogleFonts.cairo()),
              onChanged: (p) =>
                  setState(() => _selectedPatient = p),
              validator: (v) =>
                  v == null ? 'الرجاء اختيار مريض' : null,
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFCFD8DC))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFCFD8DC))),
              ),
              items: _patients.map((p) {
                return DropdownMenuItem<Patient>(
                  value: p,
                  child: Text(p.name, style: GoogleFonts.cairo()),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('التاريخ', Icons.calendar_today_outlined),
            const Divider(height: 20),
            CustomTextField(
              label: 'تاريخ الفاتورة',
              controller: _dateCtrl,
              prefixIcon: Icons.calendar_today_outlined,
              readOnly: true,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  locale: const Locale('ar'),
                );
                if (picked != null) {
                  _dateCtrl.text =
                      picked.toIso8601String().substring(0, 10);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.list_alt_outlined,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('الخدمات',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _items.add(_ItemEntry())),
                icon: const Icon(Icons.add, size: 18),
                label: Text('إضافة', style: GoogleFonts.cairo()),
              ),
            ]),
            const Divider(height: 20),
            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return _ItemRow(
                entry: e,
                index: i + 1,
                canRemove: _items.length > 1,
                onRemove: () {
                  setState(() {
                    e.dispose();
                    _items.removeAt(i);
                  });
                },
                onChanged: () => setState(() {}),
              );
            }),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'الإجمالي: ${_fmtAmount(_total)}',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: AppTheme.primary, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primary)),
    ]);
  }
}

// ─── Item Entry ───────────────────────────────────────────────────────────────

class _ItemEntry {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController(text: '0');
  final TextEditingController qtyCtrl = TextEditingController(text: '1');

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _ItemRow extends StatelessWidget {
  final _ItemEntry entry;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRow({
    required this.entry,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('خدمة $index',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      fontSize: 13)),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.error, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          CustomTextField(
            label: 'اسم الخدمة',
            controller: entry.nameCtrl,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  label: 'السعر (د.ع)',
                  controller: entry.priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                  label: 'الكمية',
                  controller: entry.qtyCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Invoice Detail + PDF ─────────────────────────────────────────────────────

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;
  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _db = DatabaseHelper();
  final _auth = AuthService();
  late Invoice _invoice;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final doctor = _auth.currentDoctor!;
      final bytes = await PdfService.generateInvoicePdf(
        doctor: doctor,
        invoice: _invoice,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'invoice_${_invoice.id}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تصدير الفاتورة: $e',
                style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _toggleStatus() async {
    final newStatus =
        _invoice.status == 'paid' ? 'unpaid' : 'paid';
    await _db.updateInvoiceStatus(_invoice.id!, newStatus);
    setState(() {
      _invoice = Invoice(
        id: _invoice.id,
        doctorId: _invoice.doctorId,
        patientId: _invoice.patientId,
        patientName: _invoice.patientName,
        date: _invoice.date,
        items: _invoice.items,
        total: _invoice.total,
        status: newStatus,
        notes: _invoice.notes,
        createdAt: _invoice.createdAt,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = _invoice.status == 'paid';
    return Scaffold(
      appBar: AppBar(
        title: Text('الفاتورة #${_invoice.id}',
            style: GoogleFonts.cairo()),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting ? null : _exportPdf,
            tooltip: 'تصدير PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: isPaid
                  ? AppTheme.success.withValues(alpha: 0.05)
                  : AppTheme.warning.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: isPaid ? AppTheme.success : AppTheme.warning,
                    width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('فاتورة #${_invoice.id}',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppTheme.primary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (isPaid
                                      ? AppTheme.success
                                      : AppTheme.warning)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _invoice.statusLabel,
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  color: isPaid
                                      ? AppTheme.success
                                      : AppTheme.warning),
                            ),
                          ),
                        ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(_invoice.patientName,
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(_invoice.date,
                          style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppTheme.textSecondary)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Text('الخدمة',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const Spacer(),
                      Text('الكمية × السعر = الإجمالي',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ]),
                  ),
                  const Divider(height: 1),
                  ..._invoice.items.map((item) => ListTile(
                        title: Text(item.name,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(
                            '${item.quantity} × ${_nf.format(item.price)}',
                            style: GoogleFonts.cairo(fontSize: 12)),
                        trailing: Text(
                          _fmtAmount(item.total),
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary),
                        ),
                      )),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الإجمالي الكلي',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(
                            _fmtAmount(_invoice.total),
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: AppTheme.primary),
                          ),
                        ]),
                  ),
                ],
              ),
            ),
            if (_invoice.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('ملاحظات: ${_invoice.notes}',
                      style: GoogleFonts.cairo()),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _toggleStatus,
              icon: Icon(isPaid
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline),
              label: Text(
                isPaid ? 'تعليم كغير مدفوعة' : 'تعليم كمدفوعة',
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPaid ? AppTheme.warning : AppTheme.success,
                  minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
