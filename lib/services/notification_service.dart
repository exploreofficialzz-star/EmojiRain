import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../constants/app_constants.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _androidChannel = AndroidNotificationDetails(
    'emoji_rain_channel',
    'Emoji Rain',
    channelDescription: 'Game reminders and alerts',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const _notifDetails = NotificationDetails(
    android: _androidChannel,
    iOS: _iosDetails,
  );

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (_) {},
    );

    _initialized = true;
    await _requestPermissions();
    await _scheduleDailyReminder();
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ── Daily reminder ────────────────────────────────────────────────────────
  Future<void> _scheduleDailyReminder() async {
    if (!_initialized) return;
    try {
      await _plugin.zonedSchedule(
        GameConstants.notifDailyReminder,
        'Emoji Rain 🎮',
        'Your emojis are waiting! Can you beat your high score? 🔥',
        _nextInstanceOf(20, 0),
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Fix: required parameter for iOS local notification date interpretation
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  // ── Comeback notification ─────────────────────────────────────────────────
  Future<void> scheduleComeback({int hoursLater = 4}) async {
    if (!_initialized) return;
    try {
      final msgs = [
        "You left mid-game! The emojis miss you 😢",
        "Come back and beat your high score! 🏆",
        "Your streak is waiting... don't break it! 🔥",
        "One more round? Your fingers can handle it 💪",
        "The emojis are judging you for leaving 👀",
      ];
      await _plugin.zonedSchedule(
        GameConstants.notifComeBack,
        'Still here? 👀',
        msgs[DateTime.now().second % msgs.length],
        tz.TZDateTime.now(tz.local).add(Duration(hours: hoursLater)),
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Fix: required parameter
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelComeback() async {
    await _plugin.cancel(GameConstants.notifComeBack);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }
}
