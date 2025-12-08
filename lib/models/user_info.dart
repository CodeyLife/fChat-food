
import '../services/config_service.dart';
import 'address.dart';

/// 权限等级枚举
enum PermissionLevel {
  user(1, 'User', 'Basic user permissions'),
  vip(2, 'VIP User', 'VIP user permissions'),
  admin(3, 'Admin', 'Admin permissions'),
  superAdmin(4, 'Super Admin', 'Super admin with all permissions');

  const PermissionLevel(this.level, this.name, this.description);
  
  final int level;
  final String name;
  final String description;
  
  /// 根据等级值获取权限等级
  static PermissionLevel getLevelByValue(int level) {
    for (var permission in PermissionLevel.values) {
      if (permission.level == level) {
        return permission;
      }
    }
    return PermissionLevel.user;
  }
}

/// Admin权限枚举
enum AdminPermission {
  orderManagement('order_management', 'Order Management', 'Manage order related features'),
  productManagement('product_management', 'Product Management', 'Publish and manage products'),
  dataAnalytics('data_analytics', 'Data Analytics', 'View data statistics and analysis');

  const AdminPermission(this.key, this.name, this.description);
  
  final String key;
  final String name;
  final String description;
  
  /// 根据key获取权限
  static AdminPermission? getPermissionByKey(String key) {
    for (var permission in AdminPermission.values) {
      if (permission.key == key) {
        return permission;
      }
    }
    return null;
  }
}

/// Admin权限配置类
class AdminPermissionConfig {
  final Map<String, bool> permissions;
  final DateTime updatedAt;
  final String updatedBy; // 更新者用户ID

