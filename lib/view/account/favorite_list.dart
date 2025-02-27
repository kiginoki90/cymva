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

  const FavoriteList({Key? key, required this.myAccount}) : super(key: key);

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
    _favoritePost.getFavoritePosts(); // お気に入りの投稿を取得
    _bookmarkPost.getBookmarkPosts(); // ブックマークの投稿を取得
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
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
              itemCount: model.postList.length + 1,
              itemBuilder: (context, index) {
                if (index == model.postList.length) {
                  return _isLoadingMore
                      ? const Center(child: Text(" Loading..."))
                      : const Center(child: Text("結果は以上です"));
                }

                final post = model.postList[index];

                // お気に入りユーザー数の初期化と更新
                _favoritePost.favoriteUsersNotifiers[post.postId] ??=
                    ValueNotifier<int>(0);
                _favoritePost.updateFavoriteUsersCount(post.postId);

                _bookmarkPost.bookmarkUsersNotifiers[post.postId] ??=
                    ValueNotifier<int>(0);
                _bookmarkPost.updateBookmarkUsersCount(post.postId);

                return FutureBuilder<Account?>(
                  future: _fetchAccount(post.postAccountId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: Text("アカウント情報が取得できませんでした"));
                    }

                    final postAccount = snapshot.data!;

                    return PostItemWidget(
                      key: ValueKey(post.postId),
                      post: post,
                      postAccount: postAccount,
                      favoriteUsersNotifier:
                          _favoritePost.favoriteUsersNotifiers[post.postId]!,
                      isFavoriteNotifier: ValueNotifier<bool>(
                        _favoritePost.favoritePostsNotifier.value
                            .contains(post.postId),
                      ),
                      onFavoriteToggle: () => _favoritePost.toggleFavorite(
                        post.postId,
                        _favoritePost.favoritePostsNotifier.value
                            .contains(post.postId),
                      ),
                      replyFlag: ValueNotifier<bool>(false),
                      bookmarkUsersNotifier:
                          _bookmarkPost.bookmarkUsersNotifiers[post.postId]!,
                      isBookmarkedNotifier: ValueNotifier<bool>(
                        _bookmarkPost.bookmarkPostsNotifier.value
                            .contains(post.postId),
                      ),
                      onBookMsrkToggle: () => _bookmarkPost.toggleBookmark(
                        post.postId,
                        _bookmarkPost.bookmarkPostsNotifier.value
                            .contains(post.postId),
                      ),
                      userId: widget.myAccount.id,
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
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorite_posts')
        .orderBy('added_at', descending: true)
        .limit(5);

    final querySnapshot = await query.get();
    List<Post> posts = [];
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      List<Future<Post?>> futures = querySnapshot.docs.map((doc) async {
        final postId = doc.id;
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;
          return Post.fromMap(postData, documentSnapshot: postDoc);
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
    return posts;
  }

  Future<List<Post>> getFavoritePostsNext(String userId) async {
    if (_lastDocument == null) return [];

    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorite_posts')
        .orderBy('added_at', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(5);

    final querySnapshot = await query.get();
    List<Post> posts = [];
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      List<Future<Post?>> futures = querySnapshot.docs.map((doc) async {
        final postId = doc.id;
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;
          return Post.fromMap(postData, documentSnapshot: postDoc);
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
