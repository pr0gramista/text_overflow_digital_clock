import 'dart:async';
import 'dart:math';

import 'package:digital_clock/text_indexer.dart';
import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final Random random = Random();

List<int> range(from, to) {
  assert(to > from);
  assert(to - from >= 1);

  return List<int>.generate(to - from, (i) => i + from);
}

/// Character codes for background pattern
final List<int> codes = [
  ...range(48, 57),
  ...range(65, 90),
];

/// Returns one randomly chosen element from the list
T takeRandom<T>(List<T> list) {
  return list[random.nextInt(list.length)];
}

const List<MaterialColor> warmPrimaries = <MaterialColor>[
  Colors.red,
  Colors.pink,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
];

const List<MaterialColor> coldPrimaries = <MaterialColor>[
  Colors.indigo,
  Colors.blue,
  Colors.cyan,
  Colors.deepPurple,
  Colors.purple,
];

const List<MaterialColor> neutralPrimaries = <MaterialColor>[
  Colors.lightBlue,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
];

/// Matches points with all [WeatherCondition]s.
const weatherToPoints = {
  WeatherCondition.cloudy: 0,
  WeatherCondition.foggy: -5,
  WeatherCondition.rainy: -15,
  WeatherCondition.snowy: -5,
  WeatherCondition.sunny: 10,
  WeatherCondition.thunderstorm: -20,
  WeatherCondition.windy: -5
};

/// Generates 5000 random characters consisting of upper case alphabet and digits.
/// 5000 is a magic number - well enough to fill the screen, but not bloat the memory too much.
String _generateText() {
  final charCodes = List<int>.generate(5000, (i) => takeRandom(codes));

  return String.fromCharCodes(charCodes);
}

/// Generates [String] filled with spaces with the [length]
String empty(length) {
  final charCodes = List<int>.generate(length, (i) => 32);

  return String.fromCharCodes(charCodes);
}

const lineEnd = "\n";

const fontFamily = 'JetBrainsMono';

const int width = 96;

/// TextOverflowDigitalClock is digital clock with background filled with randomized
/// characters and digits that are animated when the time changes. Some people would
/// call this effect similar to one in The Matrix. This creates subtle assembling
/// motion, which is also practical for assuring user than the time in fact
/// changed - as the clock change is sudden.
///
/// The background is filled with color that is representing the surroundings. This color
/// changes every 15 minutes.
///
/// Warmer colors are used when it gets warmer outside, weather is nice and when it
/// is morning - to help you get out of bed.
///
/// Colder colors are used whene it gets colder, weather is bad and when it is
/// night - to help you fall asleep.
///
/// The clock tracks temperature (60 readings per 1 minute) get the sense of
/// how the temperature change.
///
/// The clock also supports dark mode and 24/12 hour.
///
/// And yes - the namee does refer to Stack Overflow
class TextOverflowDigitalClock extends StatefulWidget {
  const TextOverflowDigitalClock(this.model);

  final ClockModel model;

  @override
  _TextOverflowDigitalClockState createState() =>
      _TextOverflowDigitalClockState();
}

