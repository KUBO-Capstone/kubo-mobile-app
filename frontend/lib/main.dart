import 'package:flutter/material.dart';

import 'app.dart';
import 'features/login/services/auth_service.dart';

// Application entry point. The session saved by the last launch is read
// before the first frame, so someone who was signed in opens straight into
// the app instead of seeing the login screen flash by.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.restoreSession();
  runApp(const KuboApp());
}
