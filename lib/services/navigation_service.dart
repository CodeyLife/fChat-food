import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/debug.dart';
import 'app_state_service.dart';
import '../controllers/admin_controller.dart';

/// 导航服务
/// 提供全局导航功能
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  static void switchPage(int page) {
    AppStateService().switchToPage(page);
  }

  /// 切换到订单页面
  static void switchToOrdersPage() {
     AppStateService().switchToPage(3);
     Get.until((route) => route.isFirst);
    }
  

  /// 切换到admin订单管理页面
  static void switchToAdminOrderManagement() {
    Debug.log('NavigationService: 切换到admin订单管理页面');
    Get.until((route) => route.isFirst);
    AppStateService().switchToPage(5);
    Get.find<AdminController>().switchToOrderManagement();
  }

  /// 切换到admin页面并检查权限
  static void switchToAdminWithPermissionCheck() {
    Debug.log('NavigationService: 切换到admin页面并检查权限');
    Get.until((route) => route.isFirst);
    AppStateService().switchToPage(5);
    
    // 获取AdminController实例
    final adminController = Get.find<AdminController>();
    
    // 优先检查订单管理权限
    if (adminController.hasPermissionForPage(AdminPageType.orderManagement)) {
      Debug.log('用户有订单管理权限，跳转到订单管理页面');
      adminController.switchToOrderManagement();
    } else {
      Debug.log('用户没有订单管理权限，查找其他可用页面');
      // 如果没有订单管理权限，按优先级查找其他有权限的页面
      final availablePages = _getPrioritizedAvailablePages(adminController);
      if (availablePages.isNotEmpty) {
        Debug.log('找到可用页面: ${availablePages.first}');
        adminController.switchToPage(availablePages.first);
      } else {
        Debug.log('没有找到任何可用页面，显示权限不足提示');
        // 如果没有可用页面，显示权限不足的提示
        _showPermissionDeniedDialog();
      }
    }
  }

  /// 获取按优先级排序的可用页面列表
  static List<AdminPageType> _getPrioritizedAvailablePages(AdminController adminController) {
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
    return priorityOrder.where((pageType) => adminController.hasPermissionForPage(pageType)).toList();
  }

  /// 显示权限不足的对话框
  static void _showPermissionDeniedDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('权限不足'),
        content: const Text('您没有访问任何管理页面的权限，请联系超级管理员。'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // 关闭对话框
              Get.back(); // 返回到主页面
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

}

