
import 'package:get/get_rx/get_rx.dart';

import '../models/product.dart';
import '../models/address.dart';
import '../models/order.dart';
import '../utils/debug.dart';

  // 定义国家枚举
  enum Country {
    china,
    usa,
    japan,
    uk,
    canada,
    australia,
  }

class Shop
 {
  String name = "";
  // 使用Address类管理地址信息
  late Address address;
  // 添加国家属性
  Country country = Country.usa;
  
  // 最远配送距离（默认值5km）
  double maxDeliveryDistance = 5.0;
  
  // 最低免费配送金额（订单达到这个金额才可免费配送）
  double minimumOrderAmount = 0.0;
  
  // 配送费（当订单金额低于最低免费配送金额时收取）
  double deliveryFee = 0.0;

  // 营业时间：开始时间（格式：HH:mm，如 "09:00"）
  String openingHour = "09:00";
  
  // 营业时间：结束时间（格式：HH:mm，如 "18:00"）
  String closingHour = "18:00";

  // 是否营业（手动控制开关，独立于营业时间）
  bool isOpen = true;

  // 是否提供外卖服务
  bool enableDelivery = true;

  RxString symbol = "\$".obs;

  // 轮播广告图片列表
  List<ImageObj> bannerImages = <ImageObj>[];

  // 货币类型映射表
  static const Map<Country, String> _countryCurrencyMap = {
    Country.china: "CNY",    // 人民币
    Country.usa: "USD",      // 美元
    Country.japan: "JPY",    // 日元
    Country.uk: "GBP",       // 英镑
    Country.canada: "CAD",   // 加拿大元
    Country.australia: "AUD" // 澳大利亚元
  };

  // 货币符号映射表
  static const Map<String, String> _currencySymbolMap = {
    "CNY": "¥",    // 人民币符号
    "USD": "\$",   // 美元符号
    "JPY": "¥",    // 日元符号
    "GBP": "£",    // 英镑符号
    "CAD": "C\$",  // 加拿大元符号
    "AUD": "A\$"   // 澳大利亚元符号
  };

  Shop({
    this.name = "",
    Address? address,
    this.country = Country.usa,
    this.maxDeliveryDistance = 5.0,
    this.minimumOrderAmount = 0.0,
    this.deliveryFee = 0.0,
    this.openingHour = "09:00",
    this.closingHour = "18:00",
    this.isOpen = true,
    this.enableDelivery = true,
    this.bannerImages = const [],
  })
  {
    this.address = address ?? Address(
      address: '',
      latitude: 0.0,
      longitude: 0.0,
      notes: '',
      url: '',
      contact: '',
      phone: '',
    );
    symbol.value = getCurrencySymbolByCountry(country);
  }

  // 根据国家获取货币类型
  static String getCurrencyByCountry(Country country) {
    // 如果没有找到对应国家的货币，返回默认值
    return _countryCurrencyMap[country] ?? "USD";
  }

  // 根据国家获取货币符号
  static String getCurrencySymbolByCountry(Country country) {
    String currency = getCurrencyByCountry(country);
    return _currencySymbolMap[currency] ?? "\$";
  }

  // 根据货币代码获取货币符号
  static String getCurrencySymbolByCode(String currencyCode) {
    return _currencySymbolMap[currencyCode] ?? "\$";
  }

  // 从JSON构建对象
  factory Shop.fromJson(Map<String, dynamic> json) {
    // 解析国家字符串为枚举值
    Country? country;
    try {
      if (json['country'] != null) {
        country = Country.values.firstWhere(
          (e) => e.toString().split('.').last == json['country'].toLowerCase(),
        );
       
      }
    } catch (e) {
      // 处理无效的国家值
    }

    // 解析轮播广告图片
    List<ImageObj> bannerImages = [];
    if (json['bannerImages'] != null) {
      try {
        List<dynamic> bannerList = json['bannerImages'] as List<dynamic>;
        bannerImages = bannerList.map((item) => ImageObj.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        Debug.log("Error parsing banner images: $e");
      }
    }

    // 解析地址信息
    Address shopAddress = Address(
      address: '',
      latitude: 0.0,
      longitude: 0.0,
      notes: '',
      url: '',
      contact: '',
      phone: '',
    );
    
    if (json['address'] != null) {
      if (json['address'] is Map<String, dynamic>) {
        // 新格式：地址是Address对象
        shopAddress = Address.fromJson(json['address'] as Map<String, dynamic>);
      } else {
        // 旧格式：地址是字符串
        shopAddress = Address(
          address: json['address'] as String? ?? '',
          latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
          notes: '',
          url: '',
          contact: '',
          phone: '',
        );
      }
    }

    return Shop(
      name: json['name'] as String? ?? '',
      address: shopAddress,
      country: country ?? Country.usa,
      maxDeliveryDistance: (json['maxDeliveryDistance'] as num?)?.toDouble() ?? 5.0,
      minimumOrderAmount: (json['minimumOrderAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      openingHour: json['openingHour'] as String? ?? "09:00",
      closingHour: json['closingHour'] as String? ?? "18:00",
      isOpen: json['isOpen'] as bool? ?? true,
      enableDelivery: json['enableDelivery'] as bool? ?? true,
      bannerImages: bannerImages,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address.toJson(),
      'country': country.toString().split('.').last,
      'maxDeliveryDistance': maxDeliveryDistance,
      'minimumOrderAmount': minimumOrderAmount,
      'deliveryFee': deliveryFee,
      'openingHour': openingHour,
      'closingHour': closingHour,
      'isOpen': isOpen,
      'enableDelivery': enableDelivery,
      'bannerImages': bannerImages.map((image) => image.toJson()).toList(),
    };
  }

  // 获取当前商店的货币代码
  String get currency => getCurrencyByCountry(country);

  // 获取当前商店的货币符号
  String get currencySymbol => getCurrencySymbolByCountry(country);

  /// 计算配送费
  /// 如果订单类型为堂食（dineIn），返回 0（堂食订单配送费为0）
  /// 如果订单金额 >= minimumOrderAmount，返回 0（免费配送）
  /// 如果订单金额 < minimumOrderAmount，返回 deliveryFee
  double calculateShippingFee(double orderSubtotal, {required OrderType orderType}) {
    // 堂食订单配送费为0
    if (orderType == OrderType.dineIn) {
      return 0.0;
    }
    // 外卖订单按原有逻辑计算
    if (orderSubtotal >= minimumOrderAmount) {
      return 0.0; // 免费配送
    }
    return deliveryFee; // 收取配送费
  }

  /// 检查当前时间是否在营业时间内
  /// 返回 true 表示在营业时间内，false 表示不在营业时间
  bool isWithinBusinessHours() {
    try {
      // 解析营业时间
      final openingParts = openingHour.split(':');
      final closingParts = closingHour.split(':');
      
      if (openingParts.length != 2 || closingParts.length != 2) {
        // 格式错误，默认返回 true（允许营业）
        Debug.log('营业时间格式错误: openingHour=$openingHour, closingHour=$closingHour');
        return true;
      }
      
      final openingHourInt = int.tryParse(openingParts[0]) ?? 9;
      final openingMinuteInt = int.tryParse(openingParts[1]) ?? 0;
      final closingHourInt = int.tryParse(closingParts[0]) ?? 18;
      final closingMinuteInt = int.tryParse(closingParts[1]) ?? 0;
      
      // 获取当前时间
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      
      // 将当前时间转换为分钟数（从0点开始）
      final currentTimeInMinutes = currentHour * 60 + currentMinute;
      
      // 将营业时间转换为分钟数
      final openingTimeInMinutes = openingHourInt * 60 + openingMinuteInt;
      final closingTimeInMinutes = closingHourInt * 60 + closingMinuteInt;
      
      // 检查当前时间是否在营业时间内
      return currentTimeInMinutes >= openingTimeInMinutes && 
             currentTimeInMinutes < closingTimeInMinutes;
    } catch (e) {
      Debug.log('检查营业时间时出错: $e');
      // 出错时默认返回 true（允许营业）
      return true;
    }
  }

}


