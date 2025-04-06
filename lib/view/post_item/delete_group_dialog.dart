import 'package:cymva/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteGroupDialog extends StatelessWidget {
  final String postId;
  final String userId;
  final String groupId;

  const DeleteGroupDialog({
    Key? key,
    required this.postId,
    required this.userId,
    required this.groupId,
  }) : super(key: key);

  Future<void> _deletePostFromGroup(BuildContext context) async {
    try {
      final groupCollectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('group')
          .doc(groupId)
          .collection('posts');

      final querySnapshot =
          await groupCollectionRef.where('postId', isEqualTo: postId).get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      Navigator.of(context).pop(); // ダイアログを閉じる
      showTopSnackBar(context, 'グループから削除しました', backgroundColor: Colors.green);
    } catch (e) {
      Navigator.of(context).pop(); // ダイアログを閉じる
      showTopSnackBar(context, 'エラーが発生しました', backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('グループから削除'),
      content: Text('グループから削除しますか？'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // ダイアログを閉じる
          },
          child: Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => _deletePostFromGroup(context),
          child: Text('はい'),
        ),
      ],
    );
  }
}
