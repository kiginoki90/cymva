import 'package:flutter/material.dart';

class WidgetUtils {
  static AppBar createAppBer(String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      title: Text(
        title,
        style: TextStyle(color: Colors.black),
      ),
      centerTitle: true,
    );
  }
}
