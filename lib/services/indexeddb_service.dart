import 'dart:typed_data';
import 'package:idb_shim/idb_browser.dart';
import 'package:get/get.dart';
import '../utils/debug.dart';

/// IndexedDB 服务类
/// 使用 idb_shim 库在 Flutter Web 环境中持久化存储图片数据
class IndexedDBService extends GetxService {
  static IndexedDBService get instance => Get.find<IndexedDBService>();
  
  // IndexedDB 相关变量
  Database? _database;
  static const String _dbName = 'ImageCache';
  static const String _storeName = 'images';
  static const int _dbVersion = 1;
  
  // 存储限制配置
  static const int maxImageCount = 600; // 最大图片数量
  static const int batchDeleteCount = 100; // 批量删除数量
  
  // 缓存状态
  final RxBool _isInitialized = false.obs;
  bool get isInitialized => _isInitialized.value;
  
  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeDatabase();
  }
  
  @override
  void onClose() {
    _database?.close();
    super.onClose();
  }
  
  /// 初始化 IndexedDB 数据库
  Future<void> _initializeDatabase() async {
    try {
      // Debug.log('🗄️ 开始初始化 IndexedDB 数据库...');
    
      
      // 获取 IdbFactory 实例
      final idbFactory = getIdbFactory();
      if (idbFactory == null) {
        Debug.log('⚠️ 无法获取 IdbFactory，跳过 IndexedDB 初始化');
        _isInitialized.value = true;
        return;
      }
      
      // 打开数据库
      _database = await idbFactory.open(_dbName, version: _dbVersion, onUpgradeNeeded: _onUpgradeNeeded);
      
      // Debug.log('✅ IndexedDB 数据库初始化成功: $_dbName');
      _isInitialized.value = true;
      
    } catch (e) {
      Debug.logError('❌ IndexedDB 数据库初始化失败', e);
      _isInitialized.value = false;
    }
  }
  
  /// 数据库升级回调
  void _onUpgradeNeeded(VersionChangeEvent event) {
    Debug.log('🔄 IndexedDB 数据库升级中...');
    final db = event.database;
    
    // 创建图片存储对象
    if (!db.objectStoreNames.contains(_storeName)) {
      final store = db.createObjectStore(_storeName, keyPath: 'md5');
      store.createIndex('timestamp', 'timestamp', unique: false);
      Debug.log('✅ 创建对象存储: $_storeName');
    }
  }

  
  /// 保存图片数据到 IndexedDB
  /// [md5] 图片的 MD5 标识
  /// [imageData] 图片的字节数据
  /// [metadata] 可选的元数据
  Future<bool> saveImage(String md5, Uint8List imageData, {Map<String, dynamic>? metadata}) async {
    if (!_isInitialized.value || _database == null) {
      Debug.log('IndexedDB 未初始化，无法保存图片: $md5');
      return false;
    }
    
    try {
      // 检查存储限制
      await _enforceStorageLimits();
      
      final transaction = _database!.transaction([_storeName], 'readwrite');
      final store = transaction.objectStore(_storeName);
      
      final imageRecord = {
        'md5': md5,
        'data': imageData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'size': imageData.length,
        'metadata': metadata ?? {},
      };
      
      await store.put(imageRecord);
      await transaction.completed;

      return true;
      
    } catch (e) {
      Debug.logError('❌ 保存图片到 IndexedDB 失败: $md5', e);
      return false;
    }
  }
  
  /// 从 IndexedDB 加载图片数据
  /// [md5] 图片的 MD5 标识
  /// 返回图片字节数据，如果不存在则返回 null
  Future<Uint8List?> loadImage(String md5) async {
    if (!_isInitialized.value || _database == null) {
      Debug.log('⚠️ IndexedDB 未初始化，无法加载图片: $md5');
      return null;
    }
    
    try {
      final transaction = _database!.transaction([_storeName], 'readonly');
      final store = transaction.objectStore(_storeName);
      final result = await store.getObject(md5);
      
      if (result != null) {
        final imageRecord = result as Map<String, dynamic>;
        final imageData = imageRecord['data'] as Uint8List;
        return imageData;
      } else {
        return null;
      }
      
    } catch (e) {
      return null;
    }
  }
  
  /// 检查图片是否存在于 IndexedDB
  /// [md5] 图片的 MD5 标识
  Future<bool> hasImage(String md5) async {
    if (!_isInitialized.value || _database == null) {
      return false;
    }
    
    try {
      final transaction = _database!.transaction([_storeName], 'readonly');
      final store = transaction.objectStore(_storeName);
      final result = await store.getObject(md5);
      return result != null;
    } catch (e) {
      Debug.logError('❌ 检查图片是否存在失败: $md5', e);
      return false;
    }
  }
  
  /// 删除图片数据
  /// [md5] 图片的 MD5 标识
  Future<bool> deleteImage(String md5) async {
    if (!_isInitialized.value || _database == null) {
      return false;
    }
    
    try {
      final transaction = _database!.transaction([_storeName], 'readwrite');
      final store = transaction.objectStore(_storeName);
      await store.delete(md5);
      await transaction.completed;
      
      Debug.log('✅ 图片已从 IndexedDB 删除: $md5');
      return true;
      
    } catch (e) {
      Debug.logError('❌ 从 IndexedDB 删除图片失败: $md5', e);
      return false;
    }
  }
  
  /// 清空所有图片数据
  Future<bool> clearAllImages() async {
    if (!_isInitialized.value || _database == null) {
      return false;
    }
    
    try {
      final transaction = _database!.transaction([_storeName], 'readwrite');
      final store = transaction.objectStore(_storeName);
      await store.clear();
      await transaction.completed;
      
      Debug.log('✅ IndexedDB 中的所有图片数据已清空');
      return true;
      
    } catch (e) {
      Debug.logError('❌ 清空 IndexedDB 图片数据失败', e);
      return false;
    }
  }
  
  /// 获取存储的图片数量
  Future<int> getImageCount() async {
    if (!_isInitialized.value || _database == null) {
      return 0;
    }
    
    try {
      final transaction = _database!.transaction([_storeName], 'readonly');
      final store = transaction.objectStore(_storeName);
      final count = await store.count();
      return count;
    } catch (e) {
      Debug.logError('❌ 获取图片数量失败', e);
      return 0;
    }
  }
  
  /// 获取存储的总大小（字节）
  Future<int> getTotalSize() async {
    if (!_isInitialized.value || _database == null) {
      return 0;
    }
    
    try {
      final transaction = _database!.transaction([_storeName], 'readonly');
      final store = transaction.objectStore(_storeName);
      final cursor =  store.openCursor();
      
      int totalSize = 0;
      await for (final cursorWithValue in cursor) {
        final record = cursorWithValue.value as Map<String, dynamic>;
        totalSize += record['size'] as int;
      }
      
      return totalSize;
    } catch (e) {
      Debug.logError('❌ 获取存储总大小失败', e);
      return 0;
    }
  }
  
  /// 获取所有图片的 MD5 列表
  Future<List<String>> getAllImageMd5s() async {
    if (!_isInitialized.value || _database == null) {
      return [];
    }
    
    try {
      final transaction = _database!.transaction([_storeName], 'readonly');
      final store = transaction.objectStore(_storeName);
      final cursor =  store.openCursor();
      
      final List<String> md5List = [];
      await for (final cursorWithValue in cursor) {
        final record = cursorWithValue.value as Map<String, dynamic>;
        md5List.add(record['md5'] as String);
      }
      
      return md5List;
    } catch (e) {
      Debug.logError('❌ 获取图片 MD5 列表失败', e);
      return [];
    }
  }
  
  /// 打印存储统计信息
  Future<void> printStorageStats() async {
    if (!_isInitialized.value) {
      Debug.log('⚠️ IndexedDB 未初始化');
      return;
    }
    
    try {
      final count = await getImageCount();
      final totalSize = await getTotalSize();
      final avgSize = count > 0 ? (totalSize / count).round() : 0;
      
      Debug.log('📊 ===== IndexedDB 存储统计 =====');
      Debug.log('📈 存储图片数量: $count/$maxImageCount');
      Debug.log('💾 存储总大小: ${_formatBytes(totalSize)}');
      Debug.log('📏 平均图片大小: ${_formatBytes(avgSize)}');
      Debug.log('🗄️ 数据库名称: $_dbName');
      Debug.log('📦 对象存储: $_storeName');
      Debug.log('📊 =============================');
      
    } catch (e) {
      Debug.logError('❌ 打印存储统计信息失败', e);
    }
  }
  
  /// 获取存储限制信息
  Map<String, dynamic> getStorageLimits() {
    return {
      'maxImageCount': maxImageCount,
      'batchDeleteCount': batchDeleteCount,
      'currentCount': 0, // 需要在调用时异步获取
      'remainingCount': maxImageCount,
    };
  }
  
  /// 手动触发批量清理
  /// 当存储接近上限时，可以主动清理
  Future<int> manualBatchCleanup() async {
    if (!_isInitialized.value || _database == null) {
      return 0;
    }
    
    try {
      final currentCount = await getImageCount();
      if (currentCount <= maxImageCount) {
        Debug.log('📊 当前图片数量: $currentCount，无需清理');
        return 0;
      }
      
      Debug.log('🧹 手动触发批量清理，当前数量: $currentCount');
      await _enforceStorageLimits();
      
      final newCount = await getImageCount();
      final deletedCount = currentCount - newCount;
      Debug.log('✅ 手动清理完成，删除了 $deletedCount 张图片');
      return deletedCount;
      
    } catch (e) {
      Debug.logError('❌ 手动批量清理失败', e);
      return 0;
    }
  }
  
  /// 格式化字节数显示
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  /// 执行存储限制检查
  /// 当图片数量超过限制时，批量删除最旧的图片
  Future<void> _enforceStorageLimits() async {
    if (!_isInitialized.value || _database == null) {
      return;
    }
    
    try {
      final currentCount = await getImageCount();
      if (currentCount > maxImageCount) {
        Debug.log('📊 当前图片数量: $currentCount，超过限制 $maxImageCount，开始批量清理...');
        
        // 获取所有图片按时间排序
        final transaction = _database!.transaction([_storeName], 'readonly');
        final store = transaction.objectStore(_storeName);
        final cursor =  store.openCursor();
        
        final List<Map<String, dynamic>> imageRecords = [];
        await for (final cursorWithValue in cursor) {
          final record = cursorWithValue.value as Map<String, dynamic>;
          imageRecords.add(record);
        }
        
        // 按时间戳排序（最旧的在前）
        imageRecords.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
        
        // 批量删除最旧的图片
        final imagesToDeleteList = imageRecords.take(batchDeleteCount).toList();
        
        // 删除最旧的图片
        final deleteTransaction = _database!.transaction([_storeName], 'readwrite');
        final deleteStore = deleteTransaction.objectStore(_storeName);
        
        for (final record in imagesToDeleteList) {
          final md5 = record['md5'] as String;
          await deleteStore.delete(md5);
        }
        
        await deleteTransaction.completed;
        Debug.log('✅ 批量清理完成，删除了 ${imagesToDeleteList.length} 张旧图片');
      }
    } catch (e) {
      Debug.logError('❌ 执行存储限制失败', e);
    }
  }
}
