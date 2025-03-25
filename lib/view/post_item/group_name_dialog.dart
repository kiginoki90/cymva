import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart'; // inputFormattersを使用するために追加

class GroupNameDialog extends StatefulWidget {
  final String postId;
  final String userId;

  const GroupNameDialog(
      {super.key, required this.postId, required this.userId});

  @override
  _GroupNameDialogState createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<GroupNameDialog> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _flashMessage;
  Color _flashMessageColor = Colors.green;

  Future<void> _createGroup() async {
    final groupName = _controller.text;
    if (groupName.isNotEmpty) {
      final groupCollectionRef =
          _firestore.collection('users').doc(widget.userId).collection('group');

      final groupSnapshot = await groupCollectionRef.get();

      // すべてのグループのpostsコレクションをチェック
      for (var groupDoc in groupSnapshot.docs) {
        final postsCollectionRef = groupDoc.reference.collection('posts');
        final postsSnapshot = await postsCollectionRef.get();

        // postIdが既に存在するか確認
        final existingPost = postsSnapshot.docs.firstWhereOrNull(
          (doc) => doc.data()['postId'] == widget.postId,
        );

        if (existingPost != null) {
          setState(() {
            _flashMessage = 'グループに参加しています';
            _flashMessageColor = Colors.red;
          });
          return;
        }
      }

      try {
        final groupDocRef = groupCollectionRef.doc(groupName);
        final docSnapshot = await groupDocRef.get();
        if (docSnapshot.exists) {
          setState(() {
            _flashMessage = '同じグループ名が既に存在します。';
            _flashMessageColor = Colors.red;
          });
        } else {
          await groupDocRef.set({
            'name': groupName,
            'timestamp': FieldValue.serverTimestamp(),
          });

          final subcollectionRef = groupDocRef.collection('posts');
          await subcollectionRef.add({
            'postId': widget.postId,
            'count': 1,
            'timestamp': FieldValue.serverTimestamp(),
          });

          Navigator.of(context).pop(groupName); // グループ名を返してダイアログを閉じる
          setState(() {
            _flashMessage = 'グループを作成しました。';
            _flashMessageColor = Colors.green;
          });
        }
      } catch (e) {
        setState(() {
          _flashMessage = 'エラーが発生しました。もう一度お試しください。';
          _flashMessageColor = Colors.red;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('グループ名を入力'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_flashMessage != null)
            Container(
              padding: EdgeInsets.all(8.0),
              color: _flashMessageColor,
              child: Text(
                _flashMessage!,
                style: TextStyle(color: Colors.white),
              ),
            ),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'グループ名を12字以内で入力して下さい',
            ),
            inputFormatters: [
              LengthLimitingTextInputFormatter(12), // 文字数制限を追加
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // ダイアログを閉じる
          },
          child: Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _createGroup,
          child: Text('作成'),
        ),
      ],
    );
  }
}
