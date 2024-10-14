import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FullScreenImagePage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  FullScreenImagePage({required this.imageUrls, required this.initialIndex});

  @override
  _FullScreenImagePageState createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 10) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              builder: (context, index) {
                final imageUrl = widget.imageUrls[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(imageUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2, // 最大拡大率を設定
                );
              },
              scrollPhysics: BouncingScrollPhysics(),
              backgroundDecoration: BoxDecoration(
                color: Colors.black,
              ),
              pageController: PageController(
                  initialPage: widget.initialIndex), // PageControllerをここに移動
            ),
            SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      SizedBox(width: 20),
                      Text(
                        '${_currentIndex + 1}/${widget.imageUrls.length}',
                        style: TextStyle(color: Colors.white),
                      ),
                      Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
