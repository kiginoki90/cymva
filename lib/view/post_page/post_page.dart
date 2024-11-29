import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/main.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:video_player/video_player.dart';

class PostPage extends StatefulWidget {
  final String userId;
  const PostPage({super.key, required this.userId});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  TextEditingController contentController = TextEditingController();
  List<XFile> images = <XFile>[];
  File? _mediaFile;
  bool isVideo = false;
  VideoPlayerController? _videoController;
  bool isPickerActive = false;
  final picker = ImagePicker();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Map<String, dynamic>? accountData;

  String? selectedCategory;
  final List<String> categories = [
    '',
    '動物',
    'AI',
    '漫画',
    'イラスト',
    '写真',
    '俳句・短歌',
    '改修要望/バグ'
  ];
  final List<String> adminCategories = [
    '',
    'cymva',
    '動物',
    'AI',
    '漫画',
    'イラスト',
    '写真',
    '俳句・短歌',
    '改修要望/バグ'
  ];
  String? userProfileImageUrl;
  bool isPosting = false;

  @override
  void initState() {
    super.initState();
    fetchUserProfileImage();
    _fetchAccountData();
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
        });
      }
    } catch (e) {
      print('プロフィール画像の取得中にエラーが発生しました: $e');
    }
  }

  Future<void> getMedia(bool isVideo) async {
    if (images.isNotEmpty) {
      setState(() {
        images.clear();
      });
    }
    File? pickedFile = await FunctionUtils.getMedia(isVideo, context);
    if (pickedFile != null) {
      setState(() {
        _mediaFile = pickedFile;
        this.isVideo = isVideo;
        if (isVideo) {
          _videoController = VideoPlayerController.file(_mediaFile!)
            ..initialize().then((_) {
              setState(() {});
            });
        }
      });
    }
  }

  Future<void> _fetchAccountData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (doc.exists) {
      setState(() {
        accountData = doc.data();
      });
    }
  }

  Future<void> selectImages() async {
    if (_mediaFile != null) {
      setState(() {
        _mediaFile = null;
        _videoController?.dispose();
        _videoController = null;
        isVideo = false;
      });
    }
    final pickedFiles =
        await FunctionUtils.selectImages(context, selectedCategory);
    if (pickedFiles != null) {
      setState(() {
        images.addAll(pickedFiles);
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // キーボードを閉じるメソッド
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus(); // キーボードを閉じる
  }

  @override
  Widget build(BuildContext context) {
    // キーボードの高さを取得
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      key: scaffoldMessengerKey,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('投稿'),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (userProfileImageUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 35.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AccountPage(postUserId: widget.userId),
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
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // カテゴリー選択欄
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(
                              color: Colors.blueAccent,
                              width: 2.0,
                            ),
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                        items: (accountData == null ||
                                accountData!['admin'] == 3 ||
                                accountData!['admin'] == 4)
                            ? categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 0),
                                    child: Text(category,
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                );
                              }).toList()
                            : adminCategories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 0),
                                    child: Text(category,
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                );
                              }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                        hint: const Text(
                          'カテゴリー',
                          style: TextStyle(fontSize: 12),
                        ),
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down,
                            color: Colors.blueAccent),
                        style: TextStyle(color: Colors.black, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // コンテンツ入力欄
                  TextField(
                    controller: contentController,
                    decoration: InputDecoration(
                      hintText: 'Content',
                      filled: true,
                      fillColor: selectedCategory == '俳句・短歌'
                          ? Color.fromARGB(255, 255, 238, 240)
                          : const Color.fromARGB(255, 222, 242, 251),
                      border: InputBorder.none,
                    ),
                    minLines: 5,
                    maxLines: null,
                    maxLength: selectedCategory == '俳句・短歌' ? 40 : 200,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 20),
                  // 選択した画像または動画を表示
                  if (images.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: GridView.builder(
                        itemCount: images.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          XFile xFile = images[index];
                          File file = File(xFile.path);
                          return Image.file(
                            file,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    )
                  else if (_mediaFile != null && isVideo)
                    _videoController != null &&
                            _videoController!.value.isInitialized
                        ? Container(
                            width: double.infinity,
                            height: 300,
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                          )
                        : const SizedBox(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // キーボードの上にボタンを配置する
          Positioned(
            bottom: keyboardHeight > 0 ? 10 : 10,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // キーボードを閉じるボタン
                      if (keyboardHeight > 0)
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_down),
                          onPressed: _dismissKeyboard,
                        ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image),
                            onPressed: _mediaFile != null
                                ? null // 動画が選択されている場合は無効
                                : () => selectImages(),
                            tooltip: '画像を選択',
                          ),
                          IconButton(
                            icon: const Icon(Icons.videocam),
                            onPressed: images.isNotEmpty
                                ? null // 画像が選択されている場合は無効
                                : () => getMedia(true),
                            tooltip: 'ビデオを選択',
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: isPosting
                            ? null
                            : () async {
                                if (contentController.text.isNotEmpty ||
                                    images.isNotEmpty ||
                                    _mediaFile != null) {
                                  // 投稿中フラグをセットしてボタンを無効化
                                  setState(() {
                                    isPosting = true;
                                  });

                                  // タイムラインページへ遷移してから投稿処理を実行
                                  await Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => AccountPage(
                                          postUserId: widget.userId),
                                    ),
                                  );

                                  // 投稿処理を非同期で実行
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) async {
                                    // 投稿処理を行う
                                    List<String> mediaUrls = [];
                                    int maxImageLimit =
                                        selectedCategory == '漫画' ? 50 : 4;

                                    // 画像ファイルのアップロード処理
                                    for (var i = 0;
                                        i < images.length && i < maxImageLimit;
                                        i++) {
                                      File file = File(images[i].path);
                                      String? mediaUrl =
                                          await FunctionUtils.uploadImage(
                                        widget.userId,
                                        file,
                                        context,
                                      );
                                      if (mediaUrl != null) {
                                        mediaUrls.add(mediaUrl);
                                      }
                                    }

                                    // 動画ファイルのアップロード処理
                                    String? videoUrl;
                                    if (_mediaFile != null && isVideo) {
                                      videoUrl =
                                          await FunctionUtils.uploadVideo(
                                              widget.userId,
                                              _mediaFile!,
                                              context);
                                      if (videoUrl != null) {
                                        mediaUrls.add(videoUrl);
                                      }
                                    }

                                    // 新しい投稿データの作成
                                    Post newPost = Post(
                                      content: contentController.text,
                                      postAccountId: widget.userId,
                                      mediaUrl: mediaUrls,
                                      isVideo: isVideo,
                                      category: selectedCategory,
                                    );

                                    // Firestoreへ投稿データを保存
                                    var result =
                                        await PostFirestore.addPost(newPost);

                                    // 投稿完了後の処理
                                    if (result != null) {
                                      scaffoldMessengerKey.currentState
                                          ?.showSnackBar(
                                        SnackBar(content: Text('投稿が完了しました')),
                                      );
                                    } else {
                                      scaffoldMessengerKey.currentState
                                          ?.showSnackBar(
                                        SnackBar(content: Text('投稿に失敗しました')),
                                      );
                                    }

                                    // 投稿が完了した後に投稿中フラグをリセット
                                    if (mounted) {
                                      setState(() {
                                        isPosting = false;
                                      });
                                    }
                                  });
                                }
                              },
                        child: isPosting
                            ? CircularProgressIndicator()
                            : const Text('投稿'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 4),
    );
  }
}
