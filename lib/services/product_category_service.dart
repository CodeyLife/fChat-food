import 'dart:async';

import '../utils/file_utils.dart';
import 'package:fchatapi/util/JsonUtil.dart';
import '../utils/constants.dart';
import '../utils/debug.dart';

/// 简单的商品分类管理服务
class ProductCategoryService {
  static const String categoriesFileName = 'categories.json';
  static List<String> _categories = [];
  static bool _isInitialized = false;
  /// 初始化分类服务
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {

      // 读取分类数据
      await _loadCategoriesFromFile();

      _isInitialized = true;

    } catch (e) {
      Debug.log('ProductCategoryService.initialize - 初始化失败: $e');
      // 如果加载失败，创建默认分类
      await FileUtils.clearDirectory(AppConstants.productlabels);
      await _createDefaultCategories();
      _isInitialized = true;
    }
  }

  /// 从文件加载分类数据
  static Future<void> _loadCategoriesFromFile() async {
    try {

      var datamap = await FileUtils.readFile(AppConstants.productlabels, categoriesFileName);
      if (datamap != null && datamap.containsKey('categories')) {
        var categoriesData = datamap['categories'];
        if (categoriesData != null && categoriesData is List) {
          _categories = categoriesData.cast<String>().toList();
        } else {
          await _createDefaultCategories();
        }
      } else {
        await _createDefaultCategories();
      }
    } catch (e) {
      Debug.log('ProductCategoryService._loadCategoriesFromFile - 加载失败: $e');
      await FileUtils.clearDirectory(AppConstants.productlabels);
      await _createDefaultCategories();
    }
  }

  /// 创建默认分类
  static Future<void> _createDefaultCategories() async {
    _categories = ['咖啡', '茶饮', '甜品', '轻食'];
    Debug.log('ProductCategoryService._createDefaultCategories - 创建默认分类: $_categories');
    await saveCategoriesToFile();
  }

  /// 保存分类到文件
  static Future<bool> saveCategoriesToFile() async {
    try {
      Debug.log('ProductCategoryService.saveCategoriesToFile - 开始保存分类数据');
      
      final jsonData = {'categories': _categories};
      final jsonString = JsonUtil.maptostr(jsonData);
       Debug.log(jsonString);
       return await FileUtils.updateFile(AppConstants.productlabels, categoriesFileName, jsonString);

    } catch (e) {
      Debug.log('ProductCategoryService.saveCategoriesToFile - 保存失败: $e');
      return false;
    }
  }

  /// 获取所有分类
  static List<String> getAllCategories() {
    if (!_isInitialized) {
      Debug.log('ProductCategoryService.getAllCategories - 服务未初始化');
      return [];
    }
    return List.from(_categories);
  }

  /// 添加分类
  static Future<bool> addCategory(String category) async {
    if (!_isInitialized) {
      Debug.log('ProductCategoryService.addCategory - 服务未初始化');
      return false;
    }

    if (_categories.contains(category)) {
      Debug.log('ProductCategoryService.addCategory - 分类已存在: $category');
      return false;
    }

    try {
      _categories.add(category);
      final success = await saveCategoriesToFile();
      
      if (success) {
        Debug.log('ProductCategoryService.addCategory - 分类添加成功: $category');
      } else {
        Debug.log('ProductCategoryService.addCategory - 分类添加失败，文件保存失败');
        // 回滚操作
        _categories.remove(category);
      }
      
      return success;
    } catch (e) {
      Debug.log('ProductCategoryService.addCategory - 添加分类失败: $e');
      return false;
    }
  }

  /// 删除分类
  static Future<bool> deleteCategory(String category) async {
    if (!_isInitialized) {
    
      return false;
    }

    if (!_categories.contains(category)) {
    
      return false;
    }

    try {
      _categories.remove(category);
      final success = await saveCategoriesToFile();
      
      if (success) {
        Debug.log('ProductCategoryService.deleteCategory - 分类删除成功: $category');
      } else {
        Debug.log('ProductCategoryService.deleteCategory - 分类删除失败，文件保存失败');
        // 回滚操作
        _categories.add(category);
      }
      
      return success;
    } catch (e) {
      Debug.log('ProductCategoryService.deleteCategory - 删除分类失败: $e');
      return false;
    }
  }

  /// 更新分类
  static Future<bool> updateCategory(String oldCategory, String newCategory) async {
    if (!_isInitialized) {
      Debug.log('ProductCategoryService.updateCategory - 服务未初始化');
      return false;
    }

    if (!_categories.contains(oldCategory)) {
      Debug.log('ProductCategoryService.updateCategory - 原分类不存在: $oldCategory');
      return false;
    }

    if (_categories.contains(newCategory) && oldCategory != newCategory) {
      Debug.log('ProductCategoryService.updateCategory - 新分类已存在: $newCategory');
      return false;
    }

    try {
      final index = _categories.indexOf(oldCategory);
      _categories[index] = newCategory;
      final success = await saveCategoriesToFile();
      
      if (success) {
        Debug.log('ProductCategoryService.updateCategory - 分类更新成功: $oldCategory -> $newCategory');
      } else {
        Debug.log('ProductCategoryService.updateCategory - 分类更新失败，文件保存失败');
        // 回滚操作
        _categories[index] = oldCategory;
      }
      
      return success;
    } catch (e) {
      Debug.log('ProductCategoryService.updateCategory - 更新分类失败: $e');
      return false;
    }
  }

  /// 检查分类是否存在
  static bool hasCategory(String category) {
    if (!_isInitialized) {
      Debug.log('ProductCategoryService.hasCategory - 服务未初始化');
      return false;
    }
    return _categories.contains(category);
  }

  /// 获取分类数量
  static int get categoryCount {
    if (!_isInitialized) {
      Debug.log('ProductCategoryService.categoryCount - 服务未初始化');
      return 0;
    }
    return _categories.length;
  }

  /// 检查服务是否已初始化
  static bool get isInitialized => _isInitialized;
}
