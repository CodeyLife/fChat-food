import 'dart:async';
import '../utils/file_utils.dart';
import '../utils/constants.dart';
import '../services/config_service.dart';
import 'package:fchatapi/Login/WebLogin.dart';
import 'package:fchatapi/appapi/FChatUserInfo.dart';
import 'package:fchatapi/webapi/ChatUserobj.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import 'package:fchatapi/util/UserObj.dart';
import 'package:fchatapi/webapi/FChatFileObj.dart';
import 'package:fchatapi/util/JsonUtil.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user_info.dart';
import '../utils/debug.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/permission_denied_screen.dart';


/// 用户服务类
class UserService extends GetxController {

  static UserService get instance => Get.find<UserService>();

  static final List<String> _adminUserIds = [];

  /// 获取所有拥有管理员权限的用户ID
  static Future<List<String>> get adminUserIds async {
    if (_adminUserIds.isEmpty) {
      await getAllAdminUserIds();
    }
    return _adminUserIds;
  }



  // 当前用户信息
  final Rx<UserInfo?> _currentUser = Rx<UserInfo?>(null);
  
  /// 获取当前用户
  UserInfo? get currentUser => _currentUser.value;
  ChatUserobj? chatUserobj;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }  

  /// 初始化用户服务
  Future<void> initialize() async {
    try {
      
      // 尝试加载用户信息
      final userInfo = await loadUserInfo();
       if(!UserService.instance.isAdmin){
            
       }
      // 更新用户数据并通知UI
      _updateUser(userInfo);
    } catch (e) {
      Debug.logError('用户服务初始化失败: $e');
      // 即使初始化失败，也要更新为null，避免界面一直加载
      _updateUser(null);
    }
  }


  /// 更新用户数据并通知UI
  void _updateUser(UserInfo? user) {
    _currentUser.value = user;
 
    update();
  }

  /// 检查当前用户是否为超级管理员
  bool get isSuperAdmin {
    if (_currentUser.value == null) return false;
    return  _currentUser.value!.permissionLevel.level == PermissionLevel.superAdmin.level || _currentUser.value!.userId == ConfigService.presetUserId;
  }

  bool get isPresetUser => _currentUser.value?.userId == ConfigService.presetUserId;
  /// 检查当前用户是否为管理员
  bool get isAdmin => _currentUser.value?.isAdmin() ?? false;

  /// 检查当前用户是否有指定权限等级
  bool hasPermission(PermissionLevel requiredLevel) {
    if (_currentUser.value == null) return false;
    return _currentUser.value!.permissionLevel.level >= requiredLevel.level;
  }

  /// 检查当前用户是否有指定的admin权限
  bool hasAdminPermission(AdminPermission permission) {
    if (_currentUser.value == null) return false;
    return _currentUser.value!.hasAdminPermission(permission);
  }

  /// 检查当前用户是否有指定的admin权限（通过key）
  bool hasAdminPermissionByKey(String permissionKey) {
    if (_currentUser.value == null) return false;
    return _currentUser.value!.hasAdminPermissionByKey(permissionKey);
  }

  /// 检查当前用户是否有订单管理权限
  bool get canManageOrders => hasAdminPermission(AdminPermission.orderManagement);

  /// 检查当前用户是否有商品管理权限
  bool get canManageProducts => hasAdminPermission(AdminPermission.productManagement);

  /// 检查当前用户是否有数据分析权限
  bool get canViewAnalytics => hasAdminPermission(AdminPermission.dataAnalytics);

  /// 检查当前用户是否为指定用户ID
  bool isCurrentUser(String userId) {
    return _currentUser.value?.userId == userId;
  }


  /// 登录成功后加载用户信息
  Future<UserInfo?> loadUserInfo() async {
    try {

      String userId='';
     
      String username = '';
      String avatarURL = '';
      
      // 使用Completer来等待异步回调完成
      final completer = Completer<UserInfo?>();
      bool isCompleted = false;


      // 从app获取用户id
      try {
        FChatUserInfo().getUserInfo((user) {
        if (isCompleted) return; // 防止重复处理
        isCompleted = true;
        chatUserobj = user;
        Debug.log('拿到app用户数据: ${user.toString()}');
        try {
          // 解析JSON数据
          Map<String, dynamic> userData = user.getJson();
          // 如果需要进一步处理，可以访问具体字段
          if (userData.containsKey('id')) {
            // 处理id字段，可能是int或String类型
            dynamic idValue = userData['id'];
            String id = '';
            if (idValue is int) {
              id = idValue.toString();
            } else if (idValue is String) {
              id = idValue;
            }
            userId = id;
            username = id;
          }
          
          if (userData.containsKey('name')) {
            username = userData['name'] ?? '';
          }

          if (userData.containsKey('avatarURL')) {
            avatarURL = userData['avatarURL'] ?? '';
          }
          
          if(userId.isEmpty && ConfigService.isTest){
           // userId = ConfigService.presetUserId;
           userId =  ConfigService.presetUserId;
          }
          // 异步调用_readUserInfo并完成Completer
          if(userId.isNotEmpty) {
          _readUserInfoWithUserData(userId, username, avatarURL).then((result) {
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          }).catchError((error) {
            Debug.log('读取用户信息失败: $error');
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          });
          }else
          {
            completer.complete(null);
          }
        } catch (e) {
          Debug.log('解析app用户信息失败: $e');
          Debug.log('原始数据: ${user.toString()}');
          
        }
      });
      } catch (e) {
        // 捕获 getUserInfo 调用时可能出现的异常
        Debug.logError('调用 getUserInfo 失败: $e');
        if (!isCompleted) {
          isCompleted = true;
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      }
      
      // 设置超时处理
      Timer(const Duration(seconds: 10), () {
        if (!isCompleted) {
          PhoneUtil.applog("获取用户信息超时");
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      });
      
      return await completer.future;
    } catch (e) {
      Debug.logError('加载用户信息失败: $e');
      return null;
    }
  }
  
  /// 使用从API获取的用户数据读取用户信息
  Future<UserInfo?> _readUserInfoWithUserData(String userId, String username, String avatarURL) async {
    try {
      if (userId.isEmpty) {
        return null;
      }

      Debug.log('userId: $userId');  

      // 尝试读取用户文件
      final userData = await FileUtils.readFile(AppConstants.usermd, userId);
      
      // 打印读取到的userData
      Debug.log('读取到的userData: $userData');
      
      if (userData != null) {
        try {
          
          // 解析用户信息
          _currentUser.value = UserInfo.fromJson(userData);
          // 从API获取的头像URL直接赋值给用户信息
          _currentUser.value = _currentUser.value!.copyWith(avatar: avatarURL.isNotEmpty ? avatarURL : null);
          // Debug.log('成功加载用户信息: ${_currentUser.value!.username}');

     
        } catch (e) {
          Debug.log('解析用户信息失败: $e，将创建新用户');
          //删除原本的用户文件
          await FileUtils.clearDirectory(AppConstants.usermd);
          Debug.log('异常堆栈: ${e.toString()}');
          Debug.log('异常类型: ${e.runtimeType}');
          _currentUser.value = null;
        }
      } 
      
      // 如果读取失败或解析失败，创建新用户信息
      if (_currentUser.value == null) {
        Debug.log('创建新用户时使用的userId: "$userId"');
        // 检查是否为预设用户
        bool isPresetUser = userId == ConfigService.presetUserId;
        if (isPresetUser) {
          Debug.log('用户 $userId 被识别为预设用户（自动拥有最高权限）');
        }
        
        _currentUser.value = UserInfo.createNew(
          userId: userId,
          username: username.isNotEmpty ? username : '用户${userId.length > 4 ? userId.substring(0, 4) : userId}',
          avatar: avatarURL.isNotEmpty ? avatarURL : null, // 从API获取的头像URL
          permissionLevel: PermissionLevel.user, // 预设用户也使用普通权限等级，但通过ID判断获得最高权限
        );
        
        // 创建新用户信息
        final saveSuccess = await saveUserInfo(_currentUser.value!, isCreate: true);
        if (saveSuccess) {
          PhoneUtil.applog('创建新用户信息成功: ${_currentUser.value!.username}');
        } else {
          PhoneUtil.applog('创建新用户信息失败');
          return null;
        }
      }
      
      // 在更新登录时间之前给予每日登录奖励
      await giveDailyLoginReward();
      
      // 更新登录时间
      _currentUser.value = _currentUser.value!.updateLoginTime();
      await saveUserInfo(_currentUser.value!, isCreate: false);
      
      return _currentUser.value;
    } catch (e) {
      
      // 即使出现异常，也尝试创建新用户
      try {
        final userId = UserObj.userid;
        if (userId.isNotEmpty) {
          PhoneUtil.applog('尝试创建备用用户信息');
          // 检查是否为预设用户
          bool isPresetUser = userId == ConfigService.presetUserId;
          if (isPresetUser) {
            PhoneUtil.applog('用户 $userId 被识别为预设用户（自动拥有最高权限）');
          }
          
          _currentUser.value = UserInfo.createNew(
            userId: userId,
            username: username.isNotEmpty ? username : '用户${userId.length > 4 ? userId.substring(0, 4) : userId}',
            avatar: avatarURL.isNotEmpty ? avatarURL : null, // 从API获取的头像URL
            permissionLevel: PermissionLevel.user, // 预设用户也使用普通权限等级，但通过ID判断获得最高权限
          );
          
          await saveUserInfo(_currentUser.value!, isCreate: true);
          
          // 给予每日登录奖励
          await giveDailyLoginReward();
          
          return _currentUser.value;
        }
      } catch (e2) {
        PhoneUtil.applog('创建备用用户信息也失败: $e2');
      }
      
      return null;
    }
  }

  /// 保存用户信息
  /// [isCreate] true表示创建新用户文件，false表示更新现有用户文件
  Future<bool> saveUserInfo(UserInfo userInfo, {bool isCreate = false}) async {
    try {
      // PhoneUtil.applog('开始${isCreate ? "创建" : "保存"}用户信息 ${userInfo.userId}  ${userInfo.username}');
      
      final userId = userInfo.userId;
      if (userId.isEmpty) {
        PhoneUtil.applog('用户ID为空，无法${isCreate ? "创建" : "保存"}用户信息');
        return false;
      }
      

      // 转换为JSON
      final userJson = userInfo.toJson();
      final userData = JsonUtil.maptostr(userJson);
      
      // 根据操作类型调用相应的方法
      final success = isCreate 
        ? await _createUserFile(AppConstants.usermd, userData)
        : await _updateUserFile(AppConstants.usermd, userData);
      
      if (success) {
        _updateUser(userInfo);
        // PhoneUtil.applog('用户信息${isCreate ? "创建" : "保存"}成功');
        return true;
      } else {
        PhoneUtil.applog('用户信息${isCreate ? "创建" : "保存"}失败');
        return false;
      }
    } catch (e) {
      PhoneUtil.applog('${isCreate ? "创建" : "保存"}用户信息失败: $e');
      return false;
    }
  }

  Widget scanlogin(BuildContext context) {
    return Weblogin(
         onloginstate: (Map state) {
          final userid = state['userid']??'';
          Debug.log(state.toString());
          if(userid != null && userid.isNotEmpty)
          {
            // 检查是否为预设用户
            if(userid == ConfigService.presetUserId) {
              // 预设用户，读取用户信息并跳转到用户管理页面
              _readUserInfoWithUserData(userid, state['name'], '').then((_) {
                // 使用WidgetsBinding确保在下一帧执行
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Get.offAll(() => const UserManagementScreen());
                });
              }).catchError((error) {
                Debug.log('读取用户信息失败: $error');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Get.offAll(() => const PermissionDeniedScreen());
                });
              });
            } else {
              // 非预设用户，跳转到权限不足页面
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Get.offAll(() => const PermissionDeniedScreen());
              });
            }
          }else{
            // 空用户ID，也跳转到权限不足页面
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Get.offAll(() => const PermissionDeniedScreen());
            });
          }
   
         },
         isMerchant: true,
       );
  }

  /// 添加经验值
  Future<bool> addExperience(int exp, {String? reason}) async {
    try {
      if (_currentUser.value == null) {
        PhoneUtil.applog('用户未登录，无法添加经验');
        return false;
      }

      PhoneUtil.applog('添加经验值: $exp, 原因: ${reason ?? "未知"}');
      
      final oldLevel = _currentUser.value!.level;
      final updatedUser = _currentUser.value!.addExperience(exp);
      final newLevel = updatedUser.level;
      
      // 保存更新后的用户信息
      final success = await saveUserInfo(updatedUser, isCreate: false);
      
      if (success) {
        // 如果升级了，记录升级日志
        if (newLevel != oldLevel) {
          PhoneUtil.applog('用户升级! 从 ${oldLevel.name} 升级到 ${newLevel.name}');
        }
        
        return true;
      } else {
        PhoneUtil.applog('添加经验值失败');
        return false;
      }
    } catch (e) {
      PhoneUtil.applog('添加经验值失败: $e');
      return false;
    }
  }

  /// 每日首次登录奖励
  Future<bool> giveDailyLoginReward() async {
    try {
      if (_currentUser.value == null) return false;
      
      final today = DateTime.now().toIso8601String().split('T')[0];
      final lastLoginDate = _currentUser.value!.statistics['lastLoginDate'] as String?;
      
      // 检查是否已经领取过今日奖励
      if (lastLoginDate == today) {
        // PhoneUtil.applog('今日已领取登录奖励');
        return false;
      }
      
      // 给予登录奖励经验
      final expReward = 10; // 每日登录奖励10经验
      final success = await addExperience(expReward, reason: '每日登录奖励');
      
      if (success) {
        PhoneUtil.applog('发放每日登录奖励: $expReward 经验');
      }
      
      return success;
    } catch (e) {
      PhoneUtil.applog('发放每日登录奖励失败: $e');
      return false;
    }
  }

  /// 下单成功奖励
  Future<bool> giveOrderReward(double orderAmount) async {
    try {
      if (_currentUser.value == null) return false;
      
      // 根据订单金额计算经验奖励 (每1元1经验，最低5经验)
      final expReward = (orderAmount * 1).round().clamp(5, 100);
      
      final success = await addExperience(expReward, reason: '下单成功奖励');
      
      if (success) {
        // 更新订单统计
        final updatedUser = _currentUser.value!.updateStatistics({
          'totalOrders': (_currentUser.value!.statistics['totalOrders'] ?? 0) + 1,
          'totalSpent': (_currentUser.value!.statistics['totalSpent'] ?? 0.0) + orderAmount,
        });
        
        await saveUserInfo(updatedUser, isCreate: false);
        PhoneUtil.applog('发放下单奖励: $expReward 经验');
      }
      
      return success;
    } catch (e) {
      PhoneUtil.applog('发放下单奖励失败: $e');
      return false;
    }
  }

  /// 添加外卖地址
  Future<bool> addDeliveryAddress(DeliveryAddress address) async {
    try {
      if (_currentUser.value == null) return false;
      
      PhoneUtil.applog('添加外卖地址: ${address.name}');
      PhoneUtil.applog('添加前地址数量: ${_currentUser.value!.addresses.length}');
      
      final updatedUser = _currentUser.value!.addAddress(address);
      PhoneUtil.applog('添加后地址数量: ${updatedUser.addresses.length}');
      
      final success = await saveUserInfo(updatedUser, isCreate: false);
      
      if (success) {
        PhoneUtil.applog('外卖地址添加成功');
        _updateUser(updatedUser);
      }
      
      return success;
    } catch (e) {
      PhoneUtil.applog('添加外卖地址失败: $e');
      return false;
    }
  }

  /// 更新外卖地址
  Future<bool> updateDeliveryAddress(String addressId, DeliveryAddress address) async {
    try {
      if (_currentUser.value == null) return false;
      
      PhoneUtil.applog('更新外卖地址: $addressId');
      
      final updatedUser = _currentUser.value!.updateAddress(addressId, address);
      final success = await saveUserInfo(updatedUser, isCreate: false);
      
      if (success) {
        PhoneUtil.applog('外卖地址更新成功');
        _updateUser(updatedUser);
      }
      
      return success;
    } catch (e) {
      PhoneUtil.applog('更新外卖地址失败: $e');
      return false;
    }
  }

  /// 删除外卖地址
  Future<bool> removeDeliveryAddress(String addressId) async {
    try {
      if (_currentUser.value == null) return false;
      
      PhoneUtil.applog('删除外卖地址: $addressId');
      
      final updatedUser = _currentUser.value!.removeAddress(addressId);
      final success = await saveUserInfo(updatedUser, isCreate: false);
      
      if (success) {
        PhoneUtil.applog('外卖地址删除成功');
        _updateUser(updatedUser);
      }
      
      return success;
    } catch (e) {
      PhoneUtil.applog('删除外卖地址失败: $e');
      return false;
    }
  }

  /// 设置默认地址
  Future<bool> setDefaultAddress(String addressId) async {
    try {
      if (_currentUser.value == null) return false;
      
      PhoneUtil.applog('设置默认地址: $addressId');
      
      final updatedUser = _currentUser.value!.setDefaultAddress(addressId);
      final success = await saveUserInfo(updatedUser, isCreate: false);
      
      if (success) {
        PhoneUtil.applog('默认地址设置成功');
        _updateUser(updatedUser);
      }
      
      return success;
    } catch (e) {
      PhoneUtil.applog('设置默认地址失败: $e');
      return false;
    }
  }

  /// 更新用户偏好
  Future<bool> updatePreferences(Map<String, dynamic> preferences) async {
    try {
      if (_currentUser.value == null) return false;
      
      PhoneUtil.applog('更新用户偏好');
      
      final updatedUser = _currentUser.value!.updatePreferences(preferences);
      final success = await saveUserInfo(updatedUser, isCreate: false);
      
      if (success) {
        PhoneUtil.applog('用户偏好更新成功');
      }
      
      return success;
    } catch (e) {
      PhoneUtil.applog('更新用户偏好失败: $e');
      return false;
    }
  }

  /// 更新用户头像（从API获取）
  Future<bool> updateAvatarFromAPI(String avatarUrl) async {
    try {
      if (_currentUser.value == null) return false;
      
      PhoneUtil.applog('从API更新用户头像: $avatarUrl');
      
      // 直接更新内存中的用户信息，不保存到JSON
      _currentUser.value = _currentUser.value!.copyWith(
        avatar: avatarUrl.isNotEmpty ? avatarUrl : null,
        updatedAt: DateTime.now(),
      );
      
      // 通知UI更新
      _updateUser(_currentUser.value);
      
      PhoneUtil.applog('用户头像从API更新成功');
      return true;
    } catch (e) {
      PhoneUtil.applog('从API更新用户头像失败: $e');
      return false;
    }
  }

  /// 获取用户头像 Widget
  /// [width] 头像宽度
  /// [height] 头像高度
  /// [radius] 头像圆角半径
  /// [defaultIcon] 默认图标（当没有头像时显示）
  /// [defaultIconColor] 默认图标颜色
  Widget getAvatarWidget({
    required double width,
    required double height,
    required double radius,
    IconData? defaultIcon,
    Color? defaultIconColor,
  }) {
    // 检查 chatUserobj 是否已初始化
    if (chatUserobj != null && chatUserobj!.chatuser != null && chatUserobj!.chatuser!.avatarURL != null && chatUserobj!.chatuser!.avatarURL!.isNotEmpty) {
      Debug.log("api用户头像 ${chatUserobj!.chatuser!.base64}");
      var widget = chatUserobj!.chatuser!.getavatar(
        width: width,
        height: height,
        radius: radius,
      );
      Debug.log("api用户头像widget ${widget.toString()}");
      return widget;
    }
    
    // 否则返回默认头像
    return ClipOval(
      child: Image.asset(
        'assets/icons/avatar.png',
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 如果默认头像图片加载失败，回退到图标
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: Icon(
              defaultIcon ?? Icons.person,
              size: width * 0.5,
              color: defaultIconColor ?? Colors.grey[600],
            ),
          );
        },
      ),
    );
  }


  /// 更新admin用户权限（仅超级管理员可操作）
  Future<bool> updateAdminPermissions(String targetUserId, Map<String, bool> newPermissions) async {
    try {
      if (_currentUser.value == null) return false;
      
      // 检查是否为超级管理员
      if (!isSuperAdmin) {
        PhoneUtil.applog('只有超级管理员可以更新admin权限');
        return false;
      }
      
      // 这里需要获取目标用户信息，暂时返回false
      // 实际实现需要根据业务逻辑来获取目标用户
      PhoneUtil.applog('更新admin权限功能需要进一步实现');
      return false;
    } catch (e) {
      PhoneUtil.applog('更新admin权限失败: $e');
      return false;
    }
  }

  /// 更新当前用户的admin权限（仅超级管理员可操作）
  Future<bool> updateCurrentUserAdminPermissions(Map<String, bool> newPermissions) async {
    try {
      if (_currentUser.value == null) return false;
      
      // 检查是否为超级管理员
      if (!isSuperAdmin) {
        PhoneUtil.applog('只有超级管理员可以更新admin权限');
        return false;
      }
      
      // 检查当前用户是否为admin
      if (!isAdmin) {
        PhoneUtil.applog('只有admin用户可以配置权限');
        return false;
      }
      
      PhoneUtil.applog('更新当前用户admin权限');
      
      final currentUserId = _currentUser.value!.userId;
      final updatedPermissions = AdminPermissionConfig(
        permissions: newPermissions,
        updatedAt: DateTime.now(),
        updatedBy: currentUserId,
      );
      
      final updatedUser = _currentUser.value!.copyWith(
        adminPermissions: updatedPermissions,
        updatedAt: DateTime.now(),
      );
      
      final success = await saveUserInfo(updatedUser, isCreate: false);
      
      if (success) {
        PhoneUtil.applog('admin权限更新成功');
        _updateUser(updatedUser);
      }
      
      return success;
    } catch (e) {
      PhoneUtil.applog('更新admin权限失败: $e');
      return false;
    }
  }

  /// 获取所有admin权限列表
  List<AdminPermission> getAllAdminPermissions() {
    return AdminPermission.values;
  }

  /// 获取当前用户的admin权限配置
  AdminPermissionConfig? get currentUserAdminPermissions {
    if (_currentUser.value == null) return null;
    return _currentUser.value!.adminPermissions;
  }


  /// 创建新用户文件
  Future<bool> _createUserFile(FChatFileMD fileMD, String data) async {
    try {

      bool result = await FileUtils.createFile(fileMD, data, currentUser!.userId);
      
      return result;
    
    } catch (e) {
      PhoneUtil.applog('创建用户文件失败: $e');
      return false;
    }
  }

  /// 更新现有用户文件
  Future<bool> _updateUserFile(FChatFileMD fileMD, String data) async {
    try {
    
      bool success = await FileUtils.updateFile(fileMD, currentUser!.userId, data);
      
      if(success){
        // 文件名保持不变（现在文件名就是用户ID，不需要更新）
        return true;
      }else{
        PhoneUtil.applog('用户文件更新失败');
        return false;
      }
    
    } catch (e) {
      PhoneUtil.applog('更新用户文件失败: $e');
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      
      _updateUser(null);
      
    } catch (e) {
      PhoneUtil.applog('用户登出失败: $e');
    }
  }


  /// 重置用户数据
  Future<bool> resetUserData() async {
    try {
      Debug.log('开始重置用户数据');
      
      final userId = UserObj.userid;
      if (userId.isEmpty) {
        PhoneUtil.applog('用户ID为空，无法重置用户数据');
        return false;
      }
      
      Debug.log('重置用户数据，用户ID: $userId');
      await FileUtils.clearDirectory(AppConstants.usermd);
      // 删除用户文件夹下的所有文件
      
      return true;
    } catch (e) {
      PhoneUtil.applog('重置用户数据失败: $e');
      return false;
    }
  }
  /// 获取所有拥有管理员权限的用户ID
  static Future<List<String>> getAllAdminUserIds() async {
    try {
      Debug.log('开始获取所有拥有管理员权限的用户ID');
      
      // 获取文件内容
      String? data = await FileUtils.readFileString(AppConstants.adminUserMD, 'adminUserMD');
      Debug.log('管理员用户ID文件内容: $data');
      // 检查数据是否为空
      if (data == null || data.isEmpty) {
        Debug.log('管理员用户ID文件为空，返回空列表');
         _updateAdminUserIds([]);
         return _adminUserIds;
      }

      // 解析JSON数组格式的数据
      List<String> adminUserIds = [];
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          adminUserIds = decoded.map((e) => e.toString()).toList();
        } else if (decoded is String) {
          // 兼容旧格式：如果是字符串，按逗号分割
          adminUserIds = decoded.split(',').where((id) => id.trim().isNotEmpty).toList();
        }
      } catch (e) {
        Debug.logError('解析管理员用户ID JSON失败，尝试按逗号分割: $e');
        // 如果JSON解析失败，尝试按逗号分割（兼容旧格式）
        adminUserIds = data.split(',').where((id) => id.trim().isNotEmpty).toList();
      }

      
      // 更新静态列表
      _updateAdminUserIds(adminUserIds);
      _adminUserIds.removeWhere((id) => id == UserService.instance.currentUser?.userId);
      
      Debug.log('成功获取管理员用户ID列表，共 ${adminUserIds.length} 个用户');
      Debug.log('管理员用户ID: $adminUserIds');
      
      return adminUserIds;
    } catch (e) {
      Debug.logError('获取管理员用户ID失败', e);
      
      // 返回空列表而不是抛出异常，确保应用稳定性
      return [];
    }
  }

  /// 保存所有拥有管理员权限的用户ID
  Future<bool> saveAllAdminUserIds(List<String> userIds) async {
    try {
      Debug.log('开始保存所有拥有管理员权限的用户ID');
      

      // 转换为JSON字符串 - 直接使用列表格式
      String data = jsonEncode(userIds);
  
      final result = await FileUtils.updateFile(AppConstants.adminUserMD, 'adminUserMD', data);
 
      
      if (result) {
        // 更新静态列表
       _updateAdminUserIds(userIds);
        Debug.log('管理员用户ID保存成功，文件MD5: $result');
        return true;
      } else {
        Debug.log('管理员用户ID保存失败，文件创建返回null');
        return false; 
      }
    } catch (e) {
      Debug.logError('保存管理员用户ID失败', e);
      return false;
    }
  }
  static void _updateAdminUserIds(List<String> userIds) {
    _adminUserIds.clear();
    _adminUserIds.addAll(userIds);
    if(!_adminUserIds.contains(ConfigService.presetUserId)){
      _adminUserIds.add(ConfigService.presetUserId);
    }
  }
}