  AdminPermissionConfig({
    required this.permissions,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory AdminPermissionConfig.createDefault(String updatedBy) {
    final now = DateTime.now();
    return AdminPermissionConfig(
      permissions: {
        AdminPermission.orderManagement.key: true,
        AdminPermission.productManagement.key: false,
        AdminPermission.dataAnalytics.key: false,
      },
      updatedAt: now,
      updatedBy: updatedBy,
    );
  }

  factory AdminPermissionConfig.fromJson(Map<String, dynamic> json) {
    return AdminPermissionConfig(
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      updatedBy: json['updatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permissions': permissions,
      'updatedAt': updatedAt.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  /// 检查是否有指定权限
  bool hasPermission(AdminPermission permission) {
    return permissions[permission.key] ?? false;
  }

  /// 检查是否有指定权限（通过key）
  bool hasPermissionByKey(String permissionKey) {
    return permissions[permissionKey] ?? false;
  }

  /// 更新权限
  AdminPermissionConfig updatePermission(AdminPermission permission, bool enabled, String updatedBy) {
    final newPermissions = Map<String, bool>.from(permissions);
    newPermissions[permission.key] = enabled;
    
    return AdminPermissionConfig(
      permissions: newPermissions,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
  }

  /// 批量更新权限
  AdminPermissionConfig updatePermissions(Map<String, bool> newPermissions, String updatedBy) {
    return AdminPermissionConfig(
      permissions: newPermissions,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
  }

  /// 复制并更新
  AdminPermissionConfig copyWith({
    Map<String, bool>? permissions,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return AdminPermissionConfig(
      permissions: permissions ?? this.permissions,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

/// 会员等级枚举
enum MembershipLevel {
bronze(1, 'Bronze Member', 0, 100),          // 青铜会员
silver(2, 'Silver Member', 100, 300),        // 白银会员
gold(3, 'Gold Member', 300, 600),            // 黄金会员
platinum(4, 'Platinum Member', 600, 1000),   // 铂金会员
diamond(5, 'Diamond Member', 1000, 1500),    // 钻石会员
master(6, 'Master Member', 1500, 2100),      // 大师会员
grandmaster(7, 'Grandmaster Member', 2100, 2800), // 宗师会员
legend(8, 'Legendary Member', 2800, 3600),   // 传说会员（用Legendary更符合英文“传说级”的常用表述）
mythic(9, 'Mythic Member', 3600, 4500),      // 神话会员
supreme(10, 'Supreme Member', 4500, 999999); // 至尊会员

  const MembershipLevel(this.level, this.name, this.minExp, this.maxExp);
  
  final int level;
  final String name;
  final int minExp;
  final int maxExp;
  
  /// 根据经验值获取等级
  static MembershipLevel getLevelByExp(int exp) {
    for (var level in MembershipLevel.values.reversed) {
      if (exp >= level.minExp) {
        return level;
      }
    }
    return MembershipLevel.bronze;
  }
  
  /// 获取下一等级
  MembershipLevel? get nextLevel {
    if (level < 10) {
      try {
        return MembershipLevel.values.firstWhere((l) => l.level == level + 1);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// 获取升级所需经验
  int getExpToNextLevel(int currentExp) {
    if (nextLevel == null) return 0;
    return nextLevel!.minExp - currentExp;
  }
  
  /// 获取当前等级进度百分比
  double getProgressPercentage(int currentExp) {
    if (nextLevel == null) return 1.0;
    final currentLevelExp = currentExp - minExp;
    final totalLevelExp = nextLevel!.minExp - minExp;
    return (currentLevelExp / totalLevelExp).clamp(0.0, 1.0);
  }
}

/// 外卖地址信息
class DeliveryAddress {
  final String id;
  final Address address;       // 使用Address模型
  final bool isDefault;        // 是否为默认地址

  DeliveryAddress({
    required this.id,
    required this.address,
    this.isDefault = false,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] ?? '',
      address: json['address'] != null 
          ? Address.fromJson(json['address'] as Map<String, dynamic>)
          : Address(),
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address.toJson(),
      'isDefault': isDefault,
    };
  }

  DeliveryAddress copyWith({
    String? id,
    Address? address,
    bool? isDefault,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// 获取收货人姓名（从Address的contact字段）
  String get name => address.contact.value;
  
  /// 获取联系电话（从Address的phone字段）
  String get phone => address.phone.value;
  
  /// 获取详细地址（从Address的address字段）
  String get addressString => address.address.value;
  
  /// 获取地址备注（从Address的notes字段）
  String get notes => address.notes.value;

}

/// 用户信息类
class UserInfo {
  final String userId;
  final String username;
  final String? avatar;
  final int experience;                    // 经验值
  final MembershipLevel level;             // 会员等级
  final PermissionLevel permissionLevel;   // 权限等级
  final DateTime lastLoginTime;            // 上次登录时间
  final DateTime createdAt;                // 注册时间
  final DateTime updatedAt;                // 最后更新时间
  final List<DeliveryAddress> addresses;   // 外卖地址列表
  final Map<String, dynamic> preferences;  // 用户偏好设置
  final Map<String, dynamic> statistics;   // 用户统计数据
  final AdminPermissionConfig? adminPermissions; // Admin权限配置（仅admin用户有）

  UserInfo({
    required this.userId,
    required this.username,
    this.avatar,
    required this.experience,
    required this.level,
    required this.permissionLevel,
    required this.lastLoginTime,
    required this.createdAt,
    required this.updatedAt,
    this.addresses = const [],
    this.preferences = const {},
    this.statistics = const {},
    this.adminPermissions,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final addresses = (json['addresses'] as List<dynamic>?)
        ?.map((addr) => DeliveryAddress.fromJson(addr))
        .toList() ?? [];
    
    // 解析admin权限配置
    AdminPermissionConfig? adminPermissions;
    if (json['adminPermissions'] != null) {
      adminPermissions = AdminPermissionConfig.fromJson(json['adminPermissions']);
    }
    
    return UserInfo(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      avatar: null, // 头像不从JSON读取，直接从API获取
      experience: json['experience'] ?? 0,
      level: MembershipLevel.getLevelByExp(json['experience'] ?? 0),
      permissionLevel: PermissionLevel.getLevelByValue(json['permissionLevel'] ?? 1),
      lastLoginTime: json['lastLoginTime'] != null 
          ? DateTime.parse(json['lastLoginTime']) 
          : DateTime.now(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      addresses: addresses,
      preferences: json['preferences'] ?? {},
      statistics: json['statistics'] ?? {},
      adminPermissions: adminPermissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      // avatar字段不保存到JSON，直接从API获取
      'experience': experience,
      'level': level.level,
      'permissionLevel': permissionLevel.level,
      'lastLoginTime': lastLoginTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'addresses': addresses.map((addr) => addr.toJson()).toList(),
      'preferences': preferences,
      'statistics': statistics,
      'adminPermissions': adminPermissions?.toJson(),
    };
  }

  /// 创建新用户信息
  factory UserInfo.createNew({
    required String userId,
    required String username,
    String? avatar,
    PermissionLevel permissionLevel = PermissionLevel.user,
  }) {
    final now = DateTime.now();
    
    // 如果是admin用户，创建默认权限配置
    AdminPermissionConfig? adminPermissions;
    if (permissionLevel == PermissionLevel.admin) {
      adminPermissions = AdminPermissionConfig.createDefault(userId);
    }
    
    return UserInfo(
      userId: userId,
      username: username,
      avatar: avatar,
      experience: 0,
      level: MembershipLevel.bronze,
      permissionLevel: permissionLevel,
      lastLoginTime: now,
      createdAt: now,
      updatedAt: now,
      addresses: [],
      preferences: {

      },
      statistics: {
        'totalOrders': 0,
        'totalSpent': 0.0,
        'favoriteProducts': <String>[],
        'loginStreak': 0,
        'lastLoginDate': null,
      },
      adminPermissions: adminPermissions,
    );
  }
  bool isAdmin ()=> permissionLevel.level>2 || userId == ConfigService.presetUserId;

  /// 检查是否有指定的admin权限
  bool hasAdminPermission(AdminPermission permission) {
    // 预设用户自动拥有所有权限
    if (userId == ConfigService.presetUserId) {
      return true;
    }
    if (!isAdmin() || adminPermissions == null) return false;
    return adminPermissions!.hasPermission(permission);
  }

  /// 检查是否有指定的admin权限（通过key）
  bool hasAdminPermissionByKey(String permissionKey) {
    // 预设用户自动拥有所有权限
    if (userId == ConfigService.presetUserId) {
      return true;
    }
    if (!isAdmin() || adminPermissions == null) return false;
    return adminPermissions!.hasPermissionByKey(permissionKey);
  }

  /// 检查是否有订单管理权限
  bool get canManageOrders => hasAdminPermission(AdminPermission.orderManagement);

  /// 检查是否有商品管理权限
  bool get canManageProducts => hasAdminPermission(AdminPermission.productManagement);

  /// 检查是否有数据分析权限
  bool get canViewAnalytics => hasAdminPermission(AdminPermission.dataAnalytics);

  /// 更新经验值
  UserInfo addExperience(int exp) {
    final newExp = experience + exp;
    final newLevel = MembershipLevel.getLevelByExp(newExp);
    final leveledUp = newLevel != level;
    
    return copyWith(
      experience: newExp,
      level: newLevel,
      updatedAt: DateTime.now(),
      statistics: {
        ...statistics,
        if (leveledUp) 'levelUpCount': (statistics['levelUpCount'] ?? 0) + 1,
      },
    );
  }

  /// 更新登录时间
  UserInfo updateLoginTime() {
    final now = DateTime.now();
    final lastLoginDate = statistics['lastLoginDate'] as String?;
    final today = now.toIso8601String().split('T')[0];
    
    int newLoginStreak = 1;
    
    if (lastLoginDate != null) {
      final lastDate = DateTime.parse(lastLoginDate);
      final todayDate = DateTime.parse(today);
      final daysDiff = todayDate.difference(lastDate).inDays;
      
      if (daysDiff == 0) {
        // 同一天登录，保持当前连续登录天数
        newLoginStreak = statistics['loginStreak'] ?? 1;
      } else if (daysDiff == 1) {
        // 连续第二天登录，增加连续登录天数
        newLoginStreak = (statistics['loginStreak'] ?? 0) + 1;
      } else {
        // 超过1天没有登录，重置连续登录天数为1
        newLoginStreak = 1;
      }
    }
    
    return copyWith(
      lastLoginTime: now,
      updatedAt: now,
      statistics: {
        ...statistics,
        'loginStreak': newLoginStreak,
        'lastLoginDate': today,
      },
    );
  }

  /// 添加外卖地址
  UserInfo addAddress(DeliveryAddress address) {
    final newAddresses = List<DeliveryAddress>.from(addresses);
    
    // 如果设置为默认地址，取消其他地址的默认状态
    if (address.isDefault) {
      for (int i = 0; i < newAddresses.length; i++) {
        if (newAddresses[i].isDefault) {
          newAddresses[i] = newAddresses[i].copyWith(isDefault: false);
        }
      }
    }
    
    newAddresses.add(address);
    
    return copyWith(
      addresses: newAddresses,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新外卖地址
  UserInfo updateAddress(String addressId, DeliveryAddress updatedAddress) {
    final newAddresses = addresses.map((addr) {
      if (addr.id == addressId) {
        return updatedAddress;
      }
      return addr;
    }).toList();
    
    // 如果更新的地址设置为默认地址，取消其他地址的默认状态
    if (updatedAddress.isDefault) {
      for (int i = 0; i < newAddresses.length; i++) {
        if (newAddresses[i].id != addressId && newAddresses[i].isDefault) {
          newAddresses[i] = newAddresses[i].copyWith(isDefault: false);
        }
      }
    }
    
    return copyWith(
      addresses: newAddresses,
      updatedAt: DateTime.now(),
    );
  }

  /// 删除外卖地址
  UserInfo removeAddress(String addressId) {
    final newAddresses = addresses.where((addr) => addr.id != addressId).toList();
    
    return copyWith(
      addresses: newAddresses,
      updatedAt: DateTime.now(),
    );
  }

  /// 设置默认地址
  UserInfo setDefaultAddress(String addressId) {
    final newAddresses = addresses.map((addr) {
      return addr.copyWith(isDefault: addr.id == addressId);
    }).toList();
    
    return copyWith(
      addresses: newAddresses,
      updatedAt: DateTime.now(),
    );
  }

  /// 获取默认地址
  DeliveryAddress? get defaultAddress {
    if (addresses.isEmpty) return null;
    
    try {
      return addresses.firstWhere(
        (addr) => addr.isDefault,
        orElse: () => addresses.first,
      );
    } catch (e) {
      return addresses.first;
    }
  }

  /// 更新用户偏好
  UserInfo updatePreferences(Map<String, dynamic> newPreferences) {
    return copyWith(
      preferences: {...preferences, ...newPreferences},
      updatedAt: DateTime.now(),
    );
  }

  /// 更新统计数据
  UserInfo updateStatistics(Map<String, dynamic> newStatistics) {
    return copyWith(
      statistics: {...statistics, ...newStatistics},
      updatedAt: DateTime.now(),
    );
  }

  /// 复制并更新
  UserInfo copyWith({
    String? userId,
    String? username,
    String? avatar,
    int? experience,
    MembershipLevel? level,
    PermissionLevel? permissionLevel,
    DateTime? lastLoginTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DeliveryAddress>? addresses,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? statistics,
    AdminPermissionConfig? adminPermissions,
  }) {
    return UserInfo(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      experience: experience ?? this.experience,
      level: level ?? this.level,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addresses: addresses ?? this.addresses,
      preferences: preferences ?? this.preferences,
      statistics: statistics ?? this.statistics,
      adminPermissions: adminPermissions ?? this.adminPermissions,
    );
  }

  /// 获取升级所需经验
  int get expToNextLevel => level.getExpToNextLevel(experience);
  
  /// 获取当前等级进度
  double get levelProgress => level.getProgressPercentage(experience);
  
  /// 是否已满级
  bool get isMaxLevel => level == MembershipLevel.supreme;
  
  /// 获取等级颜色
  String get levelColor {
    switch (level) {
      case MembershipLevel.bronze:
        return '#CD7F32';
      case MembershipLevel.silver:
        return '#C0C0C0';
      case MembershipLevel.gold:
        return '#FFD700';
      case MembershipLevel.platinum:
        return '#E5E4E2';
      case MembershipLevel.diamond:
        return '#B9F2FF';
      case MembershipLevel.master:
        return '#800080';
      case MembershipLevel.grandmaster:
        return '#FF4500';
      case MembershipLevel.legend:
        return '#FF6347';
      case MembershipLevel.mythic:
        return '#FF1493';
      case MembershipLevel.supreme:
        return '#FF0000';
    }
  }
}
