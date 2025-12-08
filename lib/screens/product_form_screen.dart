import '../services/shop_service.dart';
import '../widgets/luckin_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/product.dart';
import '../utils/debug.dart';
import '../widgets/banner_image_picker.dart';
import '../widgets/simple_video_picker.dart';
import '../services/product_service.dart';
import '../services/product_category_service.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/snackbar_utils.dart';
import '../utils/debouncer.dart';

/// 键盘交互处理组件，避免软键盘冲突导致白屏
class KeyboardDismissOnTap extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnTap({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 点击空白区域时隐藏键盘
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  final CoffeeProduct? product; // 如果为null则是新增，否则是编辑

  const ProductFormScreen({
    super.key,
    this.product,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> 
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = '';
  bool _isStatusEnabled = true;
  bool _isLoading = false;
  List<ImageObj> _selectedImages = [];
  String? _selectedVideoUrl;

  List<String> _categories = [];

  // 防抖器，避免频繁的状态更新导致白屏
  late Debouncer _imagesDebouncer;
  late Debouncer _videoDebouncer;
  

  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    // 初始化防抖器，延迟300ms更新状态
    _imagesDebouncer = Debouncer(delay: const Duration(milliseconds: 300));
    _videoDebouncer = Debouncer(delay: const Duration(milliseconds: 300));
    
    // 添加键盘状态监听
    WidgetsBinding.instance.addObserver(this);
    
    _initializeData();
  }


  /// 初始化数据
  Future<void> _initializeData() async {
    if (_isEditMode) {
      // 编辑模式：填充现有数据
      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price.toString();
      _descriptionController.text = widget.product!.description;
      _selectedCategory = widget.product!.category;
      _isStatusEnabled = widget.product!.status;
      _selectedVideoUrl = widget.product!.videoUrl;
      
      // 初始化图片列表
      if (widget.product!.productImages != null) {
        _selectedImages = List.from(widget.product!.productImages!.images);
      }
    }
    
    // 加载分类数据
    await _loadCategories();
  }

  /// 加载分类数据
  Future<void> _loadCategories() async {
    try {
      await ProductCategoryService.initialize();
      final categories = ProductCategoryService.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          if (_isEditMode) {
            // 编辑模式：如果当前商品的分类不在列表中，添加到列表中
            if (!categories.contains(_selectedCategory)) {
              _categories.add(_selectedCategory);
            }
          } else {
            // 新增模式：选择第一个分类
            if (categories.isNotEmpty) {
              _selectedCategory = categories.first;
            }
          }
        });
      }
    } catch (e) {
      Debug.log('加载分类数据失败: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imagesDebouncer.dispose();
    _videoDebouncer.dispose();
    // 移除键盘状态监听
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CommonWidget.appBar(title: _isEditMode ? LocationUtils.translate('Edit Product') : LocationUtils.translate('Add Product'), context: context),
      // 让系统自动处理键盘弹出时的布局调整
      resizeToAvoidBottomInset: true,
      body: KeyboardDismissOnTap(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          // 添加键盘滚动行为，确保输入时不会出现布局问题
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // 防止过度滚动，提供更好的用户体验
          physics: const ClampingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本信息卡片
                _buildInfoCard(),
                SizedBox(height: 16.h),
                // 商品图片卡片 - 使用 RepaintBoundary 隔离重绘
                RepaintBoundary(
                  child: _buildImageCard(),
                ),
                SizedBox(height: 16.h),
                // 商品视频卡片 - 使用 RepaintBoundary 隔离重绘
                RepaintBoundary(
                  child: _buildVideoCard(),
                ),
                SizedBox(height: 16.h),
                // 其他设置卡片
                _buildSettingsCard(),
                SizedBox(height: 32.h),
                // 操作按钮
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建基本信息卡片
  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocationUtils.translate('Basic Information'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: 16.h),
            // 商品名称
            TextFormField(
              key: const ValueKey('product_name'),
              controller: _nameController,
              // 添加键盘交互优化
              textInputAction: TextInputAction.next,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: LocationUtils.translate('Product Name'),
                hintText: LocationUtils.translate('Please enter the product name'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                prefixIcon: const Icon(Icons.shopping_bag_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return LocationUtils.translate('Please enter the product name');
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            // 商品价格
            TextFormField(
              key: const ValueKey('product_price'),
              controller: _priceController,
              // 添加键盘交互优化
              textInputAction: TextInputAction.next,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: LocationUtils.translate('Product Price'),
                hintText: LocationUtils.translate('Please enter the product price'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                prefixText: LocationUtils.translate('${ShopService.symbol.value} '),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return LocationUtils.translate('Please enter the product price');
                }
                if (double.tryParse(value) == null) {
                  return LocationUtils.translate('Please enter a valid price');
                }
                if (double.parse(value) <= 0) {
                  return LocationUtils.translate('The price must be greater than 0');
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            // 商品描述
            TextFormField(
              key: const ValueKey('product_description'),
              controller: _descriptionController,
              // 添加键盘交互优化
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: LocationUtils.translate('Product description'),
                hintText: LocationUtils.translate('Please enter product description'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                prefixIcon: const Icon(Icons.description_outlined),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return LocationUtils.translate('Please enter product description');
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            // 商品分类
            DropdownButtonFormField<String>(
              key: const ValueKey('product_category'),
              initialValue: _selectedCategory.isEmpty ? null : _selectedCategory,
              decoration: InputDecoration(
                labelText: LocationUtils.translate('Product Category'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.red[600]!, width: 2),
                ),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return LocationUtils.translate('Please select a product category');
                }
                return null;
              },
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建商品图片卡片
  Widget _buildImageCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  LocationUtils.translate('Product Image'),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const Spacer(),
                if (_selectedImages.isNotEmpty)
                  Text(
                    '${_selectedImages.length}/9',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
            BannerImagePicker(
              selectedImages: _selectedImages,
              onImagesChanged: (images) {
                // 使用防抖器延迟状态更新，避免频繁重建导致白屏
                _imagesDebouncer(() {
                  if (mounted) {
                    setState(() {
                      _selectedImages = images;
                    });
                  }
                });
              },
              maxImages: 9,
            ),
            if (_selectedImages.isEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        LocationUtils.translate('Suggest adding 1-3 product images, with the first image displayed as the main image'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建商品视频卡片
  Widget _buildVideoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  LocationUtils.translate('Product Video'),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const Spacer(),
                if (_selectedVideoUrl != null && _selectedVideoUrl!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      'Uploaded',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
            SimpleVideoPicker(
              selectedVideoUrl: _selectedVideoUrl,
              onVideoChanged: (videoUrl) {
                // 使用防抖器延迟状态更新，避免频繁重建导致白屏
                _videoDebouncer(() {
                  if (mounted) {
                    setState(() {
                      _selectedVideoUrl = videoUrl;
                    });
                  }
                });
              },
              width: double.infinity,
              height: 200.h,
            ),
            if (_selectedVideoUrl == null || _selectedVideoUrl!.isEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '${LocationUtils.translate('Supported video formats')}: MP4, MOV, AVI. ${LocationUtils.translate('File size less than')} 5MB',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建其他设置卡片
  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocationUtils.translate('Other Settings'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: 16.h),
            // 商品状态
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.grey[600]),
                SizedBox(width: 12.w),
                Text(
                  LocationUtils.translate('Product Status'),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _isStatusEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isStatusEnabled = value;
                    });
                  },
                  activeThumbColor: AppTheme.primaryBlue,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              _isStatusEnabled ? LocationUtils.translate('Listed for sale') : LocationUtils.translate('Unlisted'),
              style: TextStyle(
                fontSize: 14.sp,
                color: _isStatusEnabled ? Colors.green[600] : Colors.red[600],
              ),
            ),
            // 编辑模式下显示商品信息
            if (_isEditMode) ...[
              SizedBox(height: 16.h),
              _buildProductInfo(),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建商品信息（仅编辑模式）
  Widget _buildProductInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocationUtils.translate('Product Information'),
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.primaryBlue,
          ),
        ),
        SizedBox(height: 8.h),
        _buildInfoRow('Product ID', widget.product!.id),
        _buildInfoRow('Creation Time', _formatDateTime(widget.product!.createdAt)),
        _buildInfoRow('Update Time', _formatDateTime(widget.product!.updatedAt)),
      ],
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isEditMode ? LocationUtils.translate('Save Changes') : LocationUtils.translate('Save Product'),
                    style: TextStyle(fontSize: 16.sp),
                  ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: BorderSide(color: AppTheme.primaryBlue),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              LocationUtils.translate('Cancel'),
              style: TextStyle(fontSize: 16.sp),
            ),
          ),
        ),
      ],
    );
  }

  /// 保存商品
  void _saveProduct() async {
    // 防止重复提交
    if (_isLoading) return;
    
    // 先进行表单验证，避免不必要的异步操作
    if (!_formKey.currentState!.validate()) {
      // 表单验证失败，显示提示信息并滚动到错误字段
      SnackBarUtils.showWarning(
        context,
        LocationUtils.translate('Please fill in all required fields correctly'),
      );
      _scrollToFirstError();
      return;
    }

    // 检查是否至少有一张图片
    if (_selectedImages.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        LocationUtils.translate('Please add at least one product image'),
      );
      return;
    }

    // 使用 addPostFrameCallback 延迟状态更新，避免在输入完成后立即重建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
        _performSave();
      }
    });
  }

  /// 执行实际的保存操作
  Future<void> _performSave() async {

    try {
      if (_isEditMode) {
        // 编辑模式：更新现有商品
        widget.product!.update(
          name: _nameController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          status: _isStatusEnabled,
          videoUrl: _selectedVideoUrl ?? '',
        );

        // 根据用户权限设置审核状态
        final userService = UserService.instance;
        final previousStatus = widget.product!.approvalStatus;
        
        if (userService.isSuperAdmin) {
          // 超级管理员编辑：直接设置为已通过审核
          widget.product!.updateApprovalStatus(ProductApprovalStatus.approved);
          Debug.log('超级管理员编辑商品: ${widget.product!.name}, 审核状态: $previousStatus -> approved');
        } else {
          // 普通用户编辑：设置为待审核状态
          widget.product!.updateApprovalStatus(ProductApprovalStatus.pending);
          Debug.log('普通用户编辑商品: ${widget.product!.name}, 审核状态: $previousStatus -> pending');
        }

        // 更新图片
        if (widget.product!.productImages == null) {
          widget.product!.productImages = ProductGallery();
        }
        widget.product!.productImages!.images.clear();
        widget.product!.productImages!.images.addAll(_selectedImages);

        // 保存商品
        final success = await ProductService.saveProduct(widget.product!);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(LocationUtils.translate('Product updated successfully')),
                backgroundColor: Colors.green[600],
              ),
            );
            Navigator.pop(context, true); // 返回并通知刷新
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(LocationUtils.translate('Product update failed, please try again')),
                backgroundColor: Colors.red[600],
              ),
            );
          }
        }
      } else {
        // 新增模式：创建新商品
        final productGallery = ProductGallery();
        for (var image in _selectedImages) {
          productGallery.images.add(image);
        }
        
        final product = CoffeeProduct(
          name: _nameController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          status: _isStatusEnabled,
          productImages: productGallery,
          videoUrl: _selectedVideoUrl ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 根据用户权限设置审核状态
        final userService = UserService.instance;
        if (userService.isSuperAdmin) {
          // 超级管理员新增：直接设置为已通过审核
          product.updateApprovalStatus(ProductApprovalStatus.approved);
          Debug.log('超级管理员新增商品: ${product.name}, 审核状态: approved');
        } else {
          // 普通用户新增：设置为待审核状态
          product.updateApprovalStatus(ProductApprovalStatus.pending);
          Debug.log('普通用户新增商品: ${product.name}, 审核状态: pending');
        }

        // 保存商品
        final success = await ProductService.saveProduct(product);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(LocationUtils.translate('Product saved successfully')),
                backgroundColor: Colors.green[600],
              ),
            );
            Navigator.pop(context, true); // 返回并通知刷新
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(LocationUtils.translate('Product save failed, please try again')),
                backgroundColor: Colors.red[600],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocationUtils.translate('Save failed: \$e')),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  /// 滚动到第一个验证错误的字段
  void _scrollToFirstError() {
    // 延迟执行，确保错误信息已经显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 滚动到表单顶部，让用户看到错误信息
        Scrollable.ensureVisible(
          _formKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
