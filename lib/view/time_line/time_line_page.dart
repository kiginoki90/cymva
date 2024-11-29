import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cymva/view/post_item/post_item_widget.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/favorite_post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'viewModel.dart';

class TimeLinePage extends ConsumerStatefulWidget {
  final String userId;
  const TimeLinePage({
    super.key,
    required this.userId,
  });

  @override
  _TimeLinePageState createState() => _TimeLinePageState();
}

class _TimeLinePageState extends ConsumerState<TimeLinePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(viewModelProvider).getPosts(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(viewModelProvider);
    final _favoritePost = FavoritePost();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => model.getPosts(widget.userId),
        child: model.stackedPostList.isEmpty
            ? const Center(child: Text("まだ投稿がありません"))
            : ListView.builder(
                controller: _scrollController,
                itemCount: model.stackedPostList.length + 1,
                itemBuilder: (context, int index) {
                  if (index == model.stackedPostList.length) {
                    return model.currentPostList.isNotEmpty
                        ? TextButton(
                            onPressed: () async {
                              final currentScrollPosition =
                                  _scrollController.position.pixels;
                              await model.getPostsNext(widget.userId);
                              _scrollController.jumpTo(currentScrollPosition);
                            },
                            child: const Text("もっと読み込む"),
                          )
                        : const Center(child: Text("結果は以上です"));
                  }

                  if (index >= model.stackedPostList.length) {
                    return Container(); // インデックスが範囲外の場合は空のコンテナを返す
                  }

                  final postDoc = model.stackedPostList[index];
                  final post = Post.fromDocument(postDoc);
                  final postAccount = model.postUserMap[post.postAccountId];

                  if (postAccount == null || postAccount.lockAccount) {
                    return Container(); // lockAccountがtrueの場合は表示をスキップ
                  }

                  _favoritePost.favoriteUsersNotifiers[post.id] ??=
                      ValueNotifier<int>(0);
                  _favoritePost.updateFavoriteUsersCount(post.id);

                  return PostItemWidget(
                    key: PageStorageKey(post.id),
                    post: post,
                    postAccount: postAccount,
                    favoriteUsersNotifier:
                        _favoritePost.favoriteUsersNotifiers[post.id]!,
                    isFavoriteNotifier: ValueNotifier<bool>(
                      model.favoritePosts.contains(post.id),
                    ),
                    onFavoriteToggle: () => _favoritePost.toggleFavorite(
                      post.id,
                      model.favoritePosts.contains(post.id),
                    ),
                    replyFlag: ValueNotifier<bool>(false),
                    userId: widget.userId,
                  );
                },
              ),
      ),
    );
  }
}
