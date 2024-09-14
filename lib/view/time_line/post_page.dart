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
  List<XFile> images = <XFile>[]; // XFileリストに変更
  File? _mediaFile;
  bool isVideo = false;
  VideoPlayerController? _videoController;
  bool isPickerActive = false;
  final picker = ImagePicker();

  // // 画像を選択するメソッド
  // Future<void> selectImages() async {
  //   setState(() {
  //     isPickerActive = true;
  //   });

  //   final List<XFile>? pickedFiles = await picker.pickMultiImage();

  //   if (!mounted) return;

  //   setState(() {
  //     if (pickedFiles != null) {
  //       images.addAll(pickedFiles); // 選択された画像をリストに追加
  //     }
  //     isPickerActive = false;
  //   });
  // }

  // Future<void> getMedia(bool isVideo) async {
  //   if (isPickerActive) return;
  //   setState(() {
  //     isPickerActive = true;
  //   });

  //   File? pickedFile;
  //   if (isVideo) {
  //     final videoFile = await picker.pickVideo(source: ImageSource.gallery);
  //     if (videoFile != null) {
  //       pickedFile = File(videoFile.path);
  //     }
  //   } else {
  //     // メディア選択ダイアログを表示
  //     final imageFile = await picker.pickImage(source: ImageSource.gallery);
  //     if (imageFile != null) {
  //       pickedFile = File(imageFile.path);
  //     }
  //   }

  //   setState(() {
  //     if (pickedFile != null) {
  //       _mediaFile = pickedFile;
  //       this.isVideo = isVideo;
  //       if (isVideo) {
  //         _videoController = VideoPlayerController.file(_mediaFile!)
  //           ..initialize().then((_) {
  //             setState(() {});
  //             _videoController!.play();
  //           });
  //       }
  //     } else {
  //       print('No media selected or file too large.');
  //     }
  //     isPickerActive = false;
  //   });
  // }

  // 画像を選択する
  Future<void> selectImages() async {
    final pickedFiles = await FunctionUtils.selectImages();
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
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  hintText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                maxLength: 200,
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
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: selectImages,
                    child: const Text('画像を選択'),
                  ),
                  ElevatedButton(
                    onPressed: () => getMedia(true),
                    child: const Text('ビデオを選択'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (contentController.text.isNotEmpty || images.isNotEmpty) {
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
                    );

                    var result = await PostFirestore.addPost(newPost);

                    if (result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('投稿が完了しました')),
                      );
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => AccountPage(
                              userId: FirebaseAuth.instance.currentUser!.uid),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 3),
    );
  }
}
