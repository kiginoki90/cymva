import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart'; // Firestoreからユーザー情報を取得するために必要
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';

class FavoriteList extends StatefulWidget {
  final Account myAccount;

  const FavoriteList({Key? key, required this.myAccount}) : super(key: key);

  @override
  _FavoriteListState createState() => _FavoriteListState();
}

class _FavoriteListState extends State<FavoriteList> {
  final FavoritePost _favoritePost = FavoritePost();
  late Future<List<String>>? _favoritePostsFuture;
  List<Post> _posts = [];
  Map<String, Account> _accounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
  }

  // お気に入りの投稿をFirestoreから取得するメソッド
  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true; // 読み込み開始
    });

    QuerySnapshot favoriteSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.myAccount.id)
        .collection('favorite_posts')
        .orderBy('added_at', descending: true)
        .get();

    List<String> favoritePostIds =
        favoriteSnapshot.docs.map((doc) => doc.id).toList();

    if (favoritePostIds.isNotEmpty) {
      // 投稿を取得
      List<Post> posts = await PostFirestore.getPostsFromIds(favoritePostIds);
      // 投稿者のアカウント情報を取得
      List<String> accountIds =
          posts.map((post) => post.postAccountId).toSet().toList();
      Map<String, Account> accounts =
          await UserFirestore.getUsersByIds(accountIds);

      setState(() {
        _posts = posts;
        _accounts = accounts;
        _loading = false; // 読み込み完了
      });
    } else {
      setState(() {
        _loading = false; // 読み込み完了
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return const Center(child: Text('まだお気に入りの投稿がありません'));
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites, // 下にスワイプして更新する際に呼び出される
      child: ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          Post post = _posts[index];
          Account postAccount = _accounts[post.postAccountId]!;

          bool isFavorite = true; // お気に入りの投稿なので常にtrue

          // お気に入りユーザー数の初期化と更新
          _favoritePost.favoriteUsersNotifiers[post.id] ??=
              ValueNotifier<int>(0);
          _favoritePost.updateFavoriteUsersCount(post.id);

          // リツイートの状態を管理するためのValueNotifierを初期化
          ValueNotifier<bool> isRetweetedNotifier = ValueNotifier<bool>(false);

          return PostItemWidget(
            post: post,
            postAccount: postAccount, // Firestoreから取得したユーザー情報
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
            replyFlag: ValueNotifier<bool>(false),
            userId: widget.myAccount.userId,
          );
        },
      ),
    );
  }
}
