import '../widgets/luckin_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/qr_code_utils.dart';

/// 二维码展示页面
class QRCodeScreen extends StatelessWidget {
  final String title;
  final String data;
  final QRCodeType type;
  final Map<String, dynamic>? extraData;

  const QRCodeScreen({
    super.key,
    required this.title,
    required this.data,
    required this.type,
    this.extraData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CommonWidget.appBar(title: title, context: context),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // 二维码展示区域
            _buildQRCode(context),
            
            SizedBox(height: AppSpacing.xxl),
            
            // 操作按钮
            _buildActionButtons(context),
            
         //   SizedBox(height: AppSpacing.xl),
            
            // 说明文字
            // _buildDescription(context),
          ],
        ),
      ),
    );
  }

  /// 构建二维码
  Widget _buildQRCode(BuildContext context) {
    switch (type) {
      case QRCodeType.product:
        return QRCodeUtils.generateProductQR(
          productId: data,
          productName: extraData?['productName'] ?? '商品',
        );
        
      case QRCodeType.payment:
        return QRCodeUtils.generatePaymentQR(
          orderId: data,
          amount: extraData?['amount'] ?? 0.0,
        );
        
      case QRCodeType.store:
        return QRCodeUtils.generateStoreQR(
          storeId: data,
          storeName: extraData?['storeName'],
        );
        
      case QRCodeType.simple:
        return QRCodeUtils.generateSimpleQR(data: data);
        
      case QRCodeType.order:
        // data 包含订单的唯一ID (order.id)
        // extraData['orderNumber'] 包含订单号 (order.orderNumber), 仅用于显示
        return QRCodeUtils.generateOrderQR(
          orderId: data,
          orderNumber: extraData?['orderNumber'] ?? data,
        );
    }
  }

  /// 构建操作按钮
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _shareQRCode(context),
            icon: Icon(Icons.share, size: 18.w),
            label: Text(LocationUtils.translate('Share')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.md,
              ),
            ),
          ),
        ),
        
        SizedBox(width: AppSpacing.md),
        
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _saveQRCode(context),
            icon: Icon(Icons.download, size: 18.w),
            label: Text(LocationUtils.translate('Save')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: BorderSide(color: AppTheme.primaryBlue),
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.md,
              ),
            ),
          ),
        ),
      ],
    );
  }


  /// 分享二维码
  void _shareQRCode(BuildContext context) {
    // TODO: 实现分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocationUtils.translate('Share feature is under development...')),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  /// 保存二维码
  void _saveQRCode(BuildContext context) {
    // TODO: 实现保存到相册功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocationUtils.translate('Save feature is under development...')),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }
}

/// 二维码类型枚举
enum QRCodeType {
  product,    // 商品二维码
  payment,    // 支付二维码
  store,      // 店铺二维码
  order,      // 订单取餐码
  simple,     // 简单二维码
}
