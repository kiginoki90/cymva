import 'package:flutter/material.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart';

class HiddenPostsPage extends StatefulWidget {
  @override
  State<HiddenPostsPage> createState() => _HiddenPostsPageState();
}

class _HiddenPostsPageState extends State<HiddenPostsPage> {
  List<Post> _hiddenPosts = [];
  bool _isLoading = true; // ローディング状態を管理

  Future<List<Post>> _fetchHiddenPosts() async {
    try {
      // サーバー側で "hide" が true のものを取得
      final querySnapshot = await PostFirestore.posts
          .where('hide', isEqualTo: true)
          .orderBy('created_time', descending: true)
          .get();

      // 取得したデータを Post モデルに変換
      return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
    } catch (e) {
      // エラーが発生した場合にログを出力
      print('Error fetching hidden posts: $e');
      return [];
    }
  }

  Future<void> _loadHiddenPosts() async {
    setState(() {
      _isLoading = true; // ローディングを開始
    });

    final posts = await _fetchHiddenPosts();
    setState(() {
      _hiddenPosts = posts; // 投稿をリストにセット
      _isLoading = false; // ローディングを終了
    });
  }

  @override
  void initState() {
    super.initState();
    _loadHiddenPosts(); // 初期化時に投稿をロード
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('非表示投稿'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // ローディング中の表示
          : _hiddenPosts.isEmpty
              ? const Center(child: Text('非表示の投稿はありません')) // 非表示投稿がない場合
              : ListView.builder(
                  itemCount: _hiddenPosts.length,
                  itemBuilder: (context, index) {
                    Post post = _hiddenPosts[index];

                    return FutureBuilder<Account?>(
                      future: UserFirestore.getUserByUserId(post.postAccountId),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (userSnapshot.hasError) {
                          return Center(
                              child: Text('エラーが発生しました: ${userSnapshot.error}'));
                        }

                        if (userSnapshot.hasData) {
                          Account postAccount = userSnapshot.data!;
                          return Column(
                            children: [
                              PostItemWidget(
                                post: post,
                                postAccount: postAccount,
                                favoriteUsersNotifier: ValueNotifier<int>(0),
                                isFavoriteNotifier: ValueNotifier<bool>(false),
                                onFavoriteToggle: () {
                                  // お気に入り機能を使用しない場合
                                },
                                // isRetweetedNotifier: ValueNotifier<bool>(false),
                                replyFlag: ValueNotifier<bool>(false),
                                userId: postAccount.id, // 管理者として閲覧する場合
                              ),
                              Divider(
                                color: Colors.black,
                                thickness: 3,
                              ),
                            ],
                          );
                        } else {
                          return SizedBox(); // データがない場合は空のウィジェット
                        }
                      },
                    );
                  },
                ),
    );
  }
}
