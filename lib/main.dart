import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/ac_control/firebase_ac_control_repository.dart';
import 'features/auth/firebase_auth_repository.dart';
import 'features/dashboard/firebase_monitoring_repository.dart';
import 'features/history/firebase_history_repository.dart';
import 'features/notifications/notification_service.dart';
import 'features/thresholds/firebase_threshold_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    firebaseError = error.toString();
  }

  final tabController = ValueNotifier<int>(0);
  final notificationService = firebaseError == null
      ? NotificationService(tabController: tabController)
      : null;

  runApp(
    AppMonitoringApp(
      firebaseError: firebaseError,
      tabController: tabController,
      authRepository: firebaseError == null
          ? FirebaseAuthRepository(
              onBeforeSignOut: notificationService!.removeCurrentToken,
            )
          : null,
      monitoringRepository: firebaseError == null
          ? FirebaseMonitoringRepository()
          : null,
      historyRepository: firebaseError == null
          ? FirebaseHistoryRepository()
          : null,
      thresholdRepository: firebaseError == null
          ? FirebaseThresholdRepository()
          : null,
      acControlRepository: firebaseError == null
          ? FirebaseAcControlRepository()
          : null,
    ),
  );

  if (notificationService != null) {
    unawaited(notificationService.initialize());
  }
}
