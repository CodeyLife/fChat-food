
import '../services/shop_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/app_theme.dart';
import 'async_image_widget.dart';

class CommonWidget {
  /// 通用 AppBar 组件（贴合项目主题）
  /// [title] 标题文本
  /// [context] 上下文（用于返回导航）
  /// [showBackButton] 是否显示返回按钮（默认false，首页无需返回）
  /// [actions] 右侧操作按钮列表（默认null，可自定义）
  /// [centerTitle] 标题是否居中（默认true，符合主题规范）
  /// [useGradient] 是否使用渐变背景（默认true，贴合主题渐变风格）
  static AppBar appBar({
    required String title,
    required BuildContext context,
    bool showBackButton = false,
    List<Widget>? actions,
    bool centerTitle = true,
    bool useGradient = true,
  }) {
    return AppBar(
      // 1. 基础尺寸与间距（使用项目常量，统一规范）
      toolbarHeight: 56.h, // 固定高度，适配屏幕
  //    titleSpacing: showBackButton ? 0 : AppSpacing.sm, // 标题与左侧间距
  //    leadingWidth: showBackButton ? 48.w : 0, // 返回按钮区域宽度，避免挤压

      // 2. 标题样式（复用主题文本样式，统一字体规范）
      title: Text(
        title,
        style: AppTheme.theme.textTheme.headlineSmall?.copyWith(
          color: Colors.white, // 白色标题在蓝色背景上更醒目
          letterSpacing: 0.5.w, // 微调字间距，提升精致度
        ),
      ),
      centerTitle: centerTitle,
      // 4. 左侧返回按钮（风格统一，交互优化）
      leading: showBackButton
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                size: 20.w, // 适配尺寸
                color: Colors.white, // 与标题颜色统一
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md), // 统一间距
              splashRadius: 24.w, // 点击水波纹半径，优化交互反馈
              tooltip: "返回", // 无障碍提示
            )
          : null,

      // 5. 右侧操作按钮（默认空，支持自定义，风格统一）
      actions: actions?.map((widget) {
        // 对右侧按钮统一加间距，避免贴边
        return Padding(
          padding: EdgeInsets.only(right: AppSpacing.sm),
          child: widget,
        );
      }).toList(),

      // 6. 背景样式（复用主题渐变/纯色，统一视觉）
      flexibleSpace: useGradient
          ? Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient, // 直接使用主题主渐变
                // 可选：添加细微圆角（顶部无圆角，底部轻微圆角过渡）
                // borderRadius: BorderRadius.vertical(
                //   bottom: Radius.circular(8.r)
                // ),
              ),
            )
          : Container(color: AppTheme.primaryBlue), // 纯色 fallback

      // 7. 阴影与边框（贴合主题阴影规范，提升层次）
      elevation: 2, // 轻微阴影，避免厚重感
      shadowColor: AppShadows.card.first.color, // 复用主题卡片阴影，统一风格
      bottomOpacity:0, // 消除底部默认边框，与渐变/纯色过渡更自然

      // 8. 状态栏样式（可选：根据背景色调整状态栏图标颜色）
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light, // 白色状态栏图标（蓝色背景上更清晰）
        statusBarColor: Colors.transparent, // 透明状态栏，与渐变融合
      ),
    );
  }
}

///次级标题组件
class PageSubtitle extends StatelessWidget {
  /// 页面子标题组件
  /// [title] 子标题文本
  /// [showDivider] 是否显示底部分割线（默认true，区分内容区域）
  /// [actionWidget] 右侧操作组件（如“筛选”“添加”按钮，可选）
  const PageSubtitle({
    super.key,
    required this.title,
    this.showDivider = true,
    this.actionWidget,
  });

  final String title;
  final bool showDivider;
  final Widget? actionWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 子标题主体（左侧文本 + 右侧操作）
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, // 水平间距：16.w（复用主题间距）
            vertical: AppSpacing.md,   // 垂直间距：12.w，控制高度
          ),
          color: AppTheme.surface, // 白色背景，与页面背景统一
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 子标题文本（风格：中灰标题，比 AppBar 主标题轻量）
              Text(
                title,
                style: AppTheme.theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.textSecondary, // 中灰色：#6B7280（主题中性色）
                  fontWeight: FontWeight.w500,   // 权重比主标题轻（主标题600）
                ),
              ),
              // 右侧操作组件（如筛选、添加按钮，可选）
              if (actionWidget != null) actionWidget!,
            ],
          ),
        ),
        // 底部分割线（可选，增强区域划分）
        if (showDivider)
          Container(
            height: 1.h,
            color: AppTheme.divider, // 分割线颜色：#E5E7EB（主题规范）
          ),
      ],
    );
  }
}
/// 现代化商品卡片
class LuckinProductCard extends StatelessWidget {
  final String name;
  final String price;
  final Uint8List? imageBytes;
  final String? category;
  final VoidCallback? onTap;
  final Widget? trailing;

