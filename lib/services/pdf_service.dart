import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../models/invoice.dart';
import '../models/appointment.dart';

// ─── Design constants ─────────────────────────────────────────────────────────
const _kPrimary = PdfColor.fromInt(0xFF1A3A6B);      // deep navy
const _kPrimaryLight = PdfColor.fromInt(0xFF2757A0); // medium blue
const _kAccent = PdfColor.fromInt(0xFF00796B);        // teal
const _kAccentLight = PdfColor.fromInt(0xFFE0F2F1);  // teal tint
const _kSuccess = PdfColor.fromInt(0xFF2E7D32);
const _kSuccessBg = PdfColor.fromInt(0xFFE8F5E9);   // light green bg
const _kWarning = PdfColor.fromInt(0xFFE65100);
const _kRowAlt = PdfColor.fromInt(0xFFEEF2FF);       // very light blue for rows
const _kBorder = PdfColor.fromInt(0xFFCDD8E8);
const _kBg = PdfColor.fromInt(0xFFF8FAFF);
const _kTextDark = PdfColor.fromInt(0xFF1A237E);
const _kTextMid = PdfColor.fromInt(0xFF455A64);
const _kTextLight = PdfColor.fromInt(0xFF78909C);

class PdfService {
  // ─── Fonts ────────────────────────────────────────────────────────────────
  static Future<pw.Font> _font() => PdfGoogleFonts.cairoRegular();
  static Future<pw.Font> _fontBold() => PdfGoogleFonts.cairoBold();

  static pw.TextStyle _ts(pw.Font f,
          {double size = 11,
          PdfColor? color,
          pw.FontWeight? weight,
          double? height}) =>
      pw.TextStyle(
          font: f,
          fontSize: size,
          color: color ?? _kTextDark,
          fontWeight: weight,
          lineSpacing: height);

  // ─── Shared header ────────────────────────────────────────────────────────

