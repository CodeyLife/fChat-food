import '../../widgets/luckin_components.dart';
import 'package:flutter/material.dart';
import '../../services/user_management_service.dart';
import '../../services/user_service.dart';
import '../../services/config_service.dart';
import '../../models/user_info.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../utils/debug.dart';
import '../../utils/location.dart';
import '../../utils/app_theme.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/translate_text_widget.dart';

/// 用户管理页面
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final UserManagementService _userManagementService;
  String _searchQuery = '';
  String _sortBy = 'updatedAt'; // updatedAt, createdAt, username, level, permissionLevel
  bool _sortAscending = false;

  /// 检查当前用户是否为预设用户（只有预设用户才能设置超级管理员）
   bool get isPresetUser => Get.find<UserService>().currentUser?.userId == ConfigService.presetUserId;

  @override
  void initState() {
    super.initState();
    _userManagementService = UserManagementService();
    _userManagementService.addListener(_onUserDataChanged);
    _userManagementService.loadUsers();
  }

  @override
  void dispose() {
    _userManagementService.removeListener(_onUserDataChanged);
    _userManagementService.dispose();
    super.dispose();
  }

  void _onUserDataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 刷新数据
  Future<void> _refreshData() async {
    await _userManagementService.refresh();
  }

  /// 获取过滤和排序后的用户列表
  List<UserManagementItem> get _displayUsers {
    List<UserManagementItem> users = _userManagementService.users;
    
    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      users = _userManagementService.searchUsers(_searchQuery);
    }
    
    // 排序
    users = _userManagementService.sortUsers(_sortBy, _sortAscending);
    
    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonWidget.appBar(
        title: LocationUtils.translate('User Management'),
        context: context,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            tooltip: LocationUtils.translate('Permission Info'),
            onPressed: _showPermissionInfoDialog,
          ),
          IconButton(
            iconSize: 20.r,
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索和排序栏
          _buildSearchAndSortBar(),
          
          // 用户列表
          Expanded(
            child: _userManagementService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildUserList(),
          ),
        ],
      ),
    );
  }

  /// 构建搜索和排序栏
  Widget _buildSearchAndSortBar() {
    return Container(
      padding: EdgeInsets.all(8.w),
      child: Row(
        children: [
          // 搜索框
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: LocationUtils.translate('Search user name or ID'),
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          SizedBox(width: 12.w),
          
          // 排序选项
          TranslateText('Sort:'),
          SizedBox(width: 8.w),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.textPrimary,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'updatedAt', 
                    child: TranslateText('Updated Time', style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary))
                  ),
                  DropdownMenuItem(
                    value: 'createdAt', 
                    child: TranslateText('Created Time', style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary))
                  ),
                  DropdownMenuItem(
                    value: 'username', 
                    child: TranslateText('Username', style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary)),
                  ),
                  DropdownMenuItem(
                    value: 'level', 
                    child: TranslateText('Member Level', style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary)),
                  ),
                  DropdownMenuItem(
                    value: 'permissionLevel', 
                    child: TranslateText('Permission Level', style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimary)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                },
              ),
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
            },
          ),
        ],
      ),
    );
  }

  /// 显示权限说明弹窗
  void _showPermissionInfoDialog() {
    final userService = Get.find<UserService>();
    final currentUser = userService.currentUser;
    final currentUserPermission = currentUser?.permissionLevel ?? PermissionLevel.user;
    final isSuperAdmin = userService.isSuperAdmin;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuperAdmin ? Icons.star : Icons.info_outline,
              color: isSuperAdmin ? Colors.red[600] : Colors.blue[600],
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(LocationUtils.translate('Permission Info')),
            ),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 当前用户权限信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSuperAdmin ? Colors.red.withValues(alpha:0.05) : Colors.blue.withValues(alpha:0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSuperAdmin ? Colors.red.withValues(alpha:0.2) : Colors.blue.withValues(alpha:0.2)
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocationUtils.translate('Current User Permission'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSuperAdmin ? Colors.red[700] : Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPresetUser 
                        ? LocationUtils.translate('You are a preset user, have all permissions, and can manage all users.')
                        : '${LocationUtils.translate('You are currently')} ${currentUserPermission.name}, ${LocationUtils.translate('can only modify users with a permission level lower than yours. Users that can be modified are displayed in a dropdown, users that cannot be modified are displayed with a lock icon.')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSuperAdmin ? Colors.red[700] : Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 权限等级说明
              Text(
                LocationUtils.translate('Permission Levels'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // 预设用户
              _buildPermissionLevelItem(
                icon: Icons.admin_panel_settings,
                color: Colors.purple,
                title: 'Preset User',
                description: LocationUtils.translate('Highest authority, can manage all users and system settings'),
              ),
              
              // 超级管理员
              _buildPermissionLevelItem(
                icon: Icons.star,
                color: Colors.red,
                title: 'Super Admin',
                description: LocationUtils.translate('Have all system permissions, can manage all users'),
              ),
              
              // 管理员
              _buildPermissionLevelItem(
                icon: Icons.admin_panel_settings,
                color: Colors.orange,
                title: 'Admin',
                description: LocationUtils.translate('Can manage products, orders, and users with lower permissions'),
              ),
              
              // VIP用户
              _buildPermissionLevelItem(
                icon: Icons.star_border,
                color: Colors.purple,
                title: 'VIP',
                description: LocationUtils.translate('Premium member with special privileges'),
              ),
              
              // 普通用户
              _buildPermissionLevelItem(
                icon: Icons.person,
                color: Colors.blue,
                title: 'User',
                description: LocationUtils.translate('Regular user with basic permissions'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建权限等级说明项
  Widget _buildPermissionLevelItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建用户列表
  Widget _buildUserList() {
    final users = _displayUsers;
    
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64.r, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              _searchQuery.isEmpty ? 'No user data' : 'No matching user found',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey),
            ),
            if (_searchQuery.isNotEmpty) ...[
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child:  Text(LocationUtils.translate('Clear search')),
              ),
            ],
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Align(
          alignment: Alignment.centerLeft,
          child: _buildUserCard(user),
        );
      },
    );
  }

  /// 构建用户卡片
  Widget _buildUserCard(UserManagementItem user) {
    // 获取当前用户的权限等级
    final userService = Get.find<UserService>();
    final currentUser = userService.currentUser;
    final currentUserPermission = currentUser?.permissionLevel ?? PermissionLevel.user;
    final canModify = _canModifyUser(currentUserPermission, user.userInfo.permissionLevel);
    final isUserSuperAdmin = _isUserSuperAdmin(user);
    final isUserAdmin = user.userInfo.permissionLevel == PermissionLevel.admin;
    final isUserPresetUser = user.userId == ConfigService.presetUserId;
    
    return Card(
     
      margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 16.w),
      elevation: 4.r,
      shadowColor: Colors.black.withValues(alpha:0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: EdgeInsets.only(left: 2.w, right: 16.w, top: 4.h, bottom: 4.h), child: Column(
          children: [
            // 主要用户信息行
            Row(
              children: [
                // 左侧：头像和基本信息
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getPermissionColor(user.userInfo.permissionLevel),
                      child: Text(
                        user.userInfo.username.isNotEmpty 
                            ? user.userInfo.username[0].toUpperCase() 
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isUserSuperAdmin)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                
                // 中间：用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.userInfo.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                      
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${user.userId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 右侧：权限等级显示/编辑和操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 权限等级显示或编辑
                    if (isUserPresetUser)
                      // 预设用户：显示特殊标识，不可修改
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.purple.withValues(alpha:0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.admin_panel_settings,
                              size: 12,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Preset User',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if(canModify)
                      _buildPermissionDropdown(user, currentUserPermission)
                    else if (isUserSuperAdmin)
                      // 超级管理员：非预设用户查看时显示特殊标识（只读）
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha:0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                             Text(
                              LocationUtils.translate('Super Admin'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (canModify) 
                      // 可修改：显示下拉框或只读标签（包括预设用户修改超级管理员）
                      _buildPermissionDropdown(user, currentUserPermission)
                    else
                      // 不可修改：只显示权限等级标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha:0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.userInfo.permissionLevel.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(width: 8),
                    
                    // 操作按钮
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        _handleUserAction(value, user);
                      },
                      itemBuilder: (context) => [
                        if (isUserPresetUser)
                          // 预设用户：只显示信息
                          PopupMenuItem(
                            value: 'preset_user_info',
                            child: Text(LocationUtils.translate('Preset User Info')),
                          )
                        else if (isUserSuperAdmin)
                          // 超级管理员：显示信息
                          PopupMenuItem(
                            value: 'super_admin_info',
                            child: Text(LocationUtils.translate('Super Admin Info')),
                          )
                        else ...[
                          // 普通用户：显示删除和查看详情
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(LocationUtils.translate('Delete User')),
                          ),
                          PopupMenuItem(
                            value: 'view',
                            child: Text(LocationUtils.translate('View Details')),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            
            // Admin权限管理区域（仅对admin用户显示）
            if (isUserAdmin) ...[
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),
              _buildAdminPermissionSection(user),
            ],
          ],
        ),),

      
    );
  }

  /// 获取权限等级对应的颜色
  Color _getPermissionColor(PermissionLevel permissionLevel) {
    switch (permissionLevel) {
      case PermissionLevel.user:
        return Colors.blue;
      case PermissionLevel.vip:
        return Colors.purple;
      case PermissionLevel.admin:
        return Colors.orange;
      case PermissionLevel.superAdmin:
        return Colors.red;
    }
  }


  /// 检查用户是否为超级管理员
  bool _isUserSuperAdmin(UserManagementItem user) {
    return user.userInfo.permissionLevel == PermissionLevel.superAdmin;
  }

  /// 构建权限等级下拉框或只读标签
  Widget _buildPermissionDropdown(UserManagementItem user, PermissionLevel currentUserPermission) {
    final availableLevels = _getAvailablePermissionLevels(currentUserPermission);
    
    // 如果没有可用的权限等级，显示只读标签
    if (availableLevels.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha:0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 12,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              user.userInfo.permissionLevel.name,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    // 如果有可用的权限等级，显示下拉框
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPermissionColor(user.userInfo.permissionLevel).withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getPermissionColor(user.userInfo.permissionLevel).withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: DropdownButton<PermissionLevel>(
        value: user.userInfo.permissionLevel,
        isDense: true,
        underline: const SizedBox(),
        style: TextStyle(
          fontSize: 12,
          color: _getPermissionColor(user.userInfo.permissionLevel),
          fontWeight: FontWeight.w500,
        ),
        items: availableLevels
            .map((level) => DropdownMenuItem<PermissionLevel>(
                  value: level,
                  child: Text(level.name),
                ))
            .toList(),
        onChanged: (PermissionLevel? newLevel) {
          if (newLevel != null && newLevel != user.userInfo.permissionLevel) {
            _updateUserPermission(user, newLevel);
          }
        },
      ),
    );
  }

  /// 检查是否可以修改用户权限
  bool _canModifyUser(PermissionLevel currentUserLevel, PermissionLevel targetUserLevel) {
    // 预设用户可以管理所有用户（除了其他预设用户）
    if (isPresetUser) {
      return true;
    }
    // 只有权限等级高于目标用户才能修改
    return currentUserLevel.level > targetUserLevel.level;
  }

  /// 获取当前用户可以设置的目标用户权限等级列表
  List<PermissionLevel> _getAvailablePermissionLevels(PermissionLevel currentUserLevel) {
    // 只有预设用户才能设置超级管理员权限
    if (isPresetUser) {
      return PermissionLevel.values.toList();
    }
    // 其他用户（包括普通超级管理员）只能设置比当前用户权限等级低的权限
    return PermissionLevel.values
        .where((level) => level.level < currentUserLevel.level)
        .toList();
  }

  /// 更新用户权限等级
  Future<void> _updateUserPermission(UserManagementItem user, PermissionLevel newLevel) async {
    try {
      // 显示确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(LocationUtils.translate('Confirm Permission Change')),
          content: Text(
            'Are you sure you want to change the permission level of user "${user.userInfo.username}" from "${user.userInfo.permissionLevel.name}" to "${newLevel.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(LocationUtils.translate('Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(LocationUtils.translate('Confirm')),
            ),
          ],
        ),
      );
      if(mounted) {
             if (confirmed == true) {
        // 显示加载状态
        Debug.showLoadingDialog(context, message: LocationUtils.translate('Updating permission...'));

        // 更新用户权限等级
        final updatedUser = user.userInfo.copyWith(
          permissionLevel: newLevel,
          updatedAt: DateTime.now(),
        );

        // 保存到文件
        final success = await _userManagementService.updateUserPermission(user, updatedUser);

        if(mounted) {
           Navigator.pop(context);

        if (success) {

          // 更新订单管理员的ID列表
          await _updateOrderAdminUserIds();
        }
      
        } else {
          if(mounted) {
                Debug.showUserFriendlyError('Failed to update user permission');
          }
        
        }
      }
      }
 
    } catch (e) {
      if(mounted) {
        Navigator.pop(context);
      Debug.showUserFriendlyError('Failed to update user permission: $e');
      }
     
    }
  }

  /// 处理用户操作
  void _handleUserAction(String action, UserManagementItem user) {
    switch (action) {
      case 'view':
        _showUserDetails(user);
        break;
      case 'delete':
        _deleteUser(user);
        break;
      case 'super_admin_info':
        _showSuperAdminInfo(user);
        break;
      case 'preset_user_info':
        _showPresetUserInfo(user);
        break;
    }
  }

  /// 显示用户详情
  void _showUserDetails(UserManagementItem user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.userInfo.username,
        textAlign: TextAlign.center,),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('user ID', user.userId),
              _buildDetailRow('username', user.userInfo.username),
              _buildDetailRow('permission level', user.userInfo.permissionLevel.name),
              _buildDetailRow('member level', '${user.userInfo.level.name} (${user.userInfo.level.level}级)'),
              _buildDetailRow('experience', user.userInfo.experience.toString()),
              _buildDetailRow('address count', user.userInfo.addresses.length.toString()),
              _buildDetailRow('created time', _formatDateTime(user.userInfo.createdAt)),
              _buildDetailRow('updated time', _formatDateTime(user.userInfo.updatedAt)),
              _buildDetailRow('last login time', _formatDateTime(user.userInfo.lastLoginTime)),
 
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocationUtils.translate('Close')),
          ),
        ],
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }


  /// 删除用户
  void _deleteUser(UserManagementItem user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Confirm Delete')),
        content: Text(LocationUtils.translate('Are you sure you want to delete user "${user.userInfo.username}"? This action cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocationUtils.translate('Cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDeleteUser(user);
            },
            child: Text(LocationUtils.translate('Delete')),
          ),
        ],
      ),
    );
  }

  /// 执行删除用户
  Future<void> _performDeleteUser(UserManagementItem user) async {
    try {
      Debug.showLoadingDialog(context, message: LocationUtils.translate('Deleting user...'));
      
      final success = await _userManagementService.deleteUser(user);
      
      if(mounted) {
         Navigator.pop(context);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocationUtils.translate('User deleted successfully'))),
        );
      } else {
        Debug.showUserFriendlyError('Failed to delete user');
      }
      }
    
    } catch (e) {
      if(mounted) {
       Navigator.pop(context);
      Debug.showUserFriendlyError('Failed to delete user: $e');
      }
      
    }
  }

  /// 显示超级管理员信息
  void _showSuperAdminInfo(UserManagementItem user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.star, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(LocationUtils.translate('Super Admin Info')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('username', user.userInfo.username),
            _buildInfoRow('user ID', user.userId),
            _buildInfoRow('permission level', 'Super Admin'),
            _buildInfoRow('created time', _formatDateTime(user.userInfo.createdAt)),
            _buildInfoRow('updated time', _formatDateTime(user.userInfo.updatedAt)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha:0.3)),
              ),
              child:  Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Super Admin Privileges:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(LocationUtils.translate('• Have all system permissions')),
                  Text(LocationUtils.translate('• Can manage all users')),
                  Text(LocationUtils.translate('• Cannot be modified by other users')),
                  Text(LocationUtils.translate('• Cannot be deleted')),
                  Text(LocationUtils.translate('• Automatically recognized based on permission level')),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocationUtils.translate('Close')),
          ),
        ],
      ),
    );
  }

  /// 显示预设用户信息
  void _showPresetUserInfo(UserManagementItem user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.purple, size: 24),
            const SizedBox(width: 8),
            Text(LocationUtils.translate('Preset User Info')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('username', user.userInfo.username),
            _buildInfoRow('user ID', user.userId),
            _buildInfoRow('preset user ID', ConfigService.presetUserId),
            _buildInfoRow('permission level', 'Preset User (Highest)'),
            _buildInfoRow('created time', _formatDateTime(user.userInfo.createdAt)),
            _buildInfoRow('updated time', _formatDateTime(user.userInfo.updatedAt)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha:0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${LocationUtils.translate('Preset User Privileges')}:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(LocationUtils.translate('• Have all system permissions')),
                  Text(LocationUtils.translate('• Can manage all users')),
                  Text(LocationUtils.translate('• Cannot be modified by other users')),
                  Text(LocationUtils.translate('• Cannot be deleted')),
                  Text(LocationUtils.translate('• Automatically recognized based on preset ID')),
                  Text(LocationUtils.translate('• Highest authority in the system')),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocationUtils.translate('Close')),
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 构建Admin权限管理区域
  Widget _buildAdminPermissionSection(UserManagementItem user) {
    final adminPermissions = user.userInfo.adminPermissions;
    final userService = Get.find<UserService>();
    final isSuperAdmin = userService.isSuperAdmin;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuperAdmin ? Colors.blue.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuperAdmin ? Colors.blue.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                isSuperAdmin ? Icons.admin_panel_settings : Icons.visibility,
                size: 16,
                color: isSuperAdmin ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                isSuperAdmin 
                  ? LocationUtils.translate('Admin Permission Management')
                  : LocationUtils.translate('Admin Permission View'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSuperAdmin ? Colors.blue[700] : Colors.grey[700],
                ),
              ),
              if (!isSuperAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    LocationUtils.translate('Read Only'),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // 权限列表
          if (adminPermissions != null) ...[
            ...AdminPermission.values.map((permission) {
              final hasPermission = adminPermissions.hasPermission(permission);
              return _buildPermissionItem(permission, hasPermission, user, isSuperAdmin);
            }),
            
            const SizedBox(height: 12),
            
            // 更新时间信息
            Text(
              '${LocationUtils.translate('Last Updated')}: ${_formatDateTime(adminPermissions.updatedAt)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ] else ...[
            // 如果没有权限配置，显示默认配置
            Text(
              LocationUtils.translate('This admin user has no permission configuration, will use default permissions'),
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            if (isSuperAdmin)
              ElevatedButton.icon(
                onPressed: () => _initializeAdminPermissions(user),
                icon: const Icon(Icons.add, size: 14),
                label: Text(
                  LocationUtils.translate('Initialize Permissions'),
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Text(
                  LocationUtils.translate('Only super admin can initialize permissions'),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 构建权限项
  Widget _buildPermissionItem(AdminPermission permission, bool hasPermission, UserManagementItem user, bool isSuperAdmin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // 权限图标
          Icon(
            _getPermissionIcon(permission),
            size: 20,
            color: hasPermission ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          
          // 权限信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: hasPermission ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
                Text(
                  permission.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          
          // 权限开关或只读状态
          if (isSuperAdmin)
            Switch(
              value: hasPermission,
              onChanged: (value) => _updateAdminPermission(user, permission, value),
              activeThumbColor: Colors.green,
              inactiveThumbColor: Colors.grey,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasPermission 
                  ? Colors.green.withValues(alpha: 0.1) 
                  : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasPermission 
                    ? Colors.green.withValues(alpha: 0.3) 
                    : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasPermission ? Icons.check_circle : Icons.cancel,
                    size: 14,
                    color: hasPermission ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasPermission ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 10,
                      color: hasPermission ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 获取权限图标
  IconData _getPermissionIcon(AdminPermission permission) {
    switch (permission) {
      case AdminPermission.orderManagement:
        return Icons.receipt_long;
      case AdminPermission.productManagement:
        return Icons.inventory;
      case AdminPermission.dataAnalytics:
        return Icons.analytics;
    }
  }

  /// 更新Admin权限
  Future<void> _updateAdminPermission(UserManagementItem user, AdminPermission permission, bool enabled) async {
    try {
      final userService = Get.find<UserService>();
      
      // 显示确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(LocationUtils.translate('Confirm Permission Change')),
          content: Text(
            LocationUtils.translate('Are you sure you want to ${enabled ? 'grant' : 'revoke'} ${permission.name} permission for user "${user.userInfo.username}"?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(LocationUtils.translate('Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(LocationUtils.translate('Confirm')),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        // 显示加载状态
        Debug.showLoadingDialog(context, message: LocationUtils.translate('Updating permissions...'));

        // 获取当前权限配置
        final currentPermissions = user.userInfo.adminPermissions;
        Map<String, bool> newPermissions;
        
        if (currentPermissions != null) {
          newPermissions = Map<String, bool>.from(currentPermissions.permissions);
        } else {
          // 如果没有权限配置，创建默认配置
          newPermissions = {
            AdminPermission.orderManagement.key: true,
            AdminPermission.productManagement.key: false,
            AdminPermission.dataAnalytics.key: false,
          };
        }
        
        // 更新指定权限
        newPermissions[permission.key] = enabled;
        
        // 创建新的权限配置
        final updatedPermissions = AdminPermissionConfig(
          permissions: newPermissions,
          updatedAt: DateTime.now(),
          updatedBy: userService.currentUser?.userId ?? '',
        );
        
        // 更新用户信息
        final updatedUser = user.userInfo.copyWith(
          adminPermissions: updatedPermissions,
          updatedAt: DateTime.now(),
        );
        
        // 保存到文件
        final success = await _userManagementService.updateUserPermission(user, updatedUser);
        
        if (mounted) {
          Navigator.pop(context);
          
          if (success) {
            // 刷新用户列表以获取最新数据
            await _userManagementService.refresh();
            
            // 如果是订单管理权限，更新订单管理员的ID列表
            if (permission == AdminPermission.orderManagement) {
              await _updateOrderAdminUserIds();
            }
              
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        Debug.showUserFriendlyError('${LocationUtils.translate('Failed to update permission')}: $e');
      }
    }
  }

  /// 初始化Admin权限配置
  Future<void> _initializeAdminPermissions(UserManagementItem user) async {
    try {
      final userService = Get.find<UserService>();
      
      // 显示确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(LocationUtils.translate('Initialize Permission Configuration')),
          content: Text(
            LocationUtils.translate('Are you sure you want to initialize Admin permission configuration for user "${user.userInfo.username}"?\n\nWill grant all default permissions.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(LocationUtils.translate('Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(LocationUtils.translate('Confirm')),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        // 显示加载状态
        Debug.showLoadingDialog(context, message: LocationUtils.translate('Initializing permission configuration...'));

        // 创建默认权限配置
        final defaultPermissions = AdminPermissionConfig.createDefault(userService.currentUser?.userId ?? '');
        
        // 更新用户信息
        final updatedUser = user.userInfo.copyWith(
          adminPermissions: defaultPermissions,
          updatedAt: DateTime.now(),
        );
        
        // 保存到文件
        final success = await _userManagementService.updateUserPermission(user, updatedUser);
        
        if (mounted) {
          Navigator.pop(context);
          
          if (success) {
            // 刷新用户列表以获取最新数据
            await _userManagementService.refresh();
            
            // 更新订单管理员的ID列表
            await _updateOrderAdminUserIds();
            SnackBarUtils.getSnackbar( 'Success', 'Permission configuration initialized successfully');
            
          } else {
            Debug.showUserFriendlyError(LocationUtils.translate('Failed to initialize permission configuration'));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
          Debug.showUserFriendlyError('${LocationUtils.translate('Failed to initialize permission configuration')}: $e');
      }
    }
  }

  /// 更新所有拥有订单管理权限的用户ID列表
  Future<void> _updateOrderAdminUserIds() async {
    try {
      final userService = Get.find<UserService>();
      
      // 获取所有用户
      final allUsers = _userManagementService.users;
      
      // 过滤出拥有订单管理权限的用户ID
      final orderAdminUserIds = allUsers
          .where((user) => user.userInfo.isAdmin())
          .where((user) {
            // 检查用户是否有订单管理权限
            return user.userInfo.canManageOrders;
          })
          .map((user) => user.userId)
          .toList();
      
      // 保存到UserService
      await userService.saveAllAdminUserIds(orderAdminUserIds);
      
      Debug.log('已更新订单管理员ID列表，共 ${orderAdminUserIds.length} 个用户');
    } catch (e) {
      Debug.log('更新订单管理员ID列表失败: $e');
    }
  }
}
