import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'clinic_appointments';
  static const _channelName = 'مواعيد العيادة';

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> scheduleAppointmentReminder({
    required int appointmentId,
    required String patientName,
    required DateTime appointmentDateTime,
  }) async {
    final reminderTime =
        appointmentDateTime.subtract(const Duration(hours: 1));
    if (reminderTime.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'تذكيرات المواعيد الطبية',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      appointmentId,
      'تذكير موعد طبي',
      'لديك موعد مع $patientName في الساعة '
          '${appointmentDateTime.hour.toString().padLeft(2, '0')}:'
          '${appointmentDateTime.minute.toString().padLeft(2, '0')}',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int appointmentId) async {
    await _plugin.cancel(appointmentId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> showInstant({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}
