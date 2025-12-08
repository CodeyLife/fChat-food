import 'dart:async';
import '../utils/file_utils.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import 'package:fchatapi/util/Tools.dart';
import 'package:fchatapi/webapi/FChatFileObj.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/debug.dart';

class ProductService {
  static final List<CoffeeProduct> _products = [];
  static bool _isInitialized = false;

  /// 获取所有商品
  static List<CoffeeProduct> get products => List.unmodifiable(_products);

  /// 是否已初始化
  static bool get isInitialized => _isInitialized;
  

  /// 初始化商品服务
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadProducts();
      _isInitialized = true;
      PhoneUtil.applog('商品服务初始化完成，加载了 ${_products.length} 个商品');
    } catch (e) {
      PhoneUtil.applog('商品服务初始化失败: $e');
      rethrow;
    }
  }

  /// 从文件系统加载商品列表
  static Future<void> _loadProducts() async {
    try {
  
      var files = await FileUtils.readDirectory(AppConstants.product);
      _products.clear();
      for (Map<String, dynamic> file in files) {
        try {
          // 创建商品对象
          CoffeeProduct product = CoffeeProduct.fromJson(file);
                _products.add(product);

              }
               catch (e) {
                PhoneUtil.applog("解析商品文件失败 ${file['filename']}: $e");
                // 继续处理其他文件，不中断整个加载过程
              }
        } 
      
      
    } catch (e) {
      PhoneUtil.applog('加载商品列表失败: $e');
      rethrow;
    }
  }

  /// 保存商品到文件系统
  static Future<bool> saveProduct(CoffeeProduct product) async {
    try {
      FChatFileObj fileObj = FChatFileObj();
      fileObj.filemd = AppConstants.product;
      
      // 确保商品有有效的ID（防止空ID导致覆盖）
      if (product.id.isEmpty) {
        product.id = Tools.generateRandomString(30);
      }
      
      // 更新修改时间
      product.updatedAt = DateTime.now();
      
      PhoneUtil.applog('保存商品: ${product.name}, ID: ${product.id}');
      
      // 调试：打印要保存的数据
      String productData = product.toString();
      PhoneUtil.applog('商品数据内容: $productData');
      
      await FileUtils.updateFile(AppConstants.product, product.id, productData);

      
      // 更新本地列表
      int index = _products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        _products[index] = product;
        Debug.log('更新现有商品: ${product.name}');
      } else {
        _products.add(product);
        Debug.log('添加新商品: ${product.name}');
      }
      
      return true;
    } catch (e) {
      Debug.logError('保存商品失败: $e', Exception('保存商品失败'));
      return false;
    }
  }


    /// 删除商品
  static Future<bool> deleteProduct(CoffeeProduct product) async {
    try {
      if (product.id.isNotEmpty) {
        await FileUtils.deleteFile(AppConstants.product, product.id);
      }
    
      // 从本地列表移除
      _products.removeWhere((p) => p.id == product.id);
      
      Debug.log('商品删除成功: ${product.name}');
      return true;
    } catch (e) {
      Debug.logError('删除商品失败: $e', Exception('删除商品失败'));
      return false;
    }
  }

  /// 批量更新商品状态
  static Future<bool> updateProductsStatus(List<String> productIds, bool status) async {
    try {
      List<Future<bool>> saveFutures = [];
      
      for (String productId in productIds) {
        CoffeeProduct? product = _products.firstWhere(
          (p) => p.id == productId,
          orElse: () => throw Exception('商品不存在: $productId'),
        );
        
        product.status = status;
        product.updatedAt = DateTime.now();
        
        saveFutures.add(saveProduct(product));
      }
      
      List<bool> results = await Future.wait(saveFutures);
      bool allSuccess = results.every((result) => result);
      
      Debug.log('批量更新商品状态完成: $allSuccess');
      return allSuccess;
    } catch (e) {
      Debug.logError('批量更新商品状态失败: $e', Exception('批量更新商品状态失败'));
      return false;
    }
  }

  /// 更新单个商品状态
  static Future<bool> updateProductStatus(String productId, bool status) async {
    try {
      CoffeeProduct? product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('商品不存在: $productId'),
      );
      
      product.status = status;
      product.updatedAt = DateTime.now();
      
      bool success = await saveProduct(product);
      
      if (success) {
        Debug.log('商品状态更新成功: ${product.name} -> ${status ? "上架" : "下架"}');
      } else {
        Debug.logError('商品状态更新失败: ${product.name}', Exception('商品状态更新失败'));
      }
      
      return success;
    } catch (e) {
      Debug.logError('更新商品状态失败: $e', Exception('更新商品状态失败'));
      return false;
    }
  }

  /// 更新商品审核状态
  static Future<bool> updateProductApprovalStatus(String productId, ProductApprovalStatus approvalStatus) async {
    try {
      CoffeeProduct? product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('商品不存在: $productId'),
      );
      
      product.updateApprovalStatus(approvalStatus);
      
      bool success = await saveProduct(product);
      
      if (success) {
          Debug.log('商品审核状态更新成功: ${product.name} -> ${approvalStatus.name}');
      } else {
        Debug.logError('商品审核状态更新失败: ${product.name}', Exception('商品审核状态更新失败'));
      }
      
      return success;
    } catch (e) {
      Debug.logError('更新商品审核状态失败: $e', Exception('更新商品审核状态失败'));
      return false;
    }
  }

  /// 根据ID获取商品
  static CoffeeProduct? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 根据分类获取商品（仅显示已通过审核的商品）
  static List<CoffeeProduct> getProductsByCategory(String category) {
    return _products.where((p) => p.category == category && p.status && p.approvalStatus == ProductApprovalStatus.approved).toList();
  }

  /// 获取上架商品（仅显示已通过审核的商品）
  static List<CoffeeProduct> getActiveProducts() {
    return _products.where((p) => p.status && p.approvalStatus == ProductApprovalStatus.approved).toList();
  }

  /// 获取最新的活跃商品（按发布时间降序排序，限制数量）
  /// [limit] 返回的商品数量，默认为10
  static List<CoffeeProduct> getLatestActiveProducts(int limit) {
    final activeProducts = _products.where((p) => p.status && p.approvalStatus == ProductApprovalStatus.approved).toList();
    // 按 createdAt 降序排序（最新的在前）
    activeProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // 返回前 limit 个商品
    return activeProducts.take(limit).toList();
  }

  /// 获取下架商品
  static List<CoffeeProduct> getInactiveProducts() {
    return _products.where((p) => !p.status).toList();
  }

  /// 获取待审核商品
  static List<CoffeeProduct> getPendingApprovalProducts() {
    return _products.where((p) => p.approvalStatus == ProductApprovalStatus.pending).toList();
  }

  /// 获取已通过审核商品
  static List<CoffeeProduct> getApprovedProducts() {
    return _products.where((p) => p.approvalStatus == ProductApprovalStatus.approved).toList();
  }

  /// 获取被拒绝商品
  static List<CoffeeProduct> getRejectedProducts() {
    return _products.where((p) => p.approvalStatus == ProductApprovalStatus.rejected).toList();
  }

  /// 搜索商品（仅显示已通过审核的商品）
  static List<CoffeeProduct> searchProducts(String query) {
    if (query.isEmpty) return getActiveProducts();
    
    return _products.where((product) {
      return product.status && 
             product.approvalStatus == ProductApprovalStatus.approved &&
             (product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.description.toLowerCase().contains(query.toLowerCase()) ||
              product.category.toLowerCase().contains(query.toLowerCase()));
    }).toList();
  }

  /// 刷新商品列表
  static Future<void> refreshProducts() async {
    _isInitialized = false;
    await initialize();
  }

  /// 获取商品统计信息
  static Map<String, int> getProductStats() {
    return {
      'total': _products.length,
      'active': _products.where((p) => p.status).length,
      'inactive': _products.where((p) => !p.status).length,
      'pending': _products.where((p) => p.approvalStatus == ProductApprovalStatus.pending).length,
      'approved': _products.where((p) => p.approvalStatus == ProductApprovalStatus.approved).length,
      'rejected': _products.where((p) => p.approvalStatus == ProductApprovalStatus.rejected).length,
      'categories': _products.map((p) => p.category).toSet().length,
    };
  }


}
