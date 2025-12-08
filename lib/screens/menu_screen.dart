import '../services/shop_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../services/product_service.dart';
import '../services/product_category_service.dart';
import '../services/cart_service.dart';
import '../models/product.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/debug.dart';
import '../utils/screen_util.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/async_image_widget.dart';
import 'product_detail_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<CoffeeProduct> _products = [];
  List<CoffeeProduct> _filteredProducts = [];
  bool _isLoading = true;
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  
  List<String> _categories = ['All']; // 默认包含"All"
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAndLoadProducts();
  }

  /// 初始化并加载商品数据
  Future<void> _initializeAndLoadProducts() async {
    try {

      await ProductService.initialize();
      await ProductCategoryService.initialize();
      
      final products = ProductService.getActiveProducts();
      final categories = ProductCategoryService.getAllCategories();

      if (mounted) {
        setState(() {
          _products = products;
          _filteredProducts = products;
          _categories = ['All', ...categories]; // 添加"All"到分类列表开头
          _isLoading = false;
        });
        // 确保初始筛选状态正确
        _applyFilters();
      }
    } catch (e) {
      Debug.log('加载商品数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 根据分类筛选商品
  void _filterProductsByCategory(int categoryIndex) {
    setState(() {
      _selectedCategoryIndex = categoryIndex;
      _applyFilters();
    });
  }

  /// 搜索商品
  void _searchProducts(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  /// 应用所有筛选条件
  void _applyFilters() {
    List<CoffeeProduct> filtered = List.from(_products);

    // 按分类筛选
    if (_selectedCategoryIndex > 0) {
      final selectedCategory = _categories[_selectedCategoryIndex];
      filtered = filtered.where((product) {
        // 更灵活的匹配：包含关键词即可
        return product.category.toLowerCase().contains(selectedCategory.toLowerCase()) ||
               selectedCategory.toLowerCase().contains(product.category.toLowerCase());
      }).toList();
    }

    // 按搜索关键词筛选
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               product.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    _filteredProducts = filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Column(
        children: [
          // 顶部导航栏
      //    _buildAppBar(),
          
          // 搜索栏
          _buildSearchBar(),
          
          // 主要内容区域
          Expanded(
            child: Row(
              children: [
                // 左侧分类栏
                _buildCategorySidebar(),
                
                // 右侧商品列表
                Expanded(
                  child: _buildProductList(),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }



  /// 构建搜索栏
  Widget _buildSearchBar() {
    final isLandscape = AppScreenUtil.isLandscape(context);
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isLandscape ? 12.w : 16.w,
        vertical: isLandscape ? 6.h : 8.h,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 12.w : 16.w,
          vertical: isLandscape ? 6.h : 8.h,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surface,
              AppTheme.primaryBlue.withValues(alpha:0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(isLandscape ? 6.r : 12.r),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha:0.08),
              blurRadius: isLandscape ? 8 : 12,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha:0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: isLandscape ? 28.w : 32.w,
              height: isLandscape ? 28.w : 32.w,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: AppRadius.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: isLandscape ? 4 : 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.search,
                color: Colors.white,
                size: isLandscape ? 14.w : 16.w,
              ),
            ),
            SizedBox(width: isLandscape ? 8.w : 12.w),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: LocationUtils.translate('  Search for products you like...'),
                  hintStyle: TextStyle(
                    fontSize: isLandscape ? 11.sp : 12.sp,
                    color: AppTheme.textHint,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: isLandscape ? 12.sp : 14.sp,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: _searchProducts,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _searchProducts('');
                },
                child: Container(
                  width: isLandscape ? 24.w : 28.w,
                  height: isLandscape ? 24.w : 28.w,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha:0.1),
                    borderRadius: AppRadius.circle,
                  ),
                  child: Icon(
                    Icons.clear,
                    color: AppTheme.textSecondary,
                    size: isLandscape ? 14.w : 16.w,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建左侧分类栏
  Widget _buildCategorySidebar() {
    return Container(
      width: AppScreenUtil.getLandscapeMenuSidebarWidth(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surface,
            AppTheme.primaryBlue.withValues(alpha:0.02),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: AppTheme.primaryBlue.withValues(alpha:0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha:0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 分类标题
          Container(
            padding: EdgeInsets.all(12.w),
            child: Text(
              textAlign: TextAlign.center,
              LocationUtils.translate('Classification'),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDarkBlue,
              ),
            ),
          ),
          // 分类列表
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return _buildCategoryItem(
                  category: _categories[index],
                  isSelected: isSelected,
                  onTap: () => _filterProductsByCategory(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类项目
  Widget _buildCategoryItem({
    required String category,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final categoryIcon = _getCategoryIcon(category);
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? AppTheme.primaryGradient
                : LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.primaryBlue.withValues(alpha:0.02),
                    ],
                  ),
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primaryBlue
                  : AppTheme.primaryBlue.withValues(alpha:0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha:0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            children: [
              // 分类图标
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  gradient: isSelected 
                      ? LinearGradient(
                          colors: [Colors.white.withValues(alpha:0.2), Colors.white.withValues(alpha:0.1)],
                        )
                      : AppTheme.primaryGradient,
                  borderRadius: AppRadius.circle,
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha:0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ] : null,
                ),
                child: Icon(
                  categoryIcon,
                  color: isSelected ? Colors.white : AppTheme.primaryBlue,
                  size: 18.w,
                ),
              ),
              SizedBox(height: 8.h),
              // 分类名称
              Text(
                category,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取分类图标
  IconData _getCategoryIcon(String category) {
    // 所有分类使用相同的图标
    return Icons.category;
  }

  /// 构建商品列表
  Widget _buildProductList() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    final isLandscape = AppScreenUtil.isLandscape(context);
    
    return Container(
      padding: EdgeInsets.all(isLandscape ? 12.w : 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品列表 - 横向布局
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 4.w : 8.w,
                vertical: isLandscape ? 4.h : 8.h,
              ),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return _buildHorizontalProductCard(product, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    return SizedBox(
      height: 200.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha:0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              LocationUtils.translate('Loading products...'),
              style: TextStyle(
                fontSize: 16.sp,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40.w),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha:0.1),
                    AppTheme.primaryLightBlue.withValues(alpha:0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha:0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha:0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 40.w,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              _products.isEmpty ? LocationUtils.translate('No product data available') : LocationUtils.translate('No products are available under this category'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              LocationUtils.translate('Please try other categories or search keywords'),
              textAlign:TextAlign.center,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// 构建横向商品卡片
  Widget _buildHorizontalProductCard(CoffeeProduct product, int index) {
    final isLandscape = AppScreenUtil.isLand;
    
    return GestureDetector(
      onTap: () {
        Get.to(() => ProductDetailScreen(product: product));
      },
      child: Container(
        height: isLandscape ? 100.h : 120.h, // 横屏模式下减少高度
        margin: EdgeInsets.only(bottom: isLandscape ? 8.h : 12.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surface,
              AppTheme.primaryBlue.withAlpha(5),
            ],
          ),
          borderRadius: BorderRadius.circular(isLandscape ? 8.r : 12.r),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withAlpha(20),
              blurRadius: isLandscape ? 8 : 16,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: AppTheme.primaryBlue.withAlpha(10),
              blurRadius: isLandscape ? 16 : 32,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppTheme.primaryBlue.withAlpha(25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 商品图片区域
            Container(
              width: 100.h, // 横屏模式下增加图片宽度
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isLandscape ? 8.r : 12.r),
                  bottomLeft: Radius.circular(isLandscape ? 8.r : 12.r),
                ),
              ),
              child: _buildProductImage(product),
            ),
            // 商品信息区域
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8.w : 12.w,
                  vertical: isLandscape ? 8.h : 12.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 商品名称和描述
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 商品名称
                          Text(
                            product.name,
                            style: TextStyle(
                              fontSize: isLandscape ? 12.sp : 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: isLandscape ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // 商品描述（仅在横屏模式下显示）
                          if (isLandscape && product.description.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              product.description,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: AppTheme.textSecondary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 价格和操作按钮
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 价格
                        Flexible(
                          child: Text(
                              '${ShopService.instance.shop.value.symbol.value}${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isLandscape ? 12.sp : 14.sp,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // 添加到购物车按钮
                        GestureDetector(
                          onTap: () {
                            _addToCart(context, product);
                          },
                          child: Container(
                            width: isLandscape ? 24.w : 28.w,
                            height: isLandscape ? 24.w : 28.w,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withAlpha(30),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add,
                              size: isLandscape ? 12.w : 14.w,
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
          '${LocationUtils.translate('Failed to add to cart')} ${e.toString()}',
        );
      }
    }
  }

  /// 构建商品图片
  Widget _buildProductImage(CoffeeProduct product) {
    final imageObj = product.getMainImageObj();
    
    if (imageObj == null) {
      return _buildPlaceholderImage();
    }
    
    // 使用 AsyncImageWidget 来处理异步加载
    return AsyncImageWidget(
      imageobj: imageObj,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }

  /// 构建占位图片
  Widget _buildPlaceholderImage() {
    final isLandscape = AppScreenUtil.isLandscape(context);
    
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isLandscape ? 8.r : 12.r),
        bottomLeft: Radius.circular(isLandscape ? 8.r : 12.r),
      ),
      child: Container(
        color: AppTheme.background,
        child: Center(
          child: Icon(
            Icons.local_cafe_outlined,
            size: isLandscape ? 24.w : 32.w,
            color: AppTheme.textHint,
          ),
        ),
      ),
    );
  }

}
