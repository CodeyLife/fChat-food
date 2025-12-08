import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'location.dart';

/// SnackBar 工具类，提供统一的弹窗调用接口
class SnackBarUtils {

  ///调用Get.snackbar  默认已经使用翻译功能
  static void getSnackbar(
     String title ,
     String message,
    {SnackPosition snackPosition = SnackPosition.TOP,
    Color? backgroundColor,
    Widget? icon,
    Color? colorText,
    Duration duration = const Duration(seconds: 2),}) {
    Get.snackbar(
       LocationUtils.translate(title),
       LocationUtils.translate(message), 
       snackPosition: snackPosition, backgroundColor: backgroundColor ?? Get.theme.colorScheme.primary, 
       icon: icon, duration: duration, colorText: colorText ?? Get.theme.colorScheme.onPrimary);
  }
  /// 显示成功消息
  static void showSuccess(
    String message) {
     getSnackbar("Success", message,icon: const Icon(Icons.check_circle),
     backgroundColor: Colors.green[600]!);

    // _showSnackBar(
    //   context: context,
    //   message: message,r
    //   backgroundColor: Colors.green[600]!,
    //   icon: Icons.check_circle,
    //   duration: duration,
    //   onAction: onAction,
    //   actionLabel: actionLabel,
    // );
  }

  /// 显示错误消息
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: Colors.red[600]!,
      icon: Icons.error,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// 显示警告消息
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: Colors.orange[600]!,
      icon: Icons.warning,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// 显示信息消息
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: Colors.blue[600]!,
      icon: Icons.info,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// 显示自定义消息
  static void showCustom(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: backgroundColor ?? Colors.grey[600]!,
      icon: icon,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// 显示带图标的错误消息（兼容现有代码风格）
  static void showErrorWithIcon(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error,
              color: Colors.white,
              size: 20.w,
            ),
            SizedBox(width: 8.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600]!,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }

  /// 清除所有 SnackBar
  static void clearAll(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// 私有方法：显示 SnackBar
  static void _showSnackBar({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: icon != null
            ? Row(
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 20.w,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(child: Text(message)),
                ],
              )
            : Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        action: onAction != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
