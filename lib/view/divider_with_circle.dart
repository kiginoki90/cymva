import 'package:flutter/material.dart';

class DividerWithCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24, // 固定幅
      child: CustomPaint(
        size: Size(24, 150), // 幅は24、高さは制約なし
        painter: DividerWithCirclePainter(),
      ),
    );
  }
}

class DividerWithCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint circlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // 円を描画
    canvas.drawCircle(Offset(size.width / 2, 40), 10, circlePaint);

    // 線を描画
    final Path path = Path()
      ..moveTo(size.width / 2, 30) // 円の下から始める
      ..lineTo(size.width / 2, size.height); // 要素いっぱいの高さに線を引く

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Divider with Circle Example'),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DividerWithCircle(),
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: Center(
                child: Text('Content Here'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: MyHomePage(),
  ));
}
