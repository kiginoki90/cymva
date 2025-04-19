import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cymva/ad_widget.dart';

class FollowTimelinePage extends ConsumerStatefulWidget {
  final String userId;
  FollowTimelinePage({
    super.key,
    required this.userId,
  });

  @override
  _FollowTimelinePageState createState() => _FollowTimelinePageState();
}

class _FollowTimelinePageState extends ConsumerState<FollowTimelinePage> {
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  String? loginUserId;
  final FlutterSecureStorage storage = FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showScrollToTopButton = ValueNotifier(false);
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadLoginUserId();
    _scrollController.addListener(_scrollListener);
    // _favoritePost.getFavoritePosts();
    // _bookmarkPost.getBookmarkPosts();
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
      await ref.read(viewModelProvider).getFollowedPostsNext(widget.userId);
      setState(() {
        _isLoadingMore = false;
      });
    }

    if (_scrollController.offset >= 600) {
      _showScrollToTopButton.value = true;
    } else {
      _showScrollToTopButton.value = false;
    }
  }

  Future<void> _loadLoginUserId() async {
    loginUserId = await storage.read(key: 'account_id');
    if (loginUserId != null) {
      await ref.read(viewModelProvider).getFollowedPosts(widget.userId);
    }
  }

  Future<void> _refreshPosts() async {
    await ref.read(viewModelProvider).getFollowedPosts(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(viewModelProvider);

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: RefreshIndicator(
                onRefresh: _refreshPosts,
                child: model.followedPostList.isEmpty
                    ? const Center(child: Text("まだ投稿がありません"))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: model.followedPostList.length +
                            (model.followedPostList.length ~/ 10) +
                            1,
                        itemBuilder: (context, int index) {
                          if (index ==
                              model.followedPostList.length +
                                  (model.followedPostList.length ~/ 10)) {
                            return _isLoadingMore
                                ? const Center(child: Text(" Loading..."))
                                : const Center(child: Text("結果は以上です"));
                          }

                          if (index % 8 == 7) {
                            return BannerAdWidget() ??
                                SizedBox(height: 50); // 広告ウィジェットを表示
                          }

                          final postIndex = index - (index ~/ 11);
                          if (postIndex >= model.followedPostList.length) {
                            return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                          }

                          final postDoc = model.followedPostList[postIndex];
                          final post = Post.fromDocument(postDoc);
                          final postAccount =
                              model.postUserMap[post.postAccountId];

                          _favoritePost.favoriteUsersNotifiers[post.id] ??=
                              ValueNotifier<int>(0);
                          _favoritePost.updateFavoriteUsersCount(post.id);

                          _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                              ValueNotifier<int>(0);
                          _bookmarkPost.updateBookmarkUsersCount(post.id);

                          return PostItemWidget(
                            key: PageStorageKey(post.id),
                            post: post,
                            postAccount: postAccount!,
                            favoriteUsersNotifier:
                                _favoritePost.favoriteUsersNotifiers[post.id]!,
                            isFavoriteNotifier: ValueNotifier<bool>(
                              _favoritePost.favoritePostsNotifier.value
                                  .contains(post.id),
                            ),
                            onFavoriteToggle: () =>
                                _favoritePost.toggleFavorite(
                              post.id,
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
                            onBookMsrkToggle: () =>
                                _bookmarkPost.toggleBookmark(
                              post.id,
                              _bookmarkPost.bookmarkPostsNotifier.value
                                  .contains(post.id),
                            ),
                            userId: widget.userId,
                          );
                        },
                      ),
              ),
            ),
          ),
          Positioned(
            bottom: 30.0,
            right: 16.0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _showScrollToTopButton,
              builder: (context, value, child) {
                return value
                    ? GestureDetector(
                        onDoubleTap: () {
                          _scrollController.animateTo(
                            0,
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          width: 56.0,
                          height: 56.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.lightBlue, width: 2.0),
                            color: Colors.transparent, // 内側を透明にする場合
                          ),
                          child: Icon(
                            Icons.keyboard_double_arrow_up,
                            color: Colors.lightBlue,
                            size: 40.0,
                          ),
                        ),
                      )
                    : Container();
              },
            ),
          ),
        ],
      ),
    );
  }
}

