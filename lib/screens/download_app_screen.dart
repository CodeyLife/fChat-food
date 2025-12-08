import 'package:fchatapi/webapi/WebUtil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';

/// 下载App提示页面
class DownloadAppScreen extends StatelessWidget {
  const DownloadAppScreen({super.key});

  /// 下载地址
  static const String downloadUrl = 'https://fchat.us/app/fchat/?downapp';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIcon(),
                  SizedBox(height: 32.h),
                  _buildTitle(),
                  SizedBox(height: 16.h),
                  _buildSubtitle(),
                  SizedBox(height: 48.h),
                  _buildDownloadButton(context),
                  SizedBox(height: 24.h),
                  _buildFeatures(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建图标
  Widget _buildIcon() {
    return Container(
      width: 120.w,
      height: 120.w,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: AppShadows.lg,
      ),
      child: Icon(
        Icons.phone_android,
        size: 60.r,
        color: Colors.white,
      ),
    );
  }

  /// 构建标题
  Widget _buildTitle() {
    return Text(
      LocationUtils.translate('Download App'),
      style: TextStyle(
        fontSize: 28.sp,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// 构建副标题
  Widget _buildSubtitle() {
    // 检查是否在微信中打开
    final isWeChat = WebUtil.isWecHAT();
    
    return Column(
      children: [
        Text(
          LocationUtils.translate('Experience our full-featured mobile app'),
          style: TextStyle(
            fontSize: 16.sp,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        if (isWeChat) ...[
          SizedBox(height: 16.h),
          _buildWeChatTip(),
        ],
      ],
    );
  }

  /// 构建下载按钮
  Widget _buildDownloadButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppShadows.button,
      ),
      child: ElevatedButton(
        onPressed: () => _handleDownload(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download,
              color: Colors.white,
              size: 24.r,
            ),
            SizedBox(width: 12.w),
            Text(
              LocationUtils.translate('Download Now'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建微信提示卡片
  Widget _buildWeChatTip() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.orange[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange[700],
            size: 24.r,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              LocationUtils.translate('Please open this page in your browser to download the app'),
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建功能特性列表
  Widget _buildFeatures() {
    return Column(
      children: [
        _buildFeatureItem(
          Icons.speed,
          LocationUtils.translate('Faster Performance'),
          LocationUtils.translate('Optimized for mobile devices'),
        ),
        SizedBox(height: 16.h),
        _buildFeatureItem(
          Icons.security,
          LocationUtils.translate('Secure & Safe'),
          LocationUtils.translate('Your data is protected'),
        ),
        SizedBox(height: 16.h),
        _buildFeatureItem(
          Icons.notifications_active,
          LocationUtils.translate('Real-time Updates'),
          LocationUtils.translate('Get instant notifications'),
        ),
      ],
    );
  }

  /// 构建功能项
  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              gradient: AppTheme.lightBlueGradient,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24.r,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 处理下载
  Future<void> _handleDownload(BuildContext context) async {
    try {
      final uri = Uri.parse(downloadUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          _showErrorDialog(context);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context);
      }
    }
  }

  /// 显示错误对话框
  void _showErrorDialog(BuildContext context) {
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
}
