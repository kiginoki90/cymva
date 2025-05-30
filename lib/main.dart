import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'maintenance_page.dart';
import 'view/start_up/login_page.dart';
import 'package:flutter/services.dart';

// バックグラウンドで通知を受信した際のハンドラー
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('バックグラウンドで通知を受信: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // エラーハンドリングを設定
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ログを送信する場合はここで処理
  };

  try {
    // Firebaseの初期化
    await Firebase.initializeApp();
  } catch (e) {
    // Firebase初期化エラーの処理
    print('Firebase initialization failed: $e');
    return; // アプリを起動しない
  }

  // バックグラウンドメッセージハンドラーを設定
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // MobileAdsの初期化を非同期で実行
  MobileAds.instance.initialize();

  // アプリを起動
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  static const String currentVersion = '1.2.9'; // 現在のバージョンを直接記述

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 140, 199, 221)),
        useMaterial3: true,
        fontFamily: 'CustomFont',
      ),
      home: InitialScreen(currentVersion: currentVersion), // 初期画面に遷移するウィジェットを指定
      debugShowCheckedModeBanner: false,
    );
  }
}

class InitialScreen extends StatefulWidget {
  final String currentVersion;

  InitialScreen({required this.currentVersion});

  @override
  _InitialScreenState createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  late Future<Widget> _initialScreenFuture;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _determineInitialScreen();
  }

  // 初期画面を決定するための非同期処理
  Future<Widget> _determineInitialScreen() async {
    // メンテナンスモードのチェック
    final maintenanceDoc = await FirebaseFirestore.instance
        .collection('setting')
        .doc('lOq7swYoUFttv7LnZs2n')
        .get();

    final data = maintenanceDoc.data() as Map<String, dynamic>?;

    final isMaintenance = data?['Maintenance'] ?? false;
    final maintenanceContent = data?['MaintenanceContent'] ?? 'メンテナンス中です';

    if (isMaintenance) {
      return MaintenancePage(content: maintenanceContent);
    }

    // バージョンチェック
    final shouldUpdate = await _checkVersion(data);
    if (shouldUpdate) {
      return _showUpdateDialog();
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      // userIdをsecure storageから取得
      String? userId = await storage.read(key: 'account_id') ??
          FirebaseAuth.instance.currentUser?.uid;

      // FirestoreからユーザーIDが存在するかチェック
      if (userId != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          return NavigationBarPage(userId: userId, showChatIcon: true);
        }
      }
    }
    // ログインしていないかメール認証がされていない場合、またはユーザーIDが存在しない場合
    return const LoginPage();
  }

  Future<bool> _checkVersion(Map<String, dynamic>? data) async {
    // Firestoreから最新バージョンを取得
    final latestVersion = data?['version'] ?? '0.0.0';

    // 現在のアプリバージョンを取得
    final currentVersion = widget.currentVersion;

    return _isVersionOutdated(currentVersion, latestVersion);
  }

  bool _isVersionOutdated(String currentVersion, String latestVersion) {
    final currentVersionParts =
        currentVersion.split('.').map(int.parse).toList();
    final latestVersionParts = latestVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < latestVersionParts.length; i++) {
      if (i >= currentVersionParts.length ||
          currentVersionParts[i] < latestVersionParts[i]) {
        return true;
      } else if (currentVersionParts[i] > latestVersionParts[i]) {
        return false;
      }
    }
    return false;
  }

  Widget _showUpdateDialog() {
    return Scaffold(
      body: Center(
        child: AlertDialog(
          title: Text('アップデートが必要です'),
          content: Text('最新バージョンにアップデートしてください。'),
          actions: [
            TextButton(
              onPressed: () async {
                // アップデートページへの遷移
                final Uri appStoreUrl = Uri.parse(
                    'https://apps.apple.com/jp/app/cymva/id6733224284');
                final Uri playStoreUrl = Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.kobayashi.cymva');

                if (Platform.isIOS) {
                  if (await canLaunchUrl(appStoreUrl)) {
                    await launchUrl(appStoreUrl);
                  } else {
                    throw 'Could not launch $appStoreUrl';
                  }
                } else if (Platform.isAndroid) {
                  if (await canLaunchUrl(playStoreUrl)) {
                    await launchUrl(playStoreUrl);
                  } else {
                    throw 'Could not launch $playStoreUrl';
                  }
                }
              },
              child: Text('アップデート'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 非同期処理が完了するまでローディング画面を表示
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          // エラーが発生した場合のエラーメッセージ
          return Scaffold(
            body: Center(
              child: Text('エラーが発生しました: ${snapshot.error}'),
            ),
          );
        } else {
          // 初期画面へ遷移
          return snapshot.data!;
        }
      },
    );
  }
}

class NotificationService {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  NotificationService() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel_id',
              'Default Channel',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }
}

Future<int> _getVideoRotation(String videoUrl) async {
  const MethodChannel channel = MethodChannel('video_rotation'); // ネイティブコードと一致
  try {
    final int rotation =
        await channel.invokeMethod('getVideoRotation', videoUrl);
    return rotation;
  } catch (e) {
    print('Error retrieving video rotation: $e');
    return 0; // デフォルトで回転なし
  }
}
