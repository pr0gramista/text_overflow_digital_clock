import 'dart:math';

/// TextIndexer is a utility class that handles taking parts of one string with
/// the possibility to replace [percantage] of it with the old one.
///
/// This is used for background pattern animation of [DigitalClock]
class TextIndexer {
  /// This [Random] instance with constant seed is the reason why the
  /// animation does not flicker and renders the same even it is "random".
  final Random _random = Random(5892589);

  final String _currentText;
  final String _oldText;
  final int percantage;
  int index = 0;

  TextIndexer(
    this._currentText,
    this._oldText,
    this.percantage,
  );

  bool _useOld() {
    return percantage != 100 && _random.nextInt(100) >= percantage;
  }

  /// Supplies part of the initial String with [percantage] of it consisting old String.
  String part(length) {
    String textToReturn = "";
    for (var i = 0; i < length; i++) {
      if (_useOld()) {
        textToReturn += _oldText[index + i];
      } else {
        textToReturn += _currentText[index + i];
      }
    }
    index += length;
    return textToReturn;
  }
}
