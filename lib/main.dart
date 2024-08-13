import 'package:cymva/view/time_line/time_line_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

//material.dartなどのライブラリをインポートしている

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  //voidとは戻り値がない場合に使うデータ型。プログラムが開始される場所
  // await FirebaseAppCheck.instance.activate(
  //   webProvider: ReCaptchaV3Provider('your-site-key'),
  // );
  runApp(const MyApp());
  //MyAppクラスのインスタンスを作成。runAppはflutterアプリの開始時点で使用される関数
}

//StatelessWidgetを継承しているMyAppクラス
class MyApp extends StatelessWidget {
  const MyApp({super.key}); //super.key は親クラスのコンストラクタに key を渡す。
  @override //親クラスのメソッドを再定義している
  //ウィジットを構築するためのメソッド。全てのウィジットはこのメソッドを持ち、それを通じてUIを描画する
  Widget build(BuildContext context) {
    //MaterialAppウィジットを返す。
    return MaterialApp(
      //アプリケーションのタイトル
      title: 'Flutter Demo',
      //アプリケーションのテーマ。seedColorを元に色合いが生成される。
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      //homeプロパティはこの画面が起動された際に表示される最初の画面となる。
      home: const TimeLinePage(),
    );
  }
}
