import 'package:cymva/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteListPage extends StatefulWidget {
  final String postId;

  FavoriteListPage({required this.postId});

  @override
  _FavoriteListPageState createState() => _FavoriteListPageState();
}

class _FavoriteListPageState extends State<FavoriteListPage> {
  List<Map<String, dynamic>> favoriteUsers = [];
  DocumentSnapshot? lastDocument; // 最後に取得したドキュメント
  bool isLoading = false; // データ取得中かどうか
  bool hasMore = true; // さらにデータがあるかどうか
  final int limit = 15; // 1回の取得件数
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchFavoriteUsers(); // 初回データ取得
    _scrollController.addListener(_onScroll); // スクロールリスナーを追加
  }

  @override
  void dispose() {
    _scrollController.dispose(); // スクロールコントローラーを破棄
    super.dispose();
  }

  Future<void> _fetchFavoriteUsers() async {
    if (isLoading || !hasMore) return; // データ取得中またはデータがない場合は処理をスキップ

    setState(() {
      isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('favorite_users')
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument!); // 前回の最後のドキュメントから取得
    }

    final favoriteUsersSnapshot = await query.get();

    if (favoriteUsersSnapshot.docs.isNotEmpty) {
      lastDocument = favoriteUsersSnapshot.docs.last; // 最後のドキュメントを更新

      for (var doc in favoriteUsersSnapshot.docs) {
        final userId = doc.id;
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.data()!;
          userData['id'] = userId; // userIdをuserDataに追加
          favoriteUsers.add(userData);
        }
      }
    }

    setState(() {
      isLoading = false;
      hasMore = favoriteUsersSnapshot.docs.length == limit; // データがlimit未満なら終了
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoading &&
        hasMore) {
      _fetchFavoriteUsers(); // スクロール位置が下部に到達したら次のデータを取得
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('お気に入りユーザー'),
      ),
      body: favoriteUsers.isEmpty && isLoading
          ? Center(child: CircularProgressIndicator()) // 初回ローディング
          : ListView.builder(
              controller: _scrollController, // スクロールコントローラーを設定
              itemCount:
                  favoriteUsers.length + (hasMore ? 1 : 0), // ローディングインジケータ用に+1
              itemBuilder: (context, index) {
                if (index == favoriteUsers.length) {
                  return Center(child: Text('読み込み中...'));
                }

                final userData = favoriteUsers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          navigateToPage(
                              context, userData['id'], '1', true, false);
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
                            navigateToPage(
                                context, userData['id'], '1', false, false);
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
                );
              },
            ),
    );
  }
}
