import 'package:cymva/view/time_line/timeline_body.dart';
import 'package:cymva/view/start_up/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

//material.dartなどのライブラリをインポートしている

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ユーザーがログインしているかどうかをチェック
  User? user = FirebaseAuth.instance.currentUser;

  Widget initialScreen;
  if (user != null && user.emailVerified) {
    initialScreen = TimeLineBody(userId: user.uid); // ログイン済みかつメール認証済みならタイムラインへ
  } else {
    initialScreen = const LoginPage(); // それ以外ならログインページへ
  }

  runApp(MyApp(initialScreen: initialScreen));
}

//StatelessWidgetを継承しているMyAppクラス
class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({required this.initialScreen, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 140, 199, 221)),
        useMaterial3: true,
      ),
      home: initialScreen, // 初期画面を設定
    );
  }
}
