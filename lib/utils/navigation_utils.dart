import 'package:flutter/material.dart';
import 'package:cymva/view/navigation_bar.dart';

void navigateToPage(BuildContext context, String userId, String firstIndex,
    bool rebuildNavigation, bool myAccount) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          NavigationBarPage(
        userId: userId,
        firstIndex: int.parse(firstIndex),
        rebuildNavigation: rebuildNavigation,
        myAccount: myAccount,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child; // アニメーションをなくす
      },
    ),
  );
}

void navigateToSearchPage(BuildContext context, String userId,
    String firstIndex, bool notDleteStotage) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          NavigationBarPage(
        userId: userId,
        firstIndex: int.parse(firstIndex),
        notDleteStotage: notDleteStotage,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child; // アニメーションをなくす
      },
    ),
  );
}
