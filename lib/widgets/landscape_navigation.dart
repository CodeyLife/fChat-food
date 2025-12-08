
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../services/cart_service.dart';
import '../services/order_monitor_service.dart';
import '../services/user_service.dart';
import '../services/language_service.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/screen_util.dart';
import 'language_selector.dart';

/// 横屏左侧导航栏组件
class LandscapeNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  
  const LandscapeNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppScreenUtil.getLandscapeNavWidth(),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surface,
            AppTheme.primaryBlue.withValues(alpha: 0.02),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部语言切换区域
          _buildLanguageHeader(context),
          
          // 导航项列表
          Expanded(
            child: _buildNavigationItems(context),
          ),
          
          // 底部用户信息或登录选项
          _buildFooter(context),
        ],
      ),
    );
  }

  /// 构建顶部语言切换区域
  Widget _buildLanguageHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      child: Column(
        children: [
          // 语言切换按钮
          LanguageSelector(
            isCompact: true,
            onLanguageChanged: (String languageCode) {
              // 使用 LanguageService 处理语言切换
              _handleLanguageChange(languageCode);
            },
          ),
        ],
      ),
    );
  }

  /// 处理语言切换
  void _handleLanguageChange(String languageCode) {
    try {
      // 使用 LanguageService 切换语言
      LanguageService.instance.changeLanguage(languageCode);
      

    } catch (e) {
      // 显示错误提示
      _showLanguageChangeError(e.toString());
    }
  }


  /// 显示语言切换错误
  void _showLanguageChangeError(String error) {
    Get.snackbar(
      'Language Change Failed',
      'Failed to change language: $error',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.withValues(alpha: 0.8),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.error, color: Colors.white),
    );
  }

  /// 构建导航项列表
  Widget _buildNavigationItems(BuildContext context) {
    return GetX<UserService>(
      builder: (userService) {
        final isAdmin = userService.isAdmin || userService.isSuperAdmin;
        
        final items = [
          _NavigationItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: LocationUtils.translate('Home'),
            index: 0,
          ),
          _NavigationItem(
            icon: Icons.restaurant_menu_outlined,
            activeIcon: Icons.restaurant_menu,
            label: LocationUtils.translate('Menu'),
            index: 1,
          ),
          _NavigationItem(
            icon: Icons.shopping_cart_outlined,
            activeIcon: Icons.shopping_cart,
            label: LocationUtils.translate('Cart'),
            index: 2,
            badge: _buildCartBadge(),
          ),
          _NavigationItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long,
            label: LocationUtils.translate('Orders'),
            index: 3,
            badge: _buildOrderBadge(),
          ),
          _NavigationItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: LocationUtils.translate('Profile'),
            index: 4,
          ),
        ];

        // 只有管理员才显示Admin选项
        if (isAdmin) {
          items.add(
            _NavigationItem(
              icon: Icons.admin_panel_settings_outlined,
              activeIcon: Icons.admin_panel_settings,
              label: LocationUtils.translate('Admin'),
              index: 5,
              badge: _buildAdminBadge(),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildNavigationItem(context, item);
          },
        );
      },
    );
  }

  /// 构建导航项
  Widget _buildNavigationItem(BuildContext context, _NavigationItem item) {
    final isSelected = currentIndex == item.index;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      child: GestureDetector(
        onTap: () => onTap(item.index),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? AppTheme.primaryGradient
                : LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.primaryBlue.withValues(alpha: 0.02),
                    ],
                  ),
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primaryBlue
                  : AppTheme.primaryBlue.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            children: [
              // 图标和角标
              Stack(
                children: [
                  SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? Colors.white : AppTheme.primaryBlue,
                      size: 20.w,
                    ),
                  ),
                  if (item.badge != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: item.badge!,
                    ),
                ],
              ),
              SizedBox(width: 8.w),
              // 标签文字
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建购物车角标
  Widget _buildCartBadge() {
    return Obx(() {
      final cartController = Get.find<CartController>();
      if (cartController.itemCount <= 0) return const SizedBox.shrink();
      
      return Container(
        width: 16.w,
        height: 16.w,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Center(
          child: Text(
            cartController.itemCount > 99 ? '99+' : cartController.itemCount.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 8.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }

  /// 构建订单角标
  Widget _buildOrderBadge() {
    return Consumer<AppStateService>(
      builder: (context, appStateService, child) {
        if (!OrderMonitorService.instance.hasAnyOrderChanges) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: 8.w,
          height: 8.w,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  /// 构建管理角标
  Widget _buildAdminBadge() {
    return Consumer<AppStateService>(
      builder: (context, appStateService, child) {
        if (!OrderMonitorService.instance.hasAnyOrderChanges) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: 8.w,
          height: 8.w,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  /// 构建底部用户信息或登录选项
  Widget _buildFooter(BuildContext context) {
    return GetX<UserService>(
      builder: (userService) {
        final userInfo = userService.currentUser;
        
        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              if (userInfo != null) ...[
                // 已登录显示用户信息
                CircleAvatar(
                  radius: 16.w,
                  backgroundColor: AppTheme.primaryBlue,
                  backgroundImage: userInfo.avatar != null 
                      ? NetworkImage(userInfo.avatar!) 
                      : null,
                  child: userInfo.avatar == null 
                      ? Icon(
                          Icons.person,
                          size: 16.w,
                          color: Colors.white,
                        )
                      : null,
                ),
                SizedBox(height: 4.h),
                Text(
                  userInfo.username,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                // 未登录显示扫码登录选项
                GestureDetector(
                  onTap: () {
                  
                    Get.dialog(UserService.instance.scanlogin(context));
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppRadius.md,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 14.w,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 导航项数据类
class _NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final Widget? badge;

  const _NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    this.badge,
  });
}
