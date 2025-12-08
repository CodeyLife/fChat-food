import 'dart:convert';
import '../utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/file_utils.dart';

import 'package:get/get.dart';

import '../utils/debug.dart';

class ShopService extends GetxController {
  static const String shopInfoFilename = 'shop_info.json';
  static ShopService get instance =>Get.find<ShopService>();
  static RxString get symbol => ShopService.instance.shop.value.symbol;
  final Rx<Shop> shop = Shop().obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  // 表单控制器
  final RxString shopName = ''.obs;
  final Rx<Country> selectedCountry = Country.usa.obs;
  final RxList<ImageObj> bannerImages = <ImageObj>[].obs;
  
  // 新增参数
  final RxDouble maxDeliveryDistance = 5.0.obs;
  final RxDouble minimumOrderAmount = 0.0.obs;
  final RxDouble deliveryFee = 0.0.obs;
  
  // 营业时间
  final RxString openingHour = "09:00".obs;
  final RxString closingHour = "18:00".obs;
  
  // 是否营业
  final RxBool isOpen = true.obs;
  
  // 是否提供外卖服务
  final RxBool enableDelivery = true.obs;
  
  // TextEditingController
  late final TextEditingController shopNameController;
  late final TextEditingController maxDeliveryDistanceController;
  late final TextEditingController minimumOrderAmountController;
  late final TextEditingController deliveryFeeController;
  late final TextEditingController openingHourController;
  late final TextEditingController closingHourController;
  
  @override
  void onInit() async {
    super.onInit();
    shopNameController = TextEditingController();
    maxDeliveryDistanceController = TextEditingController();
    minimumOrderAmountController = TextEditingController();
    deliveryFeeController = TextEditingController();
    openingHourController = TextEditingController();
    closingHourController = TextEditingController();
    await loadShopSettings();
  }
  
