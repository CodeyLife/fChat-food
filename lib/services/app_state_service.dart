import 'package:flutter/material.dart';

/// 应用状态服务
/// 管理全局应用状态，包括页面切换
class AppStateService extends ChangeNotifier {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  int _currentPageIndex = 0;

  int get currentPageIndex => _currentPageIndex;



  /// 切换到指定页面
  void switchToPage(int index) {
    _currentPageIndex = index;
    try {
      notifyListeners();
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
}
