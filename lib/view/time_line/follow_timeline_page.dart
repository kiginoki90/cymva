import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FollowTimelinePage extends StatefulWidget {
  final String userId;
  FollowTimelinePage({
    super.key,
    required this.userId,
  });

  @override
  State<FollowTimelinePage> createState() => _FollowTimelinePageState();
}

class _FollowTimelinePageState extends State<FollowTimelinePage> {
  late Future<List<String>>? _favoritePostsFuture;
  late Future<List<String>>? _blockedAccountsFuture;
  final FavoritePost _favoritePost = FavoritePost();
  String? loginUserId;
  final FlutterSecureStorage storage = FlutterSecureStorage();
  late Future<Map<String, Account?>> _accountsFuture;
  late Future<List<QueryDocumentSnapshot>> _followedPostsFuture =
      Future.value([]);

  @override
  void initState() {
    super.initState();
    _loadLoginUserId();
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
    _blockedAccountsFuture = _fetchBlockedAccounts(widget.userId);
  }

  Future<void> _loadLoginUserId() async {
    loginUserId = await storage.read(key: 'account_id');
    if (loginUserId != null) {
      setState(() {
        _followedPostsFuture = _fetchFollowedPosts();
        _accountsFuture = _fetchAccountsForFollowedPosts();
      });
    } else {
      // loginUserIdがnullの場合は空のFutureを設定
      setState(() {
        _followedPostsFuture = Future.value([]);
      });
    }
  }

  Future<List<String>> _fetchBlockedAccounts(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();

    // ブロックされたアカウントのparentsIdをリストに変換して返す
    return snapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();
  }

  Future<List<QueryDocumentSnapshot>> _fetchFollowedPosts() async {
    // フォローしているユーザーのIDリストを取得
    final followSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('follow')
        .get();

    List<String> followedUserIds =
        followSnapshot.docs.map((doc) => doc.id).toList();

    // フォローしているユーザーがいない場合は空のリストを返す
    if (followedUserIds.isEmpty) return [];

    // ブロックしたユーザーのIDリストを取得
    final blockSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('blockUsers')
        .get();

    List<String> blockedUserIds = blockSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    // フォローしているユーザーのIDリストからブロックしたユーザーのIDを削除
    followedUserIds.removeWhere((userId) => blockedUserIds.contains(userId));

    // フォローしているユーザーの投稿を取得
    if (followedUserIds.isEmpty) return [];

    final postSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('post_account_id', whereIn: followedUserIds)
        .get();

    return postSnapshot.docs;
  }

  Future<Map<String, Account?>> _fetchAccountsForFollowedPosts() async {
    final posts = await _fetchFollowedPosts();
    final accountIds = posts
        .map((doc) => Post.fromDocument(doc).postAccountId)
        .toSet()
        .toList();
    return await _fetchAccounts(accountIds);
  }

  Future<Map<String, Account?>> _fetchAccounts(List<String> accountIds) async {
    final Map<String, Account?> accounts = {};
    for (String accountId in accountIds) {
      final account = await _fetchAccount(accountId);
      accounts[accountId] = account;
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

  Future<void> _refreshPosts() async {
    setState(() {
      // リフレッシュ時にフォロー投稿を再取得
      _followedPostsFuture = _fetchFollowedPosts();
      _accountsFuture = _fetchAccountsForFollowedPosts(); // アカウント情報も再取得
    });
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _followedPostsFuture,
          builder: (context, postSnapshot) {
            if (postSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (postSnapshot.hasError) {
              return const Center(child: Text('データの取得に失敗しました'));
            }

            if (postSnapshot.hasData && postSnapshot.data!.isNotEmpty) {
              return FutureBuilder<Map<String, Account?>>(
                future: _accountsFuture,
                builder: (context, accountSnapshot) {
                  if (accountSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (accountSnapshot.hasError) {
                    return const Center(child: Text('アカウント情報の取得に失敗しました'));
                  }

                  final accounts = accountSnapshot.data ?? {};

                  // フィルタリングされた投稿リスト
                  final visiblePosts = postSnapshot.data!.where((doc) {
                    Post post = Post.fromDocument(doc);
                    return accounts
                        .containsKey(post.postAccountId); // アカウント情報が存在するかチェック
                  }).toList();

                  if (visiblePosts.isEmpty) {
                    return const Center(child: Text('アカウント情報が見つかりません'));
                  }

                  return ListView.builder(
                    itemCount: visiblePosts.length,
                    itemBuilder: (context, index) {
                      Post post = Post.fromDocument(visiblePosts[index]);
                      Account? postAccount = accounts[post.postAccountId];

                      _favoritePost.favoriteUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _favoritePost.updateFavoriteUsersCount(post.id);

                      return PostItemWidget(
                        post: post,
                        postAccount: postAccount!,
                        favoriteUsersNotifier:
                            _favoritePost.favoriteUsersNotifiers[post.id]!,
                        isFavoriteNotifier: ValueNotifier<bool>(
                          _favoritePost.favoritePostsNotifier.value
                              .contains(post.id),
                        ),
                        onFavoriteToggle: () => _favoritePost.toggleFavorite(
                          post.id,
                          _favoritePost.favoritePostsNotifier.value
                              .contains(post.id),
                        ),
                        isRetweetedNotifier: ValueNotifier<bool>(false),
                        onRetweetToggle: () {},
                        replyFlag: ValueNotifier<bool>(false),
                        userId: widget.userId,
                      );
                    },
                  );
                },
              );
            } else {
              return const Center(child: Text('投稿がありません'));
            }
          },
        ),
      ),
    );
  }
}
