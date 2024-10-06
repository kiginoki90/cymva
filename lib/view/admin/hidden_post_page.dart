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
  String _searchQuery = '';

  Future<List<Post>> _fetchHiddenPosts() async {
    // hide フィールドが true の投稿を取得し、新しい順に並べ替え
    final querySnapshot = await PostFirestore.posts
        .where('hide', isEqualTo: true)
        .orderBy('created_time', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
  }

  Future<void> _refreshPosts() async {
    setState(() {
      // 再描画をトリガーするためのsetState
    });
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  void initState() {
    super.initState();
    _loadHiddenPosts();
  }

  Future<void> _loadHiddenPosts() async {
    final posts = await _fetchHiddenPosts();
    setState(() {
      _hiddenPosts = posts;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 検索フィルタリング
    final filteredPosts = _hiddenPosts.where((post) {
      return post.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('非表示投稿'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '検索...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: FutureBuilder<void>(
          future: _loadHiddenPosts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
            }

            if (filteredPosts.isEmpty) {
              return const Center(child: Text('非表示の投稿はありません'));
            }

            return ListView.builder(
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                Post post = filteredPosts[index];

                return FutureBuilder<Account?>(
                  future: UserFirestore.getUserByUserId(post.postAccountId),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (userSnapshot.hasError) {
                      return Center(
                          child: Text('エラーが発生しました: ${userSnapshot.error}'));
                    }

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
                          isRetweetedNotifier: ValueNotifier<bool>(false),
                          onRetweetToggle: () {
                            // リツイート機能の処理
                          },
                          replyFlag: ValueNotifier<bool>(false),
                          userId: postAccount.id, // 管理者として閲覧する場合
                        ),
                        Divider(
                          color: Colors.black,
                          thickness: 3,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
