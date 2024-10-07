import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/post_item_utils.dart';
import 'package:cymva/view/post_item/link_text.dart';
import 'package:cymva/view/post_item/media_display_widget.dart';
import 'package:cymva/view/post_item/post_visibility_widget.dart';
import 'package:cymva/view/reply_page.dart';
import 'package:cymva/view/repost_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:intl/intl.dart';
import 'package:cymva/view/post_item/post_detail_page.dart';
import 'package:cymva/view/account/account_page.dart';

class PostItemWidget extends StatefulWidget {
  final Post post;
  final Account postAccount;
  final ValueNotifier<int> favoriteUsersNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final ValueNotifier<bool> isRetweetedNotifier;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onRetweetToggle;
  final ValueNotifier<bool> replyFlag;
  final String userId;

  const PostItemWidget({
    required this.post,
    required this.postAccount,
    required this.isFavoriteNotifier,
    required this.onFavoriteToggle,
    required this.favoriteUsersNotifier,
    required this.isRetweetedNotifier,
    required this.onRetweetToggle,
    required this.replyFlag,
    required this.userId,
    Key? key,
  }) : super(key: key);

  @override
  _PostItemWidgetState createState() => _PostItemWidgetState();
}

class _PostItemWidgetState extends State<PostItemWidget> {
  final ValueNotifier<int> _replyCountNotifier = ValueNotifier<int>(0);
  Post? _repostPost;
  Account? _repostPostAccount;

  @override
  void initState() {
    super.initState();
    _fetchReplyCount();
    _fetchRepostData();
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

  Future<void> _fetchRepostData() async {
    if (widget.post.repost != null && widget.post.repost!.isNotEmpty) {
      try {
        // Fetch the original post data from Firestore
        DocumentSnapshot repostSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.repost)
            .get();

        if (repostSnapshot.exists) {
          Post repostPost = Post.fromDocument(repostSnapshot);
          _repostPost = repostPost;

          DocumentSnapshot repostAccountSnapshot = await FirebaseFirestore
              .instance
              .collection('users')
              .doc(repostPost.postAccountId)
              .get();

          if (repostAccountSnapshot.exists) {
            _repostPostAccount = Account.fromDocument(repostAccountSnapshot);
          }

          if (mounted) {
            setState(() {});
          }
        }
      } catch (e) {
        // エラーハンドリング
        print('Error fetching repost data: $e');
      }
    }
  }

  @override
  void dispose() {
    _replyCountNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(
                post: widget.post,
                postAccountName: widget.postAccount.name,
                postAccountUserId: widget.postAccount.userId,
                postAccountImagePath: widget.postAccount.imagePath,
                favoriteUsersNotifier: widget.favoriteUsersNotifier,
                isFavoriteNotifier: widget.isFavoriteNotifier,
                onFavoriteToggle: widget.onFavoriteToggle,
                isRetweetedNotifier: widget.isRetweetedNotifier,
                onRetweetToggle: widget.onRetweetToggle,
                replyFlag: widget.replyFlag,
                userId: widget.userId,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          child: Stack(
            children: [
              if (widget.replyFlag.value == true)
                Positioned(
                  top: 40,
                  bottom: 0,
                  left: 10,
                  child: Container(
                    width: 1,
                    color: Colors.grey,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            widget.postAccount.imagePath,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (widget.postAccount.lockAccount)
                                          const Padding(
                                            padding: const EdgeInsets.only(
                                                right: 4.0),
                                            child: const Icon(
                                              Icons.lock, // 南京錠のアイコン
                                              size: 16, // アイコンのサイズ
                                              color: Colors.grey, // アイコンの色
                                            ),
                                          ),
                                        Text(
                                          widget.postAccount.name.length > 13
                                              ? '${widget.postAccount.name.substring(0, 13)}...' // 15文字を超える場合は切り捨てて「...」を追加
                                              : widget.postAccount.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '@${widget.postAccount.userId.length > 25 ? '${widget.postAccount.userId.substring(0, 25)}...' : widget.postAccount.userId}',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    if (widget.post.category != null &&
                                        widget.post.category!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 3),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 0.7,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
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
                                    Text(DateFormat('yyyy/M/d').format(
                                        widget.post.createdTime!.toDate())),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.post.category == '俳句・短歌')
                                    buildVerticalText(widget.post.content)
                                  else
                                    LinkText(
                                        text: widget.post.content,
                                        userId: widget.userId),
                                ]),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                MediaDisplayWidget(
                                  mediaUrl: widget.post.mediaUrl,
                                  category: widget.post.category ?? '',
                                ),
                              ],
                            ),
                            if (_repostPost != null &&
                                _repostPostAccount != null)
                              //引用の表示
                              PostVisibilityWidget(
                                postAccount: _repostPostAccount!,
                                userId: widget.userId,
                                repostPost: _repostPost!,
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    ValueListenableBuilder<int>(
                                      valueListenable:
                                          widget.favoriteUsersNotifier,
                                      builder: (context, value, child) {
                                        return Text(value.toString());
                                      },
                                    ),
                                    const SizedBox(width: 5),
                                    ValueListenableBuilder<bool>(
                                      valueListenable:
                                          widget.isFavoriteNotifier,
                                      builder: (context, isFavorite, child) {
                                        return GestureDetector(
                                          onTap: () {
                                            widget.onFavoriteToggle();
                                            widget.isFavoriteNotifier.value =
                                                !widget
                                                    .isFavoriteNotifier.value;
                                          },
                                          child: Icon(
                                            isFavorite
                                                ? Icons.star
                                                : Icons.star_outline,
                                            color: isFavorite
                                                ? const Color.fromARGB(
                                                    255, 255, 183, 59)
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
                                          .doc(widget.post.postId.isNotEmpty
                                              ? widget.post.postId
                                              : widget.post.id)
                                          .collection('repost')
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return Text('0');
                                        }
                                        final repostCount =
                                            snapshot.data!.docs.length;
                                        return Text(repostCount.toString());
                                      },
                                    ),
                                    ValueListenableBuilder<bool>(
                                      valueListenable:
                                          widget.isRetweetedNotifier,
                                      builder: (context, isRetweeted, child) {
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RepostPage(
                                                        post: widget.post,
                                                        userId: widget.userId),
                                              ),
                                            );
                                          },
                                          child: Icon(
                                            isRetweeted
                                                ? Icons.repeat
                                                : Icons.repeat_outlined,
                                            color: isRetweeted
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 5),
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
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.share),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ));
  }
}
