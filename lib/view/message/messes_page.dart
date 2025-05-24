import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/model/account.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/book_mark.dart';
import 'package:cymva/utils/firestore/users.dart';
import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/post_item/post_detail_page.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MessesPage extends StatefulWidget {
  final String userId;

  const MessesPage({super.key, required this.userId});

  @override
  State<MessesPage> createState() => _MessesPageState();
}

class _MessesPageState extends State<MessesPage> {
  List<Map<String, dynamic>> notifications = [];
  final FlutterSecureStorage storage = FlutterSecureStorage();
  final BookmarkPost _bookmarkPost = BookmarkPost();
  String? _imageUrl;
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 15;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _deleteOldMessages(); // 古いメッセージを削除
    _fetchNotifications();
    _getImageUrl();
    _markNotificationsAsRead();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() async {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoading) {
      await _fetchNotifications();
    }
  }

//通知を既読にする
  Future<void> _markNotificationsAsRead() async {
    final firestore = FirebaseFirestore.instance;

    if (widget.userId != null) {
      QuerySnapshot messageSnapshot = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('message')
          .get();

      for (var doc in messageSnapshot.docs) {
        await firestore
            .collection('users')
            .doc(widget.userId)
            .collection('message')
            .doc(doc.id)
            .update({'isRead': true});
      }
    }
  }

  Future<void> _deleteOldMessages() async {
    final firestore = FirebaseFirestore.instance;
    final currentUserId = widget.userId;
    final now = Timestamp.now();
    final MonthsAgo = Timestamp.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch - 4 * 30 * 24 * 60 * 60 * 1000,
    );

    final snapshot = await firestore
        .collection('users')
        .doc(currentUserId)
        .collection('message')
        .get();

    for (var doc in snapshot.docs) {
      final messageRead = doc.data().containsKey('message_read')
          ? doc['message_read'] as Timestamp?
          : null;
      final messageCreated = doc.data().containsKey('timestamp')
          ? doc['timestamp'] as Timestamp?
          : null;

      if ((messageRead != null && now.seconds - messageRead.seconds > 86400) ||
          (messageCreated != null &&
              messageCreated.seconds < MonthsAgo.seconds)) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> _fetchNotifications() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    // 現在のユーザーのIDを取得
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('message')
        .orderBy('timestamp', descending: true)
        .limit(_limit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    QuerySnapshot querySnapshot = await query.get();

    if (querySnapshot.docs.isNotEmpty) {
      // 取得したデータをリストに格納
      final List<Map<String, dynamic>> tempNotifications =
          querySnapshot.docs.map((doc) {
        final data = doc.data()
            as Map<String, dynamic>?; // doc.data()を変数に格納し、nullチェックを行う
        return {
          'id': doc.id,
          'request_user': data?.containsKey('request_user') == true
              ? data!['request_user']
              : null,
          'message_type': data?['message_type'],
          'request_userId': data?.containsKey('request_userId') == true
              ? data!['request_userId']
              : null,
          'title': data?.containsKey('title') == true ? data!['title'] : null,
          'content':
              data?.containsKey('content') == true ? data!['content'] : null,
          'message_read': data?.containsKey('message_read') == true
              ? data!['message_read']
              : null,
          'timestamp': data?.containsKey('timestamp') == true
              ? data!['timestamp']
              : null,
          'postID':
              data?.containsKey('postID') == true ? data!['postID'] : null,
          'count': data?.containsKey('count') == true ? data!['count'] : 1,
          'bold': data?.containsKey('bold') == true ? data!['bold'] : false,
        };
      }).toList();

      // 非同期でユーザー情報を取得
      for (var notification in tempNotifications) {
        final userId = notification['request_user'];
        try {
          final user = await UserFirestore.getUser(userId); // 非同期でユーザー情報を取得
          notification['user'] = user; // ユーザー情報を通知に追加
        } catch (e) {
          notification['user'] = null; // エラーが発生した場合はnullを使用
        }
      }

      // ソート処理
      tempNotifications.sort((a, b) {
        if (a['message_type'] == 4 && b['message_type'] != 4) {
          return -1; // a を b の前に
        } else if (a['message_type'] != 4 && b['message_type'] == 4) {
          return 1; // b を a の前に
        } else {
          return b['timestamp'].compareTo(a['timestamp']); // timestamp の新しい順
        }
      });

      setState(() {
        _lastDocument = querySnapshot.docs.last;
        notifications.addAll(tempNotifications);
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

    // デバッグログを追加
    print('Notifications fetched: ${notifications.length}');
  }

  // フォロー依頼を許可する処理
  Future<void> _acceptFollowRequest(String requestUserId) async {
    try {
      final currentUserId = await storage.read(key: 'account_id');

      // フォロー依頼を許可した際に、相手のメッセージを削除
      final messageQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('message')
          .where('request_user', isEqualTo: requestUserId)
          .where('message_type', isEqualTo: 1)
          .get();

      // 該当するメッセージを削除
      for (var doc in messageQuerySnapshot.docs) {
        await doc.reference.delete();
      }

      // 自分のアカウントのフォロワーに相手を追加
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(currentUserId)
      //     .collection('followers')
      //     .doc(requestUserId)
      //     .set({'timestamp': FieldValue.serverTimestamp()});

      // 相手のアカウントのフォローに自分を追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(requestUserId)
          .collection('follow')
          .doc(currentUserId)
          .set({'followed_at': Timestamp.now(), 'user_id': currentUserId});

      // 相手のユーザーのmessagesサブコレクションにメッセージを追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(requestUserId)
          .collection('message')
          .add({
        'message_type': 2,
        'request_user': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'bold': true,
      });

      await _updateFollowRequests();

      navigateToPage(context, widget.userId, '3', false, false);

      // 成功メッセージを表示
      showTopSnackBar(context, 'フォロークエストを許可しました',
          backgroundColor: Colors.green);
    } catch (e) {
      showTopSnackBar(context, 'フォローリクエストの許可に失敗しました',
          backgroundColor: Colors.red);
      print(e);
    }
  }

  Future<void> _updateFollowRequests() async {
    await _fetchNotifications(); // 通知を再取得して更新
  }

  Future<void> _showDeleteConfirmationDialog(
      String requestUserId, String messageId) async {
    final currentUserId = await storage.read(key: 'account_id');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('確認'),
          content: Text('このメッセージを削除しますか？'),
          actions: [
            TextButton(
              child: Text('いいえ'),
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
            ),
            TextButton(
              child: Text('はい'),
              onPressed: () async {
                // Firestore からメッセージを削除する処理
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .collection('message')
                    .doc(messageId) // 削除するメッセージのID
                    .delete();

                // ダイアログを閉じる
                Navigator.of(context).pop();

                // 削除成功メッセージ
                showTopSnackBar(context, 'メッセージが削除されました',
                    backgroundColor: Colors.green);

                await _updateFollowRequests();

                navigateToPage(context, widget.userId, '3', false, false);

                // 通知リストの更新
                setState(() {
                  notifications.removeWhere((notification) =>
                      notification['message_id'] == messageId);
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAdminMessageDialog(String title, String content,
      String messageId, Timestamp timestamp, Timestamp? messageRead) async {
    final currentUserId = await storage.read(key: 'account_id');
    final now = Timestamp.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(height: 8),
              Text(content),
            ],
          ),
          actions: [
            TextButton(
              child: Text('閉じる'),
              onPressed: () async {
                // メッセージを既読にする（message_readがnullの場合のみ）
                if (messageRead == null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .collection('message')
                      .doc(messageId)
                      .update({'message_read': now});
                }

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToPostDetailPage(String postId) async {
    try {
      // postIDから投稿の情報を取得
      final postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();

      if (!postSnapshot.exists) {
        showTopSnackBar(context, '投稿が見つかりませんでした', backgroundColor: Colors.red);
      }

      // usersコレクションからユーザーの情報を取得
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final userData = userSnapshot.data();

      if (userData == null) {
        showTopSnackBar(context, 'ユーザーが見つかりませんでした',
            backgroundColor: Colors.red);
      }

      final post = Post.fromDocument(postSnapshot);
      final postAccount = Account.fromDocument(userSnapshot);

      _bookmarkPost.bookmarkUsersNotifiers[post.id] ??= ValueNotifier<int>(0);
      _bookmarkPost.updateBookmarkUsersCount(post.id);

      // 投稿詳細ページへ遷移
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailPage(
            post: post,
            postAccount: postAccount,
            replyFlag: ValueNotifier<bool>(false),
            userId: widget.userId,
            bookmarkUsersNotifier:
                _bookmarkPost.bookmarkUsersNotifiers[post.id]!,
            isBookmarkedNotifier: ValueNotifier<bool>(
              _bookmarkPost.bookmarkPostsNotifier.value.contains(post.id),
            ),
          ),
        ),
      );
    } catch (e) {
      showTopSnackBar(context, '投稿が見つかりませんでした', backgroundColor: Colors.red);
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final String formattedDate =
        "${dateTime.year}-${dateTime.month}-${dateTime.day}";
    final String formattedTime =
        "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
    return "$formattedDate $formattedTime";
  }

  Future<void> _getImageUrl() async {
    // FirestoreからURLを取得
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('setting')
        .doc('AppBarIMG')
        .get();
    String? imageUrl = doc.data()?['MessesPage'];
    if (imageUrl != null) {
      // Firebase StorageからダウンロードURLを取得
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      String downloadUrl = await ref.getDownloadURL();
      setState(() {
        _imageUrl = downloadUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: _imageUrl == null
            ? const Text('通知', style: TextStyle(color: Colors.black))
            : Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                height: kToolbarHeight,
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            notifications.clear();
            _lastDocument = null;
            _hasMore = true;
          });
          await _fetchNotifications();
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: notifications.length + 1,
          itemBuilder: (context, index) {
            if (index == notifications.length) {
              if (_isLoading) {
                return const Column(
                  children: [
                    SizedBox(height: 10),
                    Center(child: Text('読み込み中...')),
                    SizedBox(height: 80),
                  ],
                );
              } else if (!_hasMore) {
                return const Column(
                  children: [
                    SizedBox(height: 10),
                    Center(child: Text('結果は以上です')),
                    SizedBox(height: 80),
                  ],
                );
              } else {
                return const SizedBox(height: 150);
              }
            }

            final notification = notifications[index];
            final user = notification['user'];
            final isBold = notification['bold'] == true; // bold フィールドをチェック

            // ユーザーが必要な場合のみ非表示にする
            if ((notification['message_type'] == 2 ||
                    notification['message_type'] == 3 ||
                    notification['message_type'] == 6) &&
                user == null) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                if (notification['message_type'] == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 5.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              navigateToPage(
                                  context,
                                  notification['request_user'],
                                  '1',
                                  false,
                                  false);

                              // Firestoreでboldをfalseに更新
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.userId)
                                  .collection('message')
                                  .doc(notification['id'])
                                  .update({'bold': false});

                              // ローカルの通知リストを更新
                              setState(() {
                                notification['bold'] = false;
                              });
                            },
                            child: Text(
                              '@${notification['request_userId']}さんからフォロー依頼が届いています',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isBold
                                    ? FontWeight.bold
                                    : FontWeight.normal, // 太文字を適用
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 8.0),
                                  minimumSize: Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  _showDeleteConfirmationDialog(
                                      notification['request_user'],
                                      notification['id']);
                                },
                                child: Text(
                                  '削除',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 8.0),
                                  minimumSize: Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _acceptFollowRequest(
                                    notification['request_user']),
                                child: Text(
                                  '許可',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (notification['message_type'] == 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () async {
                        navigateToPage(context, notification['request_user'],
                            '1', false, false);

                        // Firestoreでboldをfalseに更新
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .doc(notification['id'])
                            .update({'bold': false});

                        // ローカルの通知リストを更新
                        setState(() {
                          notification['bold'] = false;
                        });
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '@${user.userId}さんへのフォローリクエストが許可されました。',
                          style: TextStyle(
                            fontWeight: isBold
                                ? FontWeight.bold
                                : FontWeight.normal, // 太文字を適用
                          ),
                        ),
                      ),
                    ),
                  ),
                if (notification['message_type'] == 3)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () async {
                        navigateToPage(context, notification['request_user'],
                            '1', false, false);

                        // Firestoreでboldをfalseに更新
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .doc(notification['id'])
                            .update({'bold': false});

                        // ローカルの通知リストを更新
                        setState(() {
                          notification['bold'] = false;
                        });
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '@${user.userId}さんからフォローされました。',
                          style: TextStyle(
                            fontWeight: isBold
                                ? FontWeight.bold
                                : FontWeight.normal, // 太文字を適用
                          ),
                        ),
                      ),
                    ),
                  ),
                if (notification['message_type'] == 4)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onTap: () async {
                        _showAdminMessageDialog(
                            notification['title'],
                            notification['content'],
                            notification['id'],
                            notification['timestamp'],
                            notification['message_read']);

                        // Firestoreでboldをfalseに更新
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .doc(notification['id'])
                            .update({'bold': false});

                        // ローカルの通知リストを更新
                        setState(() {
                          notification['bold'] = false;
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 8.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '運営より',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notification['title'],
                              style: TextStyle(
                                fontWeight: isBold
                                    ? FontWeight.bold
                                    : FontWeight.normal, // 太文字を適用
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (notification['message_type'] == 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () async {
                        _navigateToPostDetailPage(notification['postID']);

                        // Firestoreでboldをfalseに更新
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .doc(notification['id'])
                            .update({'bold': false});

                        // ローカルの通知リストを更新
                        setState(() {
                          notification['bold'] = false;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification['count'] == 1
                                      ? '投稿に返信が来ています'
                                      : '投稿に${notification['count']}件の返信が来ています',
                                  style: TextStyle(
                                    fontWeight: isBold
                                        ? FontWeight.bold
                                        : FontWeight.normal, // 太文字を適用
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(notification['postID'])
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox.shrink(); // ローディング中は何も表示しない
                              }
                              if (snapshot.hasError || !snapshot.hasData) {
                                return SizedBox
                                    .shrink(); // エラーまたはデータなしの場合も何も表示しない
                              }

                              final postContent =
                                  snapshot.data?.get('content') as String?;
                              if (postContent == null || postContent.isEmpty) {
                                return SizedBox.shrink(); // contentが空の場合も表示しない
                              }

                              return Text(
                                postContent.length > 50
                                    ? '${postContent.substring(0, 50)}...' // 最大30文字まで表示
                                    : postContent,
                                style: TextStyle(
                                  color: Colors.grey, // グレーの文字色
                                  fontSize: 12, // 小さい文字サイズ
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                if (notification['message_type'] == 6)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () async {
                        navigateToPage(context, notification['request_user'],
                            '1', false, false);

                        // Firestoreでboldをfalseに更新
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .doc(notification['id'])
                            .update({'bold': false});

                        // ローカルの通知リストを更新
                        setState(() {
                          notification['bold'] = false;
                        });
                      },
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '@${user.userId}さんにリクエストを送りました。',
                                  style: TextStyle(
                                    fontWeight: isBold
                                        ? FontWeight.bold
                                        : FontWeight.normal, // 太文字を適用
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (notification['message_type'] == 7)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () async {
                        _navigateToPostDetailPage(notification['postID']);

                        // Firestoreでboldをfalseに更新
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .doc(notification['id'])
                            .update({'bold': false});

                        // ローカルの通知リストを更新
                        setState(() {
                          notification['bold'] = false;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification['count'] == 1
                                      ? '投稿が引用されています'
                                      : '投稿に${notification['count']}件の引用がされています',
                                  style: TextStyle(
                                    fontWeight: isBold
                                        ? FontWeight.bold
                                        : FontWeight.normal, // 太文字を適用
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(notification['postID'])
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox.shrink(); // ローディング中は何も表示しない
                              }
                              if (snapshot.hasError || !snapshot.hasData) {
                                return SizedBox
                                    .shrink(); // エラーまたはデータなしの場合も何も表示しない
                              }

                              final postContent =
                                  snapshot.data?.get('content') as String?;
                              if (postContent == null || postContent.isEmpty) {
                                return SizedBox.shrink(); // contentが空の場合も表示しない
                              }

                              return Text(
                                postContent.length > 50
                                    ? '${postContent.substring(0, 50)}...' // 最大30文字まで表示
                                    : postContent,
                                style: TextStyle(
                                  color: Colors.grey, // グレーの文字色
                                  fontSize: 12, // 小さい文字サイズ
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                if (notification['message_type'] == 8)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () async {
                        _navigateToPostDetailPage(notification['postID']);

                        // Firestoreでboldをfalseに更新
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .doc(notification['id'])
                            .update({'bold': false});

                        // ローカルの通知リストを更新
                        setState(() {
                          notification['bold'] = false;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification['count'] == 1
                                      ? '投稿にスターが送られました'
                                      : '投稿に${notification['count']}件のスターが送られています',
                                  style: TextStyle(
                                    fontWeight: isBold
                                        ? FontWeight.bold
                                        : FontWeight.normal, // 太文字を適用
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(notification['postID'])
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox.shrink(); // ローディング中は何も表示しない
                              }
                              if (snapshot.hasError || !snapshot.hasData) {
                                return SizedBox
                                    .shrink(); // エラーまたはデータなしの場合も何も表示しない
                              }

                              final postContent =
                                  snapshot.data?.get('content') as String?;
                              if (postContent == null || postContent.isEmpty) {
                                return SizedBox.shrink(); // contentが空の場合も表示しない
                              }

                              return Text(
                                postContent.length > 50
                                    ? '${postContent.substring(0, 50)}...' // 最大50文字まで表示
                                    : postContent,
                                style: TextStyle(
                                  color: Colors.grey, // グレーの文字色
                                  fontSize: 12, // 小さい文字サイズ
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2, // 最大2行まで表示
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                Divider(
                  color: Colors.grey,
                  thickness: 0.5,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
