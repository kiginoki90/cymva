import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';

class AdminNotificationPage extends StatefulWidget {
  @override
  _AdminNotificationPageState createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text;
    final content = _contentController.text;
    final timestamp = Timestamp.now();

    if (title.isEmpty || content.isEmpty) {
      showTopSnackBar(context, '題名と内容を入力してください', backgroundColor: Colors.red);
      return;
    }

    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('message')
            .add({
          'isRead': false,
          'message_read': null,
          'message_type': 4,
          'timestamp': timestamp,
          'title': title,
          'content': content,
        });
      }

      showTopSnackBar(context, 'お知らせを送信しました', backgroundColor: Colors.green);

      _titleController.clear();
      _contentController.clear();
    } catch (e) {
      showTopSnackBar(context, 'お知らせの送信に失敗しました: $e',
          backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('運営からのお知らせ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: '題名'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(labelText: '内容'),
              maxLines: 5,
            ),
            SizedBox(height: 16),
            GestureDetector(
              onLongPress: () async {
                await Future.delayed(Duration(seconds: 5));
                _sendNotification();
              },
              child: ElevatedButton(
                onPressed: () {},
                child: Text('投稿'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
