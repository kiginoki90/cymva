import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FullScreenImagePage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool unberBar;

  FullScreenImagePage({
    required this.imageUrls,
    required this.initialIndex,
    this.unberBar = false, // デフォルト値をfalseに設定
  });

  @override
  _FullScreenImagePageState createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  late int _currentIndex;
  bool _showOverlay = true;
  bool _showArrow = false;
  double _arrowOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (widget.unberBar) {
      _showArrow = true;
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          _arrowOpacity = 0.0;
        });
      });
      Future.delayed(Duration(seconds: 2), () {
        setState(() {
          _showArrow = false;
        });
      });
    }
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleOverlay,
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
                final mediaUrl = widget.imageUrls[index];

                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(mediaUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2, // 最大拡大率を設定
                  heroAttributes:
                      PhotoViewHeroAttributes(tag: mediaUrl), // Heroアニメーションを追加
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        '画像を読み込めませんでした',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  },
                );
              },
              scrollPhysics: BouncingScrollPhysics(),
              backgroundDecoration: BoxDecoration(
                color: Colors.black,
              ),
              pageController: PageController(
                initialPage: widget.initialIndex,
              ),
              reverse: widget.unberBar, // unberBarがtrueの時だけスワイプ方向を逆に設定
            ),
            if (_showOverlay)
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
                        if (widget.imageUrls.length > 1)
                          Text(
                            '${_currentIndex + 1}/${widget.imageUrls.length}',
                            style: TextStyle(color: Colors.white),
                          ),
                        Spacer(),
                      ],
                    ),
                    Spacer(),
                    if (widget.imageUrls.length > 1 && widget.unberBar)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: LinearProgressIndicator(
                          value: 1 -
                              (_currentIndex + 1) /
                                  widget.imageUrls.length, // 反対方向に設定
                          backgroundColor: Colors.white,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            if (_showArrow)
              Center(
                child: AnimatedOpacity(
                  opacity: _arrowOpacity,
                  duration: Duration(milliseconds: 500),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(128),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.all(8),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
