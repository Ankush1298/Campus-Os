import 'package:flutter/material.dart';
import 'app/campus_app.dart';
import 'features/auth/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Restore any persisted secure session
  await AuthService.instance.initialize();

  runApp(const CampusApp());
}
