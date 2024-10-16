// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:twitter_login_v2/twitter_login_v2.dart';

// class XAuthPage extends StatefulWidget {
//   final String userId;
//   const XAuthPage({Key? key, required this.userId}) : super(key: key);

//   @override
//   _XAuthPageState createState() => _XAuthPageState();
// }

// class _XAuthPageState extends State<XAuthPage> {
//   bool isXLinked = false;

//   @override
//   void initState() {
//     super.initState();
//     _checkXLinkStatus(); // 初期化時に連携状況をチェック
//   }

//   Future<void> _checkXLinkStatus() async {
//     DocumentSnapshot userDoc = await FirebaseFirestore.instance
//         .collection('users')
//         .doc(widget.userId)
//         .get();

//     setState(() {
//       isXLinked = userDoc['isXLinked'] ?? false;
//     });
//   }

//   Future<void> _linkXAccount() async {
//     final twitterLogin = TwitterLoginV2(
//       clientId: 'あなたのクライアントID', // 必要な引数を追加
//       apiKey: 'あなたのAPIキー',
//       apiSecretKey: 'あなたのAPIシークレットキー',
//       redirectURI: 'あなたのコールバックURL', // 必要な引数を追加
//     );

//     final authResult = await twitterLogin.login();

//     if (authResult.status == TwitterLoginStatus.loggedIn) {
//       final user = authResult.user;
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(widget.userId)
//           .update({
//         'isXLinked': true,
//         'xUsername': user?.username,
//         'xUserId': user?.idStr,
//       });

//       setState(() {
//         isXLinked = true;
//       });
//     } else {
//       print('ログインに失敗しました: ${authResult.errorMessage}');
//     }
//   }

//   Future<void> _unlinkXAccount() async {
//     await FirebaseFirestore.instance
//         .collection('users')
//         .doc(widget.userId)
//         .update({
//       'isXLinked': false,
//       'xUsername': null,
//       'xUserId': null,
//     });

//     setState(() {
//       isXLinked = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Xアカウント設定'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             if (isXLinked)
//               ElevatedButton(
//                 onPressed: _unlinkXAccount,
//                 child: Text('Xアカウントの連携を解除'),
//               )
//             else
//               ElevatedButton(
//                 onPressed: _linkXAccount,
//                 child: Text('Xアカウントと連携'),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
