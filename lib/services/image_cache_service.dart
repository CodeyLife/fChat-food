import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:fchatapi/webapi/FChatFileObj.dart';
import 'package:fchatapi/util/JsonUtil.dart';
import '../utils/debug.dart';
import '../utils/constants.dart';
import 'indexeddb_service.dart';

/// 全局图片缓存服务
/// 实现内存缓存策略，支持LRU缓存和请求合并
class ImageCacheService extends GetxService {
  static ImageCacheService get instance => Get.find<ImageCacheService>();
  
  // 内存缓存存储：MD5 -> Uint8List
  final Map<String, Uint8List> _cache = {};
  
  // LRU 访问顺序追踪
  final List<String> _accessOrder = [];
  
  // 请求合并：MD5 -> 等待的 Future
  final Map<String, Future<Uint8List?>> _loadingRequests = {};
  
  // 缓存大小限制
  static const int maxCacheSize = 100;
  
  
  // IndexedDB 服务实例
  IndexedDBService? _indexedDBService;
  
  @override
  void onInit() {
    super.onInit();
    _initializeIndexedDB();
  }
  
  @override
  void onClose() {
    _cache.clear();
    _accessOrder.clear();
    _loadingRequests.clear();
    super.onClose();
  }
  
  /// 初始化 IndexedDB 服务
  Future<void> _initializeIndexedDB() async {
    try {
      _indexedDBService = Get.find<IndexedDBService>();
    } catch (e) {
      Debug.log('⚠️ IndexedDB 服务未找到，将仅使用内存缓存: $e');
      _indexedDBService = null;
    }
  }

  /// 获取图片数据（带缓存）
  /// [md5] 图片 MD5 标识
  /// 返回异步的图片字节数据
  Future<Uint8List?> getImage(String md5) async {

    // 检查内存缓存
    if (_cache.containsKey(md5)) {
      final bytes = _cache[md5]!;
      _updateAccessOrder(md5);
      return bytes;
    }

    // 检查是否正在加载，如果是则等待
    if (_loadingRequests.containsKey(md5)) {
    
      return await _loadingRequests[md5]!;
    }
    
   
    // 开始新的加载请求
    final future = _startLoading(md5);
    _loadingRequests[md5] = future;
     
    try {
      final result = await future;
    
      return result;
    } finally {
      _loadingRequests.remove(md5);
    }
  }
  
  
  
  /// 开始加载图片
  Future<Uint8List?> _startLoading(String md5) async {
    // 首先尝试从 IndexedDB 加载
    final indexedDBResult = await _loadFromIndexedDB(md5);
    if (indexedDBResult != null) {
      return indexedDBResult;
    }
    
    // IndexedDB 中没有找到，从服务器加载
    return await _loadFromServer(md5);
  }
  
  /// 从 IndexedDB 加载图片
  Future<Uint8List?> _loadFromIndexedDB(String md5) async {
    if (_indexedDBService != null) {
      try {
        final bytes = await _indexedDBService!.loadImage(md5);
        Debug.log('🔍 从 IndexedDB 加载图片: $md5 (${bytes?.length} bytes)');
        if (bytes != null) {
          // 缓存到内存
          _cacheImage(md5, bytes);
          return bytes;
        }
      } catch (e) {
        Debug.log('⚠️ 从 IndexedDB 加载图片失败: $md5, 错误: $e');
      }
    }
    
    // IndexedDB 中没有找到
    return null;
  }
  
