import 'package:flutter/material.dart';

import 'app/campus_app.dart';
import 'features/geocam/services/geocam_auto_sync.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Upload any GeoCam captures that are still pending (e.g. captured offline, or the app was closed mid-upload).
  GeoCamAutoSync.instance.start();

  // The saved session is restored behind the branded splash (see CampusBootstrap).
  runApp(const CampusBootstrap());
}
