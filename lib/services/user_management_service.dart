import 'dart:async';
import 'package:fchat_food/utils/constants.dart';
import '../utils/debug.dart';
import 'package:flutter/foundation.dart';
import '../models/user_info.dart';
import '../utils/file_utils.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import 'package:fchatapi/util/JsonUtil.dart';

/// 用户管理项
class UserManagementItem {
  final String userId;
  final UserInfo userInfo;
  final DateTime fileCreatedAt;

  UserManagementItem({
    required this.userId,
    required this.userInfo,
    required this.fileCreatedAt,
  });
}

/// 用户管理服务
class UserManagementService extends ChangeNotifier {
  List<UserManagementItem> _users = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  List<UserManagementItem> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 加载所有用户数据
  Future<void> loadUsers() async {
    _setLoading(true);
    _clearError();

    try {
      Debug.log('开始加载用户管理数据');
      
      // 获取user目录下的所有文件
      final userFiles = await _getAllUserFiles();
      // 解析用户数据
      final userItems = await _parseUserFiles(userFiles);
      PhoneUtil.applog('解析出 ${userItems.length} 个用户');

      _users = userItems;
      PhoneUtil.applog('用户管理数据加载完成');
    } catch (e) {
      _setError('加载用户数据失败: $e');
      PhoneUtil.applog('加载用户管理数据失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 获取user目录下的所有文件
  Future<List<Map<String, dynamic>>> _getAllUserFiles() async {
    try {
      // 使用CustomFChatFileMD获取user目录下的所有文件
      final userFileMD =AppConstants.usermd;
      final files = await FileUtils.readDirectory(userFileMD);
      return files;
    } catch (e) {
      PhoneUtil.applog('获取用户文件失败: $e');
      return [];
    }
  }

  /// 解析用户文件
  Future<List<UserManagementItem>> _parseUserFiles(List<Map<String, dynamic>> files) async {
    List<UserManagementItem> userItems = [];
    
    for (Map<String, dynamic> file in files) {
      try {
        // 解析文件内容
        Debug.log('解析用户文件: ${file['filename']}');

        // 参考项目的方式：先检查 filedata 是否存在
        final userData = UserInfo.fromJson(file);

        userItems.add(UserManagementItem(
          userId: userData.userId,
          userInfo: userData,
          fileCreatedAt: DateTime.now(), // 这里应该从文件属性获取，但FileObj可能不包含此信息
        ));
      } catch (e) {
        PhoneUtil.applog('解析用户文件失败 ${file['filename']}: $e');
      }
    }
    
    return userItems;
  }



  /// 更新用户权限等级
  Future<bool> updateUserPermission(UserManagementItem user, UserInfo updatedUserInfo) async {
    try {
      PhoneUtil.applog('开始更新用户权限: ${user.userId}');
      
      // 获取用户文件MD
      final fileMD = AppConstants.usermd;
      PhoneUtil.applog('用户文件MD: ${fileMD.name}');
      
      // 将更新后的用户信息转换为JSON
      final userJson = JsonUtil.maptostr(updatedUserInfo.toJson());

      final success = await FileUtils.updateFile(AppConstants.usermd, user.userId, userJson);
      
      // 如果更新成功，更新内部数据并通知监听者
      if (success) {
        // 找到对应的用户项并更新
        final index = _users.indexWhere((item) => item.userId == user.userId);
        if (index != -1) {
          _users[index] = UserManagementItem(
            userId: user.userId,
            userInfo: updatedUserInfo,
            fileCreatedAt: _users[index].fileCreatedAt,
          );
          // 通知监听者数据已更新
          _safeNotifyListeners();
          PhoneUtil.applog('用户权限更新成功，已通知UI: ${user.userId}');
        }
      }
      
      return success;
 
    } catch (e) {
      PhoneUtil.applog('更新用户权限失败: $e');
      return false;
    }
  }

  /// 删除用户
  Future<bool> deleteUser(UserManagementItem user) async {
    try {
      PhoneUtil.applog('开始删除用户: ${user.userId}');
   
      final success = await FileUtils.deleteFile(AppConstants.usermd, user.userId);
      
      // 如果删除成功，更新内部数据并通知监听者
      if (success) {
        _users.removeWhere((item) => item.userId == user.userId);
        // 通知监听者数据已更新
        _safeNotifyListeners();
        PhoneUtil.applog('用户删除成功，已通知UI: ${user.userId}');
      }
      
      return success;
      
    } catch (e) {
      PhoneUtil.applog('删除用户失败: $e');
      return false;
    }
  }


  /// 搜索用户
  List<UserManagementItem> searchUsers(String query) {
    if (query.isEmpty) {
      return _users;
    }
    
    return _users.where((user) {
      return user.userInfo.username.toLowerCase().contains(query.toLowerCase()) ||
             user.userId.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  /// 按字段排序用户
  List<UserManagementItem> sortUsers(String sortBy, bool ascending) {
    List<UserManagementItem> sortedUsers = List.from(_users);
    
    sortedUsers.sort((a, b) {
      int comparison = 0;
      
      switch (sortBy) {
        case 'username':
          comparison = a.userInfo.username.compareTo(b.userInfo.username);
          break;
        case 'level':
          comparison = a.userInfo.level.level.compareTo(b.userInfo.level.level);
          break;
        case 'permissionLevel':
          // 检查是否为超级管理员
          final aIsSuperAdmin = a.userInfo.permissionLevel == PermissionLevel.superAdmin;
          final bIsSuperAdmin = b.userInfo.permissionLevel == PermissionLevel.superAdmin;
          
          if (aIsSuperAdmin && !bIsSuperAdmin) {
            return -1; // a是超级管理员，排在前面
          } else if (!aIsSuperAdmin && bIsSuperAdmin) {
            return 1; // b是超级管理员，排在前面
          } else if (aIsSuperAdmin && bIsSuperAdmin) {
            return 0; // 两个都是超级管理员，保持原顺序
          } else {
            // 都不是超级管理员，按权限等级排序
            comparison = a.userInfo.permissionLevel.level.compareTo(b.userInfo.permissionLevel.level);
          }
          break;
        case 'createdAt':
          comparison = a.userInfo.createdAt.compareTo(b.userInfo.createdAt);
          break;
        case 'updatedAt':
        default:
          comparison = a.userInfo.updatedAt.compareTo(b.userInfo.updatedAt);
          break;
      }
      
      return ascending ? comparison : -comparison;
    });
    
    return sortedUsers;
  }

  /// 获取用户统计信息
  Map<String, dynamic> getUserStatistics() {
    if (_users.isEmpty) {
      return {
        'totalUsers': 0,
        'levelDistribution': {},
        'recentUsers': 0,
      };
    }
    
    Map<String, int> levelDistribution = {};
    int recentUsers = 0;
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    
    for (UserManagementItem user in _users) {
      // 统计等级分布
      String levelName = user.userInfo.level.name;
      levelDistribution[levelName] = (levelDistribution[levelName] ?? 0) + 1;
      
      // 统计最近一周注册的用户
      if (user.userInfo.createdAt.isAfter(oneWeekAgo)) {
        recentUsers++;
      }
    }
    
    return {
      'totalUsers': _users.length,
      'levelDistribution': levelDistribution,
      'recentUsers': recentUsers,
    };
  }

  /// 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    _safeNotifyListeners();
  }

  /// 设置错误信息
  void _setError(String error) {
    _errorMessage = error;
    _safeNotifyListeners();
  }

  /// 清除错误信息
  void _clearError() {
    _errorMessage = null;
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadUsers();
  }

  /// 安全的通知监听器方法
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