  /// 从服务器加载图片
  Future<Uint8List?> _loadFromServer(String md5) async {
    Debug.log('🌐 从服务器加载图片: $md5');
    
    final completer = Completer<Uint8List?>();
    
    // 从文件系统读取图片
    FChatFileArrObj fileArrObj = FChatFileArrObj();
    fileArrObj.readfile((value) {
      try {
        String base64 = value.filedata ?? "";
        base64 = JsonUtil.getbase64(base64);
        
        if (base64.isNotEmpty) {
          // 解码 base64 为 Uint8List
          final bytes = _decodeBase64ToBytes(base64);
          if (bytes != null) {
            // 缓存到内存和 IndexedDB
            _cacheImage(md5, bytes);
            _saveToIndexedDB(md5, bytes);
            
            if (!completer.isCompleted) {
              Debug.log('✅ 图片从服务器加载完成: $md5 (${bytes.length} bytes)');
              completer.complete(bytes);
            }
          } else {
            Debug.log('❌ 图片解码失败: $md5');
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        } else {
          Debug.log('⚠️ 服务器返回空数据: $md5');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      } catch (e) {
        Debug.log('💥 图片加载异常: $md5, 错误: $e');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      } finally {
        _loadingRequests.remove(md5);
      }
    }, md: AppConstants.image.name, filename: md5);
    
    return completer.future;
  }
  
  /// 保存图片到 IndexedDB
  void _saveToIndexedDB(String md5, Uint8List bytes) async {
    if (_indexedDBService != null) {
      try {
        await _indexedDBService!.saveImage(md5, bytes);

      } catch (e) {
        Debug.log('⚠️ 保存图片到 IndexedDB 失败: $md5, 错误: $e');
      }
    }
  }
  
  /// 缓存图片数据
  void _cacheImage(String md5, Uint8List bytes) {
    // 如果缓存已满，移除最久未使用的图片
    if (_cache.length >= maxCacheSize && !_cache.containsKey(md5)) {
      _evictOldest();
    }
    
    _cache[md5] = bytes;
    _updateAccessOrder(md5);
  }
  
  /// 解码 base64 为 Uint8List
  Uint8List? _decodeBase64ToBytes(String base64) {
    try {
      return base64Decode(base64);
    } catch (e) {
      Debug.log('Base64 解码失败: $e');
      return null;
    }
  }
  
  /// 更新访问顺序（LRU）
  void _updateAccessOrder(String md5) {
    _accessOrder.remove(md5);
    _accessOrder.add(md5);
  }
  
  /// 淘汰最久未使用的图片
  void _evictOldest() {
    if (_accessOrder.isNotEmpty) {
      final oldest = _accessOrder.removeAt(0);
      _cache.remove(oldest);
    }
  }
  
  
  
  /// 检查图片是否已缓存
  bool isCached(String md5) {
    return _cache.containsKey(md5);
  }
  
  /// 获取缓存大小
  int get cacheSize => _cache.length;
  
  /// 获取缓存命中率（需要外部统计）
  double getCacheHitRate() {
    // 这里需要外部统计总请求数和命中数
    // 暂时返回 0，实际使用时需要添加统计逻辑
    return 0.0;
  }
  
  /// 手动清理缓存
  void clearCache() {
    _cache.clear();
    _accessOrder.clear();
  }
  
  /// 预加载图片
  void preloadImage(String md5) {
    if (!_cache.containsKey(md5) && !_loadingRequests.containsKey(md5)) {
      getImage(md5).then((bytes) {
        // 预加载完成，无需额外处理
      });
    }
  }
  
  /// 获取缓存的图片字节数据
  Uint8List? getCachedImage(String md5) {
    return _cache[md5];
  }
  
  /// 获取缓存大小（字节）
  int get cacheSizeInBytes {
    int totalBytes = 0;
    for (var bytes in _cache.values) {
      totalBytes += bytes.length;
    }
    return totalBytes;
  }
  
  /// 打印缓存统计信息
  void printCacheStats() {
    final totalBytes = cacheSizeInBytes;
    final avgSize = _cache.isNotEmpty ? (totalBytes / _cache.length).round() : 0;
    
    Debug.log('📊 ===== 图片缓存统计 =====');
    Debug.log('📈 内存缓存图片数量: ${_cache.length}/$maxCacheSize');
    Debug.log('💾 内存缓存总大小: ${_formatBytes(totalBytes)}');
    Debug.log('📏 平均图片大小: ${_formatBytes(avgSize)}');
    Debug.log('🔄 访问顺序: ${_accessOrder.take(10).join(" → ")}${_accessOrder.length > 10 ? "..." : ""}');
    Debug.log('🌐 缓存类型: 内存缓存 + IndexedDB 持久化');
    
    // 打印 IndexedDB 统计信息
    if (_indexedDBService != null) {
      _indexedDBService!.printStorageStats();
    } else {
      Debug.log('⚠️ IndexedDB 服务未初始化');
    }
    
    Debug.log('📊 ========================');
  }
  
  /// 清空 IndexedDB 缓存
  Future<bool> clearIndexedDBCache() async {
    if (_indexedDBService != null) {
      return await _indexedDBService!.clearAllImages();
    }
    return false;
  }
  
  /// 获取 IndexedDB 缓存大小
  Future<int> getIndexedDBCacheSize() async {
    if (_indexedDBService != null) {
      return await _indexedDBService!.getTotalSize();
    }
    return 0;
  }
  
  /// 获取 IndexedDB 缓存图片数量
  Future<int> getIndexedDBCacheCount() async {
    if (_indexedDBService != null) {
      return await _indexedDBService!.getImageCount();
    }
    return 0;
  }
  
  /// 预加载图片到 IndexedDB
  Future<void> preloadToIndexedDB(String md5) async {
    if (_indexedDBService != null && !await _indexedDBService!.hasImage(md5)) {
      await getImage(md5);
      // 预加载完成，数据已自动保存到 IndexedDB
      Debug.log('✅ 图片预加载完成: $md5');
    }
  }
  
  /// 手动触发批量清理
  Future<int> manualBatchCleanup() async {
    if (_indexedDBService != null) {
      return await _indexedDBService!.manualBatchCleanup();
    }
    return 0;
  }
  
  /// 格式化字节数显示
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

