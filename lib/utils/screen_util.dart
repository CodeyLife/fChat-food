import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


/// 屏幕方向工具类
/// 提供屏幕方向判断和响应式配置
class AppScreenUtil {
  /// 竖屏设计尺寸
  static const Size portraitDesignSize = Size(375, 812);
  
  /// 横屏设计尺寸 (16:9比例)
  static const Size landscapeDesignSize = Size(896, 504);
  
  /// 判断是否为横屏
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }
  static bool get isLand => isLandscape(Get.context!);
  
  /// 判断是否为竖屏
  static bool isPortrait(BuildContext context) {
    return !isLandscape(context);
  }
  
  /// 获取当前屏幕方向
  static Orientation getOrientation(BuildContext context) {
    return isLandscape(context) ? Orientation.landscape : Orientation.portrait;
  }
  
  /// 获取当前设计尺寸
  static Size getDesignSize(BuildContext context) {
    return isLandscape(context) ? landscapeDesignSize : portraitDesignSize;
  }
  
  /// 横屏导航栏宽度
  static double getLandscapeNavWidth() {
    return 100.w;
  }
  
  /// 横屏内容区域宽度
  static double getLandscapeContentWidth(BuildContext context) {
    return MediaQuery.of(context).size.width - getLandscapeNavWidth();
  }
  

  /// 获取轮播图最佳高度
static double getOptimalBannerHeight(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  return screenWidth /3.2;
}
  
  /// 横屏网格列数
  static int getLandscapeGridColumns(BuildContext context, {int defaultColumns = 2}) {
    if (isLandscape(context)) {
      return defaultColumns * 2; // 横屏下增加列数
    }
    return defaultColumns;
  }
  
  /// 横屏特色功能网格列数
  static int getLandscapeFeatureColumns(BuildContext context) {
    return isLandscape(context) ? 4 : 2; // 横屏下4列，竖屏下2列
  }
  
  /// 横屏商品推荐网格列数
  static int getLandscapeProductColumns(BuildContext context) {
    return isLandscape(context) ? 4 : 2; // 横屏下4列，竖屏下2列
  }
  
  /// 横屏购物车网格列数
  static int getLandscapeCartColumns(BuildContext context) {
    return isLandscape(context) ? 2 : 1; // 横屏下2列，竖屏下1列
  }
  
  /// 横屏菜单分类栏宽度
  static double getLandscapeMenuSidebarWidth(BuildContext context) {
    return isLandscape(context) ? 140.w : 120.w; // 横屏下稍微增加分类栏宽度
  }
}
