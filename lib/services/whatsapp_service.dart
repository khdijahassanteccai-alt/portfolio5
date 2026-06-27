import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static const _keyPhone = 'wa_clinic_phone';
  static const _keyTemplate = 'wa_message_template';
  static const _keyCountryCode = 'wa_country_code';

  static const defaultTemplate =
      'السلام عليكم، نذكّركم بموعدكم في {اسم_العيادة} يوم {التاريخ} الساعة {الوقت}.';
  static const defaultCountryCode = '964';

  // ─── Persist ────────────────────────────────────────────────────────────────

  static Future<String> getClinicPhone() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyPhone) ?? '';
  }

  static Future<void> saveClinicPhone(String phone) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyPhone, phone.trim());
  }

  static Future<String> getMessageTemplate() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyTemplate) ?? defaultTemplate;
  }

  static Future<void> saveMessageTemplate(String template) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyTemplate, template.trim());
  }

  static Future<String> getCountryCode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyCountryCode) ?? defaultCountryCode;
  }

  static Future<void> saveCountryCode(String code) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyCountryCode, code.trim().replaceAll(RegExp(r'\D'), ''));
  }

  // ─── Message building ────────────────────────────────────────────────────────

  /// Replaces {اسم_المريض}, {التاريخ}, {الوقت}, {اسم_العيادة} in [template].
  static String buildMessage({
    required String template,
    required String patientName,
    required String date,
    required String time,
    required String clinicName,
  }) {
    final effective = template.isEmpty ? defaultTemplate : template;
    return effective
        .replaceAll('{اسم_المريض}', patientName)
        .replaceAll('{التاريخ}', date)
        .replaceAll('{الوقت}', time)
        .replaceAll('{اسم_العيادة}', clinicName);
  }

  // ─── Phone cleaning ──────────────────────────────────────────────────────────

  /// Normalises [raw] to an international number (digits only, no +).
  /// - Strips spaces, +, -, (, )
  /// - Removes leading 00
  /// - If starts with 0 → replaces it with [countryCode] (default 964 Iraq)
  /// - If already starts with [countryCode] → leaves as is
  /// - Otherwise prepends [countryCode] (handles numbers without leading 0)
  static String cleanPhone(String raw, {String countryCode = defaultCountryCode}) {
    var phone = raw
        .trim()
        .replaceAll(RegExp(r'[\s\+\-\(\)]'), '')
        .replaceAll(RegExp(r'\D'), '');

    if (phone.isEmpty) return '';

    if (phone.startsWith('00')) phone = phone.substring(2);

    if (phone.startsWith(countryCode)) return phone;

    if (phone.startsWith('0')) phone = phone.substring(1);

    return countryCode + phone;
  }

  // ─── Open WhatsApp ───────────────────────────────────────────────────────────

  /// Opens WhatsApp with [message] pre-filled in the text field.
  /// Returns `true` if WhatsApp was opened, `false` otherwise.
  static Future<bool> send({
    required String patientPhone,
    required String message,
  }) async {
    final countryCode = await getCountryCode();
    final phone = cleanPhone(patientPhone, countryCode: countryCode);
    if (phone.isEmpty) return false;
    // wa.me link pre-fills the message; user only needs to tap Send.
    final url = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
