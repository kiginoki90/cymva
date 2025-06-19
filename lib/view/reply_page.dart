import 'dart:io';
import 'package:cymva/model/account.dart';
import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/post_item/media_display_widget.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyPage extends StatefulWidget {
  final String userId;
  final Post post;
  final Account postAccount;

  const ReplyPage(
      {Key? key,
      required this.userId,
      required this.post,
      required this.postAccount})
      : super(key: key);

  @override
  State<ReplyPage> createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  final TextEditingController _replyController = TextEditingController();
  String? _postAccountName;
  String? _postAccountIconUrl;
  String? _postAccountId;
  List<File> _mediaFiles = [];
  final picker = ImagePicker();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final ValueNotifier<int> _currentTextLength = ValueNotifier<int>(0);
  String? _imageUrl;
  String? userProfileImageUrl;
  String? postUserId;
  int? imageHeight;
  int? imageWidth;

  // カテゴリー選択用の変数
  String? _selectedCategory = ''; // 初期値を空欄に設定
  final List<String> _categories = [
    '',
    '動物',
    'AI',
    '漫画',
    'イラスト',
    '音楽',
    '写真',
    '動画',
    'グルメ',
    '俳句・短歌',
    '改修要望/バグ'
  ]; // 空欄を選択肢に追加

  @override
  void initState() {
    super.initState();
    _fetchPostAccountInfo();
    _replyController.addListener(_updateTextLength);
    _getImageUrl();
    fetchUserProfileImage();
  }

  Future<void> fetchUserProfileImage() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          userProfileImageUrl = userDoc['image_path'];
          postUserId = userDoc['user_id'];
        });
      }
    } catch (e) {
      print('プロフィール画像の取得中にエラーが発生しました: $e');
    }
  }

  void _updateTextLength() {
    final maxLength = _selectedCategory == '俳句・短歌' ? 40 : 200;
    _currentTextLength.value = _replyController.text.length;
    if (_replyController.text.length > maxLength) {
      _replyController.text = _replyController.text.substring(0, maxLength);
      _replyController.selection = TextSelection.fromPosition(
        TextPosition(offset: maxLength),
      );
    }
  }

  Future<void> _pickMedia() async {
    final pickedFiles = await FunctionUtils.getImagesFromGallery(context);

    if (pickedFiles != null) {
      setState(() {
        _mediaFiles = pickedFiles;
      });
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchPostAccountInfo() async {
    final accountSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.postAccountId)
        .get();

    if (accountSnapshot.exists) {
      setState(() {
        _postAccountName = accountSnapshot['name'];
        _postAccountIconUrl = accountSnapshot['image_path'];
        _postAccountId = accountSnapshot['user_id'];
      });
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.isNotEmpty || _mediaFiles.isNotEmpty) {
      if (_mediaFiles.length > 4) {
        showTopSnackBar(context, '画像は最大4枚まで選択できます。');
        return;
      }

      List<String>? mediaUrls;

      if (_mediaFiles.isNotEmpty) {
        mediaUrls = [];

        for (var i = 0; i < _mediaFiles.length; i++) {
          File file = _mediaFiles[i];

          // 画像が1枚の場合のみ高さを取得
          bool shouldGetHeight = _mediaFiles.length == 1;

          Map<String, dynamic>? uploadResult = await FunctionUtils.uploadImage(
            widget.userId,
            file,
            context,
            shouldGetHeight: shouldGetHeight,
          );

          if (uploadResult != null) {
            mediaUrls.add(uploadResult['downloadUrl']); // ダウンロードURLを追加

            // 画像が1枚の場合のみ幅と高さを取得
            if (shouldGetHeight) {
              imageWidth = uploadResult['width'];
              imageHeight = uploadResult['height'];
            }
          }
        }
      }

      Navigator.of(context).pop();

      Post replyPost = Post(
        content: _replyController.text,
        postAccountId: widget.userId,
        mediaUrl: mediaUrls,
        reply: widget.post.id,
        imageHeight: imageHeight,
        imageWidth: imageWidth,
        category:
            _selectedCategory?.isNotEmpty == true ? _selectedCategory : null,
      );

      String? replyPostId = await PostFirestore.addPost(replyPost);

      if (replyPostId != null && replyPost.reply!.isNotEmpty) {
        final replyPostCollectionRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(replyPost.reply)
            .collection('reply_post');

        await replyPostCollectionRef.doc(replyPostId).set({
          'id': replyPostId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 返信先の投稿の返信数を更新
        if (widget.userId != widget.post.postAccountId &&
            widget.postAccount.replyMessage == true) {
          _addOrUpdateMessage(replyPostId);
        }
        // @メンションを検出して処理
        RegExp mentionRegex = RegExp(r'@([a-zA-Z0-9!#\$&*~\-_+=.,?]{1,30})');
        Iterable<Match> mentions =
            mentionRegex.allMatches(_replyController.text);

        for (var mention in mentions) {
          String mentionedUserId = mention.group(1)!;

          // 該当するユーザーのmessageコレクションにデータを追加
          final userQuerySnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('user_id', isEqualTo: mentionedUserId)
              .get();

          if (userQuerySnapshot.docs.isNotEmpty) {
            final userDoc = userQuerySnapshot.docs.first;

            final userMessageRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userDoc.id) // ドキュメントIDを使用してアクセス
                .collection('message');

            await userMessageRef.add({
              'message_type': 9,
              'timestamp': FieldValue.serverTimestamp(),
              'postID': replyPostId, // 返信投稿IDを保存
              'request_user': widget.userId,
              'isRead': false,
              'bold': true,
            });
          }
        }

        if (mounted) {
          showTopSnackBar(context, '返信が完了しました', backgroundColor: Colors.green);
        }
      } else {
        if (mounted) {
          showTopSnackBar(context, '返信に失敗しました', backgroundColor: Colors.red);
        }
      }
    }
  }

  Future<void> _addOrUpdateMessage(String replyPostId) async {
    final userMessageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.postAccountId)
        .collection('message');

    final querySnapshot = await userMessageRef
        .where('message_type', isEqualTo: 5)
        .where('postID', isEqualTo: widget.post.id)
        .where('isRead', isEqualTo: false)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // 既存のメッセージがある場合、そのcountを1増やす
      final docRef = querySnapshot.docs.first.reference;
      await docRef.update({'count': FieldValue.increment(1)});
    } else {
      // 新しいメッセージを追加
      final messageData = {
        'message_type': 5,
        'timestamp': FieldValue.serverTimestamp(),
        'postID': widget.post.id,
        'isRead': false,
        'count': 1,
        'bold': true,
      };
      await userMessageRef.add(messageData);
    }
  }

  @override
  void dispose() {
    _replyController.removeListener(_updateTextLength);
    _replyController.dispose();
    _currentTextLength.dispose();
    super.dispose();
  }

  Future<void> _getImageUrl() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('setting')
          .doc('AppBarIMG')
          .get();
      String? imageUrl = doc.data()?['ReplyPage'];
      if (imageUrl != null &&
          (imageUrl.startsWith('gs://') || imageUrl.startsWith('https://'))) {
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        String downloadUrl = await ref.getDownloadURL();
        if (mounted) {
          setState(() {
            _imageUrl = downloadUrl;
          });
        }
      }
    } catch (e) {
      print('画像URLの取得中にエラーが発生しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      key: scaffoldMessengerKey,
      appBar: AppBar(
        title: _imageUrl == null
            ? const Text('返信', style: TextStyle(color: Colors.black))
            : Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                height: kToolbarHeight,
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          if (userProfileImageUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 35.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountPage(
                        postUserId: widget.post.postAccountId,
                        withDelay: false,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    userProfileImageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
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
            ),
        ],
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_postAccountName != null)
                            GestureDetector(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  _postAccountIconUrl! ??
                                      'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_postAccountName != null)
                                Text(
                                  _postAccountName!.length > 18
                                      ? '${_postAccountName!.substring(0, 18)}...'
                                      : _postAccountName!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              if (_postAccountId != null)
                                Text(
                                  '@${_postAccountId!.length > 23 ? '${_postAccountId!.substring(0, 23)}...' : _postAccountId}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.post.content,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      if (widget.post.mediaUrl != null &&
                          widget.post.mediaUrl!.isNotEmpty)
                        MediaDisplayWidget(
                          mediaUrl: widget.post.mediaUrl,
                          category: widget.post.category ?? '',
                          atStart: true,
                          post: widget.post,
                        ),
                      const SizedBox(height: 20),
                      // カテゴリー選択用のドロップダウンメニュー
                      Align(
                        alignment: Alignment.centerRight, // 右寄せに設定
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            hint: const Text('カテゴリーを選択'),
                            underline: SizedBox(), // 下線を非表示
                            items: _categories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category.isEmpty
                                    ? '未選択'
                                    : category), // 空欄の場合は「未選択」と表示
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedCategory = newValue;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _replyController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: '返信を入力...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<int>(
                        valueListenable: _currentTextLength,
                        builder: (context, value, child) {
                          final maxLength =
                              _selectedCategory == '俳句・短歌' ? 40 : 200;
                          return Text(
                            '$value / $maxLength',
                            style: TextStyle(
                              color:
                                  value > maxLength ? Colors.red : Colors.grey,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<int>(
                        valueListenable: _currentTextLength,
                        builder: (context, value, child) {
                          final maxLength =
                              _selectedCategory == '俳句・短歌' ? 40 : 200;
                          if (value > maxLength) {
                            return Text(
                              '返信は${maxLength}文字以内で入力してください。',
                              style: TextStyle(color: Colors.red),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_mediaFiles.isNotEmpty)
                        SizedBox(
                          height: 150,
                          child: GridView.builder(
                            itemCount: _mediaFiles.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              return Image.file(
                                _mediaFiles[index],
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: keyboardHeight > 0 ? 10 : 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 0, top: 0, right: 25.0, bottom: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (keyboardHeight > 0)
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_down),
                      onPressed: _dismissKeyboard,
                    ),
                  IconButton(
                    onPressed: _pickMedia,
                    icon: const Icon(Icons.image),
                  ),
                  ElevatedButton(
                    onPressed: (_selectedCategory == '俳句・短歌' &&
                                _currentTextLength.value > 40) ||
                            _currentTextLength.value > 200
                        ? null
                        : _sendReply,
                    child: const Text('返信を送信'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
