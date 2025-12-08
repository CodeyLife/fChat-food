
import '../utils/debug.dart';
import '../utils/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/constants.dart';
import 'payment_service.dart';

/// 配置服务类
class ConfigService {

  static late final bool isTest;
  static late final String presetUserId;
  static late final String presetUserToken;
  static late final String appVersion;

  /// 初始化配置服务
  static Future<void> init() async {
    try{
       // 从 assets 目录加载 .env 文件
       await dotenv.load(fileName: "assets/.env");
    }catch(e){
      Debug.logError('配置服务初始化失败: $e');
    }
    isTest = dotenv.env['IS_TEST'] == 'true';
    presetUserId = dotenv.env['PRESET_USER_ID']!;
    presetUserToken = dotenv.env['PRESET_USER_TOKEN']??'';
    
    // 从 pubspec.yaml 读取版本号（仅版本号部分，不含构建号）
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // 从 version 字段提取版本号部分（例如从 "1.0.0+1" 提取 "1.0.0"）
      final versionString = packageInfo.version;
      appVersion = versionString.split('+').first;
    } catch (e) {
      Debug.logError('读取版本号失败: $e');
      appVersion = 'Unknown';
    }
    
    LocationUtils.inChina = dotenv.env['IN_CHINA'] == 'true';
     var realPayment = dotenv.env['REALE_PAY'];
     if(realPayment != null && realPayment == 'false'){
      PaymentService.useRealPayment = false;
    }else{
      PaymentService.useRealPayment = true;
    }
    dotenv.clean();
    Debug.log("是否测试环境: $isTest");
    Debug.log("预设用户ID: $presetUserId");
    Debug.log("是否在中国: ${LocationUtils.inChina}");
    Debug.log("是否使用真实支付: ${PaymentService.useRealPayment}");
  }

  /// 获取支付配置
  static Map<String, String> getPaymentConfig() {
    return {
      'merchantId': AppConstants.merchantId,
      'returnUrl': AppConstants.returnUrl,
      'notifyUrl': AppConstants.notifyUrl,
    };
  }

  /// 获取应用主题颜色
  static Color getPrimaryColor() {
    return Color(AppConstants.primaryColorValue);
  }


  /// 获取最大商品图片数量
  static int getMaxProductImages() {
    return AppConstants.maxProductImages;
  }

  /// 获取自动滚动间隔
  static Duration getAutoScrollInterval() {
    return Duration(seconds: AppConstants.autoScrollIntervalSeconds);
  }

  /// 获取文件操作超时时间
  static Duration getFileOperationTimeout() {
    return AppConstants.fileOperationTimeout;
  }

  /// 获取支付超时时间
  static Duration getPaymentTimeout() {
    return AppConstants.paymentTimeout;
  }

  /// 获取默认UI配置
  static UIConfig getUIConfig() {
    return UIConfig(
      defaultPadding: AppConstants.defaultPadding,
      defaultBorderRadius: AppConstants.defaultBorderRadius,
      defaultElevation: AppConstants.defaultElevation,
    );
  }
}


/// UI配置类
class UIConfig {
  final double defaultPadding;
  final double defaultBorderRadius;
  final double defaultElevation;

  UIConfig({
    required this.defaultPadding,
    required this.defaultBorderRadius,
    required this.defaultElevation,
  });
}
