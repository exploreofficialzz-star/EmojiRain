import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService extends ChangeNotifier {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const String _usernameKey = 'profile_username';
  static const String _avatarKey   = 'profile_avatar';
  static const String _countryKey  = 'profile_country';
  static const String _flagKey     = 'profile_flag';

  String _username = '';
  String _avatar   = '😎';
  String _country  = '';
  String _flag     = '';

  String get username   => _username;
  String get avatar     => _avatar;
  String get country    => _country;
  String get flag       => _flag;
  bool   get isSetUp    => _username.trim().isNotEmpty;

  String get displayName => isSetUp ? _username : 'You';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _username   = prefs.getString(_usernameKey) ?? '';
    _avatar     = prefs.getString(_avatarKey)   ?? '😎';
    _country    = prefs.getString(_countryKey)  ?? '';
    _flag       = prefs.getString(_flagKey)     ?? '';
    notifyListeners();
  }

  Future<void> saveProfile({
    required String username,
    required String avatar,
    required String country,
    required String flag,
  }) async {
    _username = username.trim();
    _avatar   = avatar;
    _country  = country;
    _flag     = flag;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, _username);
    await prefs.setString(_avatarKey,   _avatar);
    await prefs.setString(_countryKey,  _country);
    await prefs.setString(_flagKey,     _flag);

    notifyListeners();
  }

  /// Available avatar emojis for the picker
  static const List<String> avatarOptions = [
    '😎', '🤩', '😏', '🥳', '🤯', '😤', '🔥', '💪',
    '🦁', '🐯', '🦊', '🐺', '🦅', '🐲', '👾', '🤖',
    '🧠', '⚡', '💎', '👑', '🎯', '🏆', '🚀', '🎮',
  ];

  /// Country + flag options
  static const List<Map<String, String>> countryOptions = [
    {'name': 'United States',   'flag': '🇺🇸'},
    {'name': 'Nigeria',          'flag': '🇳🇬'},
    {'name': 'United Kingdom',   'flag': '🇬🇧'},
    {'name': 'India',            'flag': '🇮🇳'},
    {'name': 'Brazil',           'flag': '🇧🇷'},
    {'name': 'Germany',          'flag': '🇩🇪'},
    {'name': 'Ghana',            'flag': '🇬🇭'},
    {'name': 'Kenya',            'flag': '🇰🇪'},
    {'name': 'Canada',           'flag': '🇨🇦'},
    {'name': 'France',           'flag': '🇫🇷'},
    {'name': 'Australia',        'flag': '🇦🇺'},
    {'name': 'Japan',            'flag': '🇯🇵'},
    {'name': 'South Africa',     'flag': '🇿🇦'},
    {'name': 'South Korea',      'flag': '🇰🇷'},
    {'name': 'Mexico',           'flag': '🇲🇽'},
    {'name': 'Indonesia',        'flag': '🇮🇩'},
    {'name': 'Pakistan',         'flag': '🇵🇰'},
    {'name': 'Bangladesh',       'flag': '🇧🇩'},
    {'name': 'Philippines',      'flag': '🇵🇭'},
    {'name': 'Egypt',            'flag': '🇪🇬'},
    {'name': 'Ethiopia',         'flag': '🇪🇹'},
    {'name': 'Tanzania',         'flag': '🇹🇿'},
    {'name': 'Uganda',           'flag': '🇺🇬'},
    {'name': 'Zimbabwe',         'flag': '🇿🇼'},
    {'name': 'Cameroon',         'flag': '🇨🇲'},
    {'name': 'Senegal',          'flag': '🇸🇳'},
    {'name': 'Ivory Coast',      'flag': '🇨🇮'},
    {'name': 'Italy',            'flag': '🇮🇹'},
    {'name': 'Spain',            'flag': '🇪🇸'},
    {'name': 'Portugal',         'flag': '🇵🇹'},
    {'name': 'Netherlands',      'flag': '🇳🇱'},
    {'name': 'Turkey',           'flag': '🇹🇷'},
    {'name': 'Saudi Arabia',     'flag': '🇸🇦'},
    {'name': 'UAE',              'flag': '🇦🇪'},
    {'name': 'Argentina',        'flag': '🇦🇷'},
    {'name': 'Colombia',         'flag': '🇨🇴'},
    {'name': 'Other',            'flag': '🌍'},
  ];
}
