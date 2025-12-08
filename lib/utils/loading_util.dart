import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as html;
import 'debug.dart';
/// Loading工具类
/// 用于管理web环境下的loading显示和隐藏
class LoadingUtil {
  
  /// 关闭loading动画
  static void clearLoading() {
    if (kIsWeb) {
      try {
        var loadingElement = html.document.getElementById("loading");
        if (loadingElement != null) {
          loadingElement.remove();
          // Debug.log("loading容器已移除");
        } else {
          Debug.log("未找到loading容器");
        }
      } catch (e) {
        Debug.log("关闭loading时出错: $e");
      }
    } else {
      Debug.log("非Web环境，跳过clearloading");
    }
  }

  /// 显示loading动画（如果需要的话）
  static void showLoading() {
    if (kIsWeb) {
      try {
        // 检查是否已存在loading元素
        var existingLoading = html.document.getElementById("loading");
        if (existingLoading == null) {
          Debug.log("显示loading动画");
          // 这里可以重新创建loading元素，但通常不需要
        }
      } catch (e) {
        Debug.log("显示loading时出错: $e");
      }
    }
  }
}
