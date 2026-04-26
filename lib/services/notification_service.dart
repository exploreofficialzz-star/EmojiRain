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

  // ── Notification Channel Details (Android) ─────────────────────────────────
  static const _androidChannel = AndroidNotificationDetails(
    'emoji_rain_channel',
    'Emoji Rain',
    channelDescription: 'Game reminders and alerts',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,          // Uses device default notification sound
    enableVibration: true,
    styleInformation: BigTextStyleInformation(''),
    icon: '@mipmap/ic_launcher',
  );

  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,       // Uses device default notification sound
  );

  static const _notifDetails = NotificationDetails(
    android: _androidChannel,
    iOS: _iosDetails,
  );

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotifTapped,
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

  void _onNotifTapped(NotificationResponse response) {
    // Game opens from notification — no special routing needed
  }

  // ── Scheduled Notifications ────────────────────────────────────────────────
  /// Daily reminder at 8 PM local time
  Future<void> _scheduleDailyReminder() async {
    if (!_initialized) return;
    try {
      await _plugin.zonedSchedule(
        GameConstants.notifDailyReminder,
        'Emoji Rain 🎮',
        'Your emojis are waiting! Can you beat your high score? 🔥',
        _nextInstanceOfTime(20, 0),   // 8:00 PM
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  /// "Come back" notification — scheduled when app goes to background
  Future<void> scheduleComeback({int hoursLater = 6}) async {
    if (!_initialized) return;
    try {
      await _plugin.zonedSchedule(
        GameConstants.notifComeBack,
        'Still here? 👀',
        _comebackMessages[DateTime.now().second % _comebackMessages.length],
        tz.TZDateTime.now(tz.local).add(Duration(hours: hoursLater)),
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  /// Cancel the comeback notification (app opened before it fires)
  Future<void> cancelComeback() async {
    await _plugin.cancel(GameConstants.notifComeBack);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static const List<String> _comebackMessages = [
    "You left mid-game! The emojis miss you 😢",
    "Come back and beat your high score! 🏆",
    "Your streak is waiting... don't break it! 🔥",
    "One more round? Your fingers can handle it 💪",
    "The emojis are judging you for leaving 👀",
  ];
}
