import 'package:cymva/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShowAccountReportDialog extends StatefulWidget {
  final String accountId;

  const ShowAccountReportDialog({super.key, required this.accountId});

  @override
  State<ShowAccountReportDialog> createState() =>
      _ShowAccountReportDialogState();
}

enum AccountReportReason {
  human('人間'),
  inappropriate('不適切な内容'),
  spam('スパム'),
  fake('なりすまし'),
  other('その他');

  final String displayName;
  const AccountReportReason(this.displayName);
}

class _ShowAccountReportDialogState extends State<ShowAccountReportDialog> {
  AccountReportReason? _selectedReason = AccountReportReason.inappropriate;
  String reportContent = '';
  final int maxCharacters = 200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アカウントを報告'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ラジオボタンで理由を選択
            ...AccountReportReason.values.map((reason) {
              return ListTile(
                title: Text(reason.displayName),
                leading: Radio<AccountReportReason>(
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (AccountReportReason? value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
              );
            }).toList(),
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
                try {
                  final reportRef =
                      FirebaseFirestore.instance.collection('account_reports');
                  final querySnapshot = await reportRef
                      .where('accountId', isEqualTo: widget.accountId)
                      .limit(1)
                      .get();

                  if (querySnapshot.docs.isNotEmpty) {
                    // 既に同じ accountId のレポートが存在する場合、その count をインクリメント
                    final doc = querySnapshot.docs.first;
                    await doc.reference.update({
                      'count': FieldValue.increment(1),
                    });
                  } else {
                    // 存在しない場合は新しいレポートを作成
                    await reportRef.add({
                      'accountId': widget.accountId, // widget.accountIdを参照
                      'report_reason': _selectedReason?.displayName ?? '不明',
                      'report_content': reportContent, // テキストフィールドの内容を保存
                      'timestamp': FieldValue.serverTimestamp(),
                      'count': 1, // 初期カウントは1
                    });
                  }

                  // ページを閉じ、スナックバーで通知
                  Navigator.of(context).pop();

                  showTopSnackBar(context, 'アカウントを報告しました',
                      backgroundColor: Colors.green);
                } catch (e) {
                  // エラーハンドリング
                  showTopSnackBar(context, 'エラーが発生しました',
                      backgroundColor: Colors.red);
                }
              },
              child: Text('報告する'),
            ),
          ],
        ),
      ),
    );
  }
}
