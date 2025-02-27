import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/ad_widget.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/users.dart';

class RankingPage extends ConsumerStatefulWidget {
  final String userId;
  const RankingPage({
    super.key,
    required this.userId,
  });

  @override
  _RankingPageState createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage> {
  final ScrollController _scrollController = ScrollController();
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ValueNotifier<bool> _showScrollToTopButton = ValueNotifier(false);
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _favoritePost.getFavoritePosts();
    _bookmarkPost.getBookmarkPosts(); // ブックマークの投稿を取得
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(rankingViewModelProvider).getRankingPosts(widget.userId);
    });
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
          .read(rankingViewModelProvider)
          .getRankingPostsNext(widget.userId);
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

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(rankingViewModelProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          // リフレッシュ機能
          child: RefreshIndicator(
            onRefresh: () => model.getRankingPosts(widget.userId),
            child: model.rankingPostList.isEmpty
                ? const Center(child: Text("まだ投稿がありません"))
                : ListView.builder(
                    //リストのスクロール位置を制御するためにScrollControllerを指定
                    controller: _scrollController,
                    itemCount: model.rankingPostList.length +
                        (model.rankingPostList.length ~/ 10) +
                        1,
                    itemBuilder: (context, int index) {
                      if (index ==
                          model.rankingPostList.length +
                              (model.rankingPostList.length ~/ 10)) {
                        return _isLoadingMore
                            ? const Center(child: Text(" Loading..."))
                            : const Center(child: Text("結果は以上です"));
                      }

                      if (index % 11 == 10) {
                        return BannerAdWidget(); // 広告ウィジェットを表示
                      }

                      final postIndex = index - (index ~/ 11);
                      if (postIndex >= model.rankingPostList.length) {
                        return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                      }

                      final postDoc = model.rankingPostList[postIndex];
                      final post = Post.fromDocument(postDoc);
                      final postAccount = model.postUserMap[post.postAccountId];

                      // blockedUserIds に postAccount.id が含まれている場合は表示をスキップ
                      if (postAccount == null ||
                          postAccount.lockAccount ||
                          model.blockedAccounts.contains(postAccount.id)) {
                        return Container();
                      }

                      _favoritePost.favoriteUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _favoritePost.updateFavoriteUsersCount(post.id);

                      _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                          ValueNotifier<int>(0);
                      _bookmarkPost.updateBookmarkUsersCount(post.id);

                      return PostItemWidget(
                        key: PageStorageKey(post.id),
                        post: post,
                        postAccount: postAccount,
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
                  ),
          ),
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
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
                      border: Border.all(color: Colors.lightBlue, width: 2.0),
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
    );
  }
}

// DbManager クラス
class DbManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDocument;

  Future<List<QueryDocumentSnapshot>> getRankingPosts() async {
    DateTime now = DateTime.now();
    DateTime oneWeekAgo = now.subtract(Duration(days: 14));

    Query query = _firestore
        .collection('posts')
        .where('hide', isEqualTo: false)
        .where('created_time', isGreaterThanOrEqualTo: oneWeekAgo)
        .orderBy('created_time', descending: true)
        .limit(15);
    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
    }
    return querySnapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> getRankingPostsNext() async {
    if (_lastDocument == null) return [];

    DateTime now = DateTime.now();
    DateTime oneWeekAgo = now.subtract(Duration(days: 14));

    Query query = _firestore
        .collection('posts')
        .where('hide', isEqualTo: false)
        .where('created_time', isGreaterThanOrEqualTo: oneWeekAgo)
        .orderBy('created_time', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(15);
    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
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
    // blockUsers コレクションから blocked_user_id を取得
    final blockUsersSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();

    List<String> blockedUserIds = blockUsersSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    // block ドキュメントから blocked_user_id を取得
    final blockDocSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('block')
        .get();

    List<String> blockDocUserIds = blockDocSnapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();

    // 両方のリストを結合して返す
    blockedUserIds.addAll(blockDocUserIds);
    return blockedUserIds;
  }
}

// ViewModel クラス
final rankingViewModelProvider =
    ChangeNotifierProvider<RankingViewModel>((ref) => RankingViewModel(ref));

class RankingViewModel extends ChangeNotifier {
  RankingViewModel(this.ref);

  final Ref ref;
  List<QueryDocumentSnapshot> rankingPostList = [];
  List<QueryDocumentSnapshot> currentPostList = [];
  List<String> favoritePosts = [];
  List<String> blockedAccounts = [];
  Map<String, Account> postUserMap = {};