  /// Full-width two-tone header used by all documents.
  static pw.Widget _header(Doctor doc, pw.Font f, pw.Font fb,
      {String? subtitle}) {
    return pw.Column(children: [
      // Main banner
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: const pw.BoxDecoration(color: _kPrimary),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Left: clinic info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  doc.clinicName.isNotEmpty
                      ? doc.clinicName
                      : 'العيادة الطبية',
                  style: _ts(fb,
                      size: 17, color: PdfColors.white),
                ),
                if (doc.specialty.isNotEmpty)
                  pw.Text(doc.specialty,
                      style: _ts(f,
                          size: 10,
                          color: PdfColors.grey200)),
              ],
            ),
            // Right: doctor info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'د. ${doc.name}',
                  style: _ts(fb, size: 14, color: PdfColors.white),
                ),
                if (doc.phone.isNotEmpty)
                  pw.Text(
                    doc.phone,
                    style: _ts(f, size: 10, color: PdfColors.grey300),
                  ),
              ],
            ),
          ],
        ),
      ),
      // Accent strip
      pw.Container(
        height: 4,
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [_kAccent, _kPrimaryLight],
          ),
        ),
      ),
      // Sub-title strip (optional)
      if (subtitle != null)
        pw.Container(
          width: double.infinity,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          color: _kBg,
          child: pw.Text(
            subtitle,
            style: _ts(fb, size: 13, color: _kPrimary),
          ),
        ),
    ]);
  }

  /// Thin page footer with divider and clinic name.
  static pw.Widget _footer(Doctor doc, pw.Font f) {
    return pw.Column(children: [
      pw.Container(height: 1, color: _kBorder),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(doc.phone.isNotEmpty ? 'هاتف: ${doc.phone}' : '',
              style: _ts(f, size: 8, color: _kTextLight)),
          pw.Text(doc.clinicName,
              style: _ts(f, size: 8, color: _kTextLight)),
        ],
      ),
    ]);
  }

  /// Section title with teal left-border accent.
  static pw.Widget _sectionTitle(String text, pw.Font fb) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _kRowAlt,
        border: const pw.Border(
          right: pw.BorderSide(color: _kAccent, width: 4),
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(text, style: _ts(fb, size: 13, color: _kPrimary)),
    );
  }

  /// Info card row helper.
  static pw.Widget _infoBox(pw.Font f, pw.Font fb,
      List<MapEntry<String, String>> pairs) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _kBg,
        border: pw.Border.all(color: _kBorder),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Wrap(
        direction: pw.Axis.horizontal,
        runSpacing: 8,
        children: pairs.where((e) => e.value.isNotEmpty).map((e) {
          return pw.SizedBox(
            width: 200,
            child: pw.Row(children: [
              pw.Text('${e.key}: ',
                  style: _ts(fb, size: 10, color: _kTextMid)),
              pw.Expanded(
                child: pw.Text(e.value,
                    style: _ts(f, size: 10, color: _kTextDark)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  /// Table cell helper.
  static pw.Widget _cell(String text, pw.Font f,
      {PdfColor? color,
      bool bold = false,
      pw.Alignment align = pw.Alignment.centerRight}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: align,
      child: pw.Text(text,
          style: _ts(bold ? f : f,
              size: 10,
              color: color ?? _kTextDark,
              weight: bold ? pw.FontWeight.bold : null)),
    );
  }

  static pw.Widget _headerCell(String text, pw.Font fb) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          style: _ts(fb, size: 10, color: PdfColors.white)),
    );
  }

  static Future<Uint8List?> _loadSignatureBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('doctor_signature_path');
      if (path == null) return null;
      final file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _signature(Doctor doc, pw.Font f, pw.Font fb,
      {Uint8List? signatureBytes}) {
    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _kBg,
          border: pw.Border.all(color: _kBorder),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (signatureBytes != null)
              pw.Image(pw.MemoryImage(signatureBytes),
                  width: 120, height: 50, fit: pw.BoxFit.contain)
            else
              pw.SizedBox(
                width: 100,
                child: pw.Divider(thickness: 1, color: _kPrimary),
              ),
            pw.SizedBox(height: 4),
            pw.Text('توقيع الطبيب',
                style: _ts(f, size: 9, color: _kTextMid)),
            pw.SizedBox(height: 2),
            pw.Text('د. ${doc.name}',
                style: _ts(fb, size: 11, color: _kPrimary)),
          ],
        ),
      ),
    );
  }

  // ─── Prescription PDF (redesigned) ──────────────────────────────────────────

  static Future<Uint8List?> _loadLogoBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('clinic_logo_path');
      if (path == null) return null;
      final file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Shared new-style header used by prescription and patient report.
  static pw.Widget _rxHeader(
      Doctor doc, pw.Font f, pw.Font fb,
      {Uint8List? logoBytes, String subtitle = 'وصفة طبية'}) {
    return pw.Container(
      decoration: const pw.BoxDecoration(color: _kPrimary),
      child: pw.Column(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 18, 28, 14),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Right side: clinic name + doctor info
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        doc.clinicName.isNotEmpty ? doc.clinicName : 'العيادة الطبية',
                        style: _ts(fb, size: 20, color: PdfColors.white),
                      ),
                      if (doc.specialty.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(doc.specialty,
                              style: _ts(f, size: 10, color: PdfColors.grey300)),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: 60,
                        height: 1.5,
                        color: _kAccent,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('د. ${doc.name}',
                          style: _ts(fb, size: 13, color: PdfColors.white)),
                    ],
                  ),
                ),
                // Left side: logo only (no placeholder if absent)
                if (logoBytes != null)
                  pw.Container(
                    width: 72,
                    height: 72,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Image(pw.MemoryImage(logoBytes),
                        fit: pw.BoxFit.contain),
                  ),
              ],
            ),
          ),
          // Teal accent bottom strip
          pw.Container(
            height: 5,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_kAccent, _kPrimaryLight],
              ),
            ),
          ),
          // Subtitle ribbon
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            color: _kAccentLight,
            child: pw.Center(
              child: pw.Text(subtitle,
                  style: _ts(fb, size: 13, color: _kPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  /// Patient info strip below header.
  static pw.Widget _rxPatientStrip(
      Patient patient, String date, pw.Font f, pw.Font fb) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _kBg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _kBorder),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _rxInfoPair('المريض', patient.name, f, fb),
          if (patient.age > 0)
            _rxInfoPair('العمر', '${patient.age} سنة', f, fb),
          _rxInfoPair('التاريخ', date, f, fb),
        ],
      ),
    );
  }

  static pw.Widget _rxInfoPair(
      String label, String value, pw.Font f, pw.Font fb) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: _ts(f, size: 8, color: _kTextLight)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: _ts(fb, size: 11, color: _kTextDark)),
      ],
    );
  }

  /// The main Rx body area.
  static pw.Widget _rxBody(
      Prescription prescription, pw.Font f, pw.Font fb) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorder),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Rx symbol bar
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: const pw.BoxDecoration(
                  color: _kPrimary,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(9),
                    topRight: pw.Radius.circular(9),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('℞',
                        style: pw.TextStyle(
                            font: fb,
                            fontSize: 22,
                            color: _kAccent)),
                    pw.SizedBox(width: 10),
                    pw.Text('الوصفة الطبية',
                        style: _ts(fb, size: 12, color: PdfColors.white)),
                  ],
                ),
              ),

              // Body content
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Diagnosis
                      if (prescription.diagnosis.isNotEmpty) ...[
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 4,
                              height: 18,
                              margin: const pw.EdgeInsets.only(
                                  left: 8, top: 1),
                              decoration: pw.BoxDecoration(
                                color: _kAccent,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                            ),
                            pw.Text('التشخيص: ',
                                style: _ts(fb, size: 11,
                                    color: _kPrimary)),
                            pw.Expanded(
                              child: pw.Text(prescription.diagnosis,
                                  style: _ts(f, size: 11,
                                      color: _kTextDark)),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                        pw.Divider(color: _kBorder, thickness: 0.5),
                        pw.SizedBox(height: 12),
                      ],

                      // Medications list
                      if (prescription.medications.isNotEmpty) ...[
                        pw.Text('الأدوية:',
                            style: _ts(fb, size: 11, color: _kPrimary)),
                        pw.SizedBox(height: 8),
                        ...prescription.medications
                            .asMap()
                            .entries
                            .map((e) => _rxMedLine(
                                e.key + 1, e.value, f, fb)),
                      ],

                      // Notes
                      if (prescription.notes.isNotEmpty) ...[
                        pw.SizedBox(height: 12),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.amber50,
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(
                                color: PdfColors.amber200),
                          ),
                          child: pw.Row(
                            crossAxisAlignment:
                                pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('⚠ ',
                                  style: _ts(fb,
                                      size: 10,
                                      color: PdfColors.orange800)),
                              pw.Expanded(
                                child: pw.Text(prescription.notes,
                                    style: _ts(f,
                                        size: 10,
                                        color: PdfColors.brown700)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static pw.Widget _rxMedLine(
      int n, Medication m, pw.Font f, pw.Font fb) {
    final parts = <String>[];
    if (m.dosage.isNotEmpty) parts.add(m.dosage);
    if (m.frequency.isNotEmpty) parts.add(m.frequency);
    if (m.duration.isNotEmpty) parts.add(m.duration);
    if (m.notes.isNotEmpty) parts.add(m.notes);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 20,
            height: 20,
            decoration: pw.BoxDecoration(
              color: _kPrimary,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Center(
              child: pw.Text('$n',
                  style: _ts(fb,
                      size: 9, color: PdfColors.white)),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(m.name,
                    style: _ts(fb, size: 12, color: _kTextDark)),
                if (parts.isNotEmpty)
                  pw.Text(parts.join(' · '),
                      style: _ts(f,
                          size: 10, color: _kTextMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Prescription footer: doctor info + signature in one harmonious block.
  static pw.Widget _rxFooter(
      Doctor doc, pw.Font f, pw.Font fb,
      {Uint8List? signatureBytes}) {
    return pw.Container(
      margin: const pw.EdgeInsets.fromLTRB(28, 10, 28, 8),
      child: pw.Column(
        children: [
          // Divider
          pw.Container(
            height: 1.5,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_kAccent, _kPrimary],
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Doctor info block
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('د. ${doc.name}',
                      style: _ts(fb, size: 12, color: _kPrimary)),
                  if (doc.specialty.isNotEmpty)
                    pw.Text(doc.specialty,
                        style: _ts(f, size: 9, color: _kTextMid)),
                  if (doc.phone.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 3),
                      child: pw.Row(children: [
                        pw.Text('📞 ',
                            style: _ts(f, size: 9, color: _kAccent)),
                        pw.Text(doc.phone,
                            style: _ts(f, size: 9, color: _kTextMid)),
                      ]),
                    ),
                  if (doc.address.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Row(children: [
                        pw.Text('📍 ',
                            style: _ts(f, size: 9, color: _kAccent)),
                        pw.Text(doc.address,
                            style: _ts(f, size: 9, color: _kTextMid)),
                      ]),
                    ),
                ],
              ),
              // Signature block
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (signatureBytes != null)
                    pw.Image(pw.MemoryImage(signatureBytes),
                        width: 110, height: 44, fit: pw.BoxFit.contain)
                  else
                    pw.Container(
                      width: 110,
                      child: pw.Divider(
                          thickness: 1, color: _kPrimary),
                    ),
                  pw.SizedBox(height: 3),
                  pw.Text('التوقيع',
                      style: _ts(f, size: 8, color: _kTextLight)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> generatePrescriptionPdf({
    required Doctor doctor,
    required Patient patient,
    required Prescription prescription,
  }) async {
    final f = await _font();
    final fb = await _fontBold();
    final sigBytes = await _loadSignatureBytes();
    final logoBytes = await _loadLogoBytes();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _rxHeader(doctor, f, fb, logoBytes: logoBytes),
            _rxPatientStrip(patient, prescription.date, f, fb),
            _rxBody(prescription, f, fb),
            pw.SizedBox(height: 10),
            _rxFooter(doctor, f, fb, signatureBytes: sigBytes),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  // ─── Invoice PDF ──────────────────────────────────────────────────────────

  static Future<Uint8List> generateInvoicePdf({
    required Doctor doctor,
    required Invoice invoice,
  }) async {
    final f = await _font();
    final fb = await _fontBold();
    final sigBytes = await _loadSignatureBytes();
    final pdf = pw.Document();
    final isPaid = invoice.status == 'paid';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(doctor, f, fb, subtitle: 'فاتورة طبية'),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(28, 18, 28, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Invoice meta row
                    pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _infoChip(
                            'رقم الفاتورة', '#${invoice.id ?? 0}', f, fb),
                        _infoChip('التاريخ', invoice.date, f, fb),
                        // Status badge
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color:
                                isPaid ? _kSuccess : _kWarning,
                            borderRadius:
                                pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            invoice.statusLabel,
                            style: _ts(fb,
                                size: 12,
                                color: PdfColors.white),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 14),

                    // Patient
                    _infoBox(f, fb, [
                      MapEntry('اسم المريض', invoice.patientName),
                    ]),
                    pw.SizedBox(height: 14),

                    // Items table
                    _sectionTitle('تفاصيل الخدمات', fb),
                    _invoiceItemsTable(invoice, f, fb),

                    if (invoice.notes.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Text('ملاحظات: ${invoice.notes}',
                          style: _ts(f,
                              size: 10,
                              color: _kTextMid)),
                    ],

                    pw.Spacer(),
                    _signature(doctor, f, fb, signatureBytes: sigBytes),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(28, 0, 28, 8),
              child: _footer(doctor, f),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static pw.Widget _infoChip(
      String label, String value, pw.Font f, pw.Font fb) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _kBg,
        border: pw.Border.all(color: _kBorder),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: _ts(f, size: 8, color: _kTextLight)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: _ts(fb, size: 12, color: _kPrimary)),
        ],
      ),
    );
  }

  static pw.Widget _invoiceItemsTable(
      Invoice invoice, pw.Font f, pw.Font fb) {
    final cols = {
      0: const pw.FlexColumnWidth(4),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FlexColumnWidth(1.5),
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Table(
          columnWidths: cols,
          border: pw.TableBorder.all(color: _kBorder, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _kPrimary),
              children: ['الخدمة', 'الكمية', 'السعر', 'الإجمالي']
                  .map(_headerCell.bind(fb))
                  .toList(),
            ),
            ...invoice.items.asMap().entries.map((e) {
              final it = e.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: e.key.isEven ? PdfColors.white : _kRowAlt),
                children: [
                  _cell(it.name, f),
                  _cell('${it.quantity}', f,
                      align: pw.Alignment.center),
                  _cell(it.price.toStringAsFixed(2), f,
                      align: pw.Alignment.center),
                  _cell(it.total.toStringAsFixed(2), fb,
                      align: pw.Alignment.center,
                      bold: true),
                ],
              );
            }),
          ],
        ),
        // Total row
        pw.Container(
          decoration: const pw.BoxDecoration(
            color: _kPrimary,
            border: pw.Border(
              bottom: pw.BorderSide(color: _kAccent, width: 3),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: pw.Text('المجموع الكلي:',
                    style: _ts(fb,
                        size: 13,
                        color: PdfColors.white)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: pw.Text(
                    '${invoice.total.toStringAsFixed(2)} د.ع',
                    style: _ts(fb,
                        size: 15,
                        color: PdfColors.yellow100)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Patient Report PDF ───────────────────────────────────────────────────

  static Future<Uint8List> generatePatientReportPdf({
    required Doctor doctor,
    required Patient patient,
    required List<Appointment> appointments,
    required List<Prescription> prescriptions,
  }) async {
    final f = await _font();
    final fb = await _fontBold();
    final sigBytes = await _loadSignatureBytes();
    final logoBytes = await _loadLogoBytes();
    final pdf = pw.Document();

    pw.Widget p(pw.Widget w) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28), child: w);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.zero,
        header: (_) => _rxHeader(doctor, f, fb,
            logoBytes: logoBytes, subtitle: 'ملف المريض الطبي'),
        footer: (_) => _rxFooter(doctor, f, fb, signatureBytes: sigBytes),
        build: (ctx) => [
          p(pw.SizedBox(height: 14)),

          // Patient basic info
          p(_sectionTitle('معلومات المريض', fb)),
          p(_infoBox(f, fb, [
            MapEntry('رقم الملف', '#${patient.id}'),
            MapEntry('الاسم', patient.name),
            MapEntry('الهاتف', patient.phone),
            MapEntry('الجنس', patient.gender),
            MapEntry('فصيلة الدم', patient.bloodType),
            MapEntry('تاريخ الميلاد', patient.birthDate),
            MapEntry('العمر', patient.age > 0 ? '${patient.age} سنة' : ''),
            MapEntry('العنوان', patient.address),
          ])),
          p(pw.SizedBox(height: 16)),

          // Appointments
          p(_sectionTitle('سجل المواعيد (${appointments.length})', fb)),
          if (appointments.isEmpty)
            p(pw.Text('لا توجد مواعيد مسجّلة',
                style: _ts(f, size: 10, color: _kTextMid)))
          else
            p(_appointmentsTable(appointments, f, fb)),
          p(pw.SizedBox(height: 16)),

          // Prescriptions
          p(_sectionTitle('الوصفات الطبية (${prescriptions.length})', fb)),
          if (prescriptions.isEmpty)
            p(pw.Text('لا توجد وصفات مسجّلة',
                style: _ts(f, size: 10, color: _kTextMid)))
          else
            ...prescriptions.map((pr) => p(_prescSummaryCard(pr, f, fb))),

          p(pw.SizedBox(height: 20)),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _prescSummaryCard(
      Prescription p, pw.Font f, pw.Font fb) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _kBg,
        border: pw.Border.all(color: _kBorder, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${p.date} — ${p.diagnosis}',
                  style: _ts(fb, size: 11, color: _kPrimary)),
              pw.Text(
                  '${p.medications.length} دواء',
                  style: _ts(f, size: 9, color: _kTextLight)),
            ],
          ),
          if (p.medications.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
                p.medications.map((m) => m.name).join(' • '),
                style: _ts(f, size: 10, color: _kTextMid)),
          ],
        ],
      ),
    );
  }

  // ─── Backup PDF ───────────────────────────────────────────────────────────

  static Future<Uint8List> generateBackupPdf({
    required Doctor doctor,
    required List<Patient> patients,
    required List<Appointment> appointments,
    required List<Prescription> prescriptions,
    required List<Invoice> invoices,
  }) async {
    final f = await _font();
    final fb = await _fontBold();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(24, 0, 24, 20),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: _header(doctor, f, fb,
              subtitle:
                  'نسخة احتياطية — ${DateTime.now().toIso8601String().substring(0, 10)}'),
        ),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: _footer(doctor, f),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          _sectionTitle('المرضى (${patients.length})', fb),
          _patientsTable(patients, f, fb),
          pw.SizedBox(height: 16),
          _sectionTitle('المواعيد (${appointments.length})', fb),
          _appointmentsTable(appointments, f, fb),
          pw.SizedBox(height: 16),
          _sectionTitle('الوصفات (${prescriptions.length})', fb),
          _prescriptionsTable(prescriptions, f, fb),
          if (invoices.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('الفواتير (${invoices.length})', fb),
            _invoicesTable(invoices, f, fb),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  // ─── Statistics PDF ───────────────────────────────────────────────────────

  static Future<Uint8List> generateStatisticsPdf({
    required Doctor doctor,
    required int year,
    required List<String> monthNames,
    required List<int> monthlyAppointments,
    required List<int> monthlyPatients,
    required List<double> monthlyRevenue,
    required double totalRevenue,
    List<double> monthlyExpenses = const [],
    double totalExpenses = 0,
    required List<Map<String, dynamic>> topDiagnoses,
  }) async {
    final f = await _font();
    final fb = await _fontBold();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(28, 0, 28, 20),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: _header(doctor, f, fb,
              subtitle: 'تقرير الإحصائيات — $year'),
        ),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: _footer(doctor, f),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          // Revenue summary banner
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _kSuccessBg,
              border: pw.Border.all(color: _kSuccess),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('إجمالي الإيرادات المحصّلة:',
                    style: _ts(fb, size: 13, color: _kSuccess)),
                pw.Text(
                    '${totalRevenue.toStringAsFixed(2)} د.ع',
                    style: _ts(fb, size: 16, color: _kSuccess)),
              ],
            ),
          ),
          if (totalExpenses > 0) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FEE2E2'),
                border: pw.Border.all(color: PdfColor.fromHex('#EF4444')),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('إجمالي المصاريف:',
                      style: _ts(fb, size: 12,
                          color: PdfColor.fromHex('#DC2626'))),
                  pw.Text('${totalExpenses.toStringAsFixed(2)} د.ع',
                      style: _ts(fb, size: 14,
                          color: PdfColor.fromHex('#DC2626'))),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: totalRevenue >= totalExpenses
                    ? _kSuccessBg
                    : PdfColor.fromHex('#FEE2E2'),
                border: pw.Border.all(
                  color: totalRevenue >= totalExpenses
                      ? _kSuccess
                      : PdfColor.fromHex('#EF4444'),
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('صافي الربح:',
                      style: _ts(fb, size: 12,
                          color: totalRevenue >= totalExpenses
                              ? _kSuccess
                              : PdfColor.fromHex('#DC2626'))),
                  pw.Text(
                      '${(totalRevenue - totalExpenses).toStringAsFixed(2)} د.ع',
                      style: _ts(fb, size: 14,
                          color: totalRevenue >= totalExpenses
                              ? _kSuccess
                              : PdfColor.fromHex('#DC2626'))),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          _sectionTitle('الإحصائيات الشهرية', fb),
          _statsMonthlyTable(monthNames, monthlyAppointments,
              monthlyPatients, monthlyRevenue,
              monthlyExpenses.isEmpty
                  ? List.filled(12, 0.0)
                  : monthlyExpenses,
              f, fb),
          if (topDiagnoses.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('أكثر الأمراض شيوعاً', fb),
            _diagnosesTable(topDiagnoses, f, fb),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _statsMonthlyTable(
    List<String> months,
    List<int> appts,
    List<int> pats,
    List<double> rev,
    List<double> exp,
    pw.Font f,
    pw.Font fb,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
        5: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kPrimary),
          children: [
            'الشهر', 'المواعيد', 'المرضى',
            'إيرادات (د.ع)', 'مصاريف (د.ع)', 'صافي (د.ع)',
          ].map(_headerCell.bind(fb)).toList(),
        ),
        ...List.generate(12, (i) {
          final net = rev[i] - exp[i];
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isEven ? PdfColors.white : _kRowAlt),
            children: [
              _cell(months[i], fb, bold: true),
              _cell('${appts[i]}', f, align: pw.Alignment.center),
              _cell('${pats[i]}', f, align: pw.Alignment.center),
              _cell(rev[i].toStringAsFixed(2), f,
                  align: pw.Alignment.center),
              _cell(exp[i].toStringAsFixed(2), f,
                  align: pw.Alignment.center),
              _cell(net.toStringAsFixed(2), fb,
                  align: pw.Alignment.center,
                  bold: true,
                  color: net >= 0 ? _kSuccess : PdfColor.fromHex('#DC2626')),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _diagnosesTable(
      List<Map<String, dynamic>> diag, pw.Font f, pw.Font fb) {
    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kPrimary),
          children: ['#', 'التشخيص', 'العدد']
              .map(_headerCell.bind(fb))
              .toList(),
        ),
        ...diag.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: e.key.isEven ? PdfColors.white : _kRowAlt),
              children: [
                _cell('${e.key + 1}', fb,
                    color: _kAccent,
                    bold: true,
                    align: pw.Alignment.center),
                _cell(e.value['diagnosis'] as String, f),
                _cell('${e.value['count']}', fb,
                    align: pw.Alignment.center,
                    bold: true),
              ],
            )),
      ],
    );
  }

  // ─── Shared table helpers ─────────────────────────────────────────────────

  static pw.Widget _patientsTable(
      List<Patient> patients, pw.Font f, pw.Font fb) {
    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kPrimary),
          children: ['#', 'الاسم', 'الهاتف', 'فصيلة الدم']
              .map(_headerCell.bind(fb))
              .toList(),
        ),
        ...patients.asMap().entries.map((e) {
          final p = e.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: e.key.isEven ? PdfColors.white : _kRowAlt),
            children: [
              _cell('${p.id}', f, align: pw.Alignment.center),
              _cell(p.name, fb, bold: true),
              _cell(p.phone, f),
              _cell(p.bloodType, f, align: pw.Alignment.center),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _appointmentsTable(
      List<Appointment> appts, pw.Font f, pw.Font fb) {
    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kPrimary),
          children: ['المريض', 'التاريخ', 'النوع', 'الحالة']
              .map(_headerCell.bind(fb))
              .toList(),
        ),
        ...appts.asMap().entries.map((e) {
          final a = e.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: e.key.isEven ? PdfColors.white : _kRowAlt),
            children: [
              _cell(a.patientName, fb, bold: true),
              _cell('${a.date}\n${a.time}', f),
              _cell(a.type, f),
              _cell(a.statusLabel, f),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _prescriptionsTable(
      List<Prescription> presc, pw.Font f, pw.Font fb) {
    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kPrimary),
          children: ['المريض', 'التاريخ', 'التشخيص']
              .map(_headerCell.bind(fb))
              .toList(),
        ),
        ...presc.asMap().entries.map((e) {
          final p = e.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: e.key.isEven ? PdfColors.white : _kRowAlt),
            children: [
              _cell(p.patientName, fb, bold: true),
              _cell(p.date, f),
              _cell(p.diagnosis, f),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _invoicesTable(
      List<Invoice> inv, pw.Font f, pw.Font fb) {
    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kPrimary),
          children: ['المريض', 'التاريخ', 'المبلغ', 'الحالة']
              .map(_headerCell.bind(fb))
              .toList(),
        ),
        ...inv.asMap().entries.map((e) {
          final i = e.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: e.key.isEven ? PdfColors.white : _kRowAlt),
            children: [
              _cell(i.patientName, fb, bold: true),
              _cell(i.date, f),
              _cell('${i.total.toStringAsFixed(2)} د.ع', fb,
                  bold: true),
              _cell(i.statusLabel, f),
            ],
          );
        }),
      ],
    );
  }
}

class _PdfHelpers {
  static pw.Widget _hCell(String text, pw.Font fb) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          style: pw.TextStyle(
              font: fb, fontSize: 10, color: PdfColors.white)),
    );
  }
}

// Workaround: bind fb to _headerCell via closure
extension _FontBind on Function {
  pw.Widget Function(String) bind(pw.Font fb) =>
      (String text) => _PdfHelpers._hCell(text, fb);
}
