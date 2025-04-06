import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';

class ReportedUsersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('通報されたユーザー'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('account_reports')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          List<String> reportedAccountIds = snapshot.data!.docs
              .map((doc) => doc['accountId'] as String)
              .toList();

          if (reportedAccountIds.isEmpty) {
            return Center(child: Text('通報されたユーザーはいません'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: reportedAccountIds)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              return ListView.builder(
                itemCount: userSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var userDoc = userSnapshot.data!.docs[index];
                  var userData = userDoc.data() as Map<String, dynamic>;
                  var followId = userDoc.id;

                  // account_reportsコレクションの該当のIDのデータを取得
                  var reportDoc = snapshot.data!.docs.firstWhereOrNull(
                    (doc) => doc['accountId'] == followId,
                  );

                  var reportData = reportDoc != null
                      ? reportDoc.data() as Map<String, dynamic>?
                      : null;

                  if (reportData == null) {
                    print('該当する通報データが見つかりませんでした');
                  }
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NavigationBarPage(
                                        userId: followId, firstIndex: 1),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  userData['image_path'] ??
                                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.network(
                                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NavigationBarPage(
                                          userId: followId, firstIndex: 1),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            userData['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '@${userData['user_id']}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      userData['self_introduction'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (reportData != null) ...[
                          const SizedBox(height: 10),
                          Text('通報理由: ${reportData['report_reason'] ?? '不明'}'),
                          Text('通報内容: ${reportData['report_content'] ?? '不明'}'),
                          Text('通報回数: ${reportData['count'] ?? 0}'),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _showConfirmationDialog(
                                context,
                                '管理者権限を4に設定しますか？',
                                () async {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(followId)
                                      .update({'admin': 4});
                                },
                              ),
                              child: Text('権限4'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _showConfirmationDialog(
                                context,
                                '管理者権限を5に設定しますか？',
                                () async {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(followId)
                                      .update({'admin': 5});
                                },
                              ),
                              child: Text('権限5'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _showConfirmationDialog(
                                context,
                                '関連する通報を削除しますか？',
                                () async {
                                  final reports = await FirebaseFirestore
                                      .instance
                                      .collection('account_reports')
                                      .where('accountId', isEqualTo: followId)
                                      .get();

                                  for (var report in reports.docs) {
                                    await report.reference.delete();
                                  }
                                },
                              ),
                              child: Text('通報削除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showConfirmationDialog(
    BuildContext context,
    String message,
    Future<void> Function() onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('確認'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // ダイアログを閉じる
                await onConfirm(); // 確認後の処理を実行
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
