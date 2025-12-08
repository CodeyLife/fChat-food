import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/address.dart';
import '../utils/debug.dart';
import '../utils/location.dart';

/// 通用地址服务类
/// 提供地址获取、更新等通用功能
class AddressService extends GetxController {
  static AddressService get instance => Get.find<AddressService>();
  
  final Rx<Address> currentAddress = Address().obs;
  final RxBool isLoading = false.obs;
  
  // 地址备注控制器
  late final TextEditingController notesController;
  
  @override
  void onInit() {
    super.onInit();
    notesController = TextEditingController();
  }
  
  @override
  void onClose() {
    notesController.dispose();
    super.onClose();
  }
  
  /// 获取当前位置（地址和坐标）
  void getCurrentLocation() {
    try {
      isLoading.value = true;
      // 使用Address模型的getCurrentLocation方法
      currentAddress.value.getCurrentLocation(
        onSuccess: () {
          Debug.log('地址服务获取位置成功');
          isLoading.value = false;
        },
        onError: () {
          Debug.log('地址服务获取位置失败');
          _showLocationError();
          isLoading.value = false;
        },
      );
    } catch (e) {
      Debug.log('获取GPS位置失败: $e');
      _showLocationError();
      isLoading.value = false;
    }
  }
  
  /// 更新地址备注
  void updateNotes(String notes) {
    currentAddress.value.updateNotes(notes);
  }
  
  /// 设置地址信息
  void setAddress(Address address) {
    currentAddress.value = address;
    notesController.text = address.notes.value;
  }
  
  /// 清空地址信息
  void clearAddress() {
    currentAddress.value.clear();
    notesController.clear();
  }
  
  /// 检查地址是否完整
  bool get isAddressComplete => currentAddress.value.isComplete;
  
  /// 检查是否有坐标
  bool get hasCoordinates => currentAddress.value.hasCoordinates;
  
  /// 显示位置获取错误
  void _showLocationError() {
    Debug.log('显示位置获取错误提示');
    Get.snackbar(
      LocationUtils.translate('Error'),
      LocationUtils.translate('Unable to get current location. Please try again.'),
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );
  }
}
