import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class GroupListDialog extends StatefulWidget {
  final String userId;
  final String postId;

  const GroupListDialog(
      {super.key, required this.userId, required this.postId});

  @override
  _GroupListDialogState createState() => _GroupListDialogState();
}

class _GroupListDialogState extends State<GroupListDialog> {
  String? _flashMessage;
  Color _flashMessageColor = Colors.green;

  Future<void> _addPostToGroup(String groupName) async {
    try {
      final groupCollectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('group');

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

      final groupDocRef = groupCollectionRef.doc(groupName);
      final postsCollectionRef = groupDocRef.collection('posts');
      final postsSnapshot = await postsCollectionRef.get();

      int newCount = 1;
      if (postsSnapshot.docs.isNotEmpty) {
        final maxCount = postsSnapshot.docs
            .map((doc) => doc.data()['count'] as int)
            .reduce((a, b) => a > b ? a : b);
        newCount = maxCount + 1;
      }

      await postsCollectionRef.add({
        'postId': widget.postId,
        'timestamp': FieldValue.serverTimestamp(),
        'count': newCount,
      });

      // groupNameのtimestampフィールドを現在時刻で更新
      await groupDocRef.update({
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _flashMessage = 'グループに追加しました';
          _flashMessageColor = Colors.green;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _flashMessage = 'エラーが発生しました: $e';
          _flashMessageColor = Colors.red;
        });
      }
    }
  }

  void _showConfirmationDialog(String groupName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('確認'),
          content: Text('この投稿を「$groupName」のリストに入れますか？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('いいえ'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _addPostToGroup(groupName);
              },
              child: Text('はい'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('グループを選択'),
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
          Container(
            width: double.maxFinite,
            height: 400, // 縦幅を大きく設定
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('group')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final groups = snapshot.data!.docs;
                if (groups.isEmpty) {
                  return Center(child: Text('グループがありません'));
                }
                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      title: Text(group.id),
                      onTap: () {
                        _showConfirmationDialog(group.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('閉じる'),
        ),
      ],
    );
  }
}
