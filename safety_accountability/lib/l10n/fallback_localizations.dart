import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter's built-in Material strings don't exist for every language the
/// app offers (for example Sesotho, Setswana and isiXhosa). For those
/// languages these delegates load the English strings instead of crashing.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final supported = GlobalMaterialLocalizations.delegate.isSupported(locale);
    return GlobalMaterialLocalizations.delegate
        .load(supported ? locale : const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final supported = GlobalCupertinoLocalizations.delegate.isSupported(locale);
    return GlobalCupertinoLocalizations.delegate
        .load(supported ? locale : const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) => false;
}