import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'fcm_token_repository.dart';

class NotificationService {
  NotificationService({
    required this.tabController,
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FlutterLocalNotificationsPlugin? localNotifications,
    FcmTokenRepository? tokens,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _tokens = tokens ?? FcmTokenRepository();

  final ValueNotifier<int> tabController;
  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FcmTokenRepository _tokens;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool _permissionRequested = false;
  String? _uid;
  String? _token;
  String? _tokenId;

  Future<void> initialize() async {
    const channel = AndroidNotificationChannel(
      'monitoring_alerts',
      'Peringatan Monitoring',
      description: 'Notifikasi kondisi gudang dan status perangkat.',
      importance: Importance.high,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (_) {
        tabController.value = 0;
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showLocalNotification(message));
    });
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      _,
    ) {
      tabController.value = 0;
    });
    // ignore: deprecated_member_use
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_handleTokenRefresh(token));
    });
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _uid = null;
        _token = null;
        _tokenId = null;
        return;
      }
      unawaited(_syncToken(user));
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      tabController.value = 0;
    }
  }

  Future<void> removeCurrentToken() async {
    final uid = _uid;
    final tokenId = _tokenId;
    _uid = null;
    _token = null;
    _tokenId = null;
    if (uid == null || tokenId == null) {
      return;
    }

    try {
      await _tokens.removeToken(uid: uid, tokenId: tokenId);
    } catch (error) {
      debugPrint('Gagal menghapus token FCM: $error');
    }
  }

  Future<void> _syncToken(User user) async {
    try {
      if (!_permissionRequested) {
        _permissionRequested = true;
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token == null) {
        return;
      }
      if (_uid == user.uid && _token == token && _tokenId != null) {
        return;
      }

      if (_uid != null && _tokenId != null && _token != token) {
        await _tokens.removeToken(uid: _uid!, tokenId: _tokenId!);
      }

      final tokenId = await _tokens.saveToken(uid: user.uid, token: token);
      _uid = user.uid;
      _token = token;
      _tokenId = tokenId;
    } catch (error) {
      debugPrint('Gagal menyimpan token FCM: $error');
    }
  }

  Future<void> _handleTokenRefresh(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      if (_tokenId != null) {
        await _tokens.removeToken(uid: user.uid, tokenId: _tokenId!);
      }
      final tokenId = await _tokens.saveToken(uid: user.uid, token: token);
      _uid = user.uid;
      _token = token;
      _tokenId = tokenId;
    } catch (error) {
      debugPrint('Gagal memperbarui token FCM: $error');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title'] as String? ??
        'Monitoring Gudang';
    final body = notification?.body ?? message.data['body'] as String? ?? '';
    if (body.isEmpty) {
      return;
    }

    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'monitoring_alerts',
            'Peringatan Monitoring',
            channelDescription:
                'Notifikasi kondisi gudang dan status perangkat.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: 'dashboard',
      );
    } catch (error) {
      debugPrint('Gagal menampilkan notifikasi lokal: $error');
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}
