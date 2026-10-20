import 'package:flutter/foundation.dart';

/// Lets one screen ask another part of the app to open something.
class AppNav {
  /// Asks the home screen to show a tab: 0 map, 1 emergency, 2 e-hailing, 3 community.
  static final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  /// Asks the header to open Messages on this conversation.
  static final ValueNotifier<Map<String, dynamic>?> chatRequest = ValueNotifier<Map<String, dynamic>?>(null);

  static void showTab(int index) => tabRequest.value = index;
  static void openChat(Map<String, dynamic> conversation) => chatRequest.value = conversation;
}