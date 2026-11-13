import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _override = String.fromEnvironment('CARRENT_API_BASE_URL');
  static const timeout = Duration(seconds: 10);

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000/api';
    return 'http://localhost:5000/api';
  }
}
