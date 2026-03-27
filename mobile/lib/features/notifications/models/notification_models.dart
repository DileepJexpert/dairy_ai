import 'package:flutter/material.dart';
import 'package:dairy_ai/app/theme.dart';

/// Notification types with associated icons and colors.
enum NotificationType {
  healthAlert,
  vaccinationDue,
  consultation,
  payment,
  general;

  factory NotificationType.fromString(String value) {
    switch (value) {
      case 'health_alert':
        return NotificationType.healthAlert;
      case 'vaccination_due':
        return NotificationType.vaccinationDue;
      case 'consultation':
        return NotificationType.consultation;
      case 'payment':
        return NotificationType.payment;
      default:
        return NotificationType.general;
    }
  }

  String toApiString() {
    switch (this) {
      case NotificationType.healthAlert:
        return 'health_alert';
      case NotificationType.vaccinationDue:
        return 'vaccination_due';
      case NotificationType.consultation:
        return 'consultation';
      case NotificationType.payment:
        return 'payment';
      case NotificationType.general:
        return 'general';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.healthAlert:
        return Icons.warning_amber_rounded;
      case NotificationType.vaccinationDue:
        return Icons.vaccines_outlined;
      case NotificationType.consultation:
        return Icons.video_call_outlined;
      case NotificationType.payment:
        return Icons.currency_rupee;
      case NotificationType.general:
        return Icons.notifications_outlined;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.healthAlert:
        return DairyTheme.errorRed;
      case NotificationType.vaccinationDue:
        return DairyTheme.accentOrange;
      case NotificationType.consultation:
        return DairyTheme.primaryGreen;
      case NotificationType.payment:
        return const Color(0xFF1565C0);
      case NotificationType.general:
        return DairyTheme.subtleGrey;
    }
  }

  String get label {
    switch (this) {
      case NotificationType.healthAlert:
        return 'Health Alert';
      case NotificationType.vaccinationDue:
        return 'Vaccination Due';
      case NotificationType.consultation:
        return 'Consultation';
      case NotificationType.payment:
        return 'Payment';
      case NotificationType.general:
        return 'General';
    }
  }
}

/// A single notification item.
class NotificationItem {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String? ?? 'general'),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data_json'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.toApiString(),
        'title': title,
        'body': body,
        'data_json': data,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  NotificationItem copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) =>
      NotificationItem(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        title: title ?? this.title,
        body: body ?? this.body,
        data: data ?? this.data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt ?? this.createdAt,
      );
}
