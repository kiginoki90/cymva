import 'package:cymva/ad_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final Account postAccount;

  const GroupDetailPage(
      {Key? key, required this.groupId, required this.postAccount})
      : super(key: key);

  @override
  _GroupDetailPageState createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isOwner = false; // 追加: オーナーかどうかのフラグ

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _fetchAccountData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccountData() async {
    final account = await UserFirestore.getUser(Authentication.myAccount!.id);
    if (account!.id == widget.postAccount.id) {
      setState(() {
        _isOwner = true; // オーナーかどうかを設定
      });
    }
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
          .getPostsNext(widget.groupId, widget.postAccount.id);
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    await ref
        .read(viewModelProvider)
        .getPosts(widget.groupId, widget.postAccount.id);
  }

  Future<void> _refreshPosts() async {
    await ref
        .read(viewModelProvider)
        .getPosts(widget.groupId, widget.postAccount.id);
  }

  Future<void> _saveOrder() async {
    await _updateDatabaseOrder(widget.groupId, widget.postAccount.id,
        ref.read(viewModelProvider).postIdList);
  }

  Future<void> _deleteGroup() async {
    final userId = widget.postAccount.id;
    final groupId = widget.groupId;

    // グループ内の投稿を削除
    final postsQuerySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('group')
        .doc(groupId)
        .collection('posts')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in postsQuerySnapshot.docs) {
      batch.delete(doc.reference);
    }

    // グループ自体を削除
    final groupRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('group')
        .doc(groupId);
    batch.delete(groupRef);

    try {
      await batch.commit();
      Navigator.of(context).pop(); // グループ詳細ページを閉じる
      showTopSnackBar(context, 'グループを削除しました', backgroundColor: Colors.green);
    } catch (e) {
      showTopSnackBar(context, 'エラーが発生しました', backgroundColor: Colors.red);
      print("Error deleting group: $e");
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('グループの削除'),
          content: Text('このグループを削除しますか？'),
          actions: <Widget>[
            TextButton(
              child: Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('はい'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteGroup();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(viewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupId),
        actions: _isOwner
            ? [
                IconButton(
                  icon: Icon(Icons.save),
                  onPressed: _saveOrder,
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: _showDeleteConfirmationDialog,
                ),
              ]
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: RefreshIndicator(
            onRefresh: _refreshPosts,
            child: model.postIdList.isEmpty
                ? const Center(child: Text("まだ投稿がありません"))
                : _isOwner
                    ? ReorderableListView(
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          setState(() {
                            final movedItem =
                                model.postIdList.removeAt(oldIndex);
                            model.postIdList.insert(newIndex, movedItem);
                          });
                        },
                        children:
                            List.generate(model.postIdList.length, (index) {
                          if (index ==
                              model.postIdList.length +
                                  (model.postIdList.length ~/ 10)) {
                            return _isLoadingMore
                                ? const Center(child: Text(" Loading..."))
                                : const Center(child: Text("結果は以上です"));
                          }

                          if (index % 11 == 10) {
                            return BannerAdWidget(); // 広告ウィジェットを表示
                          }

                          final postIndex = index - (index ~/ 11);
                          if (postIndex >= model.postIdList.length) {
                            return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                          }

                          final postId = model.postIdList[postIndex];

                          return FutureBuilder<DocumentSnapshot>(
                            key: ValueKey(postId),
                            future: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(postId)
                                .get(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                    child: CircularProgressIndicator());
                              }
                              final post = Post.fromDocument(snapshot.data!);

                              // お気に入りユーザー数の初期化と更新
                              _favoritePost.favoriteUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _favoritePost.updateFavoriteUsersCount(post.id);

                              _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _bookmarkPost.updateBookmarkUsersCount(post.id);

                              return GestureDetector(
                                child: PostItemWidget(
                                  key: PageStorageKey(post.id),
                                  post: post,
                                  postAccount: widget.postAccount,
                                  favoriteUsersNotifier: _favoritePost
                                      .favoriteUsersNotifiers[post.id]!,
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
                                  bookmarkUsersNotifier: _bookmarkPost
                                      .bookmarkUsersNotifiers[post.id]!,
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
                                  replyFlag: ValueNotifier<bool>(false),
                                  userId: widget.postAccount.id,
                                ),
                              );
                            },
                          );
                        }),
                      )
                    : ListView.builder(
                        itemCount: model.postIdList.length,
                        itemBuilder: (context, index) {
                          if (index ==
                              model.postIdList.length +
                                  (model.postIdList.length ~/ 10)) {
                            return _isLoadingMore
                                ? const Center(child: Text(" Loading..."))
                                : const Center(child: Text("結果は以上です"));
                          }

                          if (index % 11 == 10) {
                            return BannerAdWidget(); // 広告ウィジェットを表示
                          }

                          final postIndex = index - (index ~/ 11);
                          if (postIndex >= model.postIdList.length) {
                            return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                          }

                          final postId = model.postIdList[postIndex];

                          return FutureBuilder<DocumentSnapshot>(
                            key: ValueKey(postId),
                            future: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(postId)
                                .get(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                    child: CircularProgressIndicator());
                              }
                              final post = Post.fromDocument(snapshot.data!);

                              // お気に入りユーザー数の初期化と更新
                              _favoritePost.favoriteUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _favoritePost.updateFavoriteUsersCount(post.id);

                              _bookmarkPost.bookmarkUsersNotifiers[post.id] ??=
                                  ValueNotifier<int>(0);
                              _bookmarkPost.updateBookmarkUsersCount(post.id);

                              return GestureDetector(
                                child: PostItemWidget(
                                  key: PageStorageKey(post.id),
                                  post: post,
                                  postAccount: widget.postAccount,
                                  favoriteUsersNotifier: _favoritePost
                                      .favoriteUsersNotifiers[post.id]!,
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
                                  bookmarkUsersNotifier: _bookmarkPost
                                      .bookmarkUsersNotifiers[post.id]!,
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
                                  replyFlag: ValueNotifier<bool>(false),
                                  userId: widget.postAccount.id,
                                ),
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

  Future<void> _updateDatabaseOrder(
      String groupId, String userId, List<String> postIdList) async {
    final batch = FirebaseFirestore.instance.batch();
    bool hasError = false;

    for (int i = 0; i < postIdList.length; i++) {
      final postId = postIdList[i];
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('group')
          .doc(groupId)
          .collection('posts')
          .where('postId', isEqualTo: postId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final postRef = querySnapshot.docs.first.reference;
        batch.update(postRef, {'count': i});
      } else {
        hasError = true;
        print("Document with postId $postId not found.");
      }
    }

    try {
      await batch.commit();
      if (!hasError) {
        showTopSnackBar(context, '並び替えを保存しました', backgroundColor: Colors.green);
      } else {
        showTopSnackBar(context, '一部のドキュメントが見つかりませんでした',
            backgroundColor: Colors.orange);
      }
    } catch (e) {
      showTopSnackBar(context, 'エラーが発生しました', backgroundColor: Colors.red);
      print("Error committing batch: $e");
    }
  }
}

final viewModelProvider =
    ChangeNotifierProvider<ViewModel>((ref) => ViewModel(ref));

class ViewModel extends ChangeNotifier {
  ViewModel(this.ref);

  final Ref ref;
  List<String> postIdList = [];
  List<String> currentPostIdList = [];

  Future<void> getPosts(String groupId, String userId) async {
    postIdList = [];
    final dbManager = ref.read(dbManagerProvider);

    currentPostIdList = await dbManager.getGroupPosts(groupId, userId);
    postIdList.addAll(currentPostIdList);
    notifyListeners();
  }

  Future<void> getPostsNext(String groupId, String userId) async {
    currentPostIdList =
        await ref.read(dbManagerProvider).getGroupPostsNext(groupId, userId);
    if (currentPostIdList.isNotEmpty) {
      postIdList.addAll(currentPostIdList);
    }
    notifyListeners();
  }
}

final dbManagerProvider = Provider((ref) => DbManager());

class DbManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _lastDocument;

  Future<List<String>> getGroupPosts(String groupId, String userId) async {
    List<String> postIds = [];

    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('group')
        .doc(groupId)
        .collection('posts')
        .orderBy('count')
        .limit(15);

    final querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      postIds = querySnapshot.docs.map((doc) {
        return doc['postId'] as String;
      }).toList();
    }

    if (postIds.isEmpty) {
      print("No posts found.");
    }

    return postIds;
  }

  Future<List<String>> getGroupPostsNext(String groupId, String userId) async {
    List<String> postIds = [];

    if (_lastDocument != null) {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('group')
          .doc(groupId)
          .collection('posts')
          .orderBy('count')
          .startAfterDocument(_lastDocument!)
          .limit(15);

      final querySnapshot = await query.get();
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        postIds = querySnapshot.docs.map((doc) {
          return doc['postId'] as String;
        }).toList();
      }
    }

    if (postIds.isEmpty) {
      print("No posts found.");
    }

    return postIds;
  }
}
