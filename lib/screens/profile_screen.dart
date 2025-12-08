import '../services/shop_service.dart';
import '../services/config_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quickalert/quickalert.dart';
import 'package:get/get.dart';
import '../models/user_info.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../screens/delivery_address_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/download_app_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: GetX<UserService>(
        builder: (userService) {
          final userInfo = userService.currentUser;
          
          if (userInfo == null) {
            return const DownloadAppScreen();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                SizedBox(height: 8.h), // 顶部留白
                
                // 用户信息和会员等级卡片
                _buildUserProfileCard(userInfo, userService),
                SizedBox(height: 20.h),
            
            // 功能菜单
            _buildMenuSection(),
                SizedBox(height: 20.h),
            
            // 其他功能
            _buildOtherSection(),
                SizedBox(height: 32.h), // 底部留白
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建用户信息和会员等级合并卡片
  Widget _buildUserProfileCard(UserInfo userInfo, UserService userService) {
    final level = userInfo.level;
    final progress = userInfo.levelProgress;
    final expToNext = userInfo.expToNextLevel;
    final levelColor = Color(int.parse(userInfo.levelColor.replaceFirst('#', '0xFF')));
    
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(24.w),
        boxShadow: [
          BoxShadow(
            color: levelColor.withValues(alpha:0.15),
            blurRadius: 25,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 装饰性背景元素
          Positioned(
            top: -30.w,
            right: -30.w,
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    levelColor.withValues(alpha:0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40.w,
            left: -40.w,
            child: Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.orange.withValues(alpha:0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // 主要内容
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                // 用户信息头部
                Column(
                  children: [
                    // 头像和用户信息
                    Row(
                      children: [
                        // 头像容器 - 支持默认头像图片
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                levelColor,
                                levelColor.withValues(alpha:0.8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: levelColor.withValues(alpha:0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(4.w),
                          child: ClipOval(
                            child: SizedBox(
                              width: 70.w,
                              height: 70.w,
                              child: userService.getAvatarWidget(
                                width: 70.w,
                                height: 70.w,
                                radius: 35.w,
                                defaultIcon: Icons.person,
                                defaultIconColor: levelColor,
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: 16.w),
                        
                        // 用户信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      userInfo.username,
                                      style: TextStyle(
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  // 编辑按钮
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.w),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha:0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: () => _editProfile(userInfo),
                                      icon: Icon(
                                        Icons.edit_rounded,
                                        size: 20.w,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    size: 16.w,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'ID: ${userInfo.userId}',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                SizedBox(height: 20.h),
                
                // 登录时间
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16.w,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${LocationUtils.translate('Last Login')}: ${_formatDateTime(userInfo.lastLoginTime)}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 24.h),
                
                // 会员等级信息
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        levelColor.withValues(alpha:0.1),
                        levelColor.withValues(alpha:0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.w),
                    border: Border.all(
                      color: levelColor.withValues(alpha:0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 等级信息头部
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: levelColor.withValues(alpha:0.2),
                              borderRadius: BorderRadius.circular(12.w),
                            ),
                            child: Icon(
                              Icons.star_rounded,
                              color: levelColor,
                              size: 24.w,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  level.name,
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: levelColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                if (!userInfo.isMaxLevel)
                                  Text(
                                    '${LocationUtils.translate('Level')} ${level.level}',
                  style: TextStyle(
                    fontSize: 12.sp,
                                      color: levelColor.withValues(alpha:0.8),
                                      fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
                          ),
                          if (!userInfo.isMaxLevel)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha:0.2),
                                borderRadius: BorderRadius.circular(20.w),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: levelColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      // 经验值信息
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            color: levelColor,
                            size: 18.w,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '${LocationUtils.translate('Experience')}: ${userInfo.experience}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: levelColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      
                      // 升级进度
                      if (!userInfo.isMaxLevel) ...[
                        SizedBox(height: 12.h),
                        Text(
                          '${LocationUtils.translate('Next level')}: $expToNext ${LocationUtils.translate('experience')}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: levelColor.withValues(alpha:0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          height: 6.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3.w),
                            color: levelColor.withValues(alpha:0.2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3.w),
                                gradient: LinearGradient(
                                  colors: [
                                    levelColor,
                                    levelColor.withValues(alpha:0.8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha:0.2),
                            borderRadius: BorderRadius.circular(12.w),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '🎉',
                                style: TextStyle(fontSize: 16.sp),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  LocationUtils.translate('Congratulations! You have reached the highest level!'),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: levelColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // 统计信息
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.5),
                          borderRadius: BorderRadius.circular(12.w),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(LocationUtils.translate('Orders'), '${userInfo.statistics['totalOrders'] ?? 0}', Icons.shopping_bag_rounded, levelColor),
                            ),
                            Container(
                              width: 1.w,
                              height: 25.h,
                              color: levelColor.withValues(alpha:0.3),
                            ),
                            Expanded(
                              child: _buildStatItem(LocationUtils.translate('Consumption'), '${ShopService.symbol.value}${(userInfo.statistics['totalSpent'] ?? 0.0).toStringAsFixed(0)}', Icons.attach_money_rounded, levelColor),
                            ),
                            Container(
                              width: 1.w,
                              height: 25.h,
                              color: levelColor.withValues(alpha:0.3),
                            ),
                            Expanded(
                              child: _buildStatItem(LocationUtils.translate('Login Streak'), '${userInfo.statistics['loginStreak'] ?? 0} ${LocationUtils.translate('days')}', Icons.calendar_today_rounded, levelColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// 构建统计项
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 18.w,
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: color.withValues(alpha:0.7),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 构建功能菜单
  Widget _buildMenuSection() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.favorite_rounded,
            title: LocationUtils.translate('My Favorites'),
            subtitle: LocationUtils.translate('My Favorites'),
            onTap: _showFavorites,
            color: Colors.red[400]!,
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.location_on_rounded,
            title: LocationUtils.translate('Delivery Address'),
            subtitle: LocationUtils.translate('Delivery Address'),
            onTap: _showAddresses,
            color: Colors.green[500]!,
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  /// 构建其他功能
  Widget _buildOtherSection() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [

          _buildMenuItem(
            icon: Icons.info_rounded,
            title: LocationUtils.translate('About Us'),
            subtitle: LocationUtils.translate('Version Information'),
            onTap: _showAbout,
            color: Colors.purple[500]!,
          ),

          _buildDivider(),
        ],
      ),
    );
  }

  /// 构建菜单项
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
        borderRadius: BorderRadius.circular(16.w),
        splashColor: color.withValues(alpha:0.1),
        highlightColor: color.withValues(alpha:0.05),
        child: Container(
          padding: EdgeInsets.all(20.w),
        child: Row(
          children: [
              // 图标容器
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12.w),
                ),
                child: Icon(
              icon,
              size: 24.w,
                  color: color,
                ),
            ),
            SizedBox(width: 16.w),
              
              // 文本内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red[600] : Colors.grey[800],
                        letterSpacing: 0.2,
                    ),
                  ),
                    SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 13.sp,
                      color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
              
              // 箭头图标
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.w),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14.w,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建分割线
  Widget _buildDivider() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      height: 1.h,
      color: Colors.grey[100],
    );
  }

  /// 编辑个人资料
  void _editProfile(UserInfo userInfo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userInfo: userInfo),
      ),
    );
    
    // 如果编辑成功，刷新页面
    if (result == true) {
      setState(() {
        // 触发重新构建以显示更新后的信息
      });
    }
  }

  /// 显示收藏
  void _showFavorites() {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.info,
      title: LocationUtils.translate('Feature Under Development'),
      text: LocationUtils.translate('Favorites is under development...'),
      confirmBtnText: LocationUtils.translate('OK'),
    );
  }

  /// 显示外卖地址
  void _showAddresses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeliveryAddressScreen(),
      ),
    );
  }


  /// 显示关于我们
  void _showAbout() {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.info,
      title: LocationUtils.translate('About Us'),
      text: 'v${ConfigService.appVersion}\n\n${LocationUtils.translate('A platform focused on providing user services')}',
      confirmBtnText: LocationUtils.translate('OK'),
    );
  }


  /// 重置用户数据
  // ignore: unused_element
  void _resetUserData() {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: LocationUtils.translate('Clear User Data'),
      text: LocationUtils.translate('This operation will delete all files in the user folder, including delivery addresses, experience values, etc. Are you sure you want to continue?'),
      confirmBtnText: LocationUtils.translate('OK'),
      cancelBtnText: LocationUtils.translate('Cancel'),
      onConfirmBtnTap: () async {
        Navigator.of(context).pop();
        await _performResetUserData();
      },
    );
  }

  /// 执行清空用户数据
  Future<void> _performResetUserData() async {
    try {

      // 显示加载对话框
      QuickAlert.show(
        context: context,
        type: QuickAlertType.loading,
        title: LocationUtils.translate('Clearing...'),
        text: LocationUtils.translate('Deleting user files'),
      );
      
      // 执行清空
      final success = await UserService.instance.resetUserData();
      
      // 关闭加载对话框
      if(mounted) {
         Navigator.of(context).pop();
      }
     
      
      if (success) {
        if(mounted) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: LocationUtils.translate('Clear Successful'),
              text: LocationUtils.translate('User data has been cleared'),
              confirmBtnText: LocationUtils.translate('OK'),
            );
        }
      } else {

        if(mounted) {
            QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: LocationUtils.translate('Clear Failed'),
          text: LocationUtils.translate('Error clearing user data'),
          confirmBtnText: LocationUtils.translate('OK'),
        );
        }
      
      }
    } catch (e) {

      if(mounted) {
          // 关闭加载对话框
      Navigator.of(context).pop();
      
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: LocationUtils.translate('Clear Failed'),
        text: LocationUtils.translate('Error clearing user data: $e'),
        confirmBtnText: LocationUtils.translate('OK'),
      );
      }
    
    }
  }


  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}
