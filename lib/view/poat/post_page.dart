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
  File? _mediaFile;
  final picker = ImagePicker();
  bool isVideo = false;
  VideoPlayerController? _videoController;
  bool isPickerActive = false;

  Future getMedia(bool isVideo) async {
    if (isPickerActive) return;
    setState(() {
      isPickerActive = true;
    });

    File? pickedFile;
    if (isVideo) {
      final videoFile = await picker.pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        pickedFile = File(videoFile.path);
      }
    } else {
      pickedFile = await FunctionUtils.getImageFromGallery(context);
    }

    setState(() {
      if (pickedFile != null) {
        _mediaFile = pickedFile;
        this.isVideo = isVideo;
        if (isVideo) {
          _videoController = VideoPlayerController.file(_mediaFile!)
            ..initialize().then((_) {
              setState(() {});
              _videoController!.play();
            });
        }
      } else {
        print('No media selected or file too large.');
      }
      isPickerActive = false;
    });
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
              if (_mediaFile != null)
                isVideo
                    ? _videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : CircularProgressIndicator()
                    : Container(
                        width: 150,
                        height: 150,
                        child: Image.file(
                          _mediaFile!,
                          fit: BoxFit.cover,
                        ),
                      ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => getMedia(false),
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
                  if (contentController.text.isNotEmpty || _mediaFile != null) {
                    String? mediaUrl;
                    if (_mediaFile != null) {
                      final String userId =
                          FirebaseAuth.instance.currentUser!.uid;
                      mediaUrl = await FunctionUtils.uploadImage(
                          userId, _mediaFile!, context);
                    }

                    Post newPost = Post(
                      content: contentController.text,
                      postAccountId: FirebaseAuth.instance.currentUser!.uid,
                      mediaUrl: mediaUrl,
                      isVideo: isVideo,
                    );

                    // 投稿の追加処理
                    var result = await PostFirestore.addPost(newPost);

                    // 投稿の保存が成功したかどうかを判定
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
