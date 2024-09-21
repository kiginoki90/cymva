import 'package:cymva/model/account.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/post_item_utils.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/view/reply_page.dart';
import 'package:cymva/view/repost_item.dart';
import 'package:cymva/view/repost_list_page.dart';
import 'package:cymva/view/repost_page.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:video_player/video_player.dart';
import 'package:cymva/view/post_item/full_screen_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostDetailPage extends StatefulWidget {
  final Post post;
  final String postAccountName;
  final String postAccountUserId;
  final String postAccountImagePath;
  final ValueNotifier<int> favoriteUsersNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final VoidCallback onFavoriteToggle;
  final ValueNotifier<bool> isRetweetedNotifier;
  final VoidCallback onRetweetToggle;
  final ValueNotifier<bool> replyFlag;

  const PostDetailPage({
    Key? key,
    required this.post,
    required this.postAccountName,
    required this.postAccountUserId,
    required this.postAccountImagePath,
    required this.favoriteUsersNotifier,
    required this.isFavoriteNotifier,
    required this.onFavoriteToggle,
    required this.isRetweetedNotifier,
    required this.onRetweetToggle,
    required this.replyFlag,
  }) : super(key: key);

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Future<List<Post>> _replyPostsFuture;
  Future<Post?>? _replyToPostFuture;
  final FavoritePost _favoritePost = FavoritePost();
  final ValueNotifier<int> _replyCountNotifier = ValueNotifier<int>(0);
  // final ScrollController _scrollController = ScrollController();
  final GlobalKey _userRowKey = GlobalKey();
  Post? _repostPost;
  Account? _repostPostAccount;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _replyPostsFuture = getRePosts(widget.post.postId);

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

  Future<void> _fetchRepostDetails() async {
    try {
      if (widget.post.repost != null) {
        _repostPost = await getPostById(widget.post.repost!);
      }
      if (_repostPost != null) {
        _repostPostAccount =
            await UserFirestore.getUser(_repostPost!.postAccountId);
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

  static Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      var doc = await _firestoreInstance.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('ユーザー情報取得エラー: $e');
      return null;
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    try {
      //返信なら返信先のreply_postを削除する。
      if (widget.post.reply != null && widget.post.reply!.isNotEmpty) {
        await _firestoreInstance
            .collection('posts')
            .doc(widget.post.reply)
            .collection('reply_post')
            .doc(widget.post.postId)
            .delete();
      }

      //投稿の削除
      await _firestoreInstance
          .collection('posts')
          .doc(widget.post.postId)
          .delete();

      //ユーザーのポスト一覧からの削除
      await _firestoreInstance
          .collection('users')
          .doc(widget.post.postAccountId)
          .collection('my_posts')
          .doc(widget.post.postId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿を削除しました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿の削除に失敗しました')),
      );
    }
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

      List<Post> replyPosts = [];
      for (var doc in snapshot.docs) {
        var replyPostId = doc.id;
        var postSnapshot =
            await _firestoreInstance.collection('posts').doc(replyPostId).get();
        if (postSnapshot.exists) {
          var postDetailData = postSnapshot.data();
          if (postDetailData != null) {
            replyPosts.add(Post.fromMap(postDetailData));
          }
        }
      }

      return replyPosts;
    } catch (e) {
      print('サブコレクションの取得に失敗しました: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _replyCountNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ポストの詳細'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          // controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 返信元の投稿を表示するためのFutureBuilder
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
                          } else if (snapshot.hasError || !snapshot.hasData) {
                            return Text('エラーが発生しました。');
                          } else {
                            Account? postAccount = snapshot.data;

                            // リツイートの状態を管理するためのValueNotifierを初期化
                            ValueNotifier<bool> isRetweetedNotifier =
                                ValueNotifier<bool>(
                              false, // Firestoreからリツイートの状態を取得し初期化する
                            );

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // DividerWithCircle(),
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
                                                replyToPost.postId] ??
                                            ValueNotifier<int>(0),
                                        isFavoriteNotifier: ValueNotifier<bool>(
                                            _favoritePost
                                                .favoritePostsNotifier.value
                                                .contains(replyToPost.postId)),
                                        onFavoriteToggle: () {
                                          _favoritePost.toggleFavorite(
                                            replyToPost.postId,
                                            _favoritePost
                                                .favoritePostsNotifier.value
                                                .contains(replyToPost.postId),
                                          );
                                          _favoritePost.favoriteUsersNotifiers[
                                                  replyToPost.postId] ??=
                                              ValueNotifier<int>(0);
                                          _favoritePost
                                              .updateFavoriteUsersCount(
                                                  replyToPost.postId);
                                        },
                                        // リツイートの状態を渡す
                                        isRetweetedNotifier:
                                            isRetweetedNotifier,
                                        // リツイートの状態をトグルする処理
                                        onRetweetToggle: () {
                                          // ここにリツイートの状態をFirestoreに保存するロジックを追加する
                                          bool currentState =
                                              isRetweetedNotifier.value;
                                          isRetweetedNotifier.value =
                                              !currentState;
                                          // Firestoreでリツイートの情報を更新する処理
                                        },

                                        replyFlag: ValueNotifier<bool>(true),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                          builder: (context) =>
                              AccountPage(userId: widget.post.postAccountId),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        widget.postAccountImagePath,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.postAccountName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '@${widget.postAccountUserId}',
                        style: const TextStyle(color: Colors.grey),
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
                      if (widget.post.postAccountId == currentUserId)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.add),
                          onSelected: (String value) {
                            if (value == 'Option 1') _deletePost(context);
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem<String>(
                                value: 'Option 1',
                                child: Text(
                                  'ポストの削除',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'Option 2',
                                child: Text('Option 2'),
                              ),
                              PopupMenuItem<String>(
                                value: 'Option 3',
                                child: Text('Option 3'),
                              ),
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
                Text(
                  widget.post.content,
                  style: const TextStyle(fontSize: 18),
                ),
              const SizedBox(height: 10),

              if (widget.post.category == '漫画' &&
                  widget.post.mediaUrl != null &&
                  widget.post.mediaUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          SlideDirectionPageRoute(
                            page: FullScreenImagePage(
                              imageUrls: widget.post.mediaUrl!,
                              initialIndex: 0,
                            ),
                            isSwipeUp: true,
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          widget.post.mediaUrl![0],
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // メディアが複数ある場合、残りの枚数を表示
                    if (widget.post.mediaUrl!.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+${widget.post.mediaUrl!.length - 1}', // 残りの枚数
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ]
              // 漫画以外の場合、メディアの枚数に応じて表示を変更
              else if (widget.post.mediaUrl != null &&
                  widget.post.mediaUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),

                // メディアが1枚の場合
                if (widget.post.mediaUrl!.length == 1) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        SlideDirectionPageRoute(
                          page: FullScreenImagePage(
                            imageUrls: widget.post.mediaUrl!,
                            initialIndex: 0,
                          ),
                          isSwipeUp: true,
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        widget.post.mediaUrl![0],
                        width: MediaQuery.of(context).size.width * 0.9, // 大きく表示
                        height: 250, // 大きめの高さ
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ]

                // メディアが2枚以上の場合はグリッドで表示
                else ...[
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: widget.post.mediaUrl!.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final mediaUrl = widget.post.mediaUrl![index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            SlideDirectionPageRoute(
                              page: FullScreenImagePage(
                                imageUrls: widget.post.mediaUrl!,
                                initialIndex: index,
                              ),
                              isSwipeUp: true,
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            mediaUrl,
                            width: MediaQuery.of(context).size.width *
                                0.9, // 適切なサイズに調整
                            height: MediaQuery.of(context).size.height * 0.5,
                            fit: BoxFit.cover, // 画面のサイズに合わせて拡大
                          ),
                        ),
                      );
                    },
                  ),
                ],

                if (_repostPost != null && _repostPostAccount != null)
                  GestureDetector(
                    onTap: () {
                      // タップされた RepostItem の詳細ページに遷移
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailPage(
                            post: _repostPost!,
                            postAccountName: _repostPostAccount!.name,
                            postAccountUserId: _repostPostAccount!.userId,
                            postAccountImagePath: _repostPostAccount!.imagePath,
                            favoriteUsersNotifier: ValueNotifier<int>(0),
                            isFavoriteNotifier: ValueNotifier<bool>(false),
                            onFavoriteToggle: () {},
                            isRetweetedNotifier: ValueNotifier<bool>(false),
                            onRetweetToggle: () {},
                            replyFlag: ValueNotifier<bool>(false),
                          ),
                        ),
                      );
                    },
                    child: RepostItem(
                      repostPost: _repostPost!,
                      repostPostAccount: _repostPostAccount!,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: widget.favoriteUsersNotifier,
                          builder: (context, value, child) {
                            return Text((value).toString());
                          },
                        ),
                        const SizedBox(width: 5),
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.isFavoriteNotifier,
                          builder: (context, isFavorite, child) {
                            return GestureDetector(
                              onTap: () {
                                widget.onFavoriteToggle();
                                widget.isFavoriteNotifier.value =
                                    !widget.isFavoriteNotifier.value;
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
                        // リツイート数を表示
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.post.postId)
                              .collection('repost')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              // データがない場合は0を表示
                              return Text('0');
                            }
                            // repostサブコレクションのドキュメント数を表示
                            final repostCount = snapshot.data!.docs.length;
                            return Text(repostCount.toString());
                          },
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.isRetweetedNotifier,
                          builder: (context, isRetweeted, child) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RepostPage(post: widget.post),
                                  ),
                                );
                              },
                              child: Icon(
                                isRetweeted
                                    ? Icons.repeat
                                    : Icons.repeat_outlined,
                                color: isRetweeted ? Colors.blue : Colors.grey,
                              ),
                            );
                          },
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
                                    builder: (context) =>
                                        ReplyPage(post: widget.post),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.comment),
                            ),
                          ],
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.share),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RepostListPage(postId: widget.post.postId),
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
                      return Text('返信ポストはありません。');
                    } else {
                      List<Post> replyPosts = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (replyPosts.isNotEmpty) ...[
                            Divider(thickness: 1.0),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
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
                              future: UserFirestore.getUser(
                                  replyPost.postAccountId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return CircularProgressIndicator();
                                } else if (snapshot.hasError ||
                                    !snapshot.hasData) {
                                  return Text('エラーが発生しました。');
                                } else {
                                  Account? postAccount = snapshot.data;
                                  // リツイートの状態を管理するためのValueNotifierを初期化
                                  ValueNotifier<bool> isRetweetedNotifier =
                                      ValueNotifier<bool>(
                                    false, // Firestoreからリツイートの状態を取得し初期化する
                                  );
                                  return PostItemWidget(
                                    post: replyPost,
                                    postAccount: postAccount!,
                                    favoriteUsersNotifier:
                                        _favoritePost.favoriteUsersNotifiers[
                                                replyPost.postId] ??
                                            ValueNotifier<int>(0),
                                    isFavoriteNotifier: ValueNotifier<bool>(
                                      _favoritePost.favoritePostsNotifier.value
                                          .contains(replyPost.postId),
                                    ),
                                    onFavoriteToggle: () {
                                      _favoritePost.toggleFavorite(
                                        replyPost.id,
                                        _favoritePost
                                            .favoritePostsNotifier.value
                                            .contains(replyPost.postId),
                                      );
                                      _favoritePost.favoriteUsersNotifiers[
                                              replyPost.postId] ??=
                                          ValueNotifier<int>(0);
                                      _favoritePost.updateFavoriteUsersCount(
                                          replyPost.postId);
                                    },
                                    isRetweetedNotifier: isRetweetedNotifier,
                                    onRetweetToggle: () {
                                      bool currentState =
                                          isRetweetedNotifier.value;
                                      isRetweetedNotifier.value = !currentState;
                                      // Firestoreでリツイートの情報を更新する処理
                                    },
                                    replyFlag: ValueNotifier<bool>(false),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 0),
    );
  }
}
