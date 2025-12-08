import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'location.dart';
import 'package:quickalert/quickalert.dart';
import 'package:fchatapi/util/PhoneUtil.dart';

/// 统一错误处理类
class Debug {

  /// 处理服务层错误
  static void handleServiceError(String service, String operation, dynamic error) {
    final errorMessage = _getErrorMessage(error);
    PhoneUtil.applog('[$service] $operation 失败: $errorMessage');
  }

  /// 显示用户友好的错误信息
  static void showUserFriendlyError( String message) {
    QuickAlert.show(
      context: Get.context!,
      type: QuickAlertType.error,
      title: LocationUtils.translate('Operation Failed'),
      text: message,
      confirmBtnText: LocationUtils.translate('OK'),
    );
  }

  /// 显示数据加载错误
  static void showDataLoadError(BuildContext context, String dataType) {
    showUserFriendlyError('加载$dataType失败，请刷新后重试');
  }

  /// 显示支付错误
  static void showPaymentError(BuildContext context, String message) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: LocationUtils.translate('Payment Failed'),
      text: message,
      confirmBtnText: LocationUtils.translate('OK'),
    );
  }

  /// 显示成功信息
  static void showSuccessMessage(BuildContext context, String message) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: LocationUtils.translate('Operation Successful'),
      text: message,
      confirmBtnText: LocationUtils.translate('OK'),
    );
  }


  /// 显示加载中对话框
  static void showLoadingDialog(BuildContext context, {String message = 'proceesing...'}) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: null,
      barrierDismissible: false,
      text:message,
    );
  }


  /// 获取错误信息
  static String _getErrorMessage(dynamic error) {
    if (error == null) return 'Unknown error';
    
    if (error is String) return error;
    
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    
    return error.toString();
  }

  /// 记录错误日志
  static void logError(String operation, [dynamic error]) {
    if(kDebugMode){
      print('❌  [$operation]: ${_getErrorMessage(error)}');
    }
  }

  /// 记录信息日志
  static void log(String message) {
    if(kDebugMode){
      print('ℹ️  $message');
    }
  }

  /// 记录警告日志
  static void logWarning(String message) {
    if(kDebugMode){
      print('⚠️  $message');
    }
  }
}