final viewModelProvider =
    ChangeNotifierProvider<ViewModel>((ref) => ViewModel(ref));

class ViewModel extends ChangeNotifier {
  ViewModel(this.ref);

  final Ref ref;
  List<QueryDocumentSnapshot> followedPostList = [];
  List<QueryDocumentSnapshot> currentPostList = [];
  List<String> favoritePosts = [];
  List<String> blockedAccounts = [];
  Map<String, Account> postUserMap = {};

  Future<void> getFollowedPosts(String userId) async {
    followedPostList = [];
    final dbManager = ref.read(dbManagerProvider);

    // 並列に非同期処理を実行
    final results = await Future.wait([
      dbManager.getFollowedPosts(userId),
      dbManager.getFavoritePosts(userId),
      dbManager.fetchBlockedAccounts(userId),
    ]);

    currentPostList = results[0] as List<QueryDocumentSnapshot>;
    favoritePosts = results[1] as List<String>;
    blockedAccounts = results[2] as List<String>;

    followedPostList.addAll(currentPostList);
    postUserMap = await UserFirestore.getPostUserMap(
          followedPostList
              .map((doc) => (doc.data()
                  as Map<String, dynamic>)['post_account_id'] as String)
              .toList(),
        ) ??
        {};
    notifyListeners();
  }

  Future<void> getFollowedPostsNext(String userId) async {
    currentPostList =
        await ref.read(dbManagerProvider).getFollowedPostsNext(userId);
    if (currentPostList.isNotEmpty) {
      followedPostList.addAll(currentPostList);
      final newPostUserMap = await UserFirestore.getPostUserMap(
            currentPostList
                .map((doc) => (doc.data()
                    as Map<String, dynamic>)['post_account_id'] as String)
                .toList(),
          ) ??
          {};
      postUserMap.addAll(newPostUserMap);
    }
    notifyListeners();
  }
}

final dbManagerProvider = Provider((ref) => DbManager());

class DbManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDocument;

  Future<List<QueryDocumentSnapshot>> getFollowedPosts(String userId) async {
    final followSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('follow')
        .get();

    List<String> followedUserIds =
        followSnapshot.docs.map((doc) => doc.id).toList();

    if (followedUserIds.isEmpty) {
      print("No followed users found.");
      return [];
    }

    final blockSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();

    List<String> blockedUserIds = blockSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    followedUserIds.removeWhere((userId) => blockedUserIds.contains(userId));

    if (followedUserIds.isEmpty) {
      print("All followed users are blocked.");
      return [];
    }

    Query query = _firestore
        .collection('posts')
        .where('post_account_id', whereIn: followedUserIds)
        .where('hide', isEqualTo: false)
        .orderBy('created_time', descending: true)
        .limit(15);

    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
    } else {
      print("No posts found.");
    }
    return querySnapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> getFollowedPostsNext(
      String userId) async {
    if (_lastDocument == null) return [];

    final followSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('follow')
        .get();

    List<String> followedUserIds =
        followSnapshot.docs.map((doc) => doc.id).toList();

    if (followedUserIds.isEmpty) {
      print("No followed users found.");
      return [];
    }

    final blockSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();

    List<String> blockedUserIds = blockSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    followedUserIds.removeWhere((userId) => blockedUserIds.contains(userId));

    if (followedUserIds.isEmpty) {
      print("All followed users are blocked.");
      return [];
    }

    Query query = _firestore
        .collection('posts')
        .where('post_account_id', whereIn: followedUserIds)
        .where('hide', isEqualTo: false)
        .orderBy('created_time', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(15);

    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
    } else {
      print("No more posts found.");
    }
    return querySnapshot.docs;
  }

  Future<List<String>> getFavoritePosts(String userId) async {
    final snapshot = await _firestore
        .collection('favorites')
        .doc(userId)
        .collection('posts')
        .get();

    return snapshot.docs.map((doc) => doc['post_id'] as String).toList();
  }

  Future<List<String>> fetchBlockedAccounts(String userId) async {
    final blockUsersSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();

    List<String> blockedUserIds = blockUsersSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    final blockDocSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('block')
        .get();

    List<String> blockDocUserIds = blockDocSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    blockedUserIds.addAll(blockDocUserIds);
    return blockedUserIds;
  }
}
