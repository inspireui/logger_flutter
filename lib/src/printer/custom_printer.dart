import 'dart:convert';

import 'package:logger/logger.dart';

import '../constant.dart';
import 'ansi_color.dart';

class CustomPrinter extends LogPrinter {
  static final levelColors = {
    Level.trace: CustomAnsiColor.fg(CustomAnsiColor.grey(0.5)),
    Level.debug: CustomAnsiColor.none(),
    Level.info: CustomAnsiColor.fg(12),
    Level.warning: CustomAnsiColor.fg(208),
    Level.error: CustomAnsiColor.fg(196),
    Level.fatal: CustomAnsiColor.fg(199),
  };

  static final levelEmojis = {
    Level.trace: '',
    Level.debug: '🐛 ',
    Level.info: '💡 ',
    Level.warning: '⚠️ ',
    Level.error: '⛔ ',
    Level.fatal: '👾 ',
  };

  static final stackTraceRegex = RegExp(r'#[0-9]+[\s]+(.+) \(([^\s]+)\)');

  static DateTime? _startTime;

  final int lineLength;

  final bool printTime;

  CustomPrinter({this.lineLength = 120, this.printTime = false}) {
    _startTime ??= DateTime.now();
  }

  @override
  List<String> log(LogEvent event) {
    final messageStr = stringifyMessage(event.message);

    String? stackTraceStr;

    final errorStr = event.error?.toString();

    String? timeStr;
    if (printTime) {
      timeStr = getTime();
    }

    formatAndPrint(event.level, messageStr, timeStr, errorStr, stackTraceStr);
    return [];
  }

  void println(String s) {
    eventBus.fire(LogMessage(s));
  }

  String? formatStackTrace(StackTrace stackTrace, int methodCount) {
    final lines = stackTrace.toString().split('\n');

    final formatted = <String>[];
    var count = 0;
    for (final line in lines) {
      final match = stackTraceRegex.matchAsPrefix(line);
      if (match != null) {
        if (match.group(2)!.startsWith('package:logger')) {
          continue;
        }
        final newLine = '#$count   ${match.group(1)} (${match.group(2)})';
        formatted.add(newLine.replaceAll('<anonymous closure>', '()'));
        if (++count == methodCount) {
          break;
        }
      } else {
        formatted.add(line);
      }
    }

    if (formatted.isEmpty) {
      return null;
    } else {
      return formatted.join('\n');
    }
  }

  String getTime() {
    String _threeDigits(int n) {
      if (n >= 100) {
        return '$n';
      }
      if (n >= 10) {
        return '0$n';
      }
      return '00$n';
    }

    String _twoDigits(int n) {
      if (n >= 10) {
        return '$n';
      }
      return '0$n';
    }

    final now = DateTime.now();
    final h = _twoDigits(now.hour);
    final min = _twoDigits(now.minute);
    final sec = _twoDigits(now.second);
    final ms = _threeDigits(now.millisecond);
    final timeSinceStart = now.difference(_startTime!).toString();
    return '$h:$min:$sec.$ms (+$timeSinceStart)';
  }

  String stringifyMessage(dynamic message) {
    if (message is Map || message is Iterable) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(message);
    } else {
      return message.toString();
    }
  }

  CustomAnsiColor? _getLevelColor(Level level) {
    return levelColors[level];
  }

  CustomAnsiColor _getErrorColor(Level level) {
    if (level == Level.fatal) {
      return levelColors[Level.fatal]!.toBg();
    } else {
      return levelColors[Level.error]!.toBg();
    }
  }

  String? _getEmoji(Level level) {
    return levelEmojis[level];
  }

  void formatAndPrint(Level level, String message, String? time, String? error,
      String? stacktrace) {
    final color = _getLevelColor(level);

    if (error != null) {
      final errorColor = _getErrorColor(level);
      for (final line in error.split('\n')) {
        println(errorColor(line));
      }
    }

    if (stacktrace != null) {
      for (final line in stacktrace.split('\n')) {
        println('$color$line');
      }
    }

    if (time != null) {
      println(color!('$time'));
    }

    final emoji = _getEmoji(level);
    for (final line in message.split('\n')) {
      println(color!('$emoji$line'));
    }
  }
}
