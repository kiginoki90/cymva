import 'package:cymva/view/time_line/timeline_body.dart';
import 'package:cymva/view/start_up/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 140, 199, 221)),
        useMaterial3: true,
      ),
      home: InitialScreen(), // 初期画面に遷移するウィジェットを指定
    );
  }
}

class InitialScreen extends StatefulWidget {
  @override
  _InitialScreenState createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  late Future<Widget> _initialScreenFuture;

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _determineInitialScreen();
  }

  // 初期画面を決定するための非同期処理
  Future<Widget> _determineInitialScreen() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      // FirestoreからユーザーIDが存在するかチェック
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        // ユーザーIDが存在する場合タイムラインへ
        return TimeLineBody(userId: user.uid);
      } else {
        // ユーザーIDが存在しない場合ログインページへ
        return const LoginPage();
      }
    } else {
      // ログインしていないかメール認証がされていない場合ログインページへ
      return const LoginPage();
    }
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