  Future<void> getRankingPosts(String userId) async {
    rankingPostList = [];
    currentPostList = await ref.read(dbManagerProvider).getRankingPosts();
    favoritePosts = await ref.read(dbManagerProvider).getFavoritePosts(userId);
    blockedAccounts =
        await ref.read(dbManagerProvider).fetchBlockedAccounts(userId);

    Map<String, int> postPoints = {};

    // 並列に非同期処理を実行
    await Future.wait(currentPostList.map((postDoc) async {
      Post post = Post.fromDocument(postDoc);
      int points = 0;

      // Calculate points for favorite_users
      QuerySnapshot favoriteSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id)
          .collection('favorite_users')
          .get();

      for (var favoriteDoc in favoriteSnapshot.docs) {
        DateTime addedAt = (favoriteDoc['added_at'] as Timestamp).toDate();
        if (addedAt.isAfter(DateTime.now().subtract(Duration(hours: 24)))) {
          points += 3;
        } else if (addedAt
            .isAfter(DateTime.now().subtract(Duration(hours: 72)))) {
          points += 2;
        } else if (addedAt
            .isAfter(DateTime.now().subtract(Duration(hours: 168)))) {
          points += 1;
        }
      }

      // Calculate points for reposts
      QuerySnapshot repostSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id)
          .collection('reposts')
          .get();

      for (var repostDoc in repostSnapshot.docs) {
        DateTime timestamp = (repostDoc['timestamp'] as Timestamp).toDate();
        if (timestamp.isAfter(DateTime.now().subtract(Duration(hours: 24)))) {
          points += 9;
        } else if (timestamp
            .isAfter(DateTime.now().subtract(Duration(hours: 72)))) {
          points += 6;
        } else if (timestamp
            .isAfter(DateTime.now().subtract(Duration(hours: 168)))) {
          points += 3;
        }
      }

      // Calculate points for reply_post
      QuerySnapshot replySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id)
          .collection('reply_post')
          .get();

      for (var replyDoc in replySnapshot.docs) {
        DateTime timestamp = (replyDoc['timestamp'] as Timestamp).toDate();
        if (timestamp.isAfter(DateTime.now().subtract(Duration(hours: 24)))) {
          points += 6;
        } else if (timestamp
            .isAfter(DateTime.now().subtract(Duration(hours: 72)))) {
          points += 4;
        } else if (timestamp
            .isAfter(DateTime.now().subtract(Duration(hours: 168)))) {
          points += 2;
        }
      }

      postPoints[post.id] = points;
    }).toList());

    // Sort posts by points
    currentPostList.sort((a, b) {
      final aPoints = postPoints[a.id] ?? 0;
      final bPoints = postPoints[b.id] ?? 0;
      return bPoints.compareTo(aPoints);
    });

    rankingPostList.addAll(currentPostList);
    postUserMap = await UserFirestore.getPostUserMap(
          rankingPostList
              .map((doc) => (doc.data()
                  as Map<String, dynamic>)['post_account_id'] as String)
              .toList(),
        ) ??
        {};
    notifyListeners();
  }

  Future<void> getRankingPostsNext(String userId) async {
    currentPostList = await ref.read(dbManagerProvider).getRankingPostsNext();
    if (currentPostList.isNotEmpty) {
      rankingPostList.addAll(currentPostList);

      Map<String, int> postPoints = {};

      // 並列に非同期処理を実行
      await Future.wait(currentPostList.map((postDoc) async {
        Post post = Post.fromDocument(postDoc);
        int points = 0;

        // Calculate points for favorite_users
        QuerySnapshot favoriteSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .collection('favorite_users')
            .get();

        for (var favoriteDoc in favoriteSnapshot.docs) {
          DateTime addedAt = (favoriteDoc['added_at'] as Timestamp).toDate();
          if (addedAt.isAfter(DateTime.now().subtract(Duration(hours: 24)))) {
            points += 3;
          } else if (addedAt
              .isAfter(DateTime.now().subtract(Duration(hours: 72)))) {
            points += 2;
          } else if (addedAt
              .isAfter(DateTime.now().subtract(Duration(hours: 168)))) {
            points += 1;
          }
        }

        // Calculate points for reposts
        QuerySnapshot repostSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .collection('reposts')
            .get();

        for (var repostDoc in repostSnapshot.docs) {
          DateTime timestamp = (repostDoc['timestamp'] as Timestamp).toDate();
          if (timestamp.isAfter(DateTime.now().subtract(Duration(hours: 24)))) {
            points += 9;
          } else if (timestamp
              .isAfter(DateTime.now().subtract(Duration(hours: 72)))) {
            points += 6;
          } else if (timestamp
              .isAfter(DateTime.now().subtract(Duration(hours: 168)))) {
            points += 3;
          }
        }

        // Calculate points for reply_post
        QuerySnapshot replySnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .collection('reply_post')
            .get();

        for (var replyDoc in replySnapshot.docs) {
          DateTime timestamp = (replyDoc['timestamp'] as Timestamp).toDate();
          if (timestamp.isAfter(DateTime.now().subtract(Duration(hours: 24)))) {
            points += 6;
          } else if (timestamp
              .isAfter(DateTime.now().subtract(Duration(hours: 72)))) {
            points += 4;
          } else if (timestamp
              .isAfter(DateTime.now().subtract(Duration(hours: 168)))) {
            points += 2;
          }
        }

        postPoints[post.id] = points;
      }).toList());

      // Sort posts by points
      currentPostList
          .sort((a, b) => postPoints[b.id]!.compareTo(postPoints[a.id]!));

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
