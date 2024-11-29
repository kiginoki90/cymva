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
  bool _hasMore = true;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
    _fetchInitialFavorites();
  }

  Future<void> _fetchInitialFavorites() async {
    setState(() {
      _isLoading = true;
    });

    final favoritePostIds = await _fetchFavoritePostIds();
    final posts = await _fetchPosts(favoritePostIds);
    final accountIds = posts.map((post) => post.postAccountId).toSet().toList();
    final accounts = await _fetchAccounts(accountIds);

    if (mounted) {
      setState(() {
        _posts = posts;
        _accounts = accounts;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreFavorites() async {
    if (_isLoading || !_hasMore) return;

    // setState(() {
    //   _isLoading = true;
    // });

    final favoritePostIds = await _fetchFavoritePostIds();
    final posts = await _fetchPosts(favoritePostIds);
    if (posts.isNotEmpty) {
      final accountIds =
          posts.map((post) => post.postAccountId).toSet().toList();
      final accounts = await _fetchAccounts(accountIds);

      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _accounts.addAll(accounts);
          _lastDocument = favoritePostIds.last;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _hasMore = false;
          // _isLoading = false;
        });
      }
    }
  }

  Future<List<DocumentSnapshot>> _fetchFavoritePostIds() async {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.myAccount.id)
        .collection('favorite_posts')
        .orderBy('added_at', descending: true)
        .limit(10);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
    }

    return querySnapshot.docs;
  }

  Future<List<Post>> _fetchPosts(List<DocumentSnapshot> favoritePostIds) async {
    List<Post> posts = [];
    for (var doc in favoritePostIds) {
      final postId = doc.id;
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        posts.add(Post.fromMap(postData, documentSnapshot: postDoc));
      }
    }
    return posts;
  }

  Future<Map<String, Account>> _fetchAccounts(List<String> accountIds) async {
    final Map<String, Account> accounts = {};
    for (String accountId in accountIds) {
      final account = await _fetchAccount(accountId);
      if (account != null) {
        accounts[accountId] = account;
      }
    }
    return accounts;
  }

  Future<Account?> _fetchAccount(String accountId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(accountId)
        .get();
    if (userDoc.exists) {
      return Account.fromDocument(userDoc);
    }
    return null;
  }

  Future<void> _refreshFavorites() async {
    setState(() {
      _posts = [];
      _accounts = {};
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchInitialFavorites();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return const Center(child: Text('まだお気に入りの投稿がありません'));
    }

    return RefreshIndicator(
      onRefresh: _refreshFavorites,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return _hasMore
                ? TextButton(
                    onPressed: _fetchMoreFavorites,
                    child: const Text("もっと読み込む"),
                  )
                : const Center(child: Text("結果は以上です"));
          }

          Post post = _posts[index];
          Account postAccount = _accounts[post.postAccountId]!;

          // お気に入りユーザー数の初期化と更新
          _favoritePost.favoriteUsersNotifiers[post.id] ??=
              ValueNotifier<int>(0);
          _favoritePost.updateFavoriteUsersCount(post.id);

          return PostItemWidget(
            key: ValueKey(post.id), // これを追加して、各投稿のキーを設定
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
            replyFlag: ValueNotifier<bool>(false),
            userId: widget.myAccount.id,
          );
        },
      ),
    );
  }
}
