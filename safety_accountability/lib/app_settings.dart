import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings shared between the Settings sheet (in header.dart) and
/// main.dart. Using ValueNotifier keeps this simple — no extra state
/// management package needed for a handful of app-wide switches.
///
/// Every notifier below is backed by shared_preferences: changing it saves
/// immediately, and loadSavedSettings() (called once from main.dart before
/// runApp) restores them before the first frame, so nothing flashes back
/// to a default and then jumps.

const String _kTheme = 'settings_theme_dark';
const String _kLanguage = 'settings_language';
const String _kNotifEmergency = 'settings_notif_emergency';
const String _kNotifCommunity = 'settings_notif_community';
const String _kNotifMessages = 'settings_notif_messages';
const String _kNotifWeekly = 'settings_notif_weekly';
const String _kPrivacyLocation = 'settings_privacy_location';
const String _kPrivacyProfile = 'settings_privacy_profile';
const String _kPrivacyAnonymous = 'settings_privacy_anonymous';

/// Whether someone is signed in. main.dart watches this to decide whether
/// to show AuthPage (sign up / log in) or the real app (HomeScreen).
/// Deliberately NOT persisted here — AuthService.tryAutoLogin() in
/// main.dart already restores the real session from the stored token,
/// which is the actual source of truth for "is this person logged in".
final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);

/// Light/Dark mode. main.dart listens to this to rebuild MaterialApp with
/// the matching theme the instant it changes.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// Selected app language. Changing this does NOT translate the UI yet —
/// real translation needs the flutter_localizations package plus .arb
/// translation files for every string in the app, which is a bigger job
/// on its own. This saves the person's choice so that work can plug in
/// here later without touching the Settings screen again.
final ValueNotifier<String> languageNotifier = ValueNotifier('English');

const List<String> appLanguages = [
  'English',
  'Afrikaans',
  'isiZulu',
  'isiXhosa',
  'Sesotho',
  'Setswana',
];

/// Notification preference toggles, shared app-wide.
class NotificationPrefs {
  static final ValueNotifier<bool> emergencyAlerts = ValueNotifier(true);
  static final ValueNotifier<bool> communityPosts = ValueNotifier(true);
  static final ValueNotifier<bool> messages = ValueNotifier(true);
  static final ValueNotifier<bool> weeklyReports = ValueNotifier(false);
}

/// Privacy preference toggles, shared app-wide.
class PrivacyPrefs {
  static final ValueNotifier<bool> shareLocationWithContacts = ValueNotifier(true);
  static final ValueNotifier<bool> showProfileToCommunity = ValueNotifier(true);
  static final ValueNotifier<bool> anonymousReportsStayAnonymous = ValueNotifier(true);
}

bool _persistenceWired = false;

/// Call once from main.dart, before runApp(), so saved settings are in
/// place before the first frame renders.
Future<void> loadSavedSettings() async {
  final prefs = await SharedPreferences.getInstance();

  themeNotifier.value = (prefs.getBool(_kTheme) ?? false) ? ThemeMode.dark : ThemeMode.light;
  languageNotifier.value = prefs.getString(_kLanguage) ?? 'English';
  NotificationPrefs.emergencyAlerts.value = prefs.getBool(_kNotifEmergency) ?? true;
  NotificationPrefs.communityPosts.value = prefs.getBool(_kNotifCommunity) ?? true;
  NotificationPrefs.messages.value = prefs.getBool(_kNotifMessages) ?? true;
  NotificationPrefs.weeklyReports.value = prefs.getBool(_kNotifWeekly) ?? false;
  PrivacyPrefs.shareLocationWithContacts.value = prefs.getBool(_kPrivacyLocation) ?? true;
  PrivacyPrefs.showProfileToCommunity.value = prefs.getBool(_kPrivacyProfile) ?? true;
  PrivacyPrefs.anonymousReportsStayAnonymous.value = prefs.getBool(_kPrivacyAnonymous) ?? true;

  if (_persistenceWired) return;
  _persistenceWired = true;

  // Wire each notifier to save itself the moment it changes, rather than
  // requiring every call site in the app to remember to persist it.
  themeNotifier.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTheme, themeNotifier.value == ThemeMode.dark);
  });
  languageNotifier.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLanguage, languageNotifier.value);
  });
  NotificationPrefs.emergencyAlerts.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifEmergency, NotificationPrefs.emergencyAlerts.value);
  });
  NotificationPrefs.communityPosts.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifCommunity, NotificationPrefs.communityPosts.value);
  });
  NotificationPrefs.messages.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifMessages, NotificationPrefs.messages.value);
  });
  NotificationPrefs.weeklyReports.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifWeekly, NotificationPrefs.weeklyReports.value);
  });
  PrivacyPrefs.shareLocationWithContacts.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPrivacyLocation, PrivacyPrefs.shareLocationWithContacts.value);
  });
  PrivacyPrefs.showProfileToCommunity.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPrivacyProfile, PrivacyPrefs.showProfileToCommunity.value);
  });
  PrivacyPrefs.anonymousReportsStayAnonymous.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPrivacyAnonymous, PrivacyPrefs.anonymousReportsStayAnonymous.value);
  });
}

/// Maps each language name in `appLanguages` to its BCP-47 locale code, for
/// flutter_localizations. main.dart reads this off languageNotifier to
/// drive MaterialApp's `locale:` property the instant it changes.
const Map<String, String> languageLocaleCodes = {
  'English': 'en',
  'Afrikaans': 'af',
  'isiZulu': 'zu',
  'isiXhosa': 'xh',
  'Sesotho': 'st',
  'Setswana': 'tn',
};

Locale localeForLanguage(String language) {
  return Locale(languageLocaleCodes[language] ?? 'en');
}