import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Future<void> requestPermission() async {
    final settings =
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      'Notification permission status: '
          '${settings.authorizationStatus}',
    );
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();

      debugPrint('FCM TOKEN:');
      debugPrint(token);

      return token;
    } catch (e) {
      debugPrint(
        'FCM TOKEN ERROR: $e',
      );

      return null;
    }
  }

  Future<void> saveTokenToFirestore() async {
    try {
      final user =
          _auth.currentUser;

      if (user == null) {
        debugPrint(
          'No logged-in user. FCM token was not saved.',
        );
        return;
      }

      final token =
      await _messaging.getToken();

      if (token == null) {
        debugPrint(
          'FCM token is null.',
        );
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt':
        FieldValue.serverTimestamp(),
      });

      debugPrint(
        'FCM token saved to Firestore.',
      );
    } catch (e) {
      debugPrint(
        'Failed to save FCM token: $e',
      );
    }
  }

  void listenToTokenRefresh() {
    _messaging.onTokenRefresh.listen(
          (newToken) async {
        debugPrint(
          'NEW FCM TOKEN:',
        );

        debugPrint(newToken);

        final user =
            _auth.currentUser;

        if (user == null) {
          return;
        }

        try {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({
            'fcmToken': newToken,
            'fcmTokenUpdatedAt':
            FieldValue.serverTimestamp(),
          });

          debugPrint(
            'New FCM token saved to Firestore.',
          );
        } catch (e) {
          debugPrint(
            'Failed to save new FCM token: $e',
          );
        }
      },
    );
  }

  Future<void> initialize() async {
    debugPrint(
      'NotificationService initializing...',
    );

    await requestPermission();

    await getToken();

    listenToTokenRefresh();
  }
}