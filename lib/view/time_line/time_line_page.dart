import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/float_bottom.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/view/account/account_page.dart';
// import 'package:video_player/video_player.dart';
import 'package:cymva/view/full_screen_image.dart';
import 'package:cymva/view/post_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TimeLinePage extends StatefulWidget {
  const TimeLinePage({super.key});

  @override
  State<TimeLinePage> createState() => _TimeLineState();
}

class _TimeLineState extends State<TimeLinePage> {
  Future<List<String>>? _favoritePostsFuture;
  final ValueNotifier<Set<String>> _favoritePostsNotifier =
      ValueNotifier<Set<String>>({});
  final Map<String, ValueNotifier<int>> _favoriteUsersNotifiers = {};

  @override
  void initState() {
    super.initState();
    _favoritePostsFuture = _getFavoritePosts(); // ユーザーのfavorite_postsを取得
  }

  Future<List<String>> _getFavoritePosts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final favoritePostsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorite_posts')
        .get();

    final favoritePosts =
        favoritePostsSnapshot.docs.map((doc) => doc.id).toSet();
    _favoritePostsNotifier.value = favoritePosts;
    return favoritePosts.toList();
  }

  Future<void> _toggleFavorite(String postId, isFavorite) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return;

    final favoritePostsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorite_posts');

    final favoriteUsersCollection = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('favorite_users');

    if (isFavorite == true) {
      await favoritePostsCollection.doc(postId).delete();
      await favoriteUsersCollection.doc(userId).delete();
    } else {
      await favoritePostsCollection.doc(postId).set({});
      await favoriteUsersCollection.doc(userId).set({});
    }

    final updatedFavorites = _favoritePostsNotifier.value.toSet();
    if (updatedFavorites.contains(postId)) {
      updatedFavorites.remove(postId);
    } else {
      updatedFavorites.add(postId);
    }
    _favoritePostsNotifier.value = updatedFavorites;

    // `favoriteUsersCount` を更新
    await _updateFavoriteUsersCount(postId);
  }

  Future<void> _updateFavoriteUsersCount(String postId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('favorite_users')
        .get();

    // `_favoriteUsersNotifiers` に存在しない場合は作成
    _favoriteUsersNotifiers[postId] ??= ValueNotifier<int>(0);

    // ドキュメント数をセット
    _favoriteUsersNotifiers[postId]!.value = snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('タイムライン'),
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: PostFirestore.posts
            .orderBy('created_time', descending: true)
            .snapshots(),
        builder: (context, postSnapshot) {
          if (postSnapshot.hasData) {
            List<String> postAccountIds = [];
            postSnapshot.data!.docs.forEach((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              if (!postAccountIds.contains(data['post_account_id'])) {
                postAccountIds.add(data['post_account_id']);
              }
            });
            return FutureBuilder<Map<String, Account>?>(
              future: UserFirestore.getPostUserMap(postAccountIds),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasData &&
                    userSnapshot.connectionState == ConnectionState.done) {
                  return FutureBuilder<List<String>>(
                    future: _favoritePostsFuture,
                    builder: (context, favoriteSnapshot) {
                      if (favoriteSnapshot.connectionState ==
                              ConnectionState.done &&
                          favoriteSnapshot.hasData) {
                        return ListView.builder(
                          itemCount: postSnapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            Map<String, dynamic> data =
                                postSnapshot.data!.docs[index].data()
                                    as Map<String, dynamic>;
                            Post post = Post(
                              id: postSnapshot.data!.docs[index].id,
                              content: data['content'],
                              postAccountId: data['post_account_id'],
                              createdTime: data['created_time'],
                              mediaUrl: data['media_url'],
                              isVideo: data['is_video'] ?? false,
                            );
                            Account postAccount =
                                userSnapshot.data![post.postAccountId]!;

                            // 投稿ごとの favoriteUsersCount を取得
                            _favoriteUsersNotifiers[post.id] ??=
                                ValueNotifier<int>(0);
                            _updateFavoriteUsersCount(post.id);

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailPage(
                                      post: post,
                                      postAccountName: postAccount.name,
                                      postAccountUserId: postAccount.userId,
                                      postAccountImagePath:
                                          postAccount.imagePath,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: index == 0
                                      ? const Border(
                                          top: BorderSide(
                                              color: Colors.grey, width: 0),
                                          bottom: BorderSide(
                                              color: Colors.grey, width: 0),
                                        )
                                      : const Border(
                                          bottom: BorderSide(
                                              color: Colors.grey, width: 0),
                                        ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 15),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AccountPage(
                                                userId: post.postAccountId),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.network(
                                          postAccount.imagePath,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    postAccount.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Text(
                                                    '@${postAccount.userId}',
                                                    style: const TextStyle(
                                                        color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                              Text(DateFormat('yyyy/M/d')
                                                  .format(post.createdTime!
                                                      .toDate())),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(post.content),
                                              const SizedBox(height: 10),
                                              if (post.mediaUrl != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            FullScreenImagePage(
                                                                imageUrl: post
                                                                    .mediaUrl!),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    constraints:
                                                        const BoxConstraints(
                                                            maxHeight: 400),
                                                    child: Image.network(
                                                      post.mediaUrl!,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                    ),
                                                  ),
                                                )
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              ValueListenableBuilder<
                                                  Set<String>>(
                                                valueListenable:
                                                    _favoritePostsNotifier,
                                                builder: (context,
                                                    favoritePosts, child) {
                                                  final isFavorite =
                                                      favoritePosts
                                                          .contains(post.id);
                                                  return Row(
                                                    children: [
                                                      if (isFavorite)
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.star,
                                                            size: 20.0,
                                                            color:
                                                                Color.fromARGB(
                                                                    255,
                                                                    255,
                                                                    192,
                                                                    31),
                                                          ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          onPressed: () async {
                                                            await _toggleFavorite(
                                                                post.id,
                                                                isFavorite);
                                                          },
                                                        )
                                                      else
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.star_outline,
                                                            size: 20.0,
                                                            color:
                                                                Color.fromARGB(
                                                                    255,
                                                                    153,
                                                                    153,
                                                                    155),
                                                          ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          onPressed: () async {
                                                            await _toggleFavorite(
                                                                post.id,
                                                                isFavorite);
                                                          },
                                                        ),
                                                      ValueListenableBuilder<
                                                          int>(
                                                        valueListenable:
                                                            _favoriteUsersNotifiers[
                                                                post.id]!,
                                                        builder: (context,
                                                            favoriteUsersCount,
                                                            child) {
                                                          return Text(
                                                              '$favoriteUsersCount');
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                },
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
                          },
                        );
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: const FloatBottom(),
      bottomNavigationBar: const NavigationBarPage(
        selectedIndex: 0,
      ),
    );
  }
}
