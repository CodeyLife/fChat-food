import 'package:fchatapi/FChatApiSdk.dart';
import 'package:fchatapi/webapi/WebUtil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/config_service.dart';
import '../utils/debug.dart';
import 'home_screen.dart';
import 'menu_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'download_app_screen.dart';
import '../services/cart_service.dart';
import '../services/app_state_service.dart';
import '../services/order_monitor_service.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../utils/loading_util.dart';
import '../utils/location.dart';
import '../utils/screen_util.dart';
import '../widgets/landscape_navigation.dart';
import '../controllers/admin_controller.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 基础页面列表（不包含admin）
  final List<Widget> _baseScreens = [
    const HomeScreen(),
    const MenuScreen(),
    const CartScreen(),
    const OrdersScreen(),
    const ProfileScreen(),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // WeChat检测状态
  bool _isWeChat = false;
  
  // Admin菜单项
  final List<String> _adminCategories = [
    'Order Management', 
    'Product Management', 
    'Product Categories', 
    'User Management', 
    'Data Statistics', 
    'Shop Setting'
  ];

  // 获取当前可用的页面列表
  List<Widget> get _screens {
    final userService = Get.find<UserService>();
    final isAdmin = userService.isAdmin || userService.isSuperAdmin;
    
    if (isAdmin) {
      final adminController = _getOrCreateAdminController();
      final adminPage = adminController.currentAdminPage;
      return [..._baseScreens, adminPage];
    }
    return _baseScreens;
  }

  @override
  void initState() {
    super.initState();
    // 关闭loading动画
    LoadingUtil.clearLoading();
    
    // 检测WeChat浏览器
    _isWeChat = WebUtil.isWecHAT();
    
    // 监听应用状态变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appStateService = Provider.of<AppStateService>(context, listen: false);
      appStateService.addListener(_onAppStateChanged);
    //  Debug.log('isTest: ${ConfigService.isTest}');
      // 检测FchatapiSdk.isFchatBrower
      if(!FChatApiSdk.isFchatBrower && !ConfigService.isTest){
        if(!WebUtil.isMobileiBrowser()){
          Get.dialog(UserService.instance.scanlogin(context));
        }
      }
    });

  }

  @override
  void dispose() {
    // 检查widget是否仍然mounted，避免在dispose时访问无效的context
    if (mounted) {
      try {
        final appStateService = Provider.of<AppStateService>(context, listen: false);
        appStateService.removeListener(_onAppStateChanged);
      } catch (e) {
        // 如果context已经无效，忽略错误
        Debug.logError('Warning: Could not remove listener in dispose: ',e);
      }
    }
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 切换到订单页面
  void switchToOrdersPage() {
    final appStateService = Provider.of<AppStateService>(context, listen: false);
    appStateService.switchToPage(3);
  }

  /// 显示admin菜单选择
  void _showAdminMenu(BuildContext context) {
    if (AppScreenUtil.isLandscape(context)) {
      // 宽屏模式：打开左对齐drawer
      _scaffoldKey.currentState?.openDrawer();
    } else {
      // 窄屏模式：打开右对齐endDrawer
      _scaffoldKey.currentState?.openEndDrawer();
    }
  }

  /// 构建WeChat下载提示横幅
  Widget _buildWeChatBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.orange[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.orange[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange[700],
            size: 20.r,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              LocationUtils.translate('Download our app for better experience'),
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: _handleDownloadApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              LocationUtils.translate('Download'),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        
        ],
      ),
    );
  }

  /// 处理下载App
  Future<void> _handleDownloadApp() async {
    try {
      final uri = Uri.parse(DownloadAppScreen.downloadUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          _showDownloadErrorDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        _showDownloadErrorDialog();
      }
    }
  }

  /// 显示下载错误对话框
  void _showDownloadErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Error')),
        content: Text(LocationUtils.translate('Unable to open download link')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocationUtils.translate('OK')),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<AppStateService>(
        builder: (context, appStateService, child) {
          return GetX<UserService>(
            builder: (userService) {
              final isAdmin = userService.isAdmin;
              final currentIndex = appStateService.currentPageIndex;
              final validIndex = currentIndex < _screens.length ? currentIndex : 0;
              final isLandscape = AppScreenUtil.isLandscape(context);
              final isAdminPage = isAdmin && validIndex == _baseScreens.length;
              
              return _buildScaffold(context, validIndex, appStateService, isAdmin, isLandscape, isAdminPage);
            },
          );
        },
      ),
    );
  }

  /// 构建Scaffold
  Widget _buildScaffold(BuildContext context, int validIndex, AppStateService appStateService, 
      bool isAdmin, bool isLandscape, bool isAdminPage) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: isAdmin && isLandscape ? _buildAdminDrawer(context) : null,
      endDrawer: isAdmin && !isLandscape ? _buildAdminEndDrawer(context) : null,
      body: Column(
        children: [
          if (_isWeChat) _buildWeChatBanner(),
          Expanded(
            child: isAdminPage 
              ? GetX<AdminController>(
                  builder: (adminController) => _buildLayout(context, validIndex, appStateService, isAdmin, isLandscape)
                )
              : _buildLayout(context, validIndex, appStateService, isAdmin, isLandscape),
          ),
        ],
      ),
      // 使用标准的 bottomNavigationBar 属性
      bottomNavigationBar: !isLandscape ? _buildBottomNavigationBar(context, validIndex, appStateService, isAdmin) : null,
    );
  }

  /// 构建布局
  Widget _buildLayout(BuildContext context, int validIndex, AppStateService appStateService, 
      bool isAdmin, bool isLandscape) {
    return isLandscape 
      ? _buildLandscapeLayout(context, validIndex, appStateService, isAdmin)
      : _buildPortraitLayout(context, validIndex, appStateService, isAdmin);
  }

  /// 构建竖屏布局
  Widget _buildPortraitLayout(BuildContext context, int validIndex, AppStateService appStateService, bool isAdmin) {
    // 现在只需要返回屏幕内容，底部导航栏由 Scaffold 的 bottomNavigationBar 处理
    return _screens[validIndex];
  }

  /// 构建横屏布局
  Widget _buildLandscapeLayout(BuildContext context, int validIndex, AppStateService appStateService, bool isAdmin) {
    return Row(
      children: [
        // 左侧导航栏
        LandscapeNavigation(
          currentIndex: validIndex,
          onTap: (index) {
            // 如果是admin按钮且是管理员，总是显示菜单
            if (isAdmin && index == _baseScreens.length) {
              _showAdminMenu(context);
            } else {
              appStateService.switchToPage(index);
            }
          },
        ),
        // 右侧内容区域
        Expanded(
          child: _screens[validIndex],
        ),
      ],
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar(BuildContext context, int validIndex, AppStateService appStateService, bool isAdmin) {
    return Obx(() {
      final cartController = Get.find<CartController>();
      return BottomNavigationBar(
        currentIndex: validIndex,
        onTap: (index) {
          // 如果是admin按钮且是管理员，总是显示菜单
          if (isAdmin && index == _baseScreens.length) {
            _showAdminMenu(context);
          } else {
            appStateService.switchToPage(index);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.textSecondary,
        elevation: 12,
        items: _buildNavigationItems(cartController, appStateService, isAdmin),
      );
    });
  }

  /// 构建带角标的购物车图标
  Widget _buildCartIconWithBadge(int itemCount, bool isSelected) {
    return _buildIconWithBadge(
      isSelected ? Icons.shopping_cart : Icons.shopping_cart_outlined,
      isSelected,
      itemCount > 0 ? (itemCount > 99 ? '99+' : itemCount.toString()) : null,
      isNumberBadge: true,
    );
  }

  /// 构建带提醒的订单图标
  Widget _buildOrderIconWithBadge(bool isSelected) {
    return Consumer<AppStateService>(
      builder: (context, appStateService, child) {
        return _buildIconWithBadge(
          isSelected ? Icons.receipt_long : Icons.receipt_long_outlined,
          isSelected,
          OrderMonitorService.instance.hasAnyOrderChanges ? '' : null,
        );
      },
    );
  }

  /// 构建带提醒的管理图标
  Widget _buildAdminIconWithBadge(bool isSelected) {
    return Consumer<AppStateService>(
      builder: (context, appStateService, child) {
        return _buildIconWithBadge(
          isSelected ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
          isSelected,
          OrderMonitorService.instance.hasAnyOrderChanges ? '' : null,
        );
      },
    );
  }

  /// 通用图标构建方法
  Widget _buildIconWithBadge(IconData icon, bool isSelected, String? badgeText, {bool isNumberBadge = false}) {
    return Stack(
      children: [
        Icon(
          icon,
          color: isSelected ? AppTheme.primaryBlue : null,
        ),
        if (badgeText != null)
          Positioned(
            right: 0,
            top: 0,
            child: isNumberBadge 
              ? _buildNumberBadge(badgeText)
              : _buildDotBadge(),
          ),
      ],
    );
  }

  /// 构建数字角标
  Widget _buildNumberBadge(String text) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 构建圆点角标
  Widget _buildDotBadge() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }

  /// 构建导航项列表
  List<BottomNavigationBarItem> _buildNavigationItems(
    CartController cartController, 
    AppStateService appStateService, 
    bool isAdmin
  ) {
    final items = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: LocationUtils.translate('Home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.restaurant_menu_outlined),
        activeIcon: const Icon(Icons.restaurant_menu),
        label: LocationUtils.translate('Menu'),
      ),
      BottomNavigationBarItem(
        icon: _buildCartIconWithBadge(cartController.itemCount, false),
        activeIcon: _buildCartIconWithBadge(cartController.itemCount, true),
        label: LocationUtils.translate('Cart'),
      ),
      BottomNavigationBarItem(
        icon: _buildOrderIconWithBadge(false),
        activeIcon: _buildOrderIconWithBadge(true),
        label: LocationUtils.translate('Orders'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: LocationUtils.translate('Profile'),
      ),
    ];

    // 只有管理员才显示Admin选项
    if (isAdmin) {
      items.add(
        BottomNavigationBarItem(
          icon: _buildAdminIconWithBadge(false),
          activeIcon: _buildAdminIconWithBadge(true),
          label: LocationUtils.translate('Admin'),
        ),
      );
    }

    return items;
  }

  /// 构建Admin Drawer - 限制宽度避免覆盖导航栏
  Widget _buildAdminDrawer(BuildContext context) {
    return _buildAdminDrawerContent(context, _calculateDrawerWidth(context));
  }

  /// 构建EndDrawer - 用于窄屏模式右对齐
  Widget _buildAdminEndDrawer(BuildContext context) {
    return _buildAdminDrawerContent(context, 200.w);
  }

  /// 计算Drawer宽度
  double _calculateDrawerWidth(BuildContext context) {
    if (AppScreenUtil.isLandscape(context)) {
      // 横屏模式：限制drawer宽度，确保不覆盖左侧导航栏
      final screenWidth = MediaQuery.of(context).size.width;
      final navWidth = AppScreenUtil.getLandscapeNavWidth();
      final calculatedWidth = (screenWidth - navWidth) * 0.6; // 使用剩余空间的60%
      return calculatedWidth > 200.w ? 200.w : calculatedWidth;
    } else {
      // 竖屏模式：使用标准宽度
      return 200.w;
    }
  }

  /// 构建Drawer内容 - 统一处理
  Widget _buildAdminDrawerContent(BuildContext context, double width) {
    return Drawer(
      width: width,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
          ),
          child: Column(
            children: [
              _buildDrawerHeader(),
              _buildDrawerMenuItems(),
              _buildDrawerFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建Drawer头部
  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20.r),
          bottomRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 36.r,
            color: Colors.white,
          ),
          SizedBox(height: 8.h),
          Text(
            LocationUtils.translate('Admin Dashboard'),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            LocationUtils.translate('Management Center'),
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建Drawer菜单项
  Widget _buildDrawerMenuItems() {
    return Expanded(
      child: GetX<AdminController>(
        builder: (adminController) {
          final availablePages = adminController.getAvailablePages();
          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            itemCount: availablePages.length,
            itemBuilder: (context, index) {
              final pageType = availablePages[index];
              final pageIndex = _getIndexByPageType(pageType);
              return Container(
                margin: EdgeInsets.symmetric(vertical: 2.h, horizontal: 8.w),
                child: ListTile(
                  onTap: () {
                    Navigator.pop(context); // 关闭drawer
                    _selectAdminPage(pageIndex);
                  },
                  leading: Icon(
                    _getCategoryIcon(pageIndex),
                    color: AppTheme.primaryBlue,
                    size: 24.w,
                  ),
                  title: Text(
                    LocationUtils.translate(_adminCategories[pageIndex]),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  hoverColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 构建Drawer底部
  Widget _buildDrawerFooter() {
    return Container(
      padding: EdgeInsets.all(16.r),
      child: Text(
        'Shop Admin ${ConfigService.appVersion}',
        style: TextStyle(
          fontSize: 10.sp,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  /// 获取分类图标
  IconData _getCategoryIcon(int index) {
    switch (index) {
      case 0: return Icons.receipt_long; // Order Management
      case 1: return Icons.inventory_2; // Product Management
      case 2: return Icons.category; // Product Categories
      case 3: return Icons.people; // User Management
      case 4: return Icons.folder; // File Management
      case 5: return Icons.analytics; // Data Statistics
      case 6: return Icons.store; // Shop Setting
      default: return Icons.settings;
    }
  }

  /// 获取或创建AdminController
  AdminController _getOrCreateAdminController() {
    try {
      
      return Get.find<AdminController>();
      
    } catch (e) {
      return Get.put(AdminController(), permanent: true);
    }
  }

  /// 选择admin页面
  void _selectAdminPage(int index) {
    final adminController = _getOrCreateAdminController();
    final pageType = _getPageTypeByIndex(index);
    
    adminController.switchToPage(pageType);
    // 切换到admin页面
    final appStateService = Provider.of<AppStateService>(context, listen: false);
    appStateService.switchToPage(_baseScreens.length);
  }

  /// 根据索引获取页面类型
  AdminPageType _getPageTypeByIndex(int index) {
    switch (index) {
      case 0: return AdminPageType.orderManagement;
      case 1: return AdminPageType.productManagement;
      case 2: return AdminPageType.productCategories;
      case 3: return AdminPageType.userManagement;
      case 4: return AdminPageType.statistics;
      case 5: return AdminPageType.shopSettings;
      default: return AdminPageType.orderManagement;
    }
  }

  /// 根据页面类型获取索引
  int _getIndexByPageType(AdminPageType pageType) {
    switch (pageType) {
      case AdminPageType.orderManagement: return 0;
      case AdminPageType.productManagement: return 1;
      case AdminPageType.productCategories: return 2;
      case AdminPageType.userManagement: return 3;
      case AdminPageType.statistics: return 4;
      case AdminPageType.shopSettings: return 5;
    }
  }
}
