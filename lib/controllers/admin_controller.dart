import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../screens/admin/order_management_screen.dart';
import '../screens/admin/product_management_screen.dart';
import '../screens/admin/product_category_management_screen.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/shop_settings_screen.dart';
import '../screens/admin/statistics_page.dart';
import '../services/user_service.dart';

/// Admin页面控制器
/// 管理admin页面的状态和切换
class AdminController extends GetxController {
  static AdminController get instance => Get.find<AdminController>();
  
  // 当前选中的admin页面类型
  final Rx<AdminPageType> _currentPageType = AdminPageType.orderManagement.obs;
  
  // 当前显示的admin页面
  Widget get currentAdminPage {
    switch (_currentPageType.value) {
      case AdminPageType.orderManagement:
        return const OrderManagementScreen();
      case AdminPageType.productManagement:
        return const ProductManagementScreen();
      case AdminPageType.productCategories:
        return const ProductCategoryManagementScreen();
      case AdminPageType.userManagement:
        return const UserManagementScreen();
      case AdminPageType.statistics:
        return StatisticsPage();
      case AdminPageType.shopSettings:
        return const ShopSettingsScreen();
    }
  }
  
  // 获取当前页面类型
  AdminPageType get currentPageType => _currentPageType.value;
  
  // 切换到指定页面
  void switchToPage(AdminPageType pageType) {
    _currentPageType.value = pageType;
  }
  
  // 检查是否有权限访问指定页面
  bool hasPermissionForPage(AdminPageType pageType) {
    final userService = UserService.instance;
    
    // 超级管理员有所有权限
    if (userService.isSuperAdmin) {
      return true;
    }
    
    // 检查admin权限
    switch (pageType) {
      case AdminPageType.orderManagement:
        return userService.canManageOrders;
      case AdminPageType.productManagement:
        return userService.canManageProducts;
      case AdminPageType.productCategories:
        return userService.canManageProducts;
      case AdminPageType.statistics:
        return userService.canViewAnalytics;
      case AdminPageType.userManagement:
        return userService.isAdmin;
      case AdminPageType.shopSettings:
        return false; // 只有超级管理员可以访问
    }
  }
  
  // 获取可用的admin页面列表
  List<AdminPageType> getAvailablePages() {
    return AdminPageType.values.where((pageType) => hasPermissionForPage(pageType)).toList();
  }
  
  // 切换到订单管理页面
  void switchToOrderManagement() {
    if (hasPermissionForPage(AdminPageType.orderManagement)) {
      switchToPage(AdminPageType.orderManagement);
    }
  }
  
  // 重置到订单管理页面
  void resetToOrderManagement() {
    if (hasPermissionForPage(AdminPageType.orderManagement)) {
      switchToPage(AdminPageType.orderManagement);
    } else {
      // 如果没有订单管理权限，按优先级跳转到其他有权限的页面
      final availablePages = _getPrioritizedAvailablePages();
      if (availablePages.isNotEmpty) {
        switchToPage(availablePages.first);
      }
    }
  }

  /// 获取按优先级排序的可用页面列表
  List<AdminPageType> _getPrioritizedAvailablePages() {
    // 定义页面优先级顺序
    final List<AdminPageType> priorityOrder = [
      AdminPageType.orderManagement,      // 订单管理 - 最高优先级
      AdminPageType.productManagement,   // 商品管理
      AdminPageType.userManagement,      // 用户管理
      AdminPageType.statistics,          // 数据统计
      AdminPageType.productCategories,   // 商品分类
      AdminPageType.shopSettings,        // 店铺设置
    ];
    
    // 按优先级顺序返回有权限的页面
    return priorityOrder.where((pageType) => hasPermissionForPage(pageType)).toList();
  }
}

/// Admin页面类型枚举
enum AdminPageType {
  orderManagement,
  productManagement,
  productCategories,
  userManagement,
  statistics,
  shopSettings,
}
