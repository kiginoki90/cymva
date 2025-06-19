import 'package:flutter/material.dart';
import 'package:cymva/view/navigation_bar.dart';

void navigateToPage(
    BuildContext context, String userId, String firstIndex, bool myAccount,
    [bool rebuildNavigation = true, bool fromLogin = false]) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          NavigationBarPage(
        userId: userId,
        firstIndex: int.parse(firstIndex),
        myAccount: myAccount,
        rebuildNavigation: rebuildNavigation,
        fromLogin: fromLogin,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child; // アニメーションをなくす
      },
    ),
  );
}

void navigateToSearchPage(BuildContext context, String userId,
    String firstIndex, bool notDleteStotage, bool rebuildNavigation) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          NavigationBarPage(
        userId: userId,
        firstIndex: int.parse(firstIndex),
        notDleteStotage: notDleteStotage,
        rebuildNavigation: rebuildNavigation,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child; // アニメーションをなくす
      },
    ),
  );
}
