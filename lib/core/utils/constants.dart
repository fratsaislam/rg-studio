import 'package:flutter/foundation.dart';

class AppConstants {
  // API
  static String get baseUrl => kIsWeb
      ? 'http://localhost:3001/api'
      : 'http://10.0.2.2:3001/api'; // Android emulator
  static const String baseUrlDevice =
      'http://192.168.1.x:3001/api'; // Real device - update IP

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';

  // Timeouts
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 15000;

  // Pagination
  static const int defaultPageSize = 20;

  // Production pipeline steps
  static const List<String> productionSteps = [
    'IMPORTING',
    'SORTING',
    'EDITING',
    'RETOUCHING',
    'VALIDATION',
    'EXPORTING',
    'DELIVERED',
    'ARCHIVED',
  ];

  // Order statuses
  static const List<String> orderStatuses = [
    'PENDING',
    'CONFIRMED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED',
  ];

  // Equipment statuses
  static const List<String> equipmentStatuses = [
    'AVAILABLE',
    'IN_USE',
    'MAINTENANCE',
    'RETIRED',
  ];
}
