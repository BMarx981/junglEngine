import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Shorthand for the generated lookup, because `context.l10n.foo` reads at a
/// glance and `AppLocalizations.of(context)!.foo` does not, at forty call sites.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// U+2068 FIRST STRONG ISOLATE and U+2069 POP DIRECTIONAL ISOLATE, built from
/// code points because both are invisible in an editor and a literal pair is
/// impossible to review.
final String _isolateStart = String.fromCharCode(0x2068);
final String _isolateEnd = String.fromCharCode(0x2069);

/// Wraps user data in Unicode isolates before it goes into translated prose.
///
/// Beat names, break names and file names are Latin. Dropped bare into an
/// Arabic sentence the bidi algorithm reorders them against the surrounding
/// run, so "ADD BEAT A" comes apart. Isolating pins the run, and costs nothing
/// in the eleven left to right locales.
String iso(String value) => '$_isolateStart$value$_isolateEnd';

/// The delegates to hand [MaterialApp], for the app and for tests alike.
///
/// [AppLocalizations.localizationsDelegates] alone is not enough. It pairs this
/// app's own strings with Flutter's bundled Material, Cupertino and Widgets
/// translations, and those do not cover Haitian Creole: with the stock list,
/// `ht` makes Flutter warn on every launch and leaves the framework's own
/// strings unresolved. The fallbacks below serve English for exactly the
/// locales Flutter has never heard of, so junglEngine is in Kreyòl and the
/// handful of framework strings around it are in English rather than missing.
///
/// If Flutter ever adds `ht`, its own delegate starts answering first and these
/// stop being consulted. Nothing here needs removing on that day.
List<LocalizationsDelegate<dynamic>> get junglengineLocalizationsDelegates => [
  ...AppLocalizations.localizationsDelegates,
  const _FallbackMaterialDelegate(),
  const _FallbackCupertinoDelegate(),
  const _FallbackWidgetsDelegate(),
];

/// True for a locale this app ships but Flutter does not translate.
bool _needsFallback(Locale locale) =>
    !GlobalMaterialLocalizations.delegate.isSupported(locale);

class _FallbackMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialDelegate();

  @override
  bool isSupported(Locale locale) => _needsFallback(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_FallbackMaterialDelegate old) => false;
}

class _FallbackCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => _needsFallback(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_FallbackCupertinoDelegate old) => false;
}

class _FallbackWidgetsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _FallbackWidgetsDelegate();

  @override
  bool isSupported(Locale locale) => _needsFallback(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_FallbackWidgetsDelegate old) => false;
}
