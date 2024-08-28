import 'package:cloud_firestore/cloud_firestore.dart';
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
  final VoidCallback onFavoriteToggle;

  const PostItemWidget({
    required this.post,
    required this.postAccount,
    required this.isFavoriteNotifier,
    required this.onFavoriteToggle,
    required this.favoriteUsersNotifier,
    Key? key,
  }) : super(key: key);

  @override
  _PostItemWidgetState createState() => _PostItemWidgetState();
}

class _PostItemWidgetState extends State<PostItemWidget> {
  final ValueNotifier<int> _replyCountNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _fetchReplyCount();
  }

  void _fetchReplyCount() {
    // post.idが存在しない場合はpost.postIdを使用する
    String documentId =
        widget.post.id.isNotEmpty ? widget.post.id : widget.post.postId;

    FirebaseFirestore.instance
        .collection('posts')
        .doc(documentId)
        .collection('reply_post')
        .snapshots()
        .listen((snapshot) {
      _replyCountNotifier.value = snapshot.size; // ドキュメント数をカウントして更新
    });
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  widget.postAccount.imagePath,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '@${widget.postAccount.userId}',
                            style: const TextStyle(color: Colors.grey),
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
                      const SizedBox(height: 10),
                      if (widget.post.mediaUrl != null)
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.post.mediaUrl!,
                              width: MediaQuery.of(context).size.width * 0.9,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
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
                      ValueListenableBuilder<int>(
                        valueListenable: _replyCountNotifier,
                        builder: (context, replyCount, child) {
                          return Row(
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.comment),
                              ),
                              Text(replyCount.toString()), // ここに返信の数を表示
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
      ),
    );
  }
}
