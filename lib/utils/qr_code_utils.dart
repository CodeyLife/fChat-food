import '../services/shop_service.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_theme.dart';

/// 二维码工具类
class QRCodeUtils {
  
  /// 生成商品分享二维码
  static Widget generateProductQR({
    required String productId,
    required String productName,
    double size = 200.0,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final data = 'coffee_shop://product/$productId';
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size.w,
            backgroundColor: backgroundColor ?? AppTheme.surface,
            errorStateBuilder: (context, error) {
              return Container(
                width: size.w,
                height: size.w,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: AppRadius.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppTheme.textHint,
                      size: 32.w,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Generate failed',
                      style: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Scan to view product details',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            productName,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  /// 生成订单支付二维码
  static Widget generatePaymentQR({
    required String orderId,
    required double amount,
    double size = 200.0,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final data = 'coffee_shop://payment/$orderId?amount=$amount';
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size.w,
            backgroundColor: backgroundColor ?? AppTheme.surface,

            errorStateBuilder: (context, error) {
              return Container(
                width: size.w,
                height: size.w,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: AppRadius.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppTheme.textHint,
                      size: 32.w,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Generate failed',
                      style: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Scan QR code to pay',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Order Number: $orderId',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            '${ShopService.symbol.value}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppTheme.accentRed,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 生成店铺推广二维码
  static Widget generateStoreQR({
    required String storeId,
    String? storeName,
    double size = 200.0,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final data = 'coffee_shop://store/$storeId';
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size.w,
            backgroundColor: backgroundColor ?? AppTheme.surface,
 
            errorStateBuilder: (context, error) {
              return Container(
                width: size.w,
                height: size.w,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: AppRadius.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppTheme.textHint,
                      size: 32.w,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Generate failed',
                      style: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Scan to follow the store',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (storeName != null) ...[
            SizedBox(height: AppSpacing.sm),
            Text(
              storeName,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// 生成带Logo的二维码
  static Widget generateQRWithLogo({
    required String data,
    required String logoPath,
    double size = 200.0,
    double logoSize = 40.0,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.sm,
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size.w,
        backgroundColor: backgroundColor ?? AppTheme.surface,

        embeddedImage: AssetImage(logoPath),
        embeddedImageStyle: QrEmbeddedImageStyle(
          size: Size(logoSize.w, logoSize.w),
        ),
        errorStateBuilder: (context, error) {
          return Container(
            width: size.w,
            height: size.w,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: AppRadius.md,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: AppTheme.textHint,
                  size: 32.w,
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Generate failed',
                  style: TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  /// 生成订单二维码
  /// [orderId] 订单的唯一ID (order.id), 用于二维码数据
  /// [orderNumber] 订单号 (order.orderNumber), 仅用于显示
  /// 二维码数据格式: coffee_shop://order/{order.id}
  static Widget generateOrderQR({
    required String orderId,
    required String orderNumber,
    double size = 200.0,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    // 使用订单唯一ID生成二维码数据
    final data = 'coffee_shop://order/$orderId';
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size.w,
            backgroundColor: backgroundColor ?? AppTheme.surface,
         
            errorStateBuilder: (context, error) {
              return Container(
                width: size.w,
                height: size.w,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: AppRadius.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppTheme.textHint,
                      size: 32.w,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Generate failed',
                      style: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Pickup Code',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Order Number: $orderNumber',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Please show this code to the staff',
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 生成简单二维码（无装饰）
  static Widget generateSimpleQR({
    required String data,
    double size = 150.0,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size.w,
      backgroundColor: backgroundColor ?? Colors.white,

      errorStateBuilder: (context, error) {
        return Container(
          width: size.w,
          height: size.w,
          color: AppTheme.background,
          child: Icon(
            Icons.error_outline,
            color: AppTheme.textHint,
            size: 32.w,
          ),
        );
      },
    );
  }
}