  const LuckinProductCard({
    super.key,
    required this.name,
    required this.price,
    this.imageBytes,
    this.category,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lg,
          boxShadow: AppShadows.sm,
          border: Border.all(
            color: AppTheme.divider,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品图片
            Container(
              height: 160.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: AppRadius.lg.topLeft,
                  topRight: AppRadius.lg.topRight,
                ),
                color: AppTheme.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: AppRadius.lg.topLeft,
                  topRight: AppRadius.lg.topRight,
                ),
                child: imageBytes != null
                    ? AsyncImageWidget(
                        initialBytes: imageBytes!,
                        width: double.infinity,
                        height: 160.h,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.only(
                          topLeft: AppRadius.lg.topLeft,
                          topRight: AppRadius.lg.topRight,
                        ),
                        errorWidget: Icon(
                          Icons.coffee,
                          size: 60.w,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : Icon(
                        Icons.coffee,
                        size: 60.w,
                        color: AppTheme.textSecondary,
                      ),
              ),
            ),
            
            // 商品信息
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null) ...[
                    Text(
                      category!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                  ],
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¥$price',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 现代化分类卡片
class LuckinCategoryCard extends StatelessWidget {
  final String name;
  final String? icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const LuckinCategoryCard({
    super.key,
    required this.name,
    this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        margin: EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: AppRadius.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.divider,
            width: 1,
          ),
          boxShadow: isSelected ? AppShadows.sm : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                _getIconData(icon!),
                size: 16.w,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              SizedBox(width: 4.w),
            ],
            Text(
              name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'coffee':
        return Icons.coffee;
      case 'cake':
        return Icons.cake;
      case 'drink':
        return Icons.local_drink;
      case 'food':
        return Icons.restaurant;
      default:
        return Icons.category;
    }
  }
}

/// 现代化订单卡片
class LuckinOrderCard extends StatelessWidget {
  final String orderNumber;
  final String status;
  final String totalAmount;
  final String date;
  final List<String> items;
  final VoidCallback? onTap;
  final Widget? trailing;

  const LuckinOrderCard({
    super.key,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.date,
    required this.items,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md),
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lg,
          boxShadow: AppShadows.sm,
          border: Border.all(
            color: AppTheme.divider,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #$orderNumber',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha:0.1),
                    borderRadius: AppRadius.sm,
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Items: ${items.join(', ')}',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ¥$totalAmount',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (trailing != null) ...[
              SizedBox(height: AppSpacing.md),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.primaryBlue;
    }
  }
}

/// 现代化按钮
class LuckinButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;

  const LuckinButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? AppTheme.primaryBlue;
    final effectiveTextColor = textColor ?? Colors.white;

    if (isOutlined) {
      return SizedBox(
        width: width,
        height: height ?? 48.h,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: effectiveBackgroundColor,
            side: BorderSide(color: effectiveBackgroundColor),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.md,
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveBackgroundColor),
                  ),
                )
              : Text(text),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height ?? 48.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.md,
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
                ),
              )
            : Text(text),
      ),
    );
  }
}

/// 现代化输入框
class LuckinInput extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;

  const LuckinInput({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

/// 现代化对话框
class LuckinDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool showCancel;

  const LuckinDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.showCancel = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      content: Text(
        content,
        style: TextStyle(
          fontSize: 14.sp,
          color: AppTheme.textSecondary,
        ),
      ),
      actions: [
        if (showCancel)
          TextButton(
            onPressed: onCancel ?? () => Navigator.of(context).pop(),
            child: Text(
              cancelText ?? 'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        LuckinButton(
          text: confirmText ?? 'Confirm',
          onPressed: onConfirm ?? () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// 空状态组件
class LuckinEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonTap;

  const LuckinEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80.w,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonTap != null) ...[
              SizedBox(height: 32.h),
              LuckinButton(
                text: buttonText!,
                onPressed: onButtonTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 购物车商品项
class LuckinCartItem extends StatelessWidget {
  final String name;
  final String price;
  final int quantity;
  final Uint8List? imageBytes;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback? onRemove;

  const LuckinCartItem({
    super.key,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageBytes,
    this.onIncrease,
    this.onDecrease,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.sm,
        border: Border.all(
          color: AppTheme.divider,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 商品图片
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              borderRadius: AppRadius.md,
              color: AppTheme.surface,
            ),
            child: ClipRRect(
              borderRadius: AppRadius.md,
              child: imageBytes != null
                  ? AsyncImageWidget(
                      initialBytes: imageBytes!,
                      width: 80.w,
                      height: 80.w,
                      fit: BoxFit.cover,
                      borderRadius: AppRadius.md,
                      errorWidget: Icon(
                        Icons.coffee,
                        size: 40.w,
                        color: AppTheme.textSecondary,
                      ),
                    )
                  : Icon(
                      Icons.coffee,
                      size: 40.w,
                      color: AppTheme.textSecondary,
                    ),
            ),
          ),
          
          SizedBox(width: AppSpacing.md),
          
          // 商品信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  '${ShopService.instance.shop.value.symbol.value}$price',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          
          // 数量控制
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
         
                children: [
                  IconButton(
                    onPressed: onDecrease,
                    icon: Icon(Icons.remove_circle_outline, size: 20.w),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      foregroundColor: AppTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha:0.1),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Text(
                      '$quantity',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onIncrease,
                    icon: Icon(Icons.add_circle_outline, size: 20.w),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      foregroundColor: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, size: 18.w),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha:0.1),
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 页面指示器
class LuckinPageIndicator extends StatelessWidget {
  final int currentIndex;
  final int itemCount;
  final Color activeColor;
  final Color inactiveColor;
  final double? size;

  const LuckinPageIndicator({
    super.key,
    required this.currentIndex,
    required this.itemCount,
    required this.activeColor,
    required this.inactiveColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        itemCount,
        (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: currentIndex == index ? (size ?? 20.w) : (size ?? 8.w),
          height: size ?? 8.h,
          decoration: BoxDecoration(
            color: currentIndex == index ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4.w),
          ),
        ),
      ),
    );
  }
}
