
import 'package:flutter/foundation.dart';

import '../utils/debug.dart';
import '../utils/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as html;

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
    isTest = kDebugMode;
    
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
    
    // Web环境下检测版本号变化并自动刷新
    if (kIsWeb) {
      try {
        await _checkAndHandleVersionUpdate();
      } catch (e) {
        Debug.logError('版本号检测失败: $e');
      }
    }
    
    LocationUtils.inChina = dotenv.env['IN_CHINA'] == 'true';

    dotenv.clean();
    Debug.log("是否测试环境: $isTest");
    Debug.log("预设用户ID: $presetUserId");
    Debug.log("是否在中国: ${LocationUtils.inChina}");
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

  /// 检查版本号变化并处理（仅Web环境）
  static Future<void> _checkAndHandleVersionUpdate() async {
    if (!kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      const versionKey = 'app_version';
      
      // 获取保存的版本号
      final savedVersion = prefs.getString(versionKey);
      
      // 获取当前版本号
      final currentVersion = appVersion;
      
      Debug.log('当前版本号: $currentVersion, 保存的版本号: $savedVersion');
      
      // 如果版本号不一致（包括首次运行）
      if (savedVersion != currentVersion) {
        // 保存新版本号
        await prefs.setString(versionKey, currentVersion);
        Debug.log('版本号已更新: $savedVersion -> $currentVersion');
        
        // 如果不是首次运行（savedVersion不为null），则刷新页面
        if (savedVersion != null) {
          Debug.log('检测到版本号变化，准备刷新页面...');
          // 延迟一小段时间确保日志输出
          await Future.delayed(const Duration(milliseconds: 100));
          // 刷新页面以清除缓存
          html.window.location.reload();
        } else {
          Debug.log('首次运行，已保存版本号: $currentVersion');
        }
      } else {
        Debug.log('版本号未变化: $currentVersion');
      }
    } catch (e) {
      Debug.logError('版本号检测处理失败: $e');
    }
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
