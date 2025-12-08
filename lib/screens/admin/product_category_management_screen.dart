import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/product_category_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/location.dart';
import '../../utils/debug.dart';

class ProductCategoryManagementScreen extends StatefulWidget {
  const ProductCategoryManagementScreen({super.key});

  @override
  State<ProductCategoryManagementScreen> createState() => _ProductCategoryManagementScreenState();
}

class _ProductCategoryManagementScreenState extends State<ProductCategoryManagementScreen> {
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 加载分类数据
  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await ProductCategoryService.initialize();
      final categories = ProductCategoryService.getAllCategories();
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      Debug.log('加载分类数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocationUtils.translate('加载分类数据失败: \$e')),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }


  /// 显示添加分类对话框
  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8B4513), const Color(0xFFA0522D)],
                ),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 20.w),
            ),
            SizedBox(width: 12.w),
            Text(
              LocationUtils.translate('Add Category'),
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: LocationUtils.translate('Category Name'),
            hintText: LocationUtils.translate('Enter category name'),
            prefixIcon: Icon(Icons.category_rounded, color: const Color(0xFF8B4513)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: const Color(0xFF8B4513), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF8B4513), const Color(0xFFA0522D)],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: ElevatedButton(
              onPressed: () async {
                final categoryName = controller.text.trim();
                if (categoryName.isNotEmpty) {
                  Navigator.pop(context);
                  final success = await ProductCategoryService.addCategory(categoryName);
                  if (success) {
                    _loadCategories();
                     if(mounted){
                       // ignore: use_build_context_synchronously
                       ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8.w),
                            Text(LocationUtils.translate('Category added successfully')),
                          ],
                        ),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    );
                     } 
                   
                  } else {
                    if(mounted){
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 8.w),
                            Text(LocationUtils.translate('Failed to add category')),
                          ],
                        ),
                        backgroundColor: Colors.red[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(LocationUtils.translate('Add')),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示编辑分类对话框
  void _showEditCategoryDialog(String oldCategory) {
    final controller = TextEditingController(text: oldCategory);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[400]!],
                ),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.edit_rounded, color: Colors.white, size: 20.w),
            ),
            SizedBox(width: 12.w),
            Text(
              LocationUtils.translate('Edit Category'),
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: LocationUtils.translate('Category Name'),
            hintText: LocationUtils.translate('Enter category name'),
            prefixIcon: Icon(Icons.category_rounded, color: Colors.blue[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              LocationUtils.translate('Cancel'),
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[400]!],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: ElevatedButton(
              onPressed: () async {
                final newCategoryName = controller.text.trim();
                if (newCategoryName.isNotEmpty && newCategoryName != oldCategory) {
                  Navigator.pop(context);
                  final success = await ProductCategoryService.updateCategory(oldCategory, newCategoryName);
                  if (success) {
                    _loadCategories();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(LocationUtils.translate('Save')),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[600]!, Colors.red[400]!],
                ),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.warning_rounded, color: Colors.white, size: 20.w),
            ),
            SizedBox(width: 12.w),
            Text(
              LocationUtils.translate('Confirm Delete'),
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[600], size: 20.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      "${LocationUtils.translate('Are you sure you want to delete category')} \"$category\"? ${LocationUtils.translate('This action cannot be undone.')}",
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.red[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              LocationUtils.translate('Cancel'),
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[600]!, Colors.red[400]!],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await ProductCategoryService.deleteCategory(category);
                if (success) {
                  _loadCategories();
                } 
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(LocationUtils.translate('Delete')),
            ),
          ),
        ],
      ),
    );
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
            // 顶部操作栏
            _buildAppBar(),
            // 分类列表
            Expanded(
              child: _buildCategoryList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建顶部操作栏
  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 40.h, 20.w, 20.h),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24.r),
          bottomRight: Radius.circular(24.r),
        ),
        boxShadow: AppShadows.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.category_outlined,
                  color: Colors.white,
                  size: 24.w,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  "${LocationUtils.translate('Product Category')}\n${LocationUtils.translate('Management')}",
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          // 按钮行
          Row(
            children: [
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.1),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _showAddCategoryDialog,
                  icon: Icon(Icons.add_rounded, size: 20.w),
                  label: Text(LocationUtils.translate('Add category'), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryBlue,
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 2,
                    shadowColor: Colors.white.withValues(alpha:0.3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  /// 构建分类列表
  Widget _buildCategoryList() {
    if (_isLoading) {
      return SizedBox(
        height: 200.h,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF8B4513), const Color(0xFFA0522D)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                LocationUtils.translate('Loading categories...'),
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return SizedBox(
        height: 200.h,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[100]!, Colors.grey[200]!],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.category_outlined,
                  size: 48.w,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                LocationUtils.translate('No categories available'),
                style: TextStyle(
                  fontSize: 18.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                LocationUtils.translate('Tap the "Add Category" button to get started'),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: _buildCategoryCard(category, index),
        );
      },
    );
  }

  /// 构建分类卡片
  Widget _buildCategoryCard(String category, int index) {
    
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppShadows.card,
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha:0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEditCategoryDialog(category),
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // 分类图标
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: AppShadows.md,
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: Colors.white,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 16.w),
                // 分类名称
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        LocationUtils.translate('Tap to edit'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                // 操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentBlue.withValues(alpha:0.1),
                            AppTheme.accentBlue.withValues(alpha:0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppTheme.accentBlue.withValues(alpha:0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _showEditCategoryDialog(category),
                        icon: Icon(Icons.edit_rounded, size: 20.w),
                        color: AppTheme.accentBlue,
                        padding: EdgeInsets.all(8.w),
                        constraints: BoxConstraints(
                          minWidth: 40.w,
                          minHeight: 40.w,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentRed.withValues(alpha:0.1),
                            AppTheme.accentRed.withValues(alpha:0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppTheme.accentRed.withValues(alpha:0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _showDeleteConfirmDialog(category),
                        icon: Icon(Icons.delete_rounded, size: 20.w),
                        color: AppTheme.accentRed,
                        padding: EdgeInsets.all(8.w),
                        constraints: BoxConstraints(
                          minWidth: 40.w,
                          minHeight: 40.w,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
