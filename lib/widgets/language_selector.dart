import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:language_picker/language_picker_dropdown.dart';
import 'package:language_picker/languages.dart';
import 'package:get/get.dart';
import 'package:fchatapi/util/Translate.dart';
import '../services/language_service.dart';
import '../utils/app_theme.dart';

/// 语言选择器组件
class LanguageSelector extends StatelessWidget {
  final Function(String)? onLanguageChanged;
  final bool isCompact;
  
  const LanguageSelector({
    super.key,
    this.onLanguageChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GetX<LanguageService>(
      builder: (languageService) {
        if (isCompact) {
          return _buildCompactSelector(context, languageService);
        } else {
          return _buildFullSelector(context, languageService);
        }
      },
    );
  }

  /// 构建紧凑型选择器（用于横屏导航栏）
  Widget _buildCompactSelector(BuildContext context, LanguageService languageService) {
    return GestureDetector(
      onTap: () => _showLanguageDialog(context, languageService),
      child: Container(
        constraints: BoxConstraints(
          minWidth: 80.w,
          maxWidth: 120.w,
        ),
        height: 32.h,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.1),
              AppTheme.primaryLightBlue.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: AppRadius.md,
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.language,
              size: 12.w,
              color: AppTheme.primaryBlue,
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                languageService.currentLanguageDisplayName,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
           
              ),
            ),
            SizedBox(width: 2.w),
            Icon(
              Icons.arrow_drop_down,
              size: 14.w,
              color: AppTheme.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建完整选择器（用于设置页面等）
  Widget _buildFullSelector(BuildContext context, LanguageService languageService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2), width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: LanguagePickerDropdown(
        initialValue: Translate.nowlanguage!,
        languages: Translate.gettranslatesupport(),
        onValuePicked: (Language language) {
          Translate.language = language.isoCode;
          onLanguageChanged?.call(language.isoCode);
        },
      ),
    );
  }

  /// 显示语言选择对话框
  void _showLanguageDialog(BuildContext context, LanguageService languageService) {
    showDialog(
      context: context,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 半透明背景
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.black54),
              ),
            ),
            // 弹窗内容 - 使用 Positioned 精确控制位置
            Positioned(
              left: 60.w,    // 距离左边的距离
             // top: 100.h,    // 距离顶部的距离
              child: SizedBox(
                width: 300.w,  // 设置弹窗宽度
                child: AlertDialog(
        title: Text(
          'Select Language',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: SizedBox(
          width: 200.w,
          height: 350.h,  // 设置固定高度
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: Translate.gettranslatesupport().map((language) {
                final isSelected = language.isoCode == languageService.currentLanguage;
                
                return _buildLanguageOption(
                  context,
                  language,
                  isSelected,
                  () {
                    Translate.language = language.isoCode;
                    onLanguageChanged?.call(language.isoCode);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建语言选项
  Widget _buildLanguageOption(
    BuildContext context,
    Language language,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 2.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? AppTheme.primaryGradient
              : LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.05),
                    AppTheme.primaryLightBlue.withValues(alpha: 0.05),
                  ],
                ),
          borderRadius: AppRadius.md,
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : AppTheme.primaryBlue.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 16.w,
                color: Colors.white,
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                size: 16.w,
                color: AppTheme.textSecondary,
              ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                language.name,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              language.nativeName,
              style: TextStyle(
                fontSize: 12.sp,
                color: isSelected 
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
