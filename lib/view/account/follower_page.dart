import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';

class FollowerPage extends StatefulWidget {
  final String userId;

  const FollowerPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FollowerPageState createState() => _FollowerPageState();
}

class _FollowerPageState extends State<FollowerPage> {
  final int _limit = 15;
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  List<DocumentSnapshot> _followDocs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchFollowDocs();

    // スクロールコントローラーのリスナーを追加
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge) {
        bool isBottom = _scrollController.position.pixels != 0;
        if (isBottom) {
          _fetchFollowDocs();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchFollowDocs() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collectionGroup('follow')
        .where('user_id', isEqualTo: widget.userId)
        .limit(_limit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    QuerySnapshot querySnapshot = await query.get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _lastDocument = querySnapshot.docs.last;
        _followDocs.addAll(querySnapshot.docs);
        _hasMore = querySnapshot.docs.length == _limit;
      });
    } else {
      setState(() {
        _hasMore = false;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('フォロワー')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _followDocs.clear();
            _lastDocument = null;
            _hasMore = true;
          });
          await _fetchFollowDocs();
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _followDocs.length + 1,
          itemBuilder: (context, index) {
            if (index == _followDocs.length) {
              if (_isLoading) {
                return Column(
                  children: [
                    SizedBox(height: 20), // 縦幅を追加
                    const Center(child: Text('読み込み中...')),
                    SizedBox(height: 20), // 縦幅を追加
                  ],
                );
              } else if (!_hasMore) {
                return const Center(child: Text('結果は以上です'));
              } else {
                return const SizedBox(height: 100);
              }
            }

            final followDoc = _followDocs[index];
            final followerId = followDoc.reference.parent.parent!.id;

            // フォロワーのユーザーデータを取得
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(followerId)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasError) {
                  return const Center(child: Text('エラー'));
                }

                final userData =
                    userSnapshot.data?.data() as Map<String, dynamic>?;

                // userDataがnullまたは空の場合はスキップ
                if (userData == null || userData.isEmpty) {
                  return const SizedBox.shrink(); // 空のウィジェットを返す
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NavigationBarPage(
                                  userId: followerId, firstIndex: 1),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            userData['image_path'] ??
                                'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                            width: 40,
                            height: 40,
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
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NavigationBarPage(
                                    userId: followerId, firstIndex: 1),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      userData['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '@${userData['user_id']}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userData['self_introduction'] ?? '',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black),
                                maxLines: 2, // 最大2行まで表示
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
