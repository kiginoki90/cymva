import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:flutter/material.dart';

class BlockedUsersPage extends StatefulWidget {
  final String userId;

  const BlockedUsersPage({required this.userId, Key? key}) : super(key: key);

  @override
  _BlockedUsersPageState createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  List<Account> _blockedAccounts = [];

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final blockCollectionRef =
          firestore.collection('users').doc(widget.userId).collection('block');

      // ブロックしたユーザーのIDを取得
      final blockedUsersSnapshot = await blockCollectionRef.get();
      final blockedUserIds = blockedUsersSnapshot.docs
          .map((doc) => doc['blocked_user_id'] as String)
          .toList();

      // ブロックされたユーザー情報を取得
      final blockedAccounts =
          await Future.wait(blockedUserIds.map((userId) async {
        final userSnapshot =
            await firestore.collection('users').doc(userId).get();
        return Account.fromDocument(userSnapshot);
      }));

      setState(() {
        _blockedAccounts = blockedAccounts;
      });
    } catch (e) {
      // エラーハンドリング
      print("Error fetching blocked users: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ブロックしたユーザー'),
      ),
      body: _blockedAccounts.isEmpty
          ? Center(child: Text('ブロックしたユーザーはいません'))
          : ListView.builder(
              itemCount: _blockedAccounts.length,
              itemBuilder: (context, index) {
                final account = _blockedAccounts[index];

                return ListTile(
                  leading: InkWell(
                    onTap: () {
                      navigateToPage(context, account.id, '1', true, false);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        account.imagePath ??
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
                  title: Text(
                    account.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '@${account.userId}\n${account.selfIntroduction ?? ''}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: OutlinedButton(
                    onPressed: () {
                      _unblockUser(account.id);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue), // 枠線の色
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // 枠線の角を丸く
                      ),
                    ),
                    child: Text(
                      '解除',
                      style: TextStyle(
                        color: Colors.blue, // ボタンの文字色
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ユーザーのブロックを解除するメソッド
  Future<void> _unblockUser(String blockedUserId) async {
    final firestore = FirebaseFirestore.instance;
    final currentUserId = widget.userId;

    // 自分の block サブコレクションの参照
    final blockCollectionRef =
        firestore.collection('users').doc(currentUserId).collection('block');

    // 一致するドキュメントを探す
    final querySnapshot = await blockCollectionRef
        .where('blocked_user_id', isEqualTo: blockedUserId)
        .get();

    // 一致するドキュメントが見つかった場合、削除する
    if (querySnapshot.docs.isNotEmpty) {
      for (var doc in querySnapshot.docs) {
        await blockCollectionRef.doc(doc.id).delete();
      }
    }

    // ブロックされたユーザーの blockUsers サブコレクションの参照
    final blockedUserBlockCollectionRef = firestore
        .collection('users')
        .doc(blockedUserId)
        .collection('blockUsers');

    // 一致するドキュメントを探す
    final blockedUserQuerySnapshot = await blockedUserBlockCollectionRef
        .where('blocked_user_id', isEqualTo: currentUserId)
        .get();

    // 一致するドキュメントが見つかった場合、削除する
    if (blockedUserQuerySnapshot.docs.isNotEmpty) {
      for (var doc in blockedUserQuerySnapshot.docs) {
        await blockedUserBlockCollectionRef.doc(doc.id).delete();
      }
    }

    // ブロック解除後にリストを更新
    _fetchBlockedUsers();
  }
}
