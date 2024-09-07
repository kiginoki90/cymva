import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/reply_page.dart';
import 'package:cymva/view/repost_item.dart';
import 'package:cymva/view/repost_page.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/model/account.dart';
import 'package:intl/intl.dart';
import 'package:cymva/view/post_detail_page.dart';
import 'package:cymva/view/full_screen_image.dart';
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

        setState(() {});
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
                                Text(widget.post.content),
                                if (widget.post.mediaUrl != null) ...[
                                  SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FullScreenImagePage(
                                            imageUrl: widget.post.mediaUrl!,
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        widget.post.mediaUrl!,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.9,
                                        height: 180,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
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
                                                ? Color.fromARGB(
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
                                          .doc(widget.post.postId)
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
}
