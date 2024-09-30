import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShowReportDialog extends StatefulWidget {
  final String postId;

  const ShowReportDialog({super.key, required this.postId});

  @override
  State<ShowReportDialog> createState() => _ShowReportDialogState();
}

class _ShowReportDialogState extends State<ShowReportDialog> {
  String selectedReportType = ''; // 選択された報告タイプを格納
  String reportContent = ''; // テキストフィールドの内容を格納
  final int maxCharacters = 200; // 最大文字数を設定

  @override
  void initState() {
    super.initState();
    // ビルド後にダイアログを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showReportDialog(context);
    });
  }

  // ダイアログを表示する関数
  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: AlertDialog(
            title: Text('報告する理由を選択してください', style: TextStyle(fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text('不適切な内容', style: TextStyle(fontSize: 12)),
                  value: 'inappropriate',
                  groupValue: selectedReportType,
                  onChanged: (String? value) {
                    setState(() {
                      selectedReportType = value!; // 状態を更新
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Text('スパム', style: TextStyle(fontSize: 12)),
                  value: 'spam',
                  groupValue: selectedReportType,
                  onChanged: (String? value) {
                    setState(() {
                      selectedReportType = value!; // 状態を更新
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Text('その他', style: TextStyle(fontSize: 12)),
                  value: 'other',
                  groupValue: selectedReportType,
                  onChanged: (String? value) {
                    setState(() {
                      selectedReportType = value!; // 状態を更新
                    });
                  },
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // ダイアログを閉じる
                  Navigator.of(context).pop(); // ShowReportDialogも閉じる
                },
                child: Text('キャンセル'),
              ),
              TextButton(
                onPressed: () async {
                  // Firestoreにデータを追加する
                  await FirebaseFirestore.instance.collection('reports').add({
                    'postId': widget.postId, // widget.postIdを参照
                    'report_type': selectedReportType,
                    'report_content': reportContent, // テキストフィールドの内容を保存
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  Navigator.of(context).pop(); // ダイアログを閉じる
                  Navigator.of(context).pop(); // ShowReportDialogも閉じる
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('報告が送信されました')),
                  );
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // このウィジェットのビルドは特に必要ないので、空のコンテナを返す
    return Container();
  }
}
