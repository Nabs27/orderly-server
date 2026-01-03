import 'package:flutter/material.dart';

class TimeHelpers {
  static String getElapsedTime(DateTime? openedAt) {
    if (openedAt == null) return '';
    final elapsed = DateTime.now().difference(openedAt);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    final seconds = elapsed.inSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  static String getTimeSinceLastOrder(dynamic lastOrderAt) {
    DateTime? dateTime;
    if (lastOrderAt is String) {
      dateTime = DateTime.tryParse(lastOrderAt);
    } else if (lastOrderAt is DateTime) {
      dateTime = lastOrderAt;
    }
    if (dateTime == null) return '';
    final elapsed = DateTime.now().difference(dateTime);
    final minutes = elapsed.inMinutes;
    if (minutes < 60) return '${minutes}min';
    final hours = elapsed.inHours;
    final mins = minutes % 60;
    return '${hours}h${mins.toString().padLeft(2, '0')}';
  }

  static Color getInactivityColor(dynamic lastOrderAt) {
    DateTime? dateTime;
    if (lastOrderAt is String) {
      dateTime = DateTime.tryParse(lastOrderAt);
    } else if (lastOrderAt is DateTime) {
      dateTime = lastOrderAt;
    }
    if (dateTime == null) return Colors.grey;
    final elapsed = DateTime.now().difference(dateTime);
    final minutes = elapsed.inMinutes;
    if (minutes < 15) return Colors.green.shade600;
    if (minutes < 30) return Colors.orange.shade600;
    return Colors.red.shade700;
  }
}
