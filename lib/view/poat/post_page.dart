import 'dart:io';
import 'package:cymva/view/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:cymva/model/post.dart';
import 'package:cymva/utils/authentication.dart';
import 'package:cymva/utils/firestore/posts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cymva/utils/function_utils.dart';
import 'package:video_player/video_player.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

//投稿ページ
class _PostPageState extends State<PostPage> {
  //_PostPageStateクラスの状態を管理するための変数やコントローラを定義している。
  //TextEditingControllerのインスタンスを定義している。
  //このコントローラを使用して、ユーザーが入力したテキストを取得したり設定したりする。
  TextEditingController contentController = TextEditingController();
  //選択した画像や動画を保持するための変数。
  File? _mediaFile;
  //ImagePickerクラスのインスタンスを作成。このクラスは画像や動画を選択するためのライブラリを提供する。
  final picker = ImagePicker();
  bool isVideo = false;
  //VideoPlayerControllerクラスのインスタンスを保持するための変数。これは動画の再生を管理する。
  VideoPlayerController? _videoController;
  //メディアがアクティブかどうかを示すためのブール型の変数。
  bool isPickerActive = false;

  //非同期の関数の宣言
  //ユーザーが画像や動画を選択するためのロジックを実装。
  Future getMedia(bool isVideo) async {
    //メディアがすでにアクティブな場合、関数を修了する。
    if (isPickerActive) return;
    //setStateメソッドはウィジェットの状態が変更されたことを Flutter に知らせる役割
    setState(() {
      isPickerActive = true;
    });

    //画像、動画の選択を非同期で行う。
    final pickedFile = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);

    //選択されたメディアの処理を行う。
    setState(() {
      if (pickedFile != null) {
        //pickedFileがnullでないのなら選択されたファイルのパスを_mediaFileに設定。
        _mediaFile = File(pickedFile.path);
        //isVideoフラグを更新
        this.isVideo = isVideo;

        //メディアが動画の場合、VideoPlayerController.fileメソッドを使用して動画再生の準備をする。
        if (isVideo) {
          _videoController = VideoPlayerController.file(_mediaFile!)
            ..initialize().then((_) {
              setState(() {}); // コントローラの初期化後に再描画
              _videoController!.play(); // ビデオを再生
            });
        }
      } else {
        print('No media selected.');
      }
      isPickerActive = false;
    });
  }

//ウィジェットが破棄される時に呼び出される。リソースを適切に解放するために使用される。
  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

//buildメソッドはflutterのUIを構築するために使用される。StatefulWidgetの状態が変更されるたびに再実行される。
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
            children: [
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  hintText: 'Content',
                ),
              ),
              const SizedBox(height: 20),
              //メディアを選択した場合のメディアの表示。
              if (_mediaFile != null)
                //isVideoはメディアが動画かどうか判定するフラグ。trueなら動画、falseは画像。
                isVideo
                    ? _videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : CircularProgressIndicator() // ビデオの初期化中にローディングインジケータを表示
                    : Container(
                        width: 150, // 画像の表示幅を指定
                        height: 150, // 画像の表示高さを指定
                        child: Image.file(
                          _mediaFile!,
                          fit: BoxFit.cover, // 画像がコンテナにフィットするように設定
                        ),
                      ),
              const SizedBox(height: 20),
              Row(
                //子ウィジェットを水平方向に配置する。
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    //ElevatedButtonを押した場合getMediaメソッドを呼ぶ。
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
                  //テキストフィールドが空でない、またはメディアが選択されている場合に処理を行う。
                  if (contentController.text.isNotEmpty || _mediaFile != null) {
                    //メディアファイルURLの変数を宣言。？はnullになる可能性があるという意味。
                    String? mediaUrl;
                    if (_mediaFile != null) {
                      //現在ログインしているユーザーのアカウントIDを取得する。
                      var result = Authentication.myAccount!.id;
                      //メディアファイルをアップロード。その後URLを取得。
                      mediaUrl =
                          await FunctionUtils.uploadImage(result, _mediaFile!);
                    }

                    //Postオブジェクトを作成。Postクラスのコンストラクタに必要な情報を渡す。
                    Post newPost = Post(
                      content: contentController.text,
                      postAccountId: Authentication.myAccount!.id,
                      mediaUrl: mediaUrl,
                      isVideo: isVideo,
                    );
                    //Postオブジェクトを Firestore に追加
                    var result = await PostFirestore.addPost(newPost);
                    //投稿の保存が成功した場合、現在の画面を閉じて前の画面に戻る。
                    if (result == true) {
                      Navigator.pop(context);
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
