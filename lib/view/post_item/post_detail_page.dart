import 'package:collection/collection.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/post_item_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/account/group_deatail_page.dart';
import 'package:cymva/view/post_item/Icons_action.dart';
import 'package:cymva/view/post_item/delete_group_dialog.dart';
import 'package:cymva/view/post_item/favorite_list_page.dart';
import 'package:cymva/view/post_item/group_list_dialog.dart';
import 'package:cymva/view/post_item/group_name_dialog.dart';
import 'package:cymva/view/post_item/link_text.dart';
import 'package:cymva/view/post_item/media_display_widget.dart';
import 'package:cymva/view/post_item/music_player_widget.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/view/post_item/post_visibility_widget.dart';
import 'package:cymva/view/post_item/show_report_Dialog.dart';
import 'package:cymva/view/repost_list_page.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cymva/model/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class PostDetailPage extends StatefulWidget {
  final Post post;
  final Account postAccount;
  final ValueNotifier<bool> replyFlag;
  final String userId;
  final ValueNotifier<int> bookmarkUsersNotifier;
  final ValueNotifier<bool> isBookmarkedNotifier;

  const PostDetailPage({
    Key? key,
    required this.post,
    required this.postAccount,
    required this.replyFlag,
    required this.userId,
    required this.bookmarkUsersNotifier,
    required this.isBookmarkedNotifier,
  }) : super(key: key);

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Future<List<Post>> _replyPostsFuture;
  final ValueNotifier<int> favoriteCountNotifier = ValueNotifier<int>(0);
  Future<Post?>? _replyToPostFuture;
  final FavoritePost _favoritePost = FavoritePost();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  final ValueNotifier<int> _replyCountNotifier = ValueNotifier<int>(0);
  final GlobalKey _userRowKey = GlobalKey();
  Post? _repostPost;
  Account? _repostPostAccount;
  final ValueNotifier<int> favoriteUsersNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isFavoriteNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> bookmarkUsersNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isBookmarkedNotifier = ValueNotifier<bool>(false);
  bool isHidden = true;
  String? _imageUrl;
  String? groupId;

  @override
  void initState() {
    super.initState();
    _fetchFavoriteData();
    _replyPostsFuture = getRePosts(widget.post.id);
    _checkAdminLevel();
    _getImageUrl();
    _checkPostInGroups();
    if (widget.post.reply != null && widget.post.reply!.isNotEmpty) {
      _replyToPostFuture = getPostById(widget.post.reply!);
    }
    _fetchRepostDetails();
    _fetchReplyCount();
  }

  Future<void> _checkPostInGroups() async {
    final groupCollectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.postAccount.id)
        .collection('group');

    final groupSnapshot = await groupCollectionRef.get();

    // すべてのグループのpostsコレクションをチェック
    for (var groupDoc in groupSnapshot.docs) {
      final postsCollectionRef = groupDoc.reference.collection('posts');
      final postsSnapshot = await postsCollectionRef.get();

      // postIdが既に存在するか確認
      final existingPost = postsSnapshot.docs.firstWhereOrNull(
        (doc) => doc.data()['postId'] == widget.post.id,
      );

      if (existingPost != null) {
        setState(() {
          groupId = groupDoc.id;
        });
        break;
      }
    }
  }

  void _fetchReplyCount() {
    String documentId =
        widget.post.id.isNotEmpty ? widget.post.id : widget.post.id;

    FirebaseFirestore.instance
        .collection('posts')
        .doc(documentId)
        .collection('reply_post')
        .snapshots()
        .listen((snapshot) {
      _replyCountNotifier.value = snapshot.size;
    });
  }

  Future<void> _fetchFavoriteData() async {
    // Firestoreからお気に入り数とお気に入り状態を取得
    final favoriteCountSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('favorite_users')
        .get();

    favoriteUsersNotifier.value = favoriteCountSnapshot.docs.length;

    // 自分がすでにお気に入りに追加しているかどうかを確認
    final isFavoriteSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('favorite_users')
        .doc(widget.userId)
        .get();

    isFavoriteNotifier.value = isFavoriteSnapshot.exists;
  }

  Future<void> _fetchRepostDetails() async {
    try {
      if (widget.post.repost != null) {
        _repostPost = await getPostById(widget.post.repost!);
      }
      if (_repostPost != null) {
        _repostPostAccount =
            await UserFirestore.getUser(_repostPost!.postAccountId);

        final favoriteCountSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(_repostPost!.id)
            .collection('favorite_users')
            .get();
        int favoriteCount = favoriteCountSnapshot.size; // ユーザー数を取得

        // favoriteCountNotifierに値を設定
        favoriteCountNotifier.value = favoriteCount; // 更新

        setState(() {});
      }
    } catch (e) {
      print('Repost details fetch failed: $e');
    }
  }

  static final _firestoreInstance = FirebaseFirestore.instance;

  // 指定されたpostIdに基づいてFirestoreから投稿を取得するメソッド
  Future<Post?> getPostById(String postId) async {
    try {
      var postSnapshot =
          await _firestoreInstance.collection('posts').doc(postId).get();
      if (postSnapshot.exists) {
        return Post.fromDocument(postSnapshot);
      }
      return null;
    } catch (e) {
      print('投稿の取得に失敗しました: $e');
      return null;
    }
  }

  Future<void> _confirmDeletePost(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('投稿の削除'),
          content: Text('この投稿を削除してもよろしいですか？'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // 削除をキャンセル
              },
              child: Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // 削除を許可
              },
              child: Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deletePost(context);
    }
  }

  Future<void> _showGroupNameDialog(postId) async {
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return GroupNameDialog(postId: postId, userId: widget.userId);
      },
    );
  }

  Future<void> _showGroupListDialog() async {
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return GroupListDialog(
          userId: widget.userId,
          postId: widget.post.id,
        );
      },
    );
  }

  Future<void> _deleteGroupDialog(postId, groupId) async {
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return DeleteGroupDialog(
            postId: postId, userId: widget.userId, groupId: groupId);
      },
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    List<String> deletedMediaUrls = []; // 削除した画像のURLを記録
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postDocRef =
            _firestoreInstance.collection('posts').doc(widget.post.id);

        // 1. すべての読み取り操作を最初に実行
        final postSnapshot = await transaction.get(postDocRef);
        final postData = postSnapshot.data() as Map<String, dynamic>;

        // サブコレクション内のすべてのドキュメントを削除する関数
        Future<List<DocumentSnapshot>> fetchSubcollectionDocs(
            String subcollectionName) async {
          final subcollectionRef = postDocRef.collection(subcollectionName);
          final snapshot = await subcollectionRef.get();
          return snapshot.docs;
        }

        final favoriteUsersDocs =
            await fetchSubcollectionDocs('favorite_users');
        final repostDocs = await fetchSubcollectionDocs('repost');
        final replyPostDocs = await fetchSubcollectionDocs('reply_post');

        // media_urlがnull以外の場合、画像を削除
        if (postData['media_url'] != null) {
          final List<dynamic> mediaUrls = postData['media_url'];
          for (String mediaUrl in mediaUrls) {
            final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
            await ref.delete(); // Firebase Storageの削除
            deletedMediaUrls.add(mediaUrl); // 削除したURLを記録
          }
        }

        // 返信が存在する場合、返信先の`reply_post`を削除
        if (widget.post.reply != null && widget.post.reply!.isNotEmpty) {
          final replyPostRef = _firestoreInstance
              .collection('posts')
              .doc(widget.post.reply)
              .collection('reply_post')
              .doc(widget.post.id);
          transaction.delete(replyPostRef);
        }

        if (widget.post.repost != null && widget.post.repost!.isNotEmpty) {
          final repostRef = _firestoreInstance
              .collection('posts')
              .doc(widget.post.repost)
              .collection('repost')
              .doc(widget.post.id);
          transaction.delete(repostRef);
        }

        // 2. 書き込み操作を実行
        for (var doc in favoriteUsersDocs) {
          transaction.delete(doc.reference);
        }
        for (var doc in repostDocs) {
          transaction.delete(doc.reference);
        }
        for (var doc in replyPostDocs) {
          transaction.delete(doc.reference);
        }

        // メインの投稿ドキュメントを削除
        transaction.delete(postDocRef);

        // グループ内の投稿を削除
        final groupCollectionRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('group')
            .doc(groupId)
            .collection('posts');

        final querySnapshot = await groupCollectionRef
            .where('postId', isEqualTo: widget.post.id)
            .get();

        for (var doc in querySnapshot.docs) {
          transaction.delete(doc.reference);
        }
      });

      // 成功時の処理
      showTopSnackBar(context, '投稿を削除しました', backgroundColor: Colors.green);
      Navigator.of(context).pop(true);
    } catch (e) {
      // エラー発生時にロールバック処理を実行
      for (String mediaUrl in deletedMediaUrls) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
          await ref.putFile(File(mediaUrl)); // 削除した画像を再アップロード
        } catch (uploadError) {
          print('画像の再アップロードに失敗しました: $uploadError');
        }
      }

      print('投稿の削除に失敗しました: $e');
      showTopSnackBar(context, '投稿の削除に失敗しました: $e', backgroundColor: Colors.red);
    }
  }

  void _toggleCloseComment() async {
    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.post.id);

    try {
      // 現在のcloseCommentの値を取得
      DocumentSnapshot postSnapshot = await postRef.get();
      Map<String, dynamic> postData =
          postSnapshot.data() as Map<String, dynamic>;
      bool currentCloseComment = postData['closeComment'] ?? false;

      // closeCommentの値を反転
      await postRef.update({'closeComment': !currentCloseComment});

      showTopSnackBar(
        context,
        currentCloseComment ? 'コメントを開きました' : 'コメントを閉じました',
        backgroundColor: Colors.green, // 必要に応じて背景色を指定
      );
    } catch (e) {
      showTopSnackBar(
        context,
        'コメントの状態を変更に失敗しました',
        backgroundColor: Colors.red, // 必要に応じて背景色を指定
      );
    }
  }

  // Firestoreの投稿のclipステータスを更新する関数
  Future<void> _updatePostClipStatus(bool clipStatus) async {
    try {
      // FirestoreのpostsコレクションにあるpostIdのドキュメントを取得
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.post.id);

      // 更新するデータ
      final data = {
        'clip': clipStatus, // clipの状態を設定
        'clipTime': clipStatus
            ? FieldValue.serverTimestamp()
            : null, // clipがtrueの時に現在時刻を設定、falseの時はnull
      };

      // Firestoreに更新を反映
      await postRef.update(data);

      showTopSnackBar(context, 'クリップ状態を更新しました',
          backgroundColor: Colors.green); // 成功時のメッセージ
    } catch (e) {
      showTopSnackBar(context, 'エラーが発生しました: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> swapImageDimensions(String postId) async {
    try {
      // Firestoreのpostsコレクションから該当の投稿を取得
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(postId);
      final postSnapshot = await postRef.get();

      if (postSnapshot.exists) {
        final postData = postSnapshot.data() as Map<String, dynamic>;

        // imageHeight と imageWidth を取得
        final int? imageHeight = postData['imageHeight'];
        final int? imageWidth = postData['imageWidth'];

        // 両方の値が存在する場合のみ入れ替え
        if (imageHeight != null && imageWidth != null) {
          await postRef.update({
            'imageHeight': imageWidth,
            'imageWidth': imageHeight,
          });

          // ページを更新
          setState(() {
            widget.post.imageHeight = imageWidth;
            widget.post.imageWidth = imageHeight;
          });

          showTopSnackBar(context, '縦横比を入れ替えました',
              backgroundColor: Colors.green);
        } else {
          showTopSnackBar(context, 'データが存在しません', backgroundColor: Colors.red);
        }
      } else {
        showTopSnackBar(context, 'エラーが発生しました', backgroundColor: Colors.red);
      }
    } catch (e) {
      showTopSnackBar(context, 'エラーが発生しました: $e', backgroundColor: Colors.red);
    }
  }

  Future<List<String>> _fetchBlockedAccounts(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('blockUsers')
        .get();
    return snapshot.docs
        .map((doc) => doc['blocked_user_id'] as String)
        .toList();
  }

  Future<List<Post>> getRePosts(String postId) async {
    try {
      final replyPostCollectionRef = _firestoreInstance
          .collection('posts')
          .doc(postId)
          .collection('reply_post');
      final snapshot = await replyPostCollectionRef.get();

      if (snapshot.docs.isEmpty) {
        print('サブコレクションreply_postは存在しません。');
        return [];
      }

      List<Post> prioritizedPosts = [];
      List<MapEntry<Post, int>> otherPostsWithFavorites = [];

      for (var doc in snapshot.docs) {
        var replyPostId = doc.id;
        var postSnapshot =
            await _firestoreInstance.collection('posts').doc(replyPostId).get();
        if (postSnapshot.exists) {
          var post = Post.fromDocument(postSnapshot);
          var postDetailData = postSnapshot.data();
          if (postDetailData != null) {
            // userIdとpost_account_idが一致する場合は優先してリストに追加
            if (post.postAccountId == widget.post.postAccountId) {
              prioritizedPosts.add(post);
            } else {
              // それ以外の投稿はfavorite_usersの件数でソートするため件数を取得
              final favoriteUsersSnapshot = await _firestoreInstance
                  .collection('posts')
                  .doc(replyPostId)
                  .collection('favorite_users')
                  .get();
              otherPostsWithFavorites
                  .add(MapEntry(post, favoriteUsersSnapshot.size));
            }
          }
        }
      }

      // favorite_usersの件数が多い順にソート
      otherPostsWithFavorites.sort((a, b) => b.value.compareTo(a.value));

      // prioritizedPostsの後にソートされたotherPostsWithFavoritesを追加
      return prioritizedPosts +
          otherPostsWithFavorites.map((e) => e.key).toList();
    } catch (e) {
      print('サブコレクションの取得に失敗しました: $e');
      return [];
    }
  }

  Future<void> _checkAdminLevel() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    // adminが4のときはRowを非表示に
    setState(() {
      isHidden = (userDoc['admin'] ?? 3) >= 4;
    });
  }

  @override
  void dispose() {
    _replyCountNotifier.dispose();
    super.dispose();
  }

  Future<void> _getImageUrl() async {
    // FirestoreからURLを取得
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('setting')
        .doc('AppBarIMG')
        .get();
    String? imageUrl = doc.data()?['PostDetailPage'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Firebase StorageからダウンロードURLを取得
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      String downloadUrl = await ref.getDownloadURL();
      setState(() {
        _imageUrl = downloadUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // お気に入りユーザー数の初期化と更新
    return Scaffold(
      appBar: AppBar(
        title: _imageUrl == null
            ? const Text('投稿の詳細', style: TextStyle(color: Colors.black))
            : Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                height: kToolbarHeight,
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_replyToPostFuture != null)
                FutureBuilder<Post?>(
                  future: _replyToPostFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return Text('エラーが発生しました: ${snapshot.error}');
                    } else if (!snapshot.hasData || snapshot.data == null) {
                      return const Center(
                        child: Column(
                          children: [
                            SizedBox(height: 15),
                            Text(
                              'この返信元は削除されています',
                              style: TextStyle(
                                  color: Color.fromARGB(255, 110, 108, 108),
                                  fontSize: 16),
                            ),
                            SizedBox(height: 15),
                            Divider(
                              color: Colors.grey,
                              thickness: 0.5,
                            ),
                          ],
                        ),
                      );
                    } else {
                      Post replyToPost = snapshot.data!;
                      return FutureBuilder<Account?>(
                        future:
                            UserFirestore.getUser(replyToPost.postAccountId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          } else if (snapshot.hasError) {
                            return Text('エラーが発生しました: ${snapshot.error}');
                          } else if (!snapshot.hasData ||
                              snapshot.data == null) {
                            return Text('エラーが発生しました。');
                          } else {
                            Account? postAccount = snapshot.data;
                            final isOwner =
                                widget.userId == replyToPost.postAccountId;

                            // フォローしているかどうかを確認する非同期関数
                            Future<bool> isFollowing() async {
                              final followSnapshot = await FirebaseFirestore
                                  .instance
                                  .collection('users')
                                  .doc(widget.userId)
                                  .collection('follow')
                                  .doc(replyToPost.postAccountId)
                                  .get();
                              return followSnapshot.exists;
                            }

                            // ブロックされているかどうかを確認する非同期関数
                            Future<bool> isBlocked() async {
                              final blockedAccounts =
                                  await _fetchBlockedAccounts(widget.userId);
                              return blockedAccounts
                                  .contains(replyToPost.postAccountId);
                            }

                            return FutureBuilder<List<bool>>(
                              future: Future.wait([isFollowing(), isBlocked()]),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                } else if (snapshot.hasError) {
                                  return const Center(
                                    child: Column(
                                      children: [
                                        SizedBox(height: 15),
                                        Text(
                                          'この返信元は表示できません',
                                          style: TextStyle(
                                              color: Color.fromARGB(
                                                  255, 110, 108, 108),
                                              fontSize: 16),
                                        ),
                                        SizedBox(height: 15),
                                        Divider(
                                          color: Colors.grey,
                                          thickness: 0.5,
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  final isFollowing = snapshot.data![0];
                                  final isBlocked = snapshot.data![1];

                                  if (replyToPost.hide == true ||
                                      isBlocked ||
                                      (postAccount?.lockAccount == true &&
                                          !isOwner &&
                                          !isFollowing) ||
                                      (replyToPost.closeComment == true &&
                                          replyToPost.postAccountId !=
                                              widget.post.postAccountId)) {
                                    return const Center(
                                      child: Column(
                                        children: [
                                          SizedBox(height: 15),
                                          Text(
                                            'この投稿は表示できません',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 16),
                                          ),
                                          SizedBox(height: 15),
                                          Divider(
                                            color: Colors.grey,
                                            thickness: 0.5,
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    _favoritePost.favoriteUsersNotifiers[
                                            replyToPost.id] ??=
                                        ValueNotifier<int>(0);
                                    _favoritePost.updateFavoriteUsersCount(
                                        replyToPost.id);

                                    _bookmarkPost.bookmarkUsersNotifiers[
                                            replyToPost.id] ??=
                                        ValueNotifier<int>(0);
                                    _bookmarkPost.updateBookmarkUsersCount(
                                        replyToPost.id);

                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              PostItemWidget(
                                                post: replyToPost,
                                                postAccount: postAccount!,
                                                favoriteUsersNotifier: _favoritePost
                                                        .favoriteUsersNotifiers[
                                                    replyToPost.id]!,
                                                isFavoriteNotifier: ValueNotifier<
                                                        bool>(
                                                    _favoritePost
                                                        .favoritePostsNotifier
                                                        .value
                                                        .contains(
                                                            replyToPost.id)),
                                                onFavoriteToggle: () {
                                                  _favoritePost.toggleFavorite(
                                                    replyToPost.id,
                                                    _favoritePost
                                                        .favoritePostsNotifier
                                                        .value
                                                        .contains(
                                                            replyToPost.id),
                                                  );
                                                  _favoritePost
                                                          .favoriteUsersNotifiers[
                                                      replyToPost
                                                          .id] ??= ValueNotifier<
                                                      int>(0);
                                                  _favoritePost
                                                      .updateFavoriteUsersCount(
                                                          replyToPost.id);
                                                },
                                                replyFlag:
                                                    ValueNotifier<bool>(true),
                                                bookmarkUsersNotifier: _bookmarkPost
                                                        .bookmarkUsersNotifiers[
                                                    replyToPost.id]!,
                                                isBookmarkedNotifier:
                                                    ValueNotifier<bool>(
                                                  _bookmarkPost
                                                      .bookmarkPostsNotifier
                                                      .value
                                                      .contains(replyToPost.id),
                                                ),
                                                onBookMsrkToggle: () =>
                                                    _bookmarkPost
                                                        .toggleBookmark(
                                                  replyToPost.id,
                                                  _bookmarkPost
                                                      .bookmarkPostsNotifier
                                                      .value
                                                      .contains(replyToPost.id),
                                                ),
                                                userId: widget.userId,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                }
                              },
                            );
                          }
                        },
                      );
                    }
                  },
                ),
              const SizedBox(height: 10),
              Row(
                key: _userRowKey,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AccountPage(
                                    postUserId: widget.post.postAccountId,
                                    withDelay: false,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                widget.postAccount.imagePath ??
                                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // 画像の取得に失敗した場合のエラービルダー
                                  return Image.network(
                                    'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.postAccount.name.length > 15
                                    ? '${widget.postAccount.name.substring(0, 15)}...'
                                    : widget.postAccount.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                '@${widget.postAccount.userId.length > 20 ? '${widget.postAccount.userId.substring(0, 20)}...' : widget.postAccount.userId}',
                                style: const TextStyle(color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        DateFormat('yyyy/M/d HH:mm:ss')
                            .format(widget.post.createdTime!.toDate()),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (groupId != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupDetailPage(
                                    groupId: groupId!,
                                    postAccount: widget.postAccount,
                                    userId: widget.userId,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.lightBlue, // 背景色を水色に設定
                                border: Border.all(
                                  color: Colors.lightBlue,
                                  width: 0.7,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                groupId!.length > 5
                                    ? '${groupId!.substring(0, 5)}'
                                    : groupId!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      const Color.fromARGB(255, 255, 255, 255),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (groupId != null) const SizedBox(height: 5),
                      if (widget.post.category != null &&
                          widget.post.category!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey,
                                width: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.post.category!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      if (widget.post.postAccountId == widget.userId)
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.add,
                            size: 30.0,
                          ),
                          onSelected: (String value) async {
                            if (value == 'Option 1') {
                              _confirmDeletePost(context); // 投稿の削除
                            } else if (value == 'Option 2') {
                              await _updatePostClipStatus(true);
                            } else if (value == 'Option 3') {
                              await _updatePostClipStatus(false);
                            } else if (value == 'Option 4') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FavoriteListPage(
                                    postId: widget.post.id,
                                  ),
                                ),
                              );
                            } else if (value == 'Option 5') {
                              _toggleCloseComment();
                            } else if (value == 'Option 6') {
                              await _showGroupNameDialog(widget.post.id);
                            } else if (value == 'Option 7') {
                              await _showGroupListDialog();
                            } else if (value == 'Option 8') {
                              _deleteGroupDialog(widget.post.id, groupId);
                            } else if (value == 'Option 9') {
                              swapImageDimensions(widget.post.id);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              const PopupMenuItem<String>(
                                value: 'Option 1',
                                child: Text(
                                  '投稿の削除',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'Option 2',
                                child: Text('トップに固定'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'Option 3',
                                child: Text('固定を解除'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'Option 4',
                                child: Text('スターを見る'),
                              ),
                              PopupMenuItem<String>(
                                value: 'Option 5',
                                child: Text(widget.post.closeComment == true
                                    ? 'コメントを開く'
                                    : 'コメントを閉じる'),
                              ),
                              if (groupId == null)
                                const PopupMenuItem<String>(
                                  value: 'Option 6',
                                  child: Text('グループを作る'),
                                ),
                              if (groupId == null)
                                const PopupMenuItem<String>(
                                  value: 'Option 7',
                                  child: Text('既存のグループに入れる'),
                                ),
                              if (groupId != null)
                                const PopupMenuItem<String>(
                                  value: 'Option 8',
                                  child: Text('グループから削除'),
                                ),
                              if (widget.post.isVideo == true)
                                const PopupMenuItem<String>(
                                  value: 'Option 9',
                                  child: Text('縦横比反転'),
                                ),
                            ];
                          },
                        )
                      else // 投稿者が自分ではない場合に報告ボタンを表示
                      if (isHidden == false)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (String value) {
                            if (value == '投稿の報告') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ShowReportDialog(postId: widget.post.id),
                                ),
                              );
                            } else if (value == 'Option 2') {
                            } else if (value == 'Option 3') {}
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              const PopupMenuItem<String>(
                                value: '投稿の報告',
                                child: Text(
                                  '投稿の報告',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ];
                          },
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // コンテンツ（テキスト）
              if (widget.post.category == '俳句・短歌')
                buildVerticalText(widget.post.content)
              else
                LinkText(
                  text: widget.post.content,
                  textSize: 18,
                  tapable: true,
                ),

              if (widget.post.musicUrl != null &&
                  widget.post.musicUrl!.isNotEmpty)
                Column(
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: MusicPlayerWidget(
                        musicUrl: widget.post.musicUrl!,
                        mediaUrl: widget.post.mediaUrl != null &&
                                widget.post.mediaUrl!.isNotEmpty
                            ? widget.post.mediaUrl!.first // リストの最初の要素を渡す
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                )
              else if (widget.post.mediaUrl != null &&
                  widget.post.mediaUrl!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    MediaDisplayWidget(
                      mediaUrl: widget.post.mediaUrl,
                      category: widget.post.category ?? '',
                      fullVideo: true,
                      post: widget.post,
                      is_video: widget.post.isVideo ?? false,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),

              if (_repostPost?.hide == true)
                Center(
                  child: Column(
                    children: [
                      SizedBox(height: 5),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey), // 枠線の色
                          borderRadius: BorderRadius.circular(8.0), // 角を丸める
                        ),
                        child: const Text(
                          'この引用投稿は表示できません',
                          textAlign: TextAlign.start,
                        ),
                      ),
                      SizedBox(height: 5),
                    ],
                  ),
                )
              else if (_repostPost != null && _repostPostAccount != null)
                PostVisibilityWidget(
                  postAccount: _repostPostAccount!,
                  userId: widget.userId,
                  repostPost: _repostPost!,
                )
              else if (widget.post.repost != null && _repostPost == null)
                Center(
                  child: Column(
                    children: [
                      SizedBox(height: 5),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey), // 枠線の色
                          borderRadius: BorderRadius.circular(8.0), // 角を丸める
                        ),
                        child: const Text(
                          'この引用投稿は削除されています',
                          textAlign: TextAlign.start,
                        ),
                      ),
                      SizedBox(height: 5),
                    ],
                  ),
                ),
              SizedBox(height: 15),
              if (isHidden == false)
                IconsActionsWidget(
                  post: widget.post,
                  postAccount: widget.postAccount,
                  userId: widget.userId,
                  bookmarkUsersNotifier: widget.bookmarkUsersNotifier,
                  isBookmarkedNotifier: widget.isBookmarkedNotifier,
                  isFavoriteNotifier: isFavoriteNotifier,
                  replyCountNotifier: _replyCountNotifier,
                ),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RepostListPage(
                        postId: widget.post.id,
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    '引用一覧 ▶️',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // FutureBuilderを使用して返信ポストを表示
              FutureBuilder<List<Post>>(
                future: _replyPostsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('エラーが発生しました: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('返信はありません');
                  } else {
                    List<Post> replyPosts = snapshot.data!;

                    // closeCommentがtrueの場合、投稿者の返信のみ表示
                    if (widget.post.closeComment == true) {
                      replyPosts = replyPosts
                          .where((replyPost) =>
                              replyPost.postAccountId == widget.userId)
                          .toList();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (replyPosts.isNotEmpty) ...[
                          Divider(thickness: 1.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              '返信',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Divider(thickness: 1.0),
                        ],
                        ...replyPosts.map((replyPost) {
                          return FutureBuilder<Account?>(
                            future:
                                UserFirestore.getUser(replyPost.postAccountId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return CircularProgressIndicator();
                              } else if (snapshot.hasError ||
                                  !snapshot.hasData) {
                                return Text('エラーが発生しました。');
                              } else {
                                Account? postAccount = snapshot.data;

                                if (replyPost.hide == true) {
                                  return const Center(
                                    child: Column(
                                      children: [
                                        SizedBox(height: 15),
                                        Text(
                                          'この投稿は表示できません',
                                          style: TextStyle(
                                              color: Colors.grey, fontSize: 16),
                                        ),
                                        SizedBox(height: 15),
                                        Divider(
                                          // 横幅いっぱいのラインを表示
                                          color: Colors.grey, // ラインの色を設定
                                          thickness: 0.5, // ラインの太さを設定
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                _favoritePost.favoriteUsersNotifiers[
                                    replyPost.id] ??= ValueNotifier<int>(0);
                                _favoritePost
                                    .updateFavoriteUsersCount(replyPost.id);

                                _bookmarkPost.bookmarkUsersNotifiers[
                                    replyPost.id] ??= ValueNotifier<int>(0);
                                _bookmarkPost
                                    .updateBookmarkUsersCount(replyPost.id);

                                return PostItemWidget(
                                  post: replyPost,
                                  postAccount: postAccount!,
                                  favoriteUsersNotifier: _favoritePost
                                      .favoriteUsersNotifiers[replyPost.id]!,
                                  isFavoriteNotifier: ValueNotifier<bool>(
                                    _favoritePost.favoritePostsNotifier.value
                                        .contains(replyPost.id),
                                  ),
                                  onFavoriteToggle: () {
                                    _favoritePost.toggleFavorite(
                                      replyPost.id,
                                      _favoritePost.favoritePostsNotifier.value
                                          .contains(replyPost.id),
                                    );
                                    _favoritePost.favoriteUsersNotifiers[
                                        replyPost.id] ??= ValueNotifier<int>(0);
                                    _favoritePost
                                        .updateFavoriteUsersCount(replyPost.id);
                                  },
                                  replyFlag: ValueNotifier<bool>(false),
                                  bookmarkUsersNotifier: _bookmarkPost
                                      .bookmarkUsersNotifiers[replyPost.id]!,
                                  isBookmarkedNotifier: ValueNotifier<bool>(
                                    _bookmarkPost.bookmarkPostsNotifier.value
                                        .contains(replyPost.id),
                                  ),
                                  onBookMsrkToggle: () =>
                                      _bookmarkPost.toggleBookmark(
                                    replyPost.id,
                                    _bookmarkPost.bookmarkPostsNotifier.value
                                        .contains(replyPost.id),
                                  ),
                                  userId: widget.userId,
                                );
                              }
                            },
                          );
                        }).toList(),
                      ],
                    );
                  }
                },
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
