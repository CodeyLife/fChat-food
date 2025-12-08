import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'app_theme.dart';
import 'debug.dart';
import '../services/image_cache_service.dart';

/// 图片处理工具类
/// 统一处理Base64图片解码和显示
class ImageUtils {
  
  /// 安全解码Base64字符串
  /// 返回解码后的字节数据，如果失败返回null
  static Uint8List? safeBase64Decode(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }
    
    try {
      // // 清理Base64字符串（移除可能的换行符和空格）
      // String cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
      
      // // 检查长度是否为4的倍数
      // if (cleanBase64.length % 4 != 0) {
      //   // 尝试添加填充字符
      //   int padding = 4 - (cleanBase64.length % 4);
      //   cleanBase64 += '=' * padding;
      // }
      
      // // 尝试解码
      // return base64Decode(cleanBase64);
      return base64Decode(base64String);
    } catch (e) {
      Debug.log('Base64解码失败: $e, 原始字符串长度: ${base64String.length}');
      return null;
    }
  }
  
  /// 构建安全的图片Widget
  /// [base64String] Base64编码的图片字符串
  /// [width] 图片宽度
  /// [height] 图片高度
  /// [fit] 图片适应方式
  /// [borderRadius] 圆角半径
  /// [placeholder] 占位符Widget
  /// [errorWidget] 错误时显示的Widget
  static Widget buildSafeImage({
    String? base64String,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // 默认占位符
    final defaultPlaceholder = placeholder ?? Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.image,
        color: Colors.grey[400],
        size: (width != null && height != null) 
            ? (width < height ? width * 0.5 : height * 0.5)
            : 24.w,
      ),
    );
    
    // 默认错误Widget
    final defaultErrorWidget = errorWidget ?? Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.broken_image,
        color: Colors.grey[400],
        size: (width != null && height != null) 
            ? (width < height ? width * 0.5 : height * 0.5)
            : 24.w,
      ),
    );
    
    // 如果没有Base64字符串，返回占位符
    if (base64String == null || base64String.isEmpty) {
      return defaultPlaceholder;
    }
    
    // 尝试解码Base64
    final imageBytes = safeBase64Decode(base64String);
    if (imageBytes == null) {
      return defaultErrorWidget;
    }
    
    // 构建图片Widget
    Widget imageWidget = Image.memory(
      imageBytes,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        Debug.log('图片显示失败: $error');
        return defaultErrorWidget;
      },
    );
    
    // 如果有圆角，添加ClipRRect
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }
  
  /// 构建商品图片（专门用于商品显示）
  static Widget buildProductImage({
    String? base64String,
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return buildSafeImage(
      base64String: base64String,
      width: width,
      height: height,
      borderRadius: borderRadius,
      placeholder: Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: Icon(
          Icons.coffee,
          color: AppTheme.primaryBlue,
          size: (width != null && height != null) 
              ? (width < height ? width * 0.5 : height * 0.5)
              : 30.w,
        ),
      ),
      errorWidget: Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: Icon(
          Icons.coffee,
          color: AppTheme.primaryBlue,
          size: (width != null && height != null) 
              ? (width < height ? width * 0.5 : height * 0.5)
              : 30.w,
        ),
      ),
    );
  }
  
  /// 构建头像图片（专门用于用户头像）
  static Widget buildAvatarImage({
    String? base64String,
    double? size,
  }) {
    return buildSafeImage(
      base64String: base64String,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size != null ? size / 2 : 20.w),
      placeholder: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          color: Colors.grey[600],
          size: size != null ? size * 0.6 : 20.w,
        ),
      ),
      errorWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          color: Colors.grey[600],
          size: size != null ? size * 0.6 : 20.w,
        ),
      ),
    );
  }
  
  /// 构建带 IndexedDB 缓存的图片Widget
  /// [md5] 图片的 MD5 标识
  /// [width] 图片宽度
  /// [height] 图片高度
  /// [fit] 图片适应方式
  /// [borderRadius] 圆角半径
  /// [placeholder] 占位符Widget
  /// [errorWidget] 错误时显示的Widget
  static Widget buildCachedImage({
    required String md5,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // 默认占位符
    final defaultPlaceholder = placeholder ?? Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.image,
        color: Colors.grey[400],
        size: (width != null && height != null) 
            ? (width < height ? width * 0.5 : height * 0.5)
            : 24.w,
      ),
    );
    
    // 默认错误Widget
    final defaultErrorWidget = errorWidget ?? Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.broken_image,
        color: Colors.grey[400],
        size: (width != null && height != null) 
            ? (width < height ? width * 0.5 : height * 0.5)
            : 24.w,
      ),
    );
    
    if (md5.isEmpty) {
      return defaultPlaceholder;
    }
    
    // 使用 ImageCacheService 获取图片
    return GetX<ImageCacheService>(
      builder: (imageCacheService) {
        return FutureBuilder<Uint8List?>(
          future: _getImageFromCache(md5),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return defaultPlaceholder;
            }
            
            if (snapshot.hasError || snapshot.data == null) {
              return defaultErrorWidget;
            }
            
            final imageBytes = snapshot.data!;
            
            // 构建图片Widget
            Widget imageWidget = Image.memory(
              imageBytes,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                Debug.log('图片显示失败: $error');
                return defaultErrorWidget;
              },
            );
            
            // 如果有圆角，添加ClipRRect
            if (borderRadius != null) {
              imageWidget = ClipRRect(
                borderRadius: borderRadius,
                child: imageWidget,
              );
            }
            
            return imageWidget;
          },
        );
      },
    );
  }
  
  /// 从缓存获取图片数据
  static Future<Uint8List?> _getImageFromCache(String md5) async {
    try {
      final imageCacheService = Get.find<ImageCacheService>();
      return await imageCacheService.getImage(md5);
    } catch (e) {
      Debug.logError('从缓存获取图片失败: $md5', e);
      return null;
    }
  }
  
  /// 预加载图片到 IndexedDB
  /// [md5] 图片的 MD5 标识
  static Future<void> preloadImage(String md5) async {
    try {
      final imageCacheService = Get.find<ImageCacheService>();
      await imageCacheService.preloadToIndexedDB(md5);
      Debug.log('✅ 图片预加载完成: $md5');
    } catch (e) {
      Debug.logError('图片预加载失败: $md5', e);
    }
  }
  
  /// 批量预加载图片
  /// [md5List] 图片 MD5 列表
  static Future<void> preloadImages(List<String> md5List) async {
    try {
      final futures = md5List.map((md5) => preloadImage(md5));
      await Future.wait(futures);
      Debug.log('✅ 批量预加载完成，共 ${md5List.length} 张图片');
    } catch (e) {
      Debug.logError('批量预加载失败', e);
    }
  }
  
  /// 清空 IndexedDB 缓存
  static Future<bool> clearIndexedDBCache() async {
    try {
      final imageCacheService = Get.find<ImageCacheService>();
      return await imageCacheService.clearIndexedDBCache();
    } catch (e) {
      Debug.logError('清空 IndexedDB 缓存失败', e);
      return false;
    }
  }
  
  /// 获取 IndexedDB 缓存统计信息
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final imageCacheService = Get.find<ImageCacheService>();
      final indexedDBCount = await imageCacheService.getIndexedDBCacheCount();
      final indexedDBSize = await imageCacheService.getIndexedDBCacheSize();
      final memoryCount = imageCacheService.cacheSize;
      final memorySize = imageCacheService.cacheSizeInBytes;
      
      return {
        'indexedDB': {
          'count': indexedDBCount,
          'size': indexedDBSize,
        },
        'memory': {
          'count': memoryCount,
          'size': memorySize,
        },
        'total': {
          'count': indexedDBCount + memoryCount,
          'size': indexedDBSize + memorySize,
        },
      };
    } catch (e) {
      Debug.logError('获取缓存统计信息失败', e);
      return {};
    }
  }
  
  /// 打印缓存统计信息
  static void printCacheStats() {
    try {
      final imageCacheService = Get.find<ImageCacheService>();
      imageCacheService.printCacheStats();
    } catch (e) {
      Debug.logError('打印缓存统计信息失败', e);
    }
  }
  
  /// 获取存储限制信息
  static Future<Map<String, dynamic>> getStorageLimits() async {
    try {
      final imageCacheService = Get.find<ImageCacheService>();
      final indexedDBCount = await imageCacheService.getIndexedDBCacheCount();
      final memoryCount = imageCacheService.cacheSize;
      
      return {
        'indexedDB': {
          'current': indexedDBCount,
          'max': 600, // IndexedDB 最大存储数量
          'remaining': 600 - indexedDBCount,
          'batchDelete': 100, // 批量删除数量
        },
        'memory': {
          'current': memoryCount,
          'max': 100, // 内存缓存最大数量
          'remaining': 100 - memoryCount,
        },
      };
    } catch (e) {
      Debug.logError('获取存储限制信息失败', e);
      return {};
    }
  }
  
  /// 手动触发批量清理
  /// 当存储接近上限时，可以主动清理
  static Future<int> manualBatchCleanup() async {
    try {
      final imageCacheService = Get.find<ImageCacheService>();
      return await imageCacheService.manualBatchCleanup();
    } catch (e) {
      Debug.logError('手动批量清理失败', e);
      return 0;
    }
  }
}
