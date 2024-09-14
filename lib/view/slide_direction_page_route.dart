import 'package:flutter/material.dart';

class SlideDirectionPageRoute extends PageRouteBuilder {
  final Widget page;
  final bool isSwipeUp;

  SlideDirectionPageRoute({required this.page, this.isSwipeUp = true})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // スワイプの方向に応じたアニメーションの開始オフセット
            final begin = isSwipeUp ? Offset(0.0, 1.0) : Offset(0.0, -1.0);
            final end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end);
            var offsetAnimation =
                animation.drive(tween.chain(CurveTween(curve: curve)));

            return SlideTransition(position: offsetAnimation, child: child);
          },
        );
}
