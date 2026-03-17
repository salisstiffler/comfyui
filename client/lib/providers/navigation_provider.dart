import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int selectedIndex = 0;
  final PageController pageController = PageController();

  void setIndex(int index) {
    selectedIndex = index;
    if (pageController.hasClients) {
      pageController.jumpToPage(index);
    }
    notifyListeners();
  }
}
