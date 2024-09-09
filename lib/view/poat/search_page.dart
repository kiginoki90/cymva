import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/poat/post_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/favorite_post.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  // late Future<List<String>>? _favoritePostsFuture;

  final FavoritePost _favoritePost = FavoritePost();

  @override
  void initState() {
    super.initState();
    // _favoritePostsFuture = _favoritePost.getFavoritePosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('検索'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                if (query.isNotEmpty) {
                  _searchPosts(query);
                } else {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
              decoration: const InputDecoration(
                hintText: '検索...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, Account>?>(
        future: _getAccountsForPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            final userMap = snapshot.data!;
            return ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final postDoc = _searchResults[index];
                final post = Post.fromDocument(postDoc);

                final postAccount = userMap[post.postAccountId];

                if (postAccount == null) return Container();

                _favoritePost.favoriteUsersNotifiers[post.id] ??=
                    ValueNotifier<int>(0);
                _favoritePost.updateFavoriteUsersCount(post.id);

                // リツイートの状態を管理するためのValueNotifierを初期化
                ValueNotifier<bool> isRetweetedNotifier = ValueNotifier<bool>(
                  false, // Firestoreからリツイートの状態を取得し初期化する
                );

                return PostItemWidget(
                  post: post,
                  postAccount: postAccount,
                  favoriteUsersNotifier:
                      _favoritePost.favoriteUsersNotifiers[post.id]!,
                  isFavoriteNotifier: ValueNotifier<bool>(
                    _favoritePost.favoritePostsNotifier.value.contains(post.id),
                  ),
                  onFavoriteToggle: () => _favoritePost.toggleFavorite(
                    post.id,
                    _favoritePost.favoritePostsNotifier.value.contains(post.id),
                  ),
                  // リツイートの状態を渡す
                  isRetweetedNotifier: isRetweetedNotifier,
                  // リツイートの状態をトグルする処理
                  onRetweetToggle: () {
                    // ここにリツイートの状態をFirestoreに保存するロジックを追加する
                    bool currentState = isRetweetedNotifier.value;
                    isRetweetedNotifier.value = !currentState;
                    // Firestoreでリツイートの情報を更新する処理
                  },
                  replyFlag: ValueNotifier<bool>(false),
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 2),
    );
  }

  Future<Map<String, Account>?> _getAccountsForPosts() async {
    List<String> postAccountIds = _searchResults
        .map((doc) => doc['post_account_id'] as String)
        .toSet()
        .toList();

    return await UserFirestore.getPostUserMap(postAccountIds);
  }

  Future<void> _searchPosts(String query) async {
    final firestore = FirebaseFirestore.instance;

    final querySnapshot = await firestore
        .collection('posts')
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    setState(() {
      _searchResults = querySnapshot.docs;
    });
  }
}
