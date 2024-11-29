import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/start_up/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteAccountPage extends StatefulWidget {
  final String userId; // 削除対象のユーザーID
  final String parentsId; // parents_id

  const DeleteAccountPage({
    Key? key,
    required this.userId,
    required this.parentsId,
  }) : super(key: key);

  @override
  _DeleteAccountPageState createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  Future<void> _deleteAccount() async {
    try {
      // パスワードを確認
      String password = _passwordController.text;
      User? user = FirebaseAuth.instance.currentUser;

      // 再認証用の認証クレデンシャルを作成
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );

      // ユーザーを再認証
      await user.reauthenticateWithCredential(credential);

      // パスワードが正しければ削除処理を実行
      await UserFirestore.deleteUser(widget.userId);

      // 同じ parents_id に紐づく他のユーザーとその投稿も削除
      await _deleteUsersAndPostsWithSameParentsId(widget.parentsId);

      // 認証情報の削除
      await Authentication.deleteAuth();

      // ログインページに遷移
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'パスワードが間違っています。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アカウント削除'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'メールアドレスに紐づいた全てのアカウントが消えます。',
              style: TextStyle(fontSize: 13),
            ),
            const Text(
              'それでもアカウントを削除するにはパスワードを入力してください。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'パスワード',
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _deleteAccount,
              child: const Text('アカウント削除'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUsersAndPostsWithSameParentsId(String parentsId) async {
    try {
      // 同じ parentsId を持つユーザーを取得
      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('parents_id', isEqualTo: parentsId)
          .get();

      // 各ユーザーを削除し、それに対応する投稿も削除
      for (var userDoc in usersSnapshot.docs) {
        String userId = userDoc.id;

        // 1. ユーザーの削除
        await UserFirestore.deleteUser(userId);

        // 2. postsコレクションから該当する投稿を削除
        QuerySnapshot postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('post_account_id', isEqualTo: userId)
            .get();

        for (var postDoc in postsSnapshot.docs) {
          await postDoc.reference.delete(); // 投稿の削除
        }

        // 3. 各サブコレクションからuserIdと一致するドキュメントを削除
        await _deleteUserFromSubcollections(userId);
      }
    } catch (e) {
      print("Error deleting users and posts with same parentsId: $e");
    }
  }

// サブコレクションからuserIdを削除するメソッド
  Future<void> _deleteUserFromSubcollections(String userId) async {
    // blockサブコレクションから削除
    await _deleteBlocked(userId);

    // followサブコレクションから削除
    await _deleteFollow(userId);

    // followersサブコレクションから削除
    await _deleteDocumentsInSubcollection(userId, 'followers');

    // blockUsersサブコレクションから削除
    await _deleteBlockedUsers(userId);
  }

// blockUsersサブコレクションからblocked_user_idがuserIdと一致するドキュメントを削除するメソッド
  Future<void> _deleteBlockedUsers(String userId) async {
    QuerySnapshot subcollectionSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .where('blocked_user_id',
            isEqualTo: userId) // blocked_user_idがuserIdと一致するものを取得
        .get();

    for (var doc in subcollectionSnapshot.docs) {
      await doc.reference.delete(); // サブコレクションのドキュメントを削除
    }
  }

  Future<void> _deleteBlocked(String userId) async {
    QuerySnapshot subcollectionSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('block')
        .where('blocked_user_id',
            isEqualTo: userId) // blocked_user_idがuserIdと一致するものを取得
        .get();

    for (var doc in subcollectionSnapshot.docs) {
      await doc.reference.delete(); // サブコレクションのドキュメントを削除
    }
  }

  Future<void> _deleteFollow(String userId) async {
    QuerySnapshot subcollectionSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('follow')
        .where('followed_user_id', isEqualTo: userId)
        .get();

    for (var doc in subcollectionSnapshot.docs) {
      await doc.reference.delete(); // サブコレクションのドキュメントを削除
    }
  }

  //   Future<void> _deleteFollower(String userId) async {
  //   QuerySnapshot subcollectionSnapshot = await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(userId)
  //       .collection('follow')
  //       .where('followed_user_id', isEqualTo: userId)
  //       .get();

  //   for (var doc in subcollectionSnapshot.docs) {
  //     await doc.reference.delete(); // サブコレクションのドキュメントを削除
  //   }
  // }

// サブコレクションからドキュメントを削除するヘルパーメソッド
  Future<void> _deleteDocumentsInSubcollection(
      String userId, String subcollection) async {
    QuerySnapshot subcollectionSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(subcollection)
        .get();

    for (var doc in subcollectionSnapshot.docs) {
      await doc.reference.delete(); // サブコレクションのドキュメントを削除
    }
  }
}
