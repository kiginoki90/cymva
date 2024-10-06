import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShowReportDialog extends StatefulWidget {
  final String postId;

  const ShowReportDialog({super.key, required this.postId});

  @override
  State<ShowReportDialog> createState() => _ShowReportDialogState();
}

enum ReportReason {
  inappropriate('不適切な内容'),
  spam('スパム'),
  fake('なりすまし'),
  other('その他');

  final String displayName;
  const ReportReason(this.displayName);
}

class _ShowReportDialogState extends State<ShowReportDialog> {
  ReportReason? _selectedReason = ReportReason.inappropriate; // 初期値
  String reportContent = ''; // テキストフィールドの内容を格納
  final int maxCharacters = 200; // 最大文字数を設定

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('報告'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ラジオボタンで理由を選択
            ListTile(
              title: Text(ReportReason.inappropriate.displayName),
              leading: Radio<ReportReason>(
                value: ReportReason.inappropriate,
                groupValue: _selectedReason,
                onChanged: (ReportReason? value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(ReportReason.spam.displayName),
              leading: Radio<ReportReason>(
                value: ReportReason.spam,
                groupValue: _selectedReason,
                onChanged: (ReportReason? value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(ReportReason.fake.displayName),
              leading: Radio<ReportReason>(
                value: ReportReason.fake,
                groupValue: _selectedReason,
                onChanged: (ReportReason? value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
              ),
            ),
            ListTile(
              title: Text(ReportReason.other.displayName),
              leading: Radio<ReportReason>(
                value: ReportReason.other,
                groupValue: _selectedReason,
                onChanged: (ReportReason? value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
              ),
            ),
            SizedBox(height: 10), // スペースを追加
            TextField(
              onChanged: (value) {
                setState(() {
                  reportContent = value; // テキストフィールドの内容を更新
                });
              },
              maxLength: maxCharacters, // 最大文字数を設定
              decoration: InputDecoration(
                hintText: '詳細を入力してください（200文字以内）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3, // 行数を指定
            ),
            SizedBox(height: 20), // スペースを追加
            ElevatedButton(
              onPressed: () async {
                // 選択された理由をFirestoreに保存
                await FirebaseFirestore.instance.collection('reports').add({
                  'postId': widget.postId, // widget.postIdを参照
                  'report_reason': _selectedReason?.displayName ?? '不明',
                  'report_content': reportContent, // テキストフィールドの内容を保存
                  'timestamp': FieldValue.serverTimestamp(),
                });

                Navigator.of(context).pop(); // ページを閉じる
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('報告しました')),
                );
              },
              child: Text('報告する'),
            ),
          ],
        ),
      ),
    );
  }
}
