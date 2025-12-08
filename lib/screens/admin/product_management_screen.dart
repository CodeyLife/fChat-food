import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/location.dart';
import '../../utils/debug.dart';
import '../../widgets/async_image_widget.dart';
import '../product_detail_screen.dart';
import '../product_form_screen.dart';
import '../../utils/screen_util.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  List<CoffeeProduct> _products = [];
  List<CoffeeProduct> _filteredProducts = [];
  final RxBool _isLoading = true.obs;
  String _searchQuery = '';
  int _selectedProductStatusIndex = 0;
  late final ShopService shopService;
  
  final List<String> _productStatusFilters = ['All', 'Listed', 'Unlisted'];
  final List<String> _approvalStatusFilters = ['All', 'Pending', 'Approved', 'Rejected'];
  final TextEditingController _searchController = TextEditingController();
  int _selectedApprovalStatusIndex = 0;

  @override
  void initState() {
    super.initState();
    shopService = Get.find<ShopService>();
    _initializeAndLoadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 初始化并加载商品数据
  Future<void> _initializeAndLoadProducts() async {
    try {
      await ProductService.initialize(); // 初始化商品服务
      final products = ProductService.products; // 获取所有商品（包括下架）
      if (mounted) {
        setState(() {
          _products = List.from(products);
          _filteredProducts = List.from(products);
          _isLoading.value = false;
        });
        _applyFilters();
      }
    } catch (e) {
      Debug.log('加载商品数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
      }
    }
  }

  /// 检查筛选器是否被选中
  bool _isFilterSelected(String filter) {
    if (filter == 'All') {
      return _selectedProductStatusIndex == 0 && _selectedApprovalStatusIndex == 0;
    } else if (['Listed', 'Unlisted'].contains(filter)) {
      final index = _productStatusFilters.indexOf(filter);
      return _selectedProductStatusIndex == index && _selectedApprovalStatusIndex == 0;
    } else if (['Pending', 'Approved', 'Rejected'].contains(filter)) {
      final index = _approvalStatusFilters.indexOf(filter);
      return _selectedApprovalStatusIndex == index && _selectedProductStatusIndex == 0;
    }
    return false;
  }

  /// 选择筛选器
  void _selectFilter(String filter) {
    setState(() {
      if (filter == 'All') {
        _selectedProductStatusIndex = 0;
        _selectedApprovalStatusIndex = 0;
      } else if (filter == 'Listed') {
        _selectedProductStatusIndex = 1;
        _selectedApprovalStatusIndex = 0;
      } else if (filter == 'Unlisted') {
        _selectedProductStatusIndex = 2;
        _selectedApprovalStatusIndex = 0;
      } else if (filter == 'Pending') {
        _selectedProductStatusIndex = 0;
        _selectedApprovalStatusIndex = 1;
      } else if (filter == 'Approved') {
        _selectedProductStatusIndex = 0;
        _selectedApprovalStatusIndex = 2;
      } else if (filter == 'Rejected') {
        _selectedProductStatusIndex = 0;
        _selectedApprovalStatusIndex = 3;
      }
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

    // 按商品状态筛选
    if (_selectedProductStatusIndex > 0) {
      final isActive = _selectedProductStatusIndex == 1; // 1: 上架, 2: 下架
      filtered = filtered.where((product) => product.status == isActive).toList();
    }

    // 按审核状态筛选
    if (_selectedApprovalStatusIndex > 0) {
      ProductApprovalStatus targetStatus;
      switch (_selectedApprovalStatusIndex) {
        case 1: // Pending
          targetStatus = ProductApprovalStatus.pending;
          break;
        case 2: // Approved
          targetStatus = ProductApprovalStatus.approved;
          break;
        case 3: // Rejected
          targetStatus = ProductApprovalStatus.rejected;
          break;
        default:
          targetStatus = ProductApprovalStatus.pending;
      }
      filtered = filtered.where((product) => product.approvalStatus == targetStatus).toList();
    }

    // 按搜索关键词筛选
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               product.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               product.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    _filteredProducts = filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
      children: [
        // 商品搜索栏
        _buildSearchBar(),
        // 操作按钮栏
        _buildActionBar(),
        // 筛选器组合
        _buildFilterSection(),
        // 商品列表
        Expanded(
          child: _buildProductList(),
        ),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(8.r),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.grey[400],
            size: 20.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              key: const ValueKey('search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: LocationUtils.translate('Search products...'),
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _searchProducts,
              // 添加键盘交互优化
              textInputAction: TextInputAction.search,
              enableSuggestions: false,
              autocorrect: false,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _searchProducts('');
              },
              child: Icon(
                Icons.clear,
                color: Colors.grey[400],
                size: 20.w,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建筛选器组合部分
  Widget _buildFilterSection() {
    // 合并所有筛选选项
    final allFilters = [
      'All',
      'Listed',
      'Unlisted', 
      'Pending',
      'Approved',
      'Rejected'
    ];
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocationUtils.translate('Filter by Status'),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 4.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: allFilters.map((filter) {
              final isSelected = _isFilterSelected(filter);
              return ElevatedButton(
                onPressed: () {
                  _selectFilter(filter);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected 
                      ? AppTheme.primaryBlue 
                      : Colors.white,
                  foregroundColor: isSelected 
                      ? Colors.white 
                      : AppTheme.primaryBlue,
                  elevation: isSelected ? 2 : 0,
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.r),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: Text(
                  LocationUtils.translate(filter),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮栏
  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.all(8.w),
      child: Wrap(
        alignment: WrapAlignment.start, // 左对齐
        spacing: 12.w, // 水平间距
        runSpacing: 8.h, // 垂直间距（换行时）
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductFormScreen(),
                ),
              ).then((_) {
                // 刷新商品列表
                _initializeAndLoadProducts();
              });
            },
            icon: Icon(Icons.add, size: 18.w),
            label: Text(LocationUtils.translate('Add Product'), style: TextStyle(fontSize: 14.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.only(left: 2.w, right: 8.w, top: 8.h, bottom: 8.h),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _showBatchStatusDialog();
            },
            icon: Icon(Icons.batch_prediction, size: 18.w),
            label: Text(LocationUtils.translate('Batch Management'), style: TextStyle(fontSize: 14.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.only(left: 2.w, right: 8.w, top: 8.h, bottom: 8.h),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // 刷新商品列表
              _initializeAndLoadProducts();
            },
            icon: Icon(Icons.refresh, size: 18.w),
            label: Text(LocationUtils.translate('Refresh'), style: TextStyle(fontSize: 14.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.only(left: 2.w, right: 8.w, top: 8.h, bottom: 8.h),
            ),
          ),
          Text(
            '${LocationUtils.translate('Total')}: ${_filteredProducts.length} ${LocationUtils.translate('products')}',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建商品列表
  Widget _buildProductList() {
    if (_isLoading.value) {
      return SizedBox(
        height: 200.h,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B4513)),
          ),
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return SizedBox(
        height: 200.h,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64.w,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16.h),
              Text(
                _products.isEmpty ? LocationUtils.translate('No product data') : LocationUtils.translate('No products in this category'),
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      // 添加键盘滚动行为，确保输入时不会出现布局问题
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // 防止过度滚动，提供更好的用户体验
      physics: const ClampingScrollPhysics(),
      // 添加缓存优化，防止滑动时白屏
      cacheExtent: 200.0,
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: _buildAdminProductCard(product, index),
        );
      },
    );
  }

  /// 构建管理用商品卡片
  Widget _buildAdminProductCard(CoffeeProduct product, int index) {
    // 使用商品ID作为稳定的key，避免筛选时重建
    return RepaintBoundary(
      key: ValueKey('product_card_${product.id}'),
      child: _buildProductCardContent(product),
    );
  }

  /// 构建商品卡片内容
  Widget _buildProductCardContent(CoffeeProduct product) {
    // 根据审核状态设置背景颜色
    List<Color> backgroundColors;
    Color borderColor;
    
    if (product.approvalStatus == ProductApprovalStatus.rejected) {
      // 只有被拒绝的商品显示浅红色背景
      backgroundColors = [Colors.red[50]!, Colors.red[100]!];
      borderColor = Colors.red[300]!;
    } else {
      // 其他状态保持原来的白色背景
      backgroundColors = [Colors.white, Colors.grey[50]!];
      borderColor = AppTheme.primaryBlue.withValues(alpha: 0.1);
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: backgroundColors,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(3, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 0,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 点击卡片查看详情
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 检测是否为横屏模式
                final isLandscape = AppScreenUtil.isLandscape(context);
       
                
                if (isLandscape) {
                  // 横屏模式：水平布局
                  return _buildLandscapeCard(product);
                } else {
                  // 竖屏模式：垂直布局
                  return _buildPortraitCard(product);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 构建横屏模式的商品卡片
  Widget _buildLandscapeCard(CoffeeProduct product) {
    return Row(
      children: [
        // 商品图片
        Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            color: Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: product.productImages?.images.isNotEmpty == true
              ? AsyncImageWidget(
                  imageobj: product.productImages!.images.first,
                  width: 80.w,
                  height: 80.w,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12.r),
                  errorWidget: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey[400],
                    size: 32.w,
                  ),
                )
              : Icon(
                  Icons.image_not_supported,
                  color: Colors.grey[400],
                  size: 32.w,
                ),
        ),
        SizedBox(width: 16.w),
        // 商品信息
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Text(
                    '${shopService.shop.value.symbol.value}${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  if(product.approvalStatus == ProductApprovalStatus.approved)
                    ...[
                         Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: product.status ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: product.status ? Colors.green[300]! : Colors.red[300]!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      product.status ? LocationUtils.translate('Listed') : LocationUtils.translate('Unlisted'),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: product.status ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                    ],
              
               
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _getApprovalStatusColor(product.approvalStatus)[0],
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: _getApprovalStatusColor(product.approvalStatus)[1],
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getApprovalStatusText(product.approvalStatus),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: _getApprovalStatusColor(product.approvalStatus)[2],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                product.category,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
     //   SizedBox(width: 10.w),
        // 操作按钮 - 横屏模式
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 操作按钮行
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (product.approvalStatus == ProductApprovalStatus.approved) ...[
                      Expanded(
                        child: _buildCompactActionButton(
                          icon: product.status ? Icons.arrow_downward : Icons.arrow_upward,
                          color: product.status ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          onPressed: () => _toggleProductStatus(product),
                          tooltip: product.status ? LocationUtils.translate('Unlist') : LocationUtils.translate('List'),
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
        
                    Expanded(
                      child: _buildCompactActionButton(
                        icon: Icons.edit_outlined,
                        color: const Color(0xFFF59E0B),
                        onPressed: () => _showEditProductDialog(product),
                        tooltip: LocationUtils.translate('Edit'),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildCompactActionButton(
                        icon: Icons.delete_outline,
                        color: const Color(0xFFEF4444),
                        onPressed: () => _showDeleteConfirmDialog(product),
                        tooltip: LocationUtils.translate('Delete'),
                      ),
                    ),
                  ],
                ),
                // 超级管理员审核按钮行（仅在待审核状态时显示）
                if (UserService.instance.isSuperAdmin && product.approvalStatus == ProductApprovalStatus.pending) ...[
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildCompactActionButton(
                          icon: Icons.check_circle_outline,
                          color: const Color(0xFF10B981),
                          onPressed: () => _approveProduct(product),
                          tooltip: 'Approve',
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildCompactActionButton(
                          icon: Icons.cancel_outlined,
                          color: const Color(0xFFEF4444),
                          onPressed: () => _rejectProduct(product),
                          tooltip: 'Reject',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建竖屏模式的商品卡片
  Widget _buildPortraitCard(CoffeeProduct product) {
    return Column(
      children: [
        Row(
          children: [
            // 商品图片
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                color: Colors.grey[100],
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: product.productImages?.images.isNotEmpty == true
                  ? AsyncImageWidget(
                      imageobj: product.productImages!.images.first,
                      width: 60.w,
                      height: 60.w,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(8.r),
                      errorWidget: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                        size: 24.w,
                      ),
                    )
                  : Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[400],
                      size: 24.w,
                    ),
            ),
            SizedBox(width: 12.w),
            // 商品信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${shopService.shop.value.symbol.value}${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Text(
                        product.category,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if(product.approvalStatus == ProductApprovalStatus.approved) 
                        ...[
                                   Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: product.status ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: product.status ? Colors.green[300]! : Colors.red[300]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          product.status ? 'Listed' : 'Unlisted',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: product.status ? Colors.green[700] : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                        ],
             
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: _getApprovalStatusColor(product.approvalStatus)[0],
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: _getApprovalStatusColor(product.approvalStatus)[1],
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getApprovalStatusText(product.approvalStatus),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: _getApprovalStatusColor(product.approvalStatus)[2],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // 操作按钮 - 竖屏模式
        Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Column(
            children: [
              // 操作按钮行
              Row(
                children: [
                  if(product.approvalStatus == ProductApprovalStatus.approved) ...[
                    Expanded(
                      child: _buildCompactActionButton(
                        icon: product.status ? Icons.arrow_downward : Icons.arrow_upward,
                        color: product.status ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        onPressed: () => _toggleProductStatus(product),
                        tooltip: product.status ? LocationUtils.translate('Unlist') : LocationUtils.translate('List'),
                      ),
                    ),
                     SizedBox(width: 12.w),
                  ],
             
                  Expanded(
                    child: _buildCompactActionButton(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFFF59E0B),
                      onPressed: () => _showEditProductDialog(product),
                      tooltip: LocationUtils.translate('Edit'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildCompactActionButton(
                      icon: Icons.delete_outline,
                      color: const Color(0xFFEF4444),
                      onPressed: () => _showDeleteConfirmDialog(product),
                      tooltip: LocationUtils.translate('Delete'),
                    ),
                  ),
                ],
              ),
              // 超级管理员审核按钮行（仅在待审核状态时显示）
              if (UserService.instance.isSuperAdmin && product.approvalStatus == ProductApprovalStatus.pending) ...[
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactActionButton(
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF10B981),
                        onPressed: () => _approveProduct(product),
                        tooltip: 'Approve',
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildCompactActionButton(
                        icon: Icons.cancel_outlined,
                        color: const Color(0xFFEF4444),
                        onPressed: () => _rejectProduct(product),
                        tooltip: 'Reject',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 构建美观的操作按钮
  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16.w, color: Colors.white),
                SizedBox(width: 6.w),
                Text(
                  tooltip,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  /// 切换商品上架/下架状态
  void _toggleProductStatus(CoffeeProduct product) async {
    try {
      setState(() {
        _isLoading.value = true;
      });

      // 直接更新商品状态，不触发审核
      final newStatus = !product.status;
      final success = await ProductService.updateProductStatus(product.id, newStatus);
      
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        
        if (success) {
          // 更新本地状态
          product.status = newStatus;
          _applyFilters();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus 
                  ? LocationUtils.translate('Product "${product.name}" has been listed')
                  : LocationUtils.translate('Product "${product.name}" has been unlisted')
              ),
              backgroundColor: newStatus ? Colors.green[600] : Colors.orange[600],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocationUtils.translate('Failed to update product status')),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        Debug.log('切换商品状态失败: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocationUtils.translate('Operation failed: $e')),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  /// 显示编辑商品对话框
  void _showEditProductDialog(CoffeeProduct product) {

    Get.to(() => ProductFormScreen(product: product))?.then((result) {
      if (result == true) {
        _initializeAndLoadProducts();
      }
    });
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => ProductFormScreen(product: product),
    //   ),
    // ).then((result) {
    //   // 如果编辑成功，刷新商品列表
    //   if (result == true) {
    //     _initializeAndLoadProducts();
    //   }
    // });
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(CoffeeProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Confirm Delete')),
        content: Text(LocationUtils.translate('Are you sure you want to delete product "${product.name}"? This action cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('Cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product);
            },
            child: Text(LocationUtils.translate('Delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 删除商品
  void _deleteProduct(CoffeeProduct product) async {
    try {
      setState(() {
        _isLoading.value = true;
      });

      final success = await ProductService.deleteProduct(product);
      
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        
        if (success) {
          // 从本地列表移除
          _products.removeWhere((p) => p.id == product.id);
          _applyFilters();
        
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocationUtils.translate('Product deleted successfully')),
              backgroundColor: Colors.green[600],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocationUtils.translate('Failed to delete product, please try again')),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        Debug.log('删除商品失败: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocationUtils.translate('Delete failed: \$e')),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  /// 显示批量状态管理对话框
  void _showBatchStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Batch Product Management')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(LocationUtils.translate('Select the operation to perform:')),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _batchUpdateStatus(true);
                  },
                  icon: Icon(Icons.arrow_upward, size: 18.w),
                  label: Text(LocationUtils.translate('List All')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _batchUpdateStatus(false);
                  },
                  icon: Icon(Icons.arrow_downward, size: 18.w),
                  label: Text(LocationUtils.translate('Unlist All')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              'Current filtered products count: ${_filteredProducts.length}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('Cancel')),
          ),
        ],
      ),
    );
  }

  /// 批量更新商品状态
  Future<void> _batchUpdateStatus(bool status) async {
    if (_filteredProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocationUtils.translate('No products available for operation')),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading.value = true;
      });

      final productIds = _filteredProducts.map((p) => p.id).toList();
      final success = await ProductService.updateProductsStatus(productIds, status);
      
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        
        if (success) {
          // 更新本地状态
          for (var product in _filteredProducts) {
            product.status = status;
          }
          _applyFilters();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocationUtils.translate('Batch ${status ? "listing" : "unlisting"} successful')),
              backgroundColor: Colors.green[600],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocationUtils.translate('Batch operation failed, please try again')),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocationUtils.translate('Operation failed: \$e')),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  /// 批准商品
  void _approveProduct(CoffeeProduct product) async {
    try {
      setState(() {
        _isLoading.value = true;
      });

      // 调用ProductService来保存审核状态
      final success = await ProductService.updateProductApprovalStatus(product.id, ProductApprovalStatus.approved);
      
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        
        if (success) {
          // 刷新筛选结果
          _applyFilters();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product "${product.name}" has been approved'),
              backgroundColor: Colors.green[600],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve product "${product.name}"'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        Debug.log('批准商品失败: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve product: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  /// 拒绝商品
  void _rejectProduct(CoffeeProduct product) async {
    try {
      setState(() {
        _isLoading.value = true;
      });

      // 调用ProductService来保存审核状态
      final success = await ProductService.updateProductApprovalStatus(product.id, ProductApprovalStatus.rejected);
      
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        
        if (success) {
          // 刷新筛选结果
          _applyFilters();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product "${product.name}" has been rejected'),
              backgroundColor: Colors.orange[600],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject product "${product.name}"'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading.value = false;
        });
        Debug.log('拒绝商品失败: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject product: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  /// 获取审核状态文本
  String _getApprovalStatusText(ProductApprovalStatus status) {
    switch (status) {
      case ProductApprovalStatus.pending:
        return LocationUtils.translate('Pending');
      case ProductApprovalStatus.approved:
        return LocationUtils.translate('Approved');
      case ProductApprovalStatus.rejected:
        return LocationUtils.translate('Rejected')  ;
    }
  }

  /// 获取审核状态颜色 [背景色, 边框色, 文字色]
  List<Color> _getApprovalStatusColor(ProductApprovalStatus status) {
    switch (status) {
      case ProductApprovalStatus.pending:
        return [Colors.orange[50]!, Colors.orange[300]!, Colors.orange[700]!];
      case ProductApprovalStatus.approved:
        return [Colors.green[50]!, Colors.green[300]!, Colors.green[700]!];
      case ProductApprovalStatus.rejected:
        return [Colors.red[50]!, Colors.red[300]!, Colors.red[700]!];
    }
  }
}