class _TextOverflowDigitalClockState extends State<TextOverflowDigitalClock>
    with TickerProviderStateMixin {
  DateTime _dateTime = DateTime.now();
  Timer _timer;

  // Related to theming
  List<double> _temperatures = [];
  Timer _themeTimer;
  int _points = 0;

  /// Controller for background pattern animation
  AnimationController _patternAnimationController;
  Animation<int> _patternAnimation;

  AnimationController _textColorAnimationController;
  Animation<Color> _textColorAnimation;

  MaterialColor _currentMainColor;

  String _currentTextPattern;
  String _oldTextPattern;

  @override
  void initState() {
    super.initState();

    // Prepare animations
    _patternAnimationController =
        AnimationController(duration: const Duration(seconds: 5), vsync: this);
    _patternAnimation =
        IntTween(begin: 0, end: 100).animate(_patternAnimationController);
    _textColorAnimationController =
        AnimationController(duration: const Duration(seconds: 10), vsync: this);
    _textColorAnimation = ColorTween(begin: Colors.black, end: Colors.black)
        .animate(_textColorAnimationController);

    _currentTextPattern = _generateText();
    _patternAnimationController.forward();

    widget.model.addListener(_updateModel);
    _updateTime();
    _updateTheme();
    _updateModel();
  }

  @override
  void didUpdateWidget(TextOverflowDigitalClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _themeTimer?.cancel();
    widget.model.removeListener(_updateModel);
    widget.model.dispose();
    _patternAnimationController?.dispose();
    _textColorAnimationController?.dispose();
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      // Cause the clock to rebuild when the model changes.
    });
  }

  void _updateTheme() {
    final oldBackgroundColor = _currentMainColor?.shade700;

    setState(() {
      _themeTimer = Timer(
        Duration(minutes: 15), // HERE: Change time to make theme update quicker
        _updateTheme,
      );
      _points = _computePoints();

      // Choose new clock main color
      if (_points >= 5) {
        _currentMainColor = takeRandom(warmPrimaries);
      } else if (_points <= 10) {
        _currentMainColor = takeRandom(coldPrimaries);
      } else {
        _currentMainColor = takeRandom(neutralPrimaries);
      }

      _textColorAnimation = ColorTween(
              begin: oldBackgroundColor ?? Colors.black,
              end: _currentMainColor.shade700)
          .animate(_textColorAnimationController);
    });

    _textColorAnimationController.reset();
    _textColorAnimationController.forward();
  }

  void _updateTime() {
    setState(() {
      _dateTime = DateTime.now();

      // Update once per minute
      _timer = Timer(
        Duration(minutes: 1) -
            Duration(seconds: _dateTime.second) -
            Duration(milliseconds: _dateTime.millisecond),
        _updateTime,
      );

      // Add temperature reading. Doing this inside _updateTime rather than _updateModel
      // since we want to have constant interval reading
      _temperatures = [
        // If there is more than 60 minutes worth of readings, remove the oldest one
        if (_temperatures.length >= 60)
          ..._temperatures.sublist(1)
        else
          ..._temperatures,
        widget.model.temperature
      ];

      _oldTextPattern = _currentTextPattern;
      _currentTextPattern = _generateText();
    });

    _patternAnimationController.reset();
    _patternAnimationController.forward();
  }

  /// Generates [count] [TextSpan] filled with [width] of [indexer] parts.
  ///
  /// Used for background creation.
  List<TextSpan> getLines(
      {@required TextIndexer indexer,
      @required int count,
      @required int width}) {
    return List<int>.generate(count, (i) => i)
        .map<TextSpan>((i) => TextSpan(text: indexer.part(width)))
        .toList();
  }

  /// Computes points for choosing clock main color.
  int _computePoints() {
    int points = 0;

    // Weather
    final WeatherCondition currentWeather = widget.model.weatherCondition;

    points += weatherToPoints[currentWeather];

    // Temperature, if already has 3 readings
    if (_temperatures.length > 3) {
      final lastAverageTemperature =
          _temperatures.reduce((t1, t2) => t1 + t2) / _temperatures.length;

      if (widget.model.temperature > lastAverageTemperature) {
        points += 11;
      } else {
        points -= 4;
      }
    }

    // Time
    // Prefer cold when night
    if (_dateTime.hour >= 21 && _dateTime.hour < 4) {
      points -= 6;
    }

    // Prefer light when morning
    if (_dateTime.hour < 12 && _dateTime.hour >= 4) {
      points += 8;
    }

    return points;
  }

  /// Builder function for [AnimatedBuilder]
  ///
  /// Applies text color animation for the background of the clock
  Function _backgroundBuilder(
      {@required int width,
      @required String location,
      @required String temperature,
      @required TextStyle style,
      @required Color backgroundTextColor}) {
    TextStyle backgroundTextStyle = style.copyWith(color: backgroundTextColor);

    return (context, child) {
      TextIndexer i = TextIndexer(
          _currentTextPattern, _oldTextPattern, _patternAnimation.value);

      return Text.rich(
        TextSpan(children: [
          TextSpan(text: i.part(width) + lineEnd),

          /// Location and temperature
          TextSpan(text: i.part(2)),
          TextSpan(text: empty(1)), // Padding
          TextSpan(text: location, style: style),
          TextSpan(text: empty(1)), // Padding
          // Fill remaing space
          TextSpan(
              text: i.part(width - location.length - 8 - temperature.length)),
          TextSpan(text: empty(1)), // Padding
          TextSpan(text: temperature, style: style),
          TextSpan(text: empty(1)), // Padding
          TextSpan(text: i.part(2) + lineEnd),
          // Fill the rest
          ...getLines(width: width, indexer: i, count: 33),
        ]),
        style: backgroundTextStyle,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Format time into 24h/12h representation
    final time = DateFormat(widget.model.is24HourFormat ? "HH:mm" : "h:mm")
        .format(_dateTime);

    final clockTextStyle = TextStyle(
      // Make clock a bit darker when in dark mode
      color: !isDarkMode ? Colors.white : Color(0xffeeeeee),
      fontFamily: fontFamily,
      fontSize: MediaQuery.of(context).size.width / 4,
    );

    final backgroundTextStyle = TextStyle(
        color: Colors.white,
        fontFamily: fontFamily,
        fontSize: MediaQuery.of(context).size.width / 58);

    final String location = widget.model.location;
    final String temperature = widget.model.temperatureString;

    return AnimatedContainer(
        duration: Duration(seconds: 10),
        decoration: BoxDecoration(color: _currentMainColor.shade500),
        child: Stack(children: [
          Container(
              // Instead of trying to match colors in animations all the time
              // we can apply dark mode by blending black on top of the background
              decoration:
                  isDarkMode ? BoxDecoration(color: Colors.black38) : null,
              child: AnimatedBuilder(
                  // AnimationBuilder for general clock color change
                  animation: _textColorAnimation,
                  builder: (context, _) => AnimatedBuilder(
                        // AnimationBuilder for background pattern animation
                        animation: _patternAnimation,
                        builder: _backgroundBuilder(
                            width: width,
                            location: location,
                            style: backgroundTextStyle,
                            backgroundTextColor: _textColorAnimation.value,
                            temperature: temperature),
                      ))),
          Center(
              child: Text(
            time,
            style: clockTextStyle,
          )),
        ]));
  }
}
