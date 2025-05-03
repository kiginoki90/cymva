import 'package:cymva/ad_widget.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteList extends ConsumerStatefulWidget {
  final Account myAccount;
  final userId;

  const FavoriteList({Key? key, required this.myAccount, required this.userId})
      : super(key: key);

  @override
  _FavoriteListState createState() => _FavoriteListState();
}

class _FavoriteListState extends ConsumerState<FavoriteList> {
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  Map<String, Account> _accountCache = {};

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_scrollListener);
    // _favoritePost.getFavoritePosts(); // お気に入りの投稿を取得
    // _bookmarkPost.getBookmarkPosts(); // ブックマークの投稿を取得
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener); // リスナーを解除
    _scrollController.dispose(); // コントローラーを破棄
    super.dispose();
  }

  void _scrollListener() async {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });
      await ref
          .read(viewModelProvider)
          .getFavoritePostsNext(widget.myAccount.id);
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    await ref.read(viewModelProvider).getFavoritePosts(widget.myAccount.id);
  }

  Future<void> _refreshPosts() async {
    await ref.read(viewModelProvider).getFavoritePosts(widget.myAccount.id);
  }

  Future<Account?> _fetchAccount(String accountId) async {
    if (_accountCache.containsKey(accountId)) {
      return _accountCache[accountId];
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(accountId)
        .get();
    if (userDoc.exists) {
      final account = Account.fromDocument(userDoc);
      _accountCache[accountId] = account;
      return account;
    }
    print(userDoc);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(viewModelProvider);

    if (model.postList.isEmpty) {
      return const Center(child: Text("まだお気に入りの投稿がありません"));
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: RefreshIndicator(
            onRefresh: _refreshPosts,
            child: ListView.builder(
              controller: _scrollController,
              itemCount:
                  model.postList.length + (model.postList.length ~/ 10) + 1,
              itemBuilder: (context, index) {
                if (index ==
                    model.postList.length + (model.postList.length ~/ 10)) {
                  return _isLoadingMore
                      ? const Center(child: Text(" Loading..."))
                      : const Center(child: Text("結果は以上です"));
                }

                if (index % 11 == 10) {
                  return BannerAdWidget(); // 広告ウィジェットを表示
                }

                final postIndex = index - (index ~/ 11);
                if (postIndex >= model.postList.length) {
                  return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                }

                final post = model.postList[postIndex];

                // お気に入りユーザー数の初期化と更新
                _favoritePost.favoriteUsersNotifiers[post.id] ??=
                    ValueNotifier<int>(0);
                _favoritePost.updateFavoriteUsersCount(post.id);

                _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                    ValueNotifier<int>(0);
                _bookmarkPost.updateBookmarkUsersCount(post.id);

                return FutureBuilder<Account?>(
                  future: _fetchAccount(post.postAccountId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: Text(""));
                    }

                    final postAccount = snapshot.data!;

                    return PostItemWidget(
                      key: ValueKey(post.id),
                      post: post,
                      postAccount: postAccount,
                      favoriteUsersNotifier:
                          _favoritePost.favoriteUsersNotifiers[post.id]!,
                      isFavoriteNotifier: ValueNotifier<bool>(
                        _favoritePost.favoritePostsNotifier.value
                            .contains(post.id),
                      ),
                      onFavoriteToggle: () => _favoritePost.toggleFavorite(
                        post.postId,
                        _favoritePost.favoritePostsNotifier.value
                            .contains(post.id),
                      ),
                      replyFlag: ValueNotifier<bool>(false),
                      bookmarkUsersNotifier:
                          _bookmarkPost.bookmarkUsersNotifiers[post.id]!,
                      isBookmarkedNotifier: ValueNotifier<bool>(
                        _bookmarkPost.bookmarkPostsNotifier.value
                            .contains(post.id),
                      ),
                      onBookMsrkToggle: () => _bookmarkPost.toggleBookmark(
                        post.id,
                        _bookmarkPost.bookmarkPostsNotifier.value
                            .contains(post.id),
                      ),
                      userId: widget.userId,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class DbManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDocument;

  Future<List<Post>> getFavoritePosts(String userId) async {
    List<Post> posts = [];
    try {
      Query query = _firestore
          .collectionGroup('favorite_users')
          .where('user_id', isEqualTo: userId)
          .orderBy('added_at', descending: true)
          .limit(10);

      final querySnapshot = await query.get();

      print('取得したドキュメントの数: ${querySnapshot.docs.length}');

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        List<Future<Post?>> futures = querySnapshot.docs.map((doc) async {
          final postId = doc.reference.parent.parent!.id;
          final postDoc =
              await _firestore.collection('posts').doc(postId).get();
          if (postDoc.exists) {
            return Post.fromDocument(postDoc);
          }
          return null;
        }).toList();

        posts = (await Future.wait(futures))
            .where((post) => post != null)
            .cast<Post>()
            .toList();
      } else {
        print("No posts found.");
      }
    } catch (e) {
      print("Error getting favorite posts: $e");
    }
    return posts;
  }

  Future<List<Post>> getFavoritePostsNext(String userId) async {
    if (_lastDocument == null) {
      return [];
    }

    List<Post> posts = [];
    try {
      Query query = _firestore
          .collectionGroup('favorite_users')
          .where('user_id', isEqualTo: userId)
          .orderBy('added_at', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(10);

      final querySnapshot = await query.get();
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        List<Future<Post?>> futures = querySnapshot.docs.map((doc) async {
          final postId = doc.reference.parent.parent!.id;
          final postDoc =
              await _firestore.collection('posts').doc(postId).get();
          if (postDoc.exists) {
            return Post.fromDocument(postDoc);
          }
          return null;
        }).toList();

        posts = (await Future.wait(futures))
            .where((post) => post != null)
            .cast<Post>()
            .toList();
      } else {
        print("No more posts found.");
      }
    } catch (e) {
      print("Error getting next favorite posts: $e");
    }
    return posts;
  }
}

final viewModelProvider =
    ChangeNotifierProvider<ViewModel>((ref) => ViewModel(ref));

class ViewModel extends ChangeNotifier {
  ViewModel(this.ref);

  final Ref ref;
  List<Post> postList = [];
  List<Post> currentPostList = [];

  Future<void> getFavoritePosts(String userId) async {
    postList = [];
    final dbManager = ref.read(dbManagerProvider);

    currentPostList = await dbManager.getFavoritePosts(userId);
    postList.addAll(currentPostList);
    notifyListeners();
  }

  Future<void> getFavoritePostsNext(String userId) async {
    currentPostList =
        await ref.read(dbManagerProvider).getFavoritePostsNext(userId);
    if (currentPostList.isNotEmpty) {
      postList.addAll(currentPostList);
    }
    notifyListeners();
  }
}

final dbManagerProvider = Provider((ref) => DbManager());
