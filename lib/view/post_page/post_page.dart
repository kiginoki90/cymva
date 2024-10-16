import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cymva/view/account/account_page.dart';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:twitter_api_v2/twitter_api_v2.dart';

class PostPage extends StatefulWidget {
  final String userId;
  const PostPage({super.key, required this.userId});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  TextEditingController contentController = TextEditingController();
  List<XFile> images = <XFile>[]; // 選択した画像ファイルリスト
  File? _mediaFile; // 選択したメディアファイル（動画）
  bool isVideo = false; // 選択したメディアが動画かどうか
  VideoPlayerController? _videoController; // 動画プレーヤーコントローラ
  bool isPickerActive = false; // メディアピッカーがアクティブかどうか
  final picker = ImagePicker(); // 画像/動画選択用のピッカー

  String? selectedCategory;
  final List<String> categories = ['', '動物', 'AI', '漫画', 'イラスト', '写真', '俳句・短歌'];
  String? userProfileImageUrl;
  bool isPosting = false; // 投稿中かどうかのフラグ

  @override
  void initState() {
    super.initState();
    fetchUserProfileImage(); // 初期化時にプロフィール画像を取得
  }

  // Firestoreからユーザーのプロフィール画像を取得
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

  // メディア（画像または動画）を取得する
  Future<void> getMedia(bool isVideo) async {
    if (images.isNotEmpty) {
      // 画像がすでに選択されている場合は、画像をクリア
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
          // VideoControllerの初期化
          _videoController = VideoPlayerController.file(_mediaFile!)
            ..initialize().then((_) {
              setState(() {});
            });
        }
      });
    }
  }

  // 画像を選択する（動画が選択されている場合は無効）
  Future<void> selectImages() async {
    if (_mediaFile != null) {
      // 動画がすでに選択されている場合は、動画をクリア
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('投稿'),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // プロフィール画像を右端に表示
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
                      // 画像の取得に失敗した場合のエラービルダー
                      return Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/cymva-595b7.appspot.com/o/Lr2K2MmxmyZNjXheJ7mPfT2vXNh2?alt=media&token=100952df-1a76-4d22-a1e7-bf4e726cc344',
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

              // メディア選択ボタン（画像と動画を同時に選択不可）
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                  ElevatedButton(
                    onPressed: isPosting
                        ? null
                        : () async {
                            if (contentController.text.isNotEmpty ||
                                images.isNotEmpty ||
                                _mediaFile != null) {
                              setState(() {
                                isPosting = true;
                              });

                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AccountPage(postUserId: widget.userId),
                                ),
                              );

                              List<String> mediaUrls = [];

                              for (var xFile in images) {
                                File file = File(xFile.path);
                                String? mediaUrl =
                                    await FunctionUtils.uploadImage(
                                        widget.userId, file, context);
                                if (mediaUrl != null) {
                                  mediaUrls.add(mediaUrl);
                                }
                              }

                              String? videoUrl;
                              if (_mediaFile != null && isVideo) {
                                videoUrl = await FunctionUtils.uploadVideo(
                                    widget.userId, _mediaFile!, context);
                                if (videoUrl != null) {
                                  mediaUrls.add(videoUrl);
                                }
                              }

                              Post newPost = Post(
                                content: contentController.text,
                                postAccountId: widget.userId,
                                mediaUrl: mediaUrls,
                                isVideo: isVideo,
                                category: selectedCategory,
                              );

                              var result = await PostFirestore.addPost(newPost);

                              if (result != null) {
                                if (mounted) {
                                  setState(() {
                                    isPosting = false;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('投稿が完了しました')),
                                  );

                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => AccountPage(
                                          postUserId: widget.userId),
                                    ),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  setState(() {
                                    isPosting = false;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('投稿に失敗しました')),
                                  );
                                }
                              }
                            }
                          },
                    child: isPosting
                        ? CircularProgressIndicator()
                        : const Text('投稿'),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarPage(selectedIndex: 4),
    );
  }
}
