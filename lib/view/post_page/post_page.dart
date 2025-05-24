import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/utils/navigation_utils.dart';
import 'package:cymva/utils/snackbar_utils.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

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
  String? _imageUrl;
  int? imageHeight;
  int? imageWidth;

  String? selectedCategory;
  final List<String> categories = [
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
    '憲章宣誓',
    '改修要望/バグ'
  ];
  final List<String> adminCategories = [
    'cymva',
    '動物',
    'AI',
    '漫画',
    'イラスト',
    '写真',
    'グルメ',
    '俳句・短歌',
    '憲章宣誓',
    '改修要望/バグ',
    '市民'
  ];
  String? userProfileImageUrl;
  bool isPosting = false;
  String? postUserId;

  @override
  void initState() {
    super.initState();
    fetchUserProfileImage();
    _fetchAccountData();
    _loadDraft();
    _getImageUrl();
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

  Future<void> _loadDraft() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? draft = userData['draft'];
      if (draft != null) {
        contentController.text = draft;
      }
    }
  }

  String _getHintText(String category) {
    switch (category) {
      case '俳句・短歌':
        return '縦書きになります。40文字以内で入力してください。';
      case '漫画':
        return '画像は最大50枚まで選択できます。';
      case '憲章宣誓':
        return '私は市民国家Cymvaの一員として、この国及び全ての機構生命の繁栄と平和のためにその責務を全うすることを誓います。';
      case '改修要望/バグ':
        return 'またなんかしちゃいました？';
      case 'イラスト':
        return '画像1枚+文字0で表示が変わるよ';
      case '写真':
        return '画像1枚+文字0で表示が変わるよ';
      default:
        return 'content';
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    contentController.dispose(); // テキストフィールドのコントローラーを破棄
    super.dispose();
  }

  void _resetFields() {
    setState(() {
      contentController.clear(); // テキストフィールドをクリア
      images.clear(); // 画像リストをクリア
      _mediaFile = null; // 動画ファイルをクリア
      _videoController?.dispose(); // 動画コントローラーを破棄
      _videoController = null;
      isVideo = false; // 動画フラグをリセット
      selectedCategory = null; // カテゴリーをリセット
    });
  }

  // キーボードを閉じるメソッド
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus(); // キーボードを閉じる
  }

  Future<void> _getImageUrl() async {
    // FirestoreからURLを取得
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('setting')
        .doc('AppBarIMG')
        .get();
    String? imageUrl = doc.data()?['PostPage'];
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
    // キーボードの高さを取得
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      key: scaffoldMessengerKey,
      appBar: AppBar(
        automaticallyImplyLeading: false, // 戻るボタンを非表示にする
        centerTitle: true,
        title: _imageUrl == null
            ? const Text('投稿', style: TextStyle(color: Colors.black))
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
                  navigateToPage(context, widget.userId, '1', false, false);
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
            alignment: Alignment.topCenter, // 上寄せに設定
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // カテゴリー選択欄
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ElevatedButton(
                            //   onPressed: () {
                            //     setState(() {
                            //       selectedCategory = null;
                            //     });
                            //   },
                            //   style: ElevatedButton.styleFrom(
                            //     backgroundColor: Colors.blueAccent,
                            //     shape: RoundedRectangleBorder(
                            //       borderRadius: BorderRadius.circular(8.0),
                            //     ),
                            //     padding: EdgeInsets.symmetric(
                            //         horizontal: 8, vertical: 4),
                            //   ),
                            //   child: Text(
                            //     'クリア',
                            //     style: TextStyle(
                            //         fontSize: 12, color: Colors.white),
                            //   ),
                            // ),
                            SizedBox(width: 8),
                            SizedBox(
                              width: 135,
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
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                ),
                                items: (accountData == null ||
                                        accountData!['admin'] == 3 ||
                                        accountData!['admin'] == 4)
                                    ? categories.map((category) {
                                        return DropdownMenuItem(
                                          value: category,
                                          child: Container(
                                            constraints: BoxConstraints(
                                              minWidth: 90, // 最小幅を指定
                                              minHeight: 37, // 最小高さを指定
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4, horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: const Color.fromARGB(
                                                  255, 250, 253, 255), // 背景色
                                              border: Border.all(
                                                color: Colors.blueAccent,
                                                width: 1.0, // 枠線の太さ
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8.0), // 角丸
                                            ),
                                            child: Text(
                                              category,
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        );
                                      }).toList()
                                    : adminCategories.map((category) {
                                        return DropdownMenuItem(
                                          value: category,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4, horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50], // 背景色
                                              border: Border.all(
                                                color: Colors.blueAccent,
                                                width: 1.0, // 枠線の太さ
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8.0), // 角丸
                                            ),
                                            child: Text(
                                              category,
                                              style: TextStyle(fontSize: 12),
                                            ),
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
                                style: TextStyle(
                                    color: Colors.black, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // コンテンツ入力欄
                      TextField(
                        controller: contentController,
                        decoration: InputDecoration(
                          hintText: _getHintText(selectedCategory ?? ''),
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
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
                          child: ReorderableGridView.builder(
                            itemCount: images.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                // 順番を入れ替える
                                final item = images.removeAt(oldIndex);
                                images.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (BuildContext context, int index) {
                              XFile xFile = images[index];
                              File file = File(xFile.path);

                              return Stack(
                                key: ValueKey(xFile.path), // 必須: 各アイテムに一意のキーを設定
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      // 拡大表示
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Dialog(
                                            backgroundColor:
                                                Colors.black.withOpacity(0.5),
                                            child: GestureDetector(
                                              onTap: () =>
                                                  Navigator.of(context).pop(),
                                              child: Center(
                                                child: Container(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.8,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.8,
                                                  decoration: BoxDecoration(
                                                    image: DecorationImage(
                                                      image: FileImage(file),
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: Image.file(
                                      file,
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // 削除ボタン
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          images.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                            dragWidgetBuilder: (index, child) {
                              // ドラッグ中のアイテムの見た目をカスタマイズ
                              return Transform.scale(
                                scale: 1.1, // 少し拡大
                                child: Opacity(
                                  opacity: 0.8, // 半透明にする
                                  child: child,
                                ),
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
                                  aspectRatio:
                                      _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                ),
                              )
                            : const SizedBox(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
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
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: () async {
                              // テキストフィールドの内容を取得
                              String draftText = contentController.text;

                              // Firestoreに保存
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.userId)
                                  .update({'draft': draftText});

                              // メッセージを表示
                              showTopSnackBar(context, 'テキストを保存しました',
                                  backgroundColor: Colors.green);
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8.0), // 角を四角くする
                              ),
                            ),
                            child: const Text('保存'),
                          ),
                        ),
                      ),
                      // キーボードを閉じるボタン
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Color.fromARGB(255, 185, 224, 240), // 背景色を設定
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0), // 角を四角くする
                          ),
                        ),
                        onPressed: isPosting
                            ? null
                            : () async {
                                if (selectedCategory == '憲章宣誓' ||
                                    contentController.text.isNotEmpty ||
                                    images.isNotEmpty ||
                                    _mediaFile != null) {
                                  // 投稿中フラグをセットしてボタンを無効化
                                  setState(() {
                                    isPosting = true;
                                  });

                                  // タイムラインページへ遷移してから投稿処理を実行
                                  navigateToPage(context, widget.userId, '1',
                                      false, false);

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

                                      Map<String, dynamic>? uploadResult =
                                          await FunctionUtils.uploadImage(
                                        widget.userId,
                                        file,
                                        context,
                                        shouldGetHeight: images.length ==
                                            1, // 画像が1枚の場合のみ高さを取得
                                      );

                                      if (uploadResult != null) {
                                        mediaUrls.add(uploadResult[
                                            'downloadUrl']); // ダウンロードURLを追加

                                        // 高さを取得する場合のみ処理
                                        if (images.length == 1 &&
                                            uploadResult
                                                .containsKey('height') &&
                                            uploadResult.containsKey('width')) {
                                          imageHeight = uploadResult['height'];
                                          imageWidth = uploadResult['width'];
                                        }
                                      }
                                    }

                                    // 動画ファイルのアップロード処理
                                    String? videoUrl;
                                    if (_mediaFile != null && isVideo) {
                                      // 動画ファイルのアップロード処理
                                      Map<String, dynamic>? uploadResult =
                                          await FunctionUtils.uploadVideo(
                                        widget.userId,
                                        _mediaFile!,
                                        context,
                                      );

                                      if (uploadResult != null) {
                                        // ダウンロードURLを取得
                                        String videoUrl =
                                            uploadResult['downloadUrl'];
                                        mediaUrls.add(videoUrl);

                                        // 動画の幅と高さを取得してクラス変数に格納
                                        imageWidth = uploadResult['width'];
                                        imageHeight = uploadResult['height'];
                                      }
                                    }

                                    // 新しい投稿データの作成
                                    Post newPost = Post(
                                      content: selectedCategory == '憲章宣誓'
                                          ? '私は市民国家Cymvaの一員として、この国及び全ての機構生命の繁栄と平和のためにその責務を全うすることを誓います。'
                                          : contentController.text,
                                      postAccountId: widget.userId,
                                      postUserId: postUserId!,
                                      mediaUrl: mediaUrls,
                                      isVideo: isVideo,
                                      category: selectedCategory,
                                      imageWidth: imageWidth,
                                      imageHeight: imageHeight,
                                    );

                                    // Firestoreへ投稿データを保存
                                    var result =
                                        await PostFirestore.addPost(newPost);

                                    // 投稿完了後の処理
                                    if (result != null) {
                                      // Firestoreのdraftフィールドを空にする
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.userId)
                                          .update({'draft': ''});

                                      showTopSnackBar(context, '投稿が完了しました',
                                          backgroundColor: Colors.green);

                                      // フィールドをリセット
                                      _resetFields();
                                    } else {
                                      showTopSnackBar(context, '投稿に失敗しました',
                                          backgroundColor: Colors.red);
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
                            : const Text('投稿',
                                style: TextStyle(
                                    color: Color.fromARGB(255, 48, 46, 46))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
      // bottomNavigationBar: NavigationBarPage(selectedIndex: 4),
    );
  }
}
