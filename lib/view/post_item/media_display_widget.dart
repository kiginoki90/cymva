import 'package:cymva/view/post_item/full_screen_image.dart';
import 'package:cymva/view/slide_direction_page_route.dart';
import 'package:flutter/material.dart';

class MediaDisplayWidget extends StatelessWidget {
  final List<String>? mediaUrl;
  final String category;

  const MediaDisplayWidget({
    Key? key,
    required this.mediaUrl,
    required this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaUrl == null || mediaUrl!.isEmpty) {
      return SizedBox.shrink(); // メディアが無い場合は空のウィジェットを返す
    }

    // カテゴリーが "漫画" の場合
    if (category == '漫画') {
      return _buildMangaMedia(context);
    }

    // メディアが1枚の場合
    else if (mediaUrl!.length == 1) {
      return _buildSingleMedia(context);
    }

    // メディアが複数枚ある場合
    else {
      return _buildMultipleMedia(context);
    }
  }

  // 漫画の場合の表示
  Widget _buildMangaMedia(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              SlideDirectionPageRoute(
                page: FullScreenImagePage(
                  imageUrls: mediaUrl!,
                  initialIndex: 0,
                ),
                isSwipeUp: true,
              ),
            );
          },
          child: ClipRRect(
            child: Image.network(
              mediaUrl![0],
              width: MediaQuery.of(context).size.width,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (mediaUrl!.length > 1)
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${mediaUrl!.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }

  // メディアが1枚の場合の表示
  Widget _buildSingleMedia(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          SlideDirectionPageRoute(
            page: FullScreenImagePage(
              imageUrls: mediaUrl!,
              initialIndex: 0,
            ),
            isSwipeUp: true,
          ),
        );
      },
      child: ClipRRect(
        child: Image.network(
          mediaUrl![0],
          width: MediaQuery.of(context).size.width * 0.9,
          height: 250,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // メディアが複数枚の場合の表示
  Widget _buildMultipleMedia(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: mediaUrl!.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              SlideDirectionPageRoute(
                page: FullScreenImagePage(
                  imageUrls: mediaUrl!,
                  initialIndex: index,
                ),
                isSwipeUp: true,
              ),
            );
          },
          child: ClipRRect(
            child: Image.network(
              mediaUrl![index],
              width: MediaQuery.of(context).size.width * 0.4,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}
