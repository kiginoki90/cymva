import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/start_up/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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
              style: TextStyle(
                fontSize: 13,
                color: Colors.red,
              ),
            ),
            const Text(
              'それでもアカウントを削除するにはパスワードを入力してください。',
              style: TextStyle(
                fontSize: 13,
                color: Colors.red, // テキストの色を赤に設定
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'パスワード',
                errorText: _errorMessage,
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(24), // 最大50文字に制限
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _deleteAccount,
                child: const Text('アカウント削除'),
              ),
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
          String postId = postDoc.id;
          String? reply = postDoc['reply'];
          await _deletePost(postId, userId, reply); // 投稿の削除
        }

        // 3. 各サブコレクションからuserIdと一致するドキュメントを削除
        await _deleteUserFromSubcollections(userId);
      }
    } catch (e) {
      print("Error deleting users and posts with same parentsId: $e");
    }
  }

  Future<void> _deletePost(
      String postId, String postAccountId, String? reply) async {
    try {
      final postDocRef =
          FirebaseFirestore.instance.collection('posts').doc(postId);

      // サブコレクション内のすべてのドキュメントを削除する関数
      Future<void> deleteSubcollection(String subcollectionName) async {
        final subcollectionRef = postDocRef.collection(subcollectionName);
        final snapshot = await subcollectionRef.get();

        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      // 返信が存在する場合、返信先の`reply_post`を削除
      if (reply != null && reply.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(reply)
            .collection('reply_post')
            .doc(postId)
            .delete();
      }

      // サブコレクションを削除 (サブコレクション名が固定されている場合)
      await deleteSubcollection('favorite_users');
      await deleteSubcollection('repost');
      await deleteSubcollection('reply_post');
      // メインの投稿ドキュメントを削除
      await postDocRef.delete();

      print('投稿を削除しました');
    } catch (e) {
      print('投稿の削除に失敗しました: $e');
    }
  }

  // サブコレクションからuserIdを削除するメソッド
  Future<void> _deleteUserFromSubcollections(String userId) async {
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    await deleteSubcollection(userDocRef, 'message');

    // blockサブコレクションから削除
    await deleteSubcollection(userDocRef, 'block');

    // followサブコレクションから削除
    await deleteSubcollection(userDocRef, 'follow');

    // blockUsersサブコレクションから削除
    await deleteSubcollection(userDocRef, 'blockUsers');

    await deleteSubcollection(userDocRef, 'my_posts');
  }

  // サブコレクションからドキュメントを削除する汎用メソッド
  Future<void> deleteSubcollection(
      DocumentReference docRef, String subcollectionName) async {
    final subcollectionRef = docRef.collection(subcollectionName);
    final snapshot = await subcollectionRef.get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
