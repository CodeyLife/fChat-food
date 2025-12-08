import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quickalert/quickalert.dart';
import '../models/user_info.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../widgets/luckin_components.dart';

class EditProfileScreen extends StatefulWidget {
  final UserInfo userInfo;

  const EditProfileScreen({
    super.key,
    required this.userInfo,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
  }

  void _initializeControllers() {
    _usernameController.text = widget.userInfo.username;
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      // 让系统自动处理键盘弹出时的布局调整
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            // 添加键盘滚动行为，确保输入时不会出现布局问题
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            // 防止过度滚动，提供更好的用户体验
            physics: const ClampingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 基本信息编辑
                  _buildBasicInfoSection(),
                  SizedBox(height: 24.h),
                  
                  // 保存按钮
                  _buildSaveButton(),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建应用栏
  PreferredSizeWidget _buildAppBar() {
    return CommonWidget.appBar(title: LocationUtils.translate('Edit Profile'), context: context,
       actions: [
        TextButton(
          onPressed: _resetForm,
          child: Text(
            'Reset',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],);
  }


  /// 构建基本信息编辑区域
  Widget _buildBasicInfoSection() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Information',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
          SizedBox(height: 20.h),
          
          // 用户名输入框
          _buildInputField(
            controller: _usernameController,
            label: LocationUtils.translate('Username'),
            hint: LocationUtils.translate('Please enter username'),
            icon: Icons.person_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username cannot be empty';
              }
              if (value.trim().length < 2) {
                return 'Username must be at least 2 characters';
              }
              if (value.trim().length > 20) {
                return 'Username cannot be more than 20 characters';
              }
              return null;
            },
          ),
          
          SizedBox(height: 20.h),
          
          // 用户ID（只读）
          _buildReadOnlyField(
            label: LocationUtils.translate('User ID'),
            value: widget.userInfo.userId,
            icon: Icons.fingerprint_rounded,
          ),
          
          SizedBox(height: 20.h),
          
          // 注册时间（只读）
          _buildReadOnlyField(
            label: LocationUtils.translate('Registration Time'),
            value: _formatDateTime(widget.userInfo.createdAt),
            icon: Icons.calendar_today_rounded,
          ),
        ],
      ),
    );
  }

  /// 构建输入框
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          key: const ValueKey('username_field'),
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
            prefixIcon: Icon(
              icon,
              color: AppTheme.primaryBlue,
              size: 20.w,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: BorderSide(
                color: AppTheme.primaryBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: BorderSide(
                color: Colors.red[400]!,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: BorderSide(
                color: Colors.red[400]!,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建只读字段
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12.w),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.grey[600],
                size: 20.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建保存按钮
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.w),
          ),
          shadowColor: AppTheme.primaryBlue.withValues(alpha:0.3),
        ),
        child: _isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }


  /// 重置表单
  void _resetForm() {
    setState(() {
      _usernameController.text = widget.userInfo.username;
    });
  }

  /// 保存个人资料
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
    
      // 检查是否有更改
      final hasChanges = _usernameController.text.trim() != widget.userInfo.username;

      if (!hasChanges) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.info,
          title: LocationUtils.translate('No Changes'),
          text: LocationUtils.translate('You have not made any changes'),
          confirmBtnText: LocationUtils.translate('OK'),
        );
        return;
      }

      // 创建更新后的用户信息
      final updatedUserInfo = widget.userInfo.copyWith(
        username: _usernameController.text.trim(),
        updatedAt: DateTime.now(),
      );

      // 更新用户信息
      final success = await UserService.instance.saveUserInfo(updatedUserInfo);
      if(mounted) {
           if (success) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: LocationUtils.translate('Save Success'),
          text: LocationUtils.translate('Personal information has been updated'),
          confirmBtnText: LocationUtils.translate('OK'),
          onConfirmBtnTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop(true); // 返回更新成功标识
          },
        );
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: LocationUtils.translate('Save Failed'),
          text: LocationUtils.translate('Error updating personal information'),
          confirmBtnText: LocationUtils.translate('OK'),
        );
      }
      }

   
    } catch (e) {
      if(mounted) {
         QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
          title: LocationUtils.translate('Save Failed'),
        text: LocationUtils.translate('Error updating personal information: \$e'),
        confirmBtnText: LocationUtils.translate('OK'),
      );
      }
     
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
