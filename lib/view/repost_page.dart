import 'dart:io';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/post_item/media_display_widget.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class RepostPage extends StatefulWidget {
  final Post post;
  final String userId;

  const RepostPage({Key? key, required this.post, required this.userId})
      : super(key: key);

  @override
  State<RepostPage> createState() => _RepostPageState();
}

class _RepostPageState extends State<RepostPage> {
  final TextEditingController _retweetController = TextEditingController();
  final ValueNotifier<int> _currentTextLength = ValueNotifier<int>(0);
  String? _postAccountName;
  String? _postAccountIconUrl;
  String? _postAccountId;
  List<File> _mediaFiles = [];
  final picker = ImagePicker();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
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
  ];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _fetchPostAccountInfo(),
      _getImageUrl(),
      fetchUserProfileImage(),
    ]);
    _retweetController.addListener(_updateTextLength);
  }

  void _updateTextLength() {
    final maxLength = _selectedCategory == '俳句・短歌' ? 40 : 200;
    _currentTextLength.value = _retweetController.text.length;
    if (_retweetController.text.length > maxLength) {
      _retweetController.text = _retweetController.text.substring(0, maxLength);
      _retweetController.selection = TextSelection.fromPosition(
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

  Future<void> fetchUserProfileImage() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userProfileImageUrl = userDoc['image_path'];
          postUserId = userDoc['user_id'];
        });
      }
    } catch (e) {
      print('プロフィール画像の取得中にエラーが発生しました: $e');
    }
  }

  // キーボードを閉じるメソッド
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus(); // キーボードを閉じる
  }

  Future<void> _fetchPostAccountInfo() async {
    // Firestoreから投稿者の情報を取得
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

  @override
  void dispose() {
    _retweetController.removeListener(_updateTextLength);
    _retweetController.dispose();
    _currentTextLength.dispose();
    super.dispose();
  }

  Future<void> _getImageUrl() async {
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('setting')
        .doc('AppBarIMG')
        .get();
    String? imageUrl = doc.data()?['RepostPage'];
    if (imageUrl != null) {
      if (imageUrl.startsWith('gs://') || imageUrl.startsWith('https://')) {
        // Firebase StorageからダウンロードURLを取得
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        String downloadUrl = await ref.getDownloadURL();
        setState(() {
          _imageUrl = downloadUrl;
        });
      }
    }
  }

  Future<void> _sendRepost() async {
    if (_retweetController.text.isEmpty && _mediaFiles.isEmpty) {
      if (mounted) {
        showTopSnackBar(context, '投稿内容を入力してください。', backgroundColor: Colors.red);
      }
      return;
    }

    if (_mediaFiles.length > 4) {
      if (mounted) {
        showTopSnackBar(context, '画像は最大4枚まで選択できます。',
            backgroundColor: Colors.red);
      }
      return;
    }

    // メディアファイルをアップロードして結果を取得
    Map<String, dynamic>? uploadResult =
        _mediaFiles.isNotEmpty ? await _uploadMediaFiles() : null;

    List<String>? mediaUrls = uploadResult?['mediaUrls'];
    int? imageWidth = uploadResult?['imageWidth'];
    int? imageHeight = uploadResult?['imageHeight'];

    Navigator.of(context).pop();

    Post rePost = Post(
      content: _retweetController.text,
      postAccountId: widget.userId,
      mediaUrl: mediaUrls,
      repost: widget.post.id,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      category: _selectedCategory?.isNotEmpty == true
          ? _selectedCategory
          : null, // カテゴリーを追加
    );

    String? rePostId = await PostFirestore.addPost(rePost);

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.postAccountId)
        .get();

    // quoteMessageがfalse以外の場合に処理を実行
    if (userDoc.exists && userDoc.data()?['quoteMessage'] != false) {
      _addOrUpdateMessage();
    }

    if (rePostId != null) {
      await _updateRepost(rePostId);
      if (mounted) {
        showTopSnackBar(context, '引用投稿が完了しました', backgroundColor: Colors.green);
      }
    } else {
      if (mounted) {
        showTopSnackBar(context, '引用投稿が失敗しました', backgroundColor: Colors.red);
      }
    }
  }

  Future<Map<String, dynamic>?> _uploadMediaFiles() async {
    if (_mediaFiles.isEmpty) return null;

    List<String> mediaUrls = [];
    int? imageWidth;
    int? imageHeight;

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

    // 3つの値をMapで返す
    return {
      'mediaUrls': mediaUrls,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    };
  }

  Future<void> _updateRepost(String rePostId) async {
    final rePostCollectionRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('repost');

    await rePostCollectionRef.doc(rePostId).set({
      'id': rePostId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      key: scaffoldMessengerKey,
      appBar: AppBar(
        title: _imageUrl == null
            ? const Text('引用', style: TextStyle(color: Colors.black))
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
                        postUserId: widget.userId,
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
                      // 引用部分を四角い枠線で囲む
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey, // 枠線の色
                              width: 1.0, // 枠線の太さ
                            ),
                            borderRadius: BorderRadius.circular(8.0), // 角を丸くする
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 投稿者のアイコンと名前を表示
                              Row(
                                children: [
                                  if (_postAccountIconUrl != null)
                                    GestureDetector(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.network(
                                          _postAccountIconUrl ??
                                              'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/export.jpg?alt=media&token=82889b0e-2163-40d8-917b-9ffd4a116ae7',
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_postAccountName != null)
                                        Text(
                                          _postAccountName!.length > 18
                                              ? '${_postAccountName!.substring(0, 18)}...'
                                              : _postAccountName!,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      if (_postAccountId != null)
                                        Text(
                                          '@${_postAccountId!.length > 20 ? '${_postAccountId!.substring(0, 20)}...' : _postAccountId}',
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 13),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // 元の投稿内容を表示
                              Text(
                                widget.post.content,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              // 画像がある場合は表示
                              if (widget.post.mediaUrl != null &&
                                  widget.post.mediaUrl!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                MediaDisplayWidget(
                                  mediaUrl: widget.post.mediaUrl,
                                  category: widget.post.category ?? '',
                                  atStart: true,
                                  post: widget.post,
                                ),
                              ],
                            ],
                          ),
                        ),
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
                      // 引用テキストフィールド
                      TextField(
                        controller: _retweetController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: '引用コメント...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<int>(
                        valueListenable: _currentTextLength,
                        builder: (context, value, child) {
                          final maxLength =
                              _selectedCategory == '俳句・短歌' ? 40 : 200;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$value / $maxLength',
                                style: TextStyle(
                                  color: value > maxLength
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                              ),
                              if (value > maxLength)
                                Text(
                                  '引用コメントは${maxLength}文字以内で入力してください。',
                                  style: TextStyle(color: Colors.red),
                                ),
                            ],
                          );
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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ボタンをキーボードの上に配置
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
                        : _sendRepost,
                    child: const Text('引用を送信'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrUpdateMessage() async {
    final userMessageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.postAccountId)
        .collection('message');

    final querySnapshot = await userMessageRef
        .where('message_type', isEqualTo: 7)
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
        'message_type': 7,
        'timestamp': FieldValue.serverTimestamp(),
        'postID': widget.post.id,
        'isRead': false,
        'count': 1,
        'bold': true,
      };
      await userMessageRef.add(messageData);
    }
  }
}
