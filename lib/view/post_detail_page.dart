import 'package:cymva/model/account.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/poat/post_item_widget.dart';
import 'package:cymva/view/reply_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:video_player/video_player.dart';
import 'package:cymva/view/full_screen_image.dart';
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

  const PostDetailPage({
    Key? key,
    required this.post,
    required this.postAccountName,
    required this.postAccountUserId,
    required this.postAccountImagePath,
    required this.favoriteUsersNotifier,
    required this.isFavoriteNotifier,
    required this.onFavoriteToggle,
  }) : super(key: key);

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Future<List<Post>> _replyPostsFuture;
  Future<Post?>? _replyToPostFuture;
  final FavoritePost _favoritePost = FavoritePost();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _userRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _replyPostsFuture = getReplyPosts(widget.post.id);
    if (widget.post.reply != null && widget.post.reply!.isNotEmpty) {
      // 投稿が他の投稿への返信である場合にその返信元を取得
      _replyToPostFuture = getPostById(widget.post.reply!);
    }

    // ウィジェットのレンダリングが完了した後にスクロールする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ユーザー情報のウィジェットの位置までスクロール
      Scrollable.ensureVisible(
        _userRowKey.currentContext!,
        duration: Duration(milliseconds: 500), // スクロールのアニメーション時間
        curve: Curves.easeInOut, // スクロールのアニメーションカーブ
      );
    });
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
            .doc(widget.post.id)
            .delete();
      }

      //投稿の削除
      await _firestoreInstance.collection('posts').doc(widget.post.id).delete();

      //ユーザーのポスト一覧からの削除
      await _firestoreInstance
          .collection('users')
          .doc(widget.post.postAccountId)
          .collection('my_posts')
          .doc(widget.post.id)
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

  Future<List<Post>> getReplyPosts(String postId) async {
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
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ポストの詳細'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
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
                            return PostItemWidget(
                              post: replyToPost,
                              postAccount: postAccount!,
                              favoriteUsersNotifier:
                                  _favoritePost.favoriteUsersNotifiers[
                                          replyToPost.postId] ??
                                      ValueNotifier<int>(0),
                              isFavoriteNotifier: ValueNotifier<bool>(
                                  _favoritePost.favoritePostsNotifier.value
                                      .contains(replyToPost.postId)),
                              onFavoriteToggle: () {
                                _favoritePost.toggleFavorite(
                                  replyToPost.id,
                                  _favoritePost.favoritePostsNotifier.value
                                      .contains(replyToPost.postId),
                                );
                                _favoritePost.favoriteUsersNotifiers[replyToPost
                                    .postId] ??= ValueNotifier<int>(0);
                                _favoritePost.updateFavoriteUsersCount(
                                    replyToPost.postId);
                              },
                            );
                          }
                        },
                      );
                    }
                  },
                ),
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
              const SizedBox(height: 10),
              Text(
                DateFormat('yyyy/M/d')
                    .format(widget.post.createdTime!.toDate()),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Text(widget.post.content),
              const SizedBox(height: 10),
              if (widget.post.isVideo)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoPlayer(VideoPlayerController.networkUrl(
                      Uri.parse(widget.post.mediaUrl!))),
                )
              else if (widget.post.mediaUrl != null)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImagePage(
                            imageUrl: widget.post.mediaUrl!),
                      ),
                    );
                  },
                  child: Container(
                    constraints: BoxConstraints(maxHeight: 400),
                    child: Image.network(
                      widget.post.mediaUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
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
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.comment),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReplyPage(post: widget.post),
                        ),
                      );
                    },
                    icon: const Icon(Icons.reply), // 返信ボタン
                  ),
                ],
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
                                      _favoritePost.favoritePostsNotifier.value
                                          .contains(replyPost.postId),
                                    );
                                    _favoritePost.favoriteUsersNotifiers[
                                            replyPost.postId] ??=
                                        ValueNotifier<int>(0);
                                    _favoritePost.updateFavoriteUsersCount(
                                        replyPost.postId);
                                  },
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
    );
  }
}
