import 'package:cymva/model/account.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/post_item_utils.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/post_item/link_text.dart';
import 'package:cymva/view/post_item/media_display_widget.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/view/post_item/post_visibility_widget.dart';
import 'package:cymva/view/post_item/show_report_Dialog.dart';
import 'package:cymva/view/reply_page.dart';
import 'package:cymva/view/repost_list_page.dart';
import 'package:cymva/view/repost_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailPage extends StatefulWidget {
  final Post post;
  final String postAccountName;
  final String postAccountUserId;
  final String postAccountImagePath;
  final ValueNotifier<bool> replyFlag;
  final String userId;

  const PostDetailPage(
      {Key? key,
      required this.post,
      required this.postAccountName,
      required this.postAccountUserId,
      required this.postAccountImagePath,
      required this.replyFlag,
      required this.userId})
      : super(key: key);

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Future<List<Post>> _replyPostsFuture;
  late Future<List<String>> _favoritePostsFuture;
  final ValueNotifier<int> favoriteCountNotifier = ValueNotifier<int>(0);
  Future<Post?>? _replyToPostFuture;
  final FavoritePost _favoritePost = FavoritePost();
  final ValueNotifier<int> _replyCountNotifier = ValueNotifier<int>(0);
  final GlobalKey _userRowKey = GlobalKey();
  Post? _repostPost;
  Account? _repostPostAccount;
  VideoPlayerController? _videoController;
  final ValueNotifier<int> favoriteUsersNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isFavoriteNotifier = ValueNotifier<bool>(false);
  bool isHidden = true;

  @override
  void initState() {
    super.initState();
    _fetchFavoriteData();
    _replyPostsFuture = getRePosts(widget.post.postId);
    _favoritePostsFuture = _favoritePost.getFavoritePosts();
    _checkAdminLevel();

    if (widget.post.reply != null && widget.post.reply!.isNotEmpty) {
      _replyToPostFuture = getPostById(widget.post.reply!);
    }
    if (widget.post.isVideo && widget.post.mediaUrl != null) {
      _initializeVideoPlayer();
    }
    _fetchRepostDetails();
    _fetchReplyCount();
  }

  void _fetchReplyCount() {
    String documentId =
        widget.post.id.isNotEmpty ? widget.post.id : widget.post.postId;

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
        .doc(widget.post.postId)
        .collection('favorite_users')
        .get();

    favoriteUsersNotifier.value = favoriteCountSnapshot.docs.length;

    // 自分がすでにお気に入りに追加しているかどうかを確認
    final isFavoriteSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.postId)
        .collection('favorite_users')
        .doc(widget.userId)
        .get();

    isFavoriteNotifier.value = isFavoriteSnapshot.exists;
  }

  Future<void> _toggleFavorite() async {
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.postId)
        .collection('favorite_users')
        .doc(widget.userId);

    if (isFavoriteNotifier.value) {
      // すでにお気に入りに登録されている場合、解除する
      await postRef.delete();
      favoriteUsersNotifier.value--;
    } else {
      // お気に入りに追加する
      await postRef.set({});
      favoriteUsersNotifier.value++;
    }

    // お気に入り状態を反転
    isFavoriteNotifier.value = !isFavoriteNotifier.value;
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
            .doc(_repostPost!.postId)
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

  void _initializeVideoPlayer() {
    if (widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl![0]))
            ..initialize().then((_) {
              setState(() {});
              _videoController!.play();
            });
    }
  }

  static final _firestoreInstance = FirebaseFirestore.instance;

  // 指定されたpostIdに基づいてFirestoreから投稿を取得するメソッド
  Future<Post?> getPostById(String postId) async {
    try {
      var postSnapshot =
          await _firestoreInstance.collection('posts').doc(postId).get();
      if (postSnapshot.exists) {
        var postDetailData = postSnapshot.data();
        if (postDetailData != null) {
          return Post.fromMap(postDetailData);
        }
      }
      return null;
    } catch (e) {
      print('投稿の取得に失敗しました: $e');
      return null;
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    try {
      final postDocRef =
          _firestoreInstance.collection('posts').doc(widget.post.postId);

      // サブコレクション内のすべてのドキュメントを削除する関数
      Future<void> _deleteSubcollection(String subcollectionName) async {
        final subcollectionRef = postDocRef.collection(subcollectionName);
        final snapshot = await subcollectionRef.get();

        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      // 返信が存在する場合、返信先の`reply_post`を削除
      if (widget.post.reply != null && widget.post.reply!.isNotEmpty) {
        await _firestoreInstance
            .collection('posts')
            .doc(widget.post.reply)
            .collection('reply_post')
            .doc(widget.post.postId)
            .delete();
      }

      // サブコレクションを削除 (サブコレクション名が固定されている場合)
      await _deleteSubcollection('favorite_users');
      await _deleteSubcollection('repost');
      await _deleteSubcollection('reply_post');

      // メインの投稿ドキュメントを削除
      await postDocRef.delete();

      // ユーザーのポスト一覧からも削除
      await _firestoreInstance
          .collection('users')
          .doc(widget.post.postAccountId)
          .collection('my_posts')
          .doc(widget.post.postId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿を削除しました')),
      );
      Navigator.of(context).pop(true); // true を渡して前のページに戻る
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿の削除に失敗しました: $e')),
      );
    }
  }

  // Firestoreの投稿のclipステータスを更新する関数
  Future<void> _updatePostClipStatus(bool clipStatus) async {
    try {
      // FirestoreのpostsコレクションにあるpostIdのドキュメントを取得
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.postId);

      // 更新するデータ
      final data = {
        'clip': clipStatus, // clipの状態を設定
        'clipTime': clipStatus
            ? FieldValue.serverTimestamp()
            : null, // clipがtrueの時に現在時刻を設定、falseの時はnull
      };

      // Firestoreに更新を反映
      await postRef.update(data);

      // userコレクションのmy_postsに対しても更新を反映
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId) // userIdを使用してユーザーを特定
          .collection('my_posts')
          .doc(widget.post.postId); // 同じpostIdでmy_postsのドキュメントを特定

      // userのmy_postsに対しても更新
      await userRef.update(data);

      print(
          'Post clip status updated to $clipStatus and user my_posts updated');
    } catch (e) {
      print('Error updating post clip status: $e');
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
          var postDetailData = postSnapshot.data();
          if (postDetailData != null) {
            var post = Post.fromMap(postDetailData);

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

  @override
  Widget build(BuildContext context) {
    // お気に入りユーザー数の初期化と更新
    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿の詳細'),
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
                      return SizedBox(); // 返信元がない場合は何も表示しない
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
                                              color: Colors.grey, fontSize: 16),
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
                                          !isFollowing)) {
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
                                            replyToPost.postId] ??=
                                        ValueNotifier<int>(0);
                                    _favoritePost.updateFavoriteUsersCount(
                                        replyToPost.postId);

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
                                                    replyToPost.postId]!,
                                                isFavoriteNotifier:
                                                    ValueNotifier<bool>(
                                                        _favoritePost
                                                            .favoritePostsNotifier
                                                            .value
                                                            .contains(
                                                                replyToPost
                                                                    .postId)),
                                                onFavoriteToggle: () {
                                                  _favoritePost.toggleFavorite(
                                                    replyToPost.postId,
                                                    _favoritePost
                                                        .favoritePostsNotifier
                                                        .value
                                                        .contains(
                                                            replyToPost.postId),
                                                  );
                                                  _favoritePost
                                                              .favoriteUsersNotifiers[
                                                          replyToPost
                                                              .postId] ??=
                                                      ValueNotifier<int>(0);
                                                  _favoritePost
                                                      .updateFavoriteUsersCount(
                                                          replyToPost.postId);
                                                },
                                                replyFlag:
                                                    ValueNotifier<bool>(true),
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
              const SizedBox(height: 15),
              Row(
                key: _userRowKey,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AccountPage(
                              postUserId: widget.post.postAccountId),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        widget.postAccountImagePath ??
                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // 画像の取得に失敗した場合のエラービルダー
                          return Image.network(
                            'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                            width: 40,
                            height: 40,
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
                        widget.postAccountName.length > 15
                            ? '${widget.postAccountName.substring(0, 15)}...'
                            : widget.postAccountName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        '@${widget.postAccountUserId.length > 20 ? '${widget.postAccountUserId.substring(0, 20)}...' : widget.postAccountUserId}',
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                  Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                          icon: Icon(Icons.add),
                          onSelected: (String value) async {
                            if (value == 'Option 1') {
                              _deletePost(context); // 投稿の削除
                            } else if (value == 'Option 2') {
                              await _updatePostClipStatus(true);
                            } else if (value == 'Option 3') {
                              await _updatePostClipStatus(false);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem<String>(
                                value: 'Option 1',
                                child: Text(
                                  '投稿の削除',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'Option 2',
                                child: Text('トップに固定'),
                              ),
                              PopupMenuItem<String>(
                                value: 'Option 3',
                                child: Text('固定を解除'),
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
                                  builder: (context) => ShowReportDialog(
                                      postId: widget.post.postId),
                                ),
                              );
                            } else if (value == 'Option 2') {
                            } else if (value == 'Option 3') {}
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem<String>(
                                value: '投稿の報告',
                                child: Text(
                                  '投稿の報告',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                              // PopupMenuItem<String>(
                              //   value: 'Option 2',
                              //   child: Text('Option 2'),
                              // ),
                              // PopupMenuItem<String>(
                              //   value: 'Option 3',
                              //   child: Text('Option 3'),
                              // ),
                            ];
                          },
                        ),
                    ],
                  ),
                ],
              ),
              Text(
                DateFormat('yyyy/M/d HH:mm:ss')
                    .format(widget.post.createdTime!.toDate()),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),

              // コンテンツ（テキスト）
              if (widget.post.category == '俳句・短歌')
                buildVerticalText(widget.post.content)
              else
                LinkText(
                  text: widget.post.content,
                  userId: widget.userId,
                  textSize: 18,
                ),
              const SizedBox(height: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MediaDisplayWidget(
                    mediaUrl: widget.post.mediaUrl,
                    category: widget.post.category ?? '',
                  ),
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
                ),
              if (isHidden == false)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: favoriteUsersNotifier,
                          builder: (context, value, child) {
                            return Text(value.toString());
                          },
                        ),
                        const SizedBox(width: 5),
                        ValueListenableBuilder<bool>(
                          valueListenable: isFavoriteNotifier,
                          builder: (context, isFavorite, child) {
                            return GestureDetector(
                              onTap: () async {
                                await _toggleFavorite();
                                _favoritePost.toggleFavorite(
                                  widget.post.postId,
                                  _favoritePost.favoritePostsNotifier.value
                                      .contains(widget.post.postId),
                                );
                              },
                              child: Icon(
                                isFavorite ? Icons.star : Icons.star_outline,
                                color: isFavorite
                                    ? Color.fromARGB(255, 255, 183, 59)
                                    : Colors.grey,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.post.postId)
                              .collection('repost')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Text('0');
                            }
                            final repostCount = snapshot.data!.docs.length;
                            return Text(repostCount.toString());
                          },
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RepostPage(
                                  post: widget.post,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.repeat_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _replyCountNotifier,
                      builder: (context, replyCount, child) {
                        return Row(
                          children: [
                            Text(replyCount.toString()),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReplyPage(
                                      post: widget.post,
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.comment),
                            ),
                          ],
                        );
                      },
                    ),
                    // IconButton(
                    //   onPressed: () {},
                    //   icon: const Icon(Icons.share),
                    // ),
                  ],
                ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RepostListPage(
                        postId: widget.post.postId,
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
                                    replyPost.postId] ??= ValueNotifier<int>(0);
                                _favoritePost
                                    .updateFavoriteUsersCount(replyPost.postId);

                                return PostItemWidget(
                                  post: replyPost,
                                  postAccount: postAccount!,
                                  favoriteUsersNotifier:
                                      _favoritePost.favoriteUsersNotifiers[
                                          replyPost.postId]!,
                                  isFavoriteNotifier: ValueNotifier<bool>(
                                    _favoritePost.favoritePostsNotifier.value
                                        .contains(replyPost.postId),
                                  ),
                                  onFavoriteToggle: () {
                                    _favoritePost.toggleFavorite(
                                      replyPost.postId,
                                      _favoritePost.favoritePostsNotifier.value
                                          .contains(replyPost.postId),
                                    );
                                    _favoritePost.favoriteUsersNotifiers[
                                            replyPost.postId] ??=
                                        ValueNotifier<int>(0);
                                    _favoritePost.updateFavoriteUsersCount(
                                        replyPost.postId);
                                  },
                                  replyFlag: ValueNotifier<bool>(false),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 0),
    );
  }
}
