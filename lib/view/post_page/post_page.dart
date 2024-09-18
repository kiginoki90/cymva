import 'dart:io';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:video_player/video_player.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

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

  String? selectedCategory;
  final List<String> categories = ['', '動物', 'AI', '漫画', 'イラスト', '写真', '俳句・短歌'];

  // 画像を選択する
  Future<void> selectImages(selectedCategory) async {
    final pickedFiles =
        await FunctionUtils.selectImages(context, selectedCategory);
    if (pickedFiles != null) {
      setState(() {
        images.addAll(pickedFiles);
      });
    }
  }

  // メディアを取得する
  Future<void> getMedia(bool isVideo) async {
    File? pickedFile = await FunctionUtils.getMedia(isVideo);
    if (pickedFile != null) {
      setState(() {
        _mediaFile = pickedFile;
        this.isVideo = isVideo;
        if (isVideo) {
          // VideoControllerの初期化も非同期処理として行う
          Future<void> initializeController() async {
            _videoController =
                await FunctionUtils.getVideoController(_mediaFile!);
          }

          initializeController();
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('新規投稿'),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // カテゴリー選択欄
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 6),
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category, style: TextStyle(fontSize: 12)),
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

                  border: InputBorder.none, // 枠線を削除
                ),
                minLines: 5,

                maxLines: null,
                maxLength:
                    selectedCategory == '俳句・短歌' ? 40 : 200, // カテゴリーによる文字数制限
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),

              const SizedBox(height: 20),

              // 選択した画像を表示する
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
                      XFile xFile = images[index]; // XFileを使用
                      File file = File(xFile.path); // XFileからFileオブジェクトを作成

                      return Image.file(
                        file,
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover, // 必要に応じて画像のフィット方法を指定
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: () => selectImages(selectedCategory),
                    tooltip: '画像を選択',
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam),
                    onPressed: () => getMedia(true),
                    tooltip: 'ビデオを選択',
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (contentController.text.isNotEmpty ||
                          images.isNotEmpty) {
                        // 複数の画像をアップロードする処理
                        List<String> mediaUrls = [];
                        final String userId =
                            FirebaseAuth.instance.currentUser!.uid;

                        for (var xFile in images) {
                          File file = File(xFile.path);

                          // 画像をそれぞれアップロード
                          String? mediaUrl = await FunctionUtils.uploadImage(
                              userId, file, context);

                          // mediaUrlがnullでない場合のみリストに追加
                          if (mediaUrl != null) {
                            mediaUrls.add(mediaUrl);
                          }
                        }

                        Post newPost = Post(
                          content: contentController.text,
                          postAccountId: FirebaseAuth.instance.currentUser!.uid,
                          mediaUrl: mediaUrls,
                          isVideo: false,
                          category: selectedCategory,
                        );

                        var result = await PostFirestore.addPost(newPost);

                        if (result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('投稿が完了しました')),
                          );
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => AccountPage(
                                  userId:
                                      FirebaseAuth.instance.currentUser!.uid),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('投稿に失敗しました')),
                          );
                        }
                      }
                    },
                    child: const Text('投稿'),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 3),
    );
  }
}
