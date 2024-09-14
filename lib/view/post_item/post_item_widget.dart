import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/reply_page.dart';
import 'package:cymva/view/repost_item.dart';
import 'package:cymva/view/repost_page.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:intl/intl.dart';
import 'package:cymva/view/post_item/post_detail_page.dart';
import 'package:cymva/view/post_item/full_screen_image.dart';
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

  const PostItemWidget({
    required this.post,
    required this.postAccount,
    required this.isFavoriteNotifier,
    required this.onFavoriteToggle,
    required this.favoriteUsersNotifier,
    required this.isRetweetedNotifier,
    required this.onRetweetToggle,
    required this.replyFlag,
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
                                  userId: widget.post.postAccountId),
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
                                    Text(
                                      widget.postAccount.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '@${widget.postAccount.userId}',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                                Text(DateFormat('yyyy/M/d')
                                    .format(widget.post.createdTime!.toDate())),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.post.category == '俳句・短歌')
                                  buildVerticalText(widget.post.content)
                                else
                                  Text(
                                    widget.post.content,
                                    style: const TextStyle(fontSize: 18),
                                  ),

                                // カテゴリーが "漫画" の場合、最初のメディアだけ表示し、残りの枚数を表示
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
                                                imageUrls:
                                                    widget.post.mediaUrl!,
                                                initialIndex: 0,
                                              ),
                                              isSwipeUp: true,
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: Image.network(
                                            widget.post.mediaUrl![0],
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.8,
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
                                              color:
                                                  Colors.black.withOpacity(0.6),
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                // 漫画以外の場合、複数のメディアをグリッドで表示
                                else if (widget.post.mediaUrl != null &&
                                    widget.post.mediaUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: widget.post.mediaUrl!.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                    ),
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final mediaUrl =
                                          widget.post.mediaUrl![index];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            SlideDirectionPageRoute(
                                              page: FullScreenImagePage(
                                                imageUrls:
                                                    widget.post.mediaUrl!,
                                                initialIndex: index,
                                              ),
                                              isSwipeUp: true,
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          child: Image.network(
                                            mediaUrl,
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.4,
                                            height: 150,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                            if (_repostPost != null &&
                                _repostPostAccount != null)
                              RepostItem(
                                repostPost: _repostPost!,
                                repostPostAccount: _repostPostAccount!,
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
                                                        post: widget.post),
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
                                                    post: widget.post),
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

  Widget buildVerticalText(String content) {
    List<String> lines = content.split('\n');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
      crossAxisAlignment: CrossAxisAlignment.start, // 上寄せ
      children: lines
          .map((line) {
            List<String> characters = line.split('');

            // 各文字を縦に配置
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0), // 行の間隔を広げる
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: characters.map((char) {
                  return Text(
                    char,
                    style: const TextStyle(fontSize: 15, height: 1.1),
                  );
                }).toList(),
              ),
            );
          })
          .toList()
          .reversed
          .toList(), // 右から左に表示するため逆順に
    );
  }
}
