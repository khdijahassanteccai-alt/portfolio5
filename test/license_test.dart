import 'package:flutter_test/flutter_test.dart';
import 'package:doctor/config.dart';

void main() {
  group('رمز الترخيص - AppConfig', () {
    test('الرمز الصحيح يُقبل', () {
      const entered = 'ahmed2024';
      expect(entered == AppConfig.licenseKey, isTrue);
    });

    test('الرمز الخاطئ يُرفض', () {
      const wrong = 'wrongkey';
      expect(wrong == AppConfig.licenseKey, isFalse);
    });

    test('الرمز حساس لحالة الأحرف', () {
      const upper = 'AHMED2024';
      expect(upper == AppConfig.licenseKey, isFalse);
    });

    test('الرمز الفارغ يُرفض', () {
      const empty = '';
      expect(empty == AppConfig.licenseKey, isFalse);
    });

    test('رمز فيه مسافة إضافية يُرفض', () {
      const withSpace = ' ahmed2024';
      expect(withSpace == AppConfig.licenseKey, isFalse);
    });

    test('اسم الطبيب واسم العيادة غير فارغَين', () {
      expect(AppConfig.doctorName, isNotEmpty);
      expect(AppConfig.clinicName, isNotEmpty);
    });

    test('الرمز الصحيح بعد trim() يُقبل', () {
      // يحاكي سلوك حقل النص عند الإدخال مع مسافة عرضية
      const withTrim = '  ahmed2024  ';
      expect(withTrim.trim() == AppConfig.licenseKey, isTrue);
    });
  });
}