  /// 加载店铺设置
  Future<void> loadShopSettings() async {
    try {
      isLoading.value = true;
      
      // 使用getDirectoryFirstFile方法读取第一个文件
      final shopString = await FileUtils.readFile(AppConstants.shopmd, shopInfoFilename);
      if (shopString != null) {
        // 解析店铺信息
        final shop = Shop.fromJson(shopString);
        
        // 更新响应式变量
        this.shop.value = shop;
        shopName.value = shop.name;
        selectedCountry.value = shop.country;
        bannerImages.value = List.from(shop.bannerImages);
        maxDeliveryDistance.value = shop.maxDeliveryDistance;
        minimumOrderAmount.value = shop.minimumOrderAmount;
        deliveryFee.value = shop.deliveryFee;
        openingHour.value = shop.openingHour;
        closingHour.value = shop.closingHour;
        isOpen.value = shop.isOpen;
        enableDelivery.value = shop.enableDelivery;
        
        // 更新TextEditingController
        shopNameController.text = shop.name;
        maxDeliveryDistanceController.text = shop.maxDeliveryDistance.toString();
        minimumOrderAmountController.text = shop.minimumOrderAmount.toString();
        deliveryFeeController.text = shop.deliveryFee.toString();
        openingHourController.text = shop.openingHour;
        closingHourController.text = shop.closingHour;
        
        Debug.log('店铺信息加载成功: ${shop.name}');
      } else {
        Debug.log('未找到店铺信息文件，使用默认设置');
      }
    } catch (e) {
      Debug.log('加载店铺设置失败: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// 保存店铺设置
  Future<bool> saveShopSettings() async {
    try {
      isSaving.value = true;
      
      // 验证表单
      if (!_validateForm()) {
        return false;
      }

      // 创建店铺对象
      final shop = Shop(
        name: shopName.value.trim(),
        address: this.shop.value.address, // 使用现有的地址对象
        country: selectedCountry.value,
        maxDeliveryDistance: maxDeliveryDistance.value,
        minimumOrderAmount: minimumOrderAmount.value,
        deliveryFee: deliveryFee.value,
        openingHour: openingHour.value,
        closingHour: closingHour.value,
        isOpen: isOpen.value,
        enableDelivery: enableDelivery.value,
        bannerImages: List.from(bannerImages),
      );

      // 将店铺信息转换为JSON
      final shopJson = shop.toJson();
      final shopJsonString = jsonEncode(shopJson);

      // 使用saveToFirstFile方法保存到第一个文件
      final result = await FileUtils.updateFile(
        AppConstants.shopmd,
        shopInfoFilename,
        shopJsonString,
      );

      if (result) {
        // 更新本地状态
        this.shop.value = shop;
        SnackBarUtils.getSnackbar(
          'Success', 'Shop settings saved successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,colorText: Get.theme.colorScheme.onPrimary);
        Debug.log('店铺信息保存成功: $result');
        return true;
      } else {
        SnackBarUtils.getSnackbar(
          'Error', 'Failed to save shop settings',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError);
        return false;
      }
    } catch (e) {
      Debug.log('保存店铺设置失败: $e');
      SnackBarUtils.getSnackbar(
        'Error', 'Error saving shop settings: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// 更新店铺名称
  void updateShopName(String name) {
    shopName.value = name;
  }
  
  /// 更新店铺地址（通过GPS API）
  void updateShopAddress(String address, double lat, double lng) {
    shop.value.address.updateFromGPS(
      newAddress: address,
      newLatitude: lat,
      newLongitude: lng,
    );
  }
  
  /// 更新地址备注
  void updateAddressNotes(String notes) {
    shop.value.address.updateNotes(notes);
  }
  
  /// 更新最远配送距离
  void updateMaxDeliveryDistance(String distance) {
    final parsedDistance = double.tryParse(distance) ?? 5.0;
    maxDeliveryDistance.value = parsedDistance;
  }
  
  /// 更新最低配送金额
  void updateMinimumOrderAmount(String amount) {
    final parsedAmount = double.tryParse(amount) ?? 0.0;
    minimumOrderAmount.value = parsedAmount;
  }
  
  /// 更新配送费
  void updateDeliveryFee(String fee) {
    final parsedFee = double.tryParse(fee) ?? 0.0;
    deliveryFee.value = parsedFee;
  }
  
  /// 更新开始营业时间
  void updateOpeningHour(String hour) {
    openingHour.value = hour;
  }
  
  /// 更新结束营业时间
  void updateClosingHour(String hour) {
    closingHour.value = hour;
  }
  
  /// 更新是否营业
  void updateIsOpen(bool value) {
    isOpen.value = value;
  }
  
  /// 更新是否提供外卖服务
  void updateEnableDelivery(bool value) {
    enableDelivery.value = value;
  }
  
  @override
  void onClose() {
    shopNameController.dispose();
    maxDeliveryDistanceController.dispose();
    minimumOrderAmountController.dispose();
    deliveryFeeController.dispose();
    openingHourController.dispose();
    closingHourController.dispose();
    super.onClose();
  }
  
  /// 更新选择的国家
  void updateSelectedCountry(Country country) {
    selectedCountry.value = country;
  }
  
  /// 更新轮播广告图片
  void updateBannerImages(List<ImageObj> images) {
    bannerImages.value = List.from(images);
  }
  
  /// 添加轮播广告图片
  void addBannerImage(ImageObj image) {
    bannerImages.add(image);
  }
  
  /// 删除轮播广告图片
  void removeBannerImage(int index) {
    if (index >= 0 && index < bannerImages.length) {
      bannerImages.removeAt(index);
    }
  }
  
  /// 清空所有轮播广告图片
  void clearBannerImages() {
    bannerImages.clear();
  }
  
  /// 验证表单
  bool _validateForm() {
    // 验证店铺名称
    if (shopName.value.trim().isEmpty) {
      SnackBarUtils.getSnackbar(
        'Validation Error', 
        'Please enter shop name',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: Duration(seconds: 3),
      );
      return false;
    }
    
    if (shopName.value.trim().length < 2) {
      SnackBarUtils.getSnackbar(
        'Validation Error', 
        'Shop name must be at least 2 characters',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: Duration(seconds: 3),
      );
      return false;
    }
    
    // 验证店铺地址
    if (!shop.value.address.isComplete) {
      SnackBarUtils.getSnackbar(
        'Validation Error', 
        'Please set shop address using GPS',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: Duration(seconds: 3),
      );
      return false;
    }
    
    
    return true;
  }

}