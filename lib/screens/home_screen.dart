import 'dart:async';
import 'dart:math';

import '../../services/shop_service.dart';
import '../../widgets/async_image_widget.dart';
import 'package:fchatapi/appapi/PromoObj.dart';
import 'package:fchatapi/appapi/GpsApi.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../services/product_service.dart';
import '../services/user_service.dart';
import '../services/cart_service.dart';
import '../services/promo_service.dart';
import '../models/product.dart';
import '../utils/debug.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
import '../utils/image_utils.dart';
import '../utils/location.dart';
import '../utils/screen_util.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/luckin_components.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<CoffeeProduct> _products = [];
  int _currentBannerIndex = 0; // 当前轮播图索引
  final PageController _pageController = PageController(); // PageView控制器
  Timer? _autoScrollTimer; // 自动滚动定时器
  bool _isAutoScrolling = false; // 是否正在自动滚动
  bool _isLoadingProducts = false; // 商品加载状态
  late AnimationController _shimmerController; // 闪烁动画控制器

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();
    _initializeAndLoadProducts();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  /// 初始化商品服务并加载商品
  Future<void> _initializeAndLoadProducts() async {
    if (mounted) {
      setState(() {
        _isLoadingProducts = true;
      });
    }
    try {
      // 先初始化商品服务
      await ProductService.initialize();
      // 然后加载商品
      await _loadProducts();
    } catch (e) {
      if(mounted) {
         Debug.showDataLoadError(context, '商品');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  /// 加载商品列表
  Future<void> _loadProducts() async {
    try {
      final products = await ProductService.initialize().then((_) => ProductService.getLatestActiveProducts(10));
      
      // 只有在数据真正变化时才更新UI
      if (mounted && _products.length != products.length) {
        setState(() {
          _products = products;
        });
        Debug.log('成功加载最新 ${products.length} 个推荐商品');
      } else if (mounted) {
        // 即使数量相同，也要检查内容是否变化
        bool hasChanged = false;
        for (int i = 0; i < products.length && i < _products.length; i++) {
          if (_products[i].id != products[i].id) {
            hasChanged = true;
            break;
          }
        }
        
        if (hasChanged) {
          setState(() {
            _products = products;
          });
          Debug.log('推荐商品列表已更新: ${products.length} 个商品');
        }
      }
    } catch (e) {
      if(mounted) {
       Debug.showDataLoadError(context, '商品');
      }
    }
  }


  /// 开始自动滚动
  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(Duration(seconds: AppConstants.autoScrollIntervalSeconds), (timer) {
      final shopService = Get.find<ShopService>();
      if (mounted && shopService.bannerImages.isNotEmpty) {
        _isAutoScrolling = true;
        _nextPage();
        if (mounted) {
            _isAutoScrolling = false;
          }
      }
    });
  }


  /// 重新启动自动滚动（优化：避免频繁重启）
  void _restartAutoScroll() {
    // 只有在定时器不存在或已停止时才重新启动
    if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
      _startAutoScroll();
    }
  }

  /// 切换到下一页
  void _nextPage() {
    if (_pageController.hasClients) {
      final shopService = Get.find<ShopService>();
      int nextPage = (_currentBannerIndex + 1) % (shopService.bannerImages.isNotEmpty ? shopService.bannerImages.length : 3);
      _pageController.animateToPage(
        nextPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: CustomScrollView(
        slivers: [
          // 店铺信息区域（轮播图上方）
          _buildStoreInfoSection(),
          
          // 顶部轮播图区域
          SliverToBoxAdapter(
            child: _buildBannerCarousel(),
          ),
          
          // 用户信息区域（轮播图下方）
          _buildUserInfoSection(),
          
          // 优惠券展示区域
          _buildPromoSection(),
          
          // 每日推荐商品
          _buildDailyRecommendations(),
          
          // 底部间距
          SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxxl + AppSpacing.xxl), // 增加底部间距
          ),
        ],
        ),
      ),
    );
  }


  /// 构建轮播图区域
  Widget _buildBannerCarousel() {
    return GetBuilder<ShopService>(
      builder: (shopService) {
        // 使用 Obx 监听 bannerImages 的变化
        return Obx(() {
          final bannerImages = shopService.bannerImages;
          
          return Container(
            height: AppScreenUtil.getOptimalBannerHeight(context),
            width: double.infinity,
            margin: EdgeInsets.zero, // 移除所有边距
            child: Stack(
              children: [
                // 轮播图主体 - 使用PageView
                PageView.builder(
                  controller: _pageController,
                  itemCount: bannerImages.isNotEmpty ? bannerImages.length : 3,
                  onPageChanged: (index) {
                    setState(() {
                      _currentBannerIndex = index;
                    });
                    // 只有在非自动滚动时才重新启动定时器
                    if (!_isAutoScrolling) {
                      _restartAutoScroll();
                    }
                  },
                  itemBuilder: (BuildContext context, int index) {
                    if (bannerImages.isNotEmpty) {
                      return _buildBannerImageCard(bannerImages[index]);
                    } else {
                      return _buildDefaultBannerCard();
                    }
                  },
                ),
                // 分页指示器 - 覆盖在图片上方
                Positioned(
                  bottom: AppSpacing.xs,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      child: LuckinPageIndicator(
                        currentIndex: _currentBannerIndex,
                        itemCount: bannerImages.isNotEmpty ? bannerImages.length : 3,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withValues(alpha:0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  /// 构建Banner图片卡片
  Widget _buildBannerImageCard(ImageObj imageObj) {
    return Container(
      decoration: BoxDecoration(
        // 移除圆角，让轮播图顶满
      ),
      child: Stack(
        children: [
          // 背景图片
          Positioned.fill(
            child: AsyncImageWidget(
              imageobj: imageObj,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建默认轮播图卡片
  Widget _buildDefaultBannerCard() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryLightBlue,
              AppTheme.accentBlue,
            ],
          ),
          // 移除圆角，让轮播图顶满
        ),
        child: Stack(
          children: [
            // 装饰性图案
            Positioned(
              top: -20.h,
              right: -20.h,
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -30.h,
              left: -30.h,
              child: Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // 文字内容
            Positioned(
              bottom: AppSpacing.xl,
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocationUtils.translate('Premium Products'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black.withValues(alpha:0.3),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Discover more premium products',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha:0.9),
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black.withValues(alpha:0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }








  /// 构建优惠券展示区域
  Widget _buildPromoSection() {
    // 只有优惠券数量>0时才显示
    PromoService promoService = Get.find<PromoService>();
    return Obx(() {
      if (promoService.promos.isEmpty) {
          return SliverToBoxAdapter(child: SizedBox.shrink());
        }
        
        return SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 优惠券标题
                Row(
                  children: [
                    Container(
                      width: 4.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: AppRadius.sm,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Text(
                      LocationUtils.translate('Available Coupons'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${promoService.promos.length} ${LocationUtils.translate('available')}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                // 优惠券列表
                _buildPromoList(promoService.promos),
              ],
            ),
          ),
        );
      });
  }


  /// 构建优惠券列表
  Widget _buildPromoList(List<dynamic> promos) {
    return SizedBox(
      height: 120.h, // 固定高度，支持横向滚动
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: promos.length,
        itemBuilder: (context, index) {
          final promo = promos[index];
          return _buildPromoCard(promo, index);
        },
      ),
    );
  }

  /// 构建优惠券卡片
  Widget _buildPromoCard(PromObj promo, int index) {
    return Container(
      width: 320.w, // 固定宽度 320px
      margin: EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: () {
          // 处理优惠券点击事件
          Debug.log('点击优惠券: ${promo.title}');
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha:0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.lg,
            child: _buildPromoImage(promo),
          ),
        ),
      ),
    );
  }

  /// 构建优惠券图片
  Widget _buildPromoImage(PromObj promo) {
    if (promo.image.isEmpty) {
      return _buildDefaultPromoCard(promo);
    }
    
    return _PromoImageWidget(
      base64String: promo.image,
      promo: promo,
    );
  }

  /// 构建默认优惠券卡片（当没有图片时）
  Widget _buildDefaultPromoCard(dynamic promo) {
    return Container(
      height: 100.h, // 默认高度
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryLightBlue,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              promo.title.isNotEmpty ? promo.title : LocationUtils.translate('Special Offer'),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              promo.text.isNotEmpty ? promo.text : LocationUtils.translate('Get great deals!'),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white.withValues(alpha:0.9),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建店铺信息区域（轮播图上方，作为标题）
  Widget _buildStoreInfoSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
        child: Row(
          children: [
            // 店铺名称
            Expanded(
              child: GetX<ShopService>(
                builder: (shopService) {
                  final shopName = shopService.shop.value.name.isNotEmpty 
                      ? shopService.shop.value.name 
                      : LocationUtils.translate('Our Store');
                  return Text(
                    shopName,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            // 定位按钮
            GetX<ShopService>(
              builder: (shopService) {
                final hasLocation = shopService.shop.value.address.hasCoordinates;
                return GestureDetector(
                  onTap: () {
                    if (hasLocation) {
                      _showStoreLocation(
                        shopService.shop.value.address.latitude.value, 
                        shopService.shop.value.address.longitude.value
                      );
                    } else {
                      SnackBarUtils.showError(
                        context,
                        LocationUtils.translate('Store location not set'),
                      );
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: hasLocation 
                          ? AppTheme.accentRed.withValues(alpha: 0.1)
                          : AppTheme.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: hasLocation 
                            ? AppTheme.accentRed.withValues(alpha: 0.3)
                            : AppTheme.textSecondary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
                          size: 14.w,
                          color: hasLocation ? AppTheme.accentRed : AppTheme.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        Text(LocationUtils.translate('Store Locator'),
                            
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: hasLocation ? AppTheme.accentRed : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建用户信息区域（轮播图下方）
  Widget _buildUserInfoSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surface,
              AppTheme.primaryBlue.withValues(alpha: 0.02),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: _buildUserInfoContent(),
        ),
      ),
    );
  }


  /// 构建用户信息内容（用于单独显示）
  Widget _buildUserInfoContent() {
    return GetX<UserService>(
      builder: (userService) {
        final userInfo = userService.currentUser;
        
        if (userInfo == null) {
          return _buildEmptyUserInfoContent();
        }

        return Row(
          children: [
            // 用户头像
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryLightBlue,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
               child: userService.getAvatarWidget(
                    width: 32.w,
                    height: 32.w,
                    radius: 16.w,
                    defaultIcon: Icons.person_rounded,
                    defaultIconColor: Colors.white,
                  ),
            ),
         //  userService.chatUserobj.chatuser!.getavatar(width: 50,height: 50,radius: 15),
            SizedBox(width: AppSpacing.sm),
            // 用户信息
            Expanded(
              child: Text(
                userInfo.username,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 等级标签 - 放到最右边，带流光效果
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(int.parse(userInfo.levelColor.replaceFirst('#', '0xFF'))),
                    Color(int.parse(userInfo.levelColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.8),
                    Color(int.parse(userInfo.levelColor.replaceFirst('#', '0xFF'))),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  // 内层阴影
                  BoxShadow(
                    color: Color(int.parse(userInfo.levelColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.4),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  // 外层流光阴影
                  BoxShadow(
                    color: Color(int.parse(userInfo.levelColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.6),
                    spreadRadius: 2,
                    blurRadius: 12,
                    offset: const Offset(0, 0),
                  ),
                  // 边缘光晕
                  BoxShadow(
                    color: Color(int.parse(userInfo.levelColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 11.w,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        offset: const Offset(0, 0),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    LocationUtils.translate(userInfo.level.name),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          offset: const Offset(0, 0),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建空用户信息内容（未登录状态，用于水平布局）
  Widget _buildEmptyUserInfoContent() {
    return Row(
      children: [
        Container(
          width: 28.w,
          height: 28.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.1),
                AppTheme.primaryLightBlue.withValues(alpha: 0.1),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.person_outline,
            size: 14.w,
            color: AppTheme.primaryBlue.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocationUtils.translate('Guest User'),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Text(
                LocationUtils.translate('Tap to login'),
                style: TextStyle(
                  fontSize: 9.sp,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // 登录按钮
        GestureDetector(
          onTap: () {
            // 这里可以添加登录逻辑
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: AppRadius.xs,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  spreadRadius: 0,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              LocationUtils.translate('Login'),
              style: TextStyle(
                fontSize: 8.sp,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }



  /// 显示商店位置
  void _showStoreLocation(double latitude, double longitude) async {
    try {

      GpsApi().showMapgps(latitude,longitude,(value)
      {
        Debug.log('显示商店位置: $value');
      }); 
    } catch (e) {
      Debug.logError('显示商店位置失败', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          LocationUtils.translate('无法显示地图'),
        );
      }
    }
  }

  /// 构建每日推荐商品
  Widget _buildDailyRecommendations() {
    // 仅首次加载时显示占位元素
    final shouldShowPlaceholder = _isLoadingProducts || (_products.isEmpty && !ProductService.isInitialized);
    
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: shouldShowPlaceholder
            ? _buildProductLoadingPlaceholder()
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppScreenUtil.getLandscapeProductColumns(context),
                  crossAxisSpacing: AppSpacing.lg,
                  mainAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 0.8, // 调整宽高比，给更多垂直空间
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return _buildEnhancedProductCard(product, index);
                },
              ),
      ),
    );
  }

  /// 构建商品加载占位元素（骨架屏）
  Widget _buildProductLoadingPlaceholder() {
    final placeholderCount = AppScreenUtil.getLandscapeProductColumns(context) * 2; // 显示2行的占位元素
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppScreenUtil.getLandscapeProductColumns(context),
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        childAspectRatio: 0.8,
      ),
      itemCount: placeholderCount,
      itemBuilder: (context, index) {
        return _buildProductSkeletonCard();
      },
    );
  }

  /// 构建单个商品骨架屏卡片
  Widget _buildProductSkeletonCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.xl,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.xl,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.surface,
                    AppTheme.primaryBlue.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图片区域占位
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _getShimmerColor(),
                        borderRadius: BorderRadius.only(
                          topLeft: AppRadius.xl.topLeft,
                          topRight: AppRadius.xl.topRight,
                        ),
                      ),
                    ),
                  ),
                  // 信息区域占位
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 标题占位
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 12.h,
                                decoration: BoxDecoration(
                                  color: _getShimmerColor(),
                                  borderRadius: AppRadius.xs,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Container(
                                width: 60.w,
                                height: 9.h,
                                decoration: BoxDecoration(
                                  color: _getShimmerColor(),
                                  borderRadius: AppRadius.xs,
                                ),
                              ),
                            ],
                          ),
                          // 价格和按钮占位
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 70.w,
                                height: 14.h,
                                decoration: BoxDecoration(
                                  color: _getShimmerColor(),
                                  borderRadius: AppRadius.xs,
                                ),
                              ),
                              Container(
                                width: 28.w,
                                height: 28.w,
                                decoration: BoxDecoration(
                                  color: _getShimmerColor(),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 获取闪烁动画颜色
  Color _getShimmerColor() {
    final animationValue = _shimmerController.value;
    // 在灰色和浅灰色之间闪烁
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;
    
    // 使用正弦波创建平滑的闪烁效果
    final opacity = 0.3 + (0.4 * (0.5 + 0.5 * sin(animationValue * 2 * pi)));
    
    return Color.lerp(baseColor, highlightColor, opacity.clamp(0.0, 1.0))!;
  }

  /// 构建增强版商品卡片
  Widget _buildEnhancedProductCard(CoffeeProduct product, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.xl,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha:0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha:0.04),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.xl,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.surface,
                  AppTheme.primaryBlue.withValues(alpha:0.02),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                        // 商品图片区域
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.only(
                                topLeft: AppRadius.xl.topLeft,
                                topRight: AppRadius.xl.topRight,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // 商品图片 - 使用缓存的图片组件
                                Positioned.fill(
                                  child: _buildProductImage(product),
                                ),
                                // 推荐标签
                                Positioned(
                                  top: AppSpacing.sm,
                                  left: AppSpacing.sm,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.accentOrange,
                                          AppTheme.accentOrange.withValues(alpha:0.8),
                                        ],
                                      ),
                                      borderRadius: AppRadius.sm,
                                      boxShadow: AppShadows.sm,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 12.w,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 2.w),
                                        Text(
                                          LocationUtils.translate('Recommended'),
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 收藏按钮
                                Positioned(
                                  top: AppSpacing.sm,
                                  right: AppSpacing.sm,
                                  child: GestureDetector(
                                    onTap: () {
                                      // 收藏功能
                                    },
                                    child: Container(
                                      width: 32.w,
                                      height: 32.w,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha:0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: AppShadows.sm,
                                      ),
                                      child: Icon(
                                        Icons.favorite_border,
                                        size: 16.w,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 商品信息区域
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.sm), // 减少内边距
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, // 使用spaceBetween分布内容
                              children: [
                                // 商品名称和分类
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 商品名称
                                    Text(
                                      product.name,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                        height: 1.1, // 减少行高
                                        fontSize: 12.sp, // 稍微减小字体
                                      ),
                                      maxLines: 1, // 减少到1行
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h), // 减少间距
                                    // 商品分类
                                    if (product.category.isNotEmpty)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4.w,
                                          vertical: 1.h, // 减少垂直内边距
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue.withValues(alpha:0.1),
                                          borderRadius: AppRadius.xs,
                                        ),
                                        child: Text(
                                          product.category,
                                          style: TextStyle(
                                            fontSize: 9.sp, // 减小字体
                                            color: AppTheme.primaryBlue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                // 价格和操作按钮
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child:
                                    Text(
                                        '${ShopService.instance.shop.value.symbol.value}${product.price.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith( // 使用更小的字体
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                     ,
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        _addToCart(context, product);
                                      },
                                      child: Container(
                                        width: 28.w, // 减小按钮尺寸
                                        height: 28.w,
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                          shape: BoxShape.circle,
                                          boxShadow: AppShadows.sm,
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          size: 16.w, // 减小图标尺寸
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  /// 添加商品到购物车
  void _addToCart(BuildContext context, CoffeeProduct product) {
    try {
      Debug.log('添加商品到购物车: ${product.name}');
      
      // 获取购物车服务并添加商品
      final cartController = Get.find<CartController>();
      cartController.addItem(product, quantity: 1);
      
      // 显示成功提示
      if (mounted) {
        SnackBarUtils.showSuccess(
          '${product.name} ${LocationUtils.translate('Added to cart')}',
        );
      }
    } catch (e) {
      Debug.logError('添加商品到购物车失败', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          LocationUtils.translate('添加失败，请重试'),
        );
      }
    }
  }

  /// 构建商品图片（使用AsyncImageWidget）
  Widget _buildProductImage(CoffeeProduct product) {
    final imageObj = product.getMainImageObj();
    if (imageObj == null) {
      return _buildPlaceholderImage();
    }

    // 先检查本地缓存，如果有就直接显示
    if (imageObj.byte != null && imageObj.byte!.isNotEmpty) {
      return AsyncImageWidget(
        initialBytes: imageObj.byte!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    // 使用AsyncImageWidget异步加载
    return AsyncImageWidget(
      imageobj: imageObj,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }

  /// 构建占位图片
  Widget _buildPlaceholderImage() {
    return Container(
      color: AppTheme.background,
      child: Center(
        child: Icon(
          Icons.local_cafe_outlined,
          size: 32.w,
          color: AppTheme.textHint,
        ),
      ),
    );
  }


}

/// 优惠券图片组件 - 支持 320x50 和 320x100 像素
class _PromoImageWidget extends StatefulWidget {
  final String base64String;
  final PromObj promo;

  const _PromoImageWidget({
    required this.base64String,
    required this.promo,
  });

  @override
  State<_PromoImageWidget> createState() => _PromoImageWidgetState();
}

class _PromoImageWidgetState extends State<_PromoImageWidget> {
  ImageProvider? _imageProvider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  void _decodeImage() {
    try {
      final imageBytes = ImageUtils.safeBase64Decode(widget.base64String);
      if (imageBytes != null) {
        setState(() {
          _imageProvider = MemoryImage(imageBytes);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Debug.log('解析优惠券图片失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 100.h,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: AppRadius.lg,
        ),
        child: Center(
          child: SizedBox(
            width: 24.w,
            height: 24.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
          ),
        ),
      );
    }

    if (_imageProvider == null) {
      return _buildDefaultPromoCard();
    }

    return SizedBox(
      height: 100.h, // 默认高度，会根据图片比例调整
      child: Stack(
        children: [
          // 背景图片
          Positioned.fill(
            child: Image(
              image: _imageProvider!,
              width: 320.w,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildDefaultPromoCard();
              },
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: Duration(milliseconds: 200),
                  child: child,
                );
              },
            ),
          ),
          // 信息覆盖层
          _buildPromoOverlay(),
        ],
      ),
    );
  }

  /// 构建优惠券信息覆盖层
  Widget _buildPromoOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          // 添加渐变遮罩，确保文字可读性
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.3),
              Colors.black.withValues(alpha: 0.6),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 顶部：优惠券类型标签
              if (widget.promo.label.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: AppRadius.md,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.promo.label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              
              // 底部：名称和截止时间
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 优惠券名称 (title)
                  if (widget.promo.title.isNotEmpty)
                    Text(
                      widget.promo.title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 4.h),
                  // 截止时间 (endTime 转换为日期)
                  if (widget.promo.endTime > 0)
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12.w,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            'endTime: ${_formatEndTime(widget.promo.endTime)}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.white.withValues(alpha: 0.9),
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 1,
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化截止时间
  String _formatEndTime(dynamic endTime) {
    try {
      if (endTime == null) return '未知';
      
      int timestamp = int.tryParse(endTime.toString()) ?? 0;
      if (timestamp == 0) return '长期有效';
      
      // 调试：打印原始时间戳
      Debug.log('原始时间戳: $timestamp');
      
      DateTime dateTime;
      
      // 判断时间戳是秒还是毫秒
      if (timestamp > 1000000000000) {
        // 毫秒时间戳
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        // 秒时间戳
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
      
      // 调试：打印转换后的日期
      Debug.log('转换后日期: $dateTime');
      
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      Debug.log('时间格式化错误: $e');
      return '长期有效';
    }
  }

  Widget _buildDefaultPromoCard() {
    return Container(
      height: 100.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryLightBlue,
          ],
        ),
      ),
      child: Stack(
        children: [
          // 背景装饰
          Positioned(
            top: -20.h,
            right: -20.h,
            child: Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // 信息覆盖层
          _buildPromoOverlay(),
        ],
      ),
    );
  }
}



