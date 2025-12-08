
import 'dart:math';
import 'package:fchatapi/webapi/WebUItools.dart';
import 'package:flutter/material.dart';
import '../utils/debug.dart';
import 'package:get/get.dart';
/// 通用地址类
/// 用于用户外卖地址和店铺地址的统一管理
class Address {
  // 地址（不可输入编辑，只能通过GPS API获取）
  RxString address = ''.obs;
  
  // 经纬度坐标（不可输入编辑，只能通过GPS API获取）
  RxDouble latitude = 0.0.obs;
  RxDouble longitude = 0.0.obs;
  
  // 地址备注（可编辑）
  RxString notes = ''.obs;
  
  // URL字段（可编辑）
  RxString url = ''.obs;
  
  // 联系人（可编辑）
  RxString contact = ''.obs;
  
  // 电话（可编辑）
  RxString phone = ''.obs;

  Address({
    String address = '',
    double latitude = 0.0,
    double longitude = 0.0,
    String notes = '',
    String url = '',
    String contact = '',
    String phone = '',
  }) {
    this.address.value = address;
    this.latitude.value = latitude;
    this.longitude.value = longitude;
    this.notes.value = notes;
    this.url.value = url;
    this.contact.value = contact;
    this.phone.value = phone;
  }

  /// 从JSON构建对象
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
      url: json['url'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'address': address.value,
      'latitude': latitude.value,
      'longitude': longitude.value,
      'notes': notes.value,
      'url': url.value,
      'contact': contact.value,
      'phone': phone.value,
    };
  }

  /// 计算与另一个地址的直线距离（单位：公里）
  double getDistance(Address other) {
    // if(ConfigService.isTest){
    //   return 0.0;
    // }
    // 使用Haversine公式计算地球表面两点间的距离
    const double earthRadius = 6371.0; // 地球半径（公里）
    
    // 打印两个地址的经纬度
    Debug.log('getDistance - 地址1: lat=${latitude.value}, lng=${longitude.value}');
    Debug.log('getDistance - 地址2: lat=${other.latitude.value}, lng=${other.longitude.value}');
    
    // 将角度转换为弧度
    double lat1Rad = latitude.value * (3.14159265359 / 180.0);
    double lat2Rad = other.latitude.value * (3.14159265359 / 180.0);
    double deltaLatRad = (other.latitude.value - latitude.value) * (3.14159265359 / 180.0);
    double deltaLngRad = (other.longitude.value - longitude.value) * (3.14159265359 / 180.0);
    
    // Haversine公式
    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * asin(sqrt(a));
    
    final distance = earthRadius * c;
    Debug.log('getDistance - 计算距离: ${distance}km');
    
    return distance;
  }


  /// 检查是否在指定距离范围内（单位：公里）
  bool isWithinDistance(Address other, double maxDistanceKm) {
    return getDistance(other) <= maxDistanceKm;
  }

  /// 格式化距离字符串（接受距离值）
  static String formatDistance(double distance) {
    if (distance < 1.0) {
      // 小于1公里，显示米
      return '${(distance * 1000).round()}m';
    } else if (distance < 10.0) {
      // 1-10公里，显示一位小数
      return '${distance.toStringAsFixed(1)}km';
    } else {
      // 大于10公里，显示整数
      return '${distance.round()}km';
    }
  }
  
  /// 获取格式化的距离字符串（兼容旧接口）
  String getDistanceString(Address other) {
    double distance = getDistance(other);
    return formatDistance(distance);
  }
  /// 更新地址信息（通过GPS API）
  void updateFromGPS({
    required String newAddress,
    required double newLatitude,
    required double newLongitude,
  }) {
    address.value = newAddress;
    latitude.value = newLatitude;
    longitude.value = newLongitude;
  }

  /// 通过GPS API获取当前位置并更新地址信息
  Future<void> getCurrentLocation({VoidCallback? onSuccess, VoidCallback? onError}) async {
    try {
      Debug.log('开始获取GPS位置...');
       final fChataddress = await WebUItools.openMap(Get.context!);
       if (fChataddress != null) {
            updateFromGPS(newAddress: fChataddress.address, newLatitude: fChataddress.position!.latitude, newLongitude: fChataddress.position!.longitude);
            onSuccess?.call();
       }else{
        onError?.call();
       }
    } catch (e) {
      Debug.log('获取GPS位置失败: $e');
      _showLocationError();
      onError?.call();
    }
  }

  /// 显示位置获取错误
  void _showLocationError() {
    Debug.log('显示位置获取错误提示');
    Get.snackbar(
      'Error',
      'Unable to get current location. Please try again.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );
  }

  /// 更新地址备注
  void updateNotes(String newNotes) {
    notes.value = newNotes;
  }


  /// 更新URL
  void updateUrl(String newUrl) {
    url.value = newUrl;
  }

  /// 更新联系人
  void updateContact(String newContact) {
    contact.value = newContact;
  }

  /// 更新电话
  void updatePhone(String newPhone) {
    phone.value = newPhone;
  }

  /// 检查地址是否完整
  bool get isComplete {
    return address.value.isNotEmpty && 
           latitude.value != 0.0 && 
           longitude.value != 0.0;
  }

  /// 检查是否有坐标
  bool get hasCoordinates {
    return latitude.value != 0.0 && longitude.value != 0.0;
  }

  /// 获取坐标字符串
  String get coordinatesString {
    return '${latitude.value.toStringAsFixed(6)}, ${longitude.value.toStringAsFixed(6)}';
  }

  /// 清空地址信息
  void clear() {
    address.value = '';
    latitude.value = 0.0;
    longitude.value = 0.0;
    notes.value = '';
    url.value = '';
    contact.value = '';
    phone.value = '';
  }

  /// 复制地址对象
  Address copy() {
    return Address(
      address: address.value,
      latitude: latitude.value,
      longitude: longitude.value,
      notes: notes.value,
      url: url.value,
      contact: contact.value,
      phone: phone.value,
    );
  }

  @override
  String toString() {
    return 'Address(address: ${address.value}, coordinates: $coordinatesString, notes: ${notes.value}, url: ${url.value}, contact: ${contact.value}, phone: ${phone.value})';
  }
}
