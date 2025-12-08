
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../models/shop.dart';
import '../../services/shop_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/debug.dart';
import '../../utils/location.dart';
import '../../widgets/banner_image_picker.dart';

class ShopSettingsScreen extends StatelessWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ShopService>(
      init: ShopService(),
      builder: (shopService) => _buildShopSettings(shopService, context),
    );
  }
  static const int _titleFontSize = 12;
  static const int _titleIconSize = 16;
  /// 构建店铺设置页面
  Widget _buildShopSettings(ShopService shopService, BuildContext context) {
    return Obx(() {
      if (shopService.isLoading.value) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
              SizedBox(height: 16.h),
              Text(
                LocationUtils.translate('Loading shop settings...'),
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24)
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.store,
                    color: Colors.white,
                    size: 32.w,
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocationUtils.translate('Shop Settings'),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        LocationUtils.translate('Manage your shop information'),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 6.h),
            
            // 店铺信息表单
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 店铺名称
                    _buildFormField(
                      label: LocationUtils.translate('Shop Name'),
                      hint: LocationUtils.translate('Enter your shop name'),
                      icon: Icons.store,
                      isRequired: true,
                      controller: shopService.shopNameController,
                      onChanged: shopService.updateShopName,
                    ),
                    
                    SizedBox(height: 8.h),
                    
                    // 店铺地址
                    _buildAddressSelect(shopService),
                    
                    SizedBox(height: 8.h),
                    
                    // 国家选择
                    _buildCountrySelector(shopService),
                    
                    SizedBox(height: 8.h),
                    
                    // 货币信息显示
                    _buildCurrencyInfo(shopService),
                    
                    SizedBox(height: 8.h),
                    
                    // 经纬度坐标显示
                    _buildCoordinatesDisplay(shopService),
                    
                    SizedBox(height: 8.h),
                    
                    // 是否营业开关
                    _buildIsOpenToggle(shopService),
                    
                    SizedBox(height: 8.h),
                    
                    // 是否提供外卖服务开关
                    _buildEnableDeliveryToggle(shopService),
                    
                    SizedBox(height: 8.h),
                    
                    // 配送相关参数（仅当提供外卖服务时显示）
                    Obx(() {
                      if (shopService.enableDelivery.value) {
                        return Column(
                          children: [
                            // 最远配送距离
                            _buildMaxDeliveryDistance(shopService),
                            
                            SizedBox(height: 8.h),
                            
                            // 最低配送金额
                            _buildMinimumOrderAmount(shopService),
                            
                            SizedBox(height: 8.h),
                            
                            // 配送费
                            _buildDeliveryFee(shopService),
                          ],
                        );
                      }
                      return SizedBox.shrink();
                    }),
                    
                    SizedBox(height: 8.h),
                    
                    // 营业时间
                    _buildBusinessHours(shopService, context),
                    
                    SizedBox(height: 8.h),
                    
                    // 轮播广告图片
                    _buildBannerImages(shopService),
                    
                    SizedBox(height: 8.h),
                    
                    // 保存按钮
                    _buildSaveButton(shopService, context),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 构建表单字段
  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required Function(String) onChanged,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: _titleIconSize.w,
              color: AppTheme.primaryBlue,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: _titleFontSize.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        TextField(
          onChanged: onChanged,
          maxLines: maxLines,
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 6.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSelect(ShopService shopService) {
    return Obx(() {
      final address = shopService.shop.value.address.address.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: _titleIconSize.w,
                color: AppTheme.primaryBlue,
              ),
              SizedBox(width: 8.w),
              Text(
                LocationUtils.translate('Shop Address'),
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              _addressPicker(shopService)
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              address.isEmpty ? LocationUtils.translate('No address set') : address,
              style: TextStyle(
                fontSize: 14.sp,
                color: address.isEmpty ? Colors.grey[500] : Colors.black87,
                fontWeight: address.isEmpty ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _addressPicker(ShopService shopService) {
  return Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _getCurrentLocation(shopService),
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child:Icon(
                      Icons.my_location,
                      size: 20.w,
                      color: AppTheme.primaryBlue,
                    ),
            ),
          ),
        ),
      );
  }

  /// 获取当前位置
  void _getCurrentLocation(ShopService shopService) {
    // 使用Address模型的getCurrentLocation方法
    shopService.shop.value.address.getCurrentLocation(
      onSuccess: () {
        Debug.log('店铺地址更新完成: ${shopService.shop.value.address.address.value}');
        // 由于使用了Obx，地址更新会自动触发UI重建
      },
      onError: () {
        Debug.log('获取店铺位置失败');
      },
    );
  }


  /// 构建国家选择器
  Widget _buildCountrySelector(ShopService shopService) {
    return Obx(() {
      final selectedCountry = shopService.selectedCountry.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.public,
                size: _titleIconSize.w,
                color: AppTheme.primaryBlue,
              ),
              SizedBox(width: 8.w),
              Text(
                LocationUtils.translate('Country'),
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Country>(
                value: selectedCountry,
                isExpanded: true,
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppTheme.primaryBlue,
                  size: _titleIconSize.w,
                ),
                dropdownColor: Colors.white,

                isDense: false,
              items: Country.values.map((country) {
                return DropdownMenuItem<Country>(
                  value: country,
                  child: Text(
                      _getCountryDisplayName(country),
                      style: TextStyle(
                        fontSize: _titleFontSize.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                );
              }).toList(),
              onChanged: (Country? newValue) {
                if (newValue != null) {
                  shopService.updateSelectedCountry(newValue);
                }
              },
            ),
                        ),
          ),
        ],
      );
    });
  }

  /// 构建货币信息显示
  Widget _buildCurrencyInfo(ShopService shopService) {
    return Obx(() {
      final selectedCountry = shopService.selectedCountry.value;
      final currency = Shop.getCurrencyByCountry(selectedCountry);
      final currencySymbol = Shop.getCurrencySymbolByCountry(selectedCountry);
      
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.attach_money,
              color: AppTheme.primaryBlue,
              size: 24.w,
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocationUtils.translate('Currency Information'),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${LocationUtils.translate('Code')}: $currency | ${LocationUtils.translate('Symbol')}: $currencySymbol',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// 构建保存按钮
  Widget _buildSaveButton(ShopService shopService, BuildContext context) {
    return Obx(() {
      final isSaving = shopService.isSaving.value;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : () => _saveShopSettings(shopService, context),
          icon: isSaving
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.save, size: 20.w),
          label: Text(
            isSaving ? LocationUtils.translate('Saving...') : LocationUtils.translate('Save Shop Settings'),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 4,
          ),
        ),
      );
    });
  }

  /// 保存店铺设置（带确认对话框）
  Future<void> _saveShopSettings(ShopService shopService, BuildContext context) async {
    // 显示确认对话框
    bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Confirm Save')),
        content: Text(LocationUtils.translate('Are you sure you want to save these shop settings?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocationUtils.translate('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LocationUtils.translate('Save')),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      bool success = await shopService.saveShopSettings();
      if (success) {
        // 显示成功消息
        Get.snackbar(
          LocationUtils.translate('Success'),
          LocationUtils.translate('Shop settings saved successfully'),
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          icon: Icon(Icons.check_circle, color: Colors.white),
        );
      }
    }
  }

  /// 构建轮播广告图片
  Widget _buildBannerImages(ShopService shopService) {
    return Obx(() {
      final bannerImages = shopService.bannerImages;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image,
                size: _titleIconSize.w,
                color: AppTheme.primaryBlue,
              ),
              SizedBox(width: 8.w),
              Text(
                LocationUtils.translate('Banner Images'),
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              if (bannerImages.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${bannerImages.length}/5',
                    style: TextStyle(
                      fontSize: _titleFontSize.sp,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          BannerImagePicker(
            selectedImages: bannerImages,
            onImagesChanged: shopService.updateBannerImages,
            maxImages: 5,
          ),
          SizedBox(height: 8.h),
          Text(
            '${LocationUtils.translate('Add banner images for homepage carousel')} (${LocationUtils.translate('Max')} 5 ${LocationUtils.translate('images')})',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
      );
    });
  }

  /// 构建经纬度坐标显示
  Widget _buildCoordinatesDisplay(ShopService shopService) {
    return Obx(() {
      final lat = shopService.shop.value.address.latitude.value;
      final lng = shopService.shop.value.address.longitude.value;
      
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: _titleIconSize.w,
                  color: AppTheme.primaryBlue,
                ),
                SizedBox(width: 8.w),
                Text(
                  LocationUtils.translate('Coordinates'),
                  style: TextStyle(
                    fontSize: _titleFontSize.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              
              
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _buildCoordinateField(
                    'Latitude',
                    lat.toStringAsFixed(6),
                    Icons.north,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildCoordinateField(
                    'Longitude',
                    lng.toStringAsFixed(6),
                    Icons.east,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// 构建坐标字段
  Widget _buildCoordinateField(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14.w,
                color: Colors.grey[600],
              ),
              SizedBox(width: 4.w),
              Text(
                LocationUtils.translate(label),
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建最远配送距离输入
  Widget _buildMaxDeliveryDistance(ShopService shopService) {
    return _buildFormField(
      label: LocationUtils.translate('Max Delivery Distance'),
      hint: LocationUtils.translate('Enter max delivery distance (km)'),
      icon: Icons.local_shipping,
      isRequired: false,
      controller: shopService.maxDeliveryDistanceController,
      onChanged: shopService.updateMaxDeliveryDistance,
    );
  }

  /// 构建最低配送金额输入
  Widget _buildMinimumOrderAmount(ShopService shopService) {
    return _buildFormField(
      label: LocationUtils.translate('Minimum Order Amount'),
      hint: LocationUtils.translate('Enter minimum order amount for delivery'),
      icon: Icons.attach_money,
      isRequired: false,
      controller: shopService.minimumOrderAmountController,
      onChanged: shopService.updateMinimumOrderAmount,
    );
  }

  /// 构建配送费输入
  Widget _buildDeliveryFee(ShopService shopService) {
    return _buildFormField(
      label: LocationUtils.translate('Delivery Fee'),
      hint: LocationUtils.translate('Enter delivery fee for orders below minimum'),
      icon: Icons.delivery_dining,
      isRequired: false,
      controller: shopService.deliveryFeeController,
      onChanged: shopService.updateDeliveryFee,
    );
  }

  /// 构建是否营业开关
  Widget _buildIsOpenToggle(ShopService shopService) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront,
                size: _titleIconSize.w,
                color: AppTheme.primaryBlue,
              ),
              SizedBox(width: 8.w),
              Text(
                LocationUtils.translate('Shop Status'),
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: shopService.isOpen.value 
                  ? Colors.green[50] 
                  : Colors.red[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: shopService.isOpen.value 
                    ? Colors.green[300]! 
                    : Colors.red[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  shopService.isOpen.value 
                      ? Icons.check_circle 
                      : Icons.cancel,
                  color: shopService.isOpen.value 
                      ? Colors.green[700] 
                      : Colors.red[700],
                  size: 24.w,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopService.isOpen.value 
                            ? LocationUtils.translate('Shop is Open')
                            : LocationUtils.translate('Shop is Closed'),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: shopService.isOpen.value 
                              ? Colors.green[800] 
                              : Colors.red[800],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        shopService.isOpen.value 
                            ? LocationUtils.translate('Currently accepting orders')
                            : LocationUtils.translate('Not accepting orders'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: shopService.isOpen.value 
                              ? Colors.green[600] 
                              : Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: shopService.isOpen.value,
                  onChanged: (value) {
                    shopService.updateIsOpen(value);
                  },
                  activeThumbColor: Colors.green,
                  inactiveThumbColor: Colors.red[300],
                  inactiveTrackColor: Colors.red[100],
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  /// 构建是否提供外卖服务开关
  Widget _buildEnableDeliveryToggle(ShopService shopService) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delivery_dining,
                size: _titleIconSize.w,
                color: AppTheme.primaryBlue,
              ),
              SizedBox(width: 8.w),
              Text(
                LocationUtils.translate('Delivery Service'),
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: shopService.enableDelivery.value 
                  ? Colors.blue[50] 
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: shopService.enableDelivery.value 
                    ? Colors.blue[300]! 
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  shopService.enableDelivery.value 
                      ? Icons.check_circle 
                      : Icons.cancel,
                  color: shopService.enableDelivery.value 
                      ? Colors.blue[700] 
                      : Colors.grey[700],
                  size: 24.w,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopService.enableDelivery.value 
                            ? LocationUtils.translate('Delivery Service Enabled')
                            : LocationUtils.translate('Delivery Service Disabled'),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: shopService.enableDelivery.value 
                              ? Colors.blue[800] 
                              : Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        shopService.enableDelivery.value 
                            ? LocationUtils.translate('Customers can place delivery orders')
                            : LocationUtils.translate('Only dine-in orders are available'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: shopService.enableDelivery.value 
                              ? Colors.blue[600] 
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: shopService.enableDelivery.value,
                  onChanged: (value) {
                    shopService.updateEnableDelivery(value);
                  },
                  activeThumbColor: Colors.blue,
                  inactiveThumbColor: Colors.grey[300],
                  inactiveTrackColor: Colors.grey[100],
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  /// 构建营业时间选择
  Widget _buildBusinessHours(ShopService shopService, BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: _titleIconSize.w,
                color: AppTheme.primaryBlue,
              ),
              SizedBox(width: 8.w),
              Text(
                LocationUtils.translate('Business Hours'),
                style: TextStyle(
                  fontSize: _titleFontSize.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              // 开始营业时间
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(
                    context: context,
                    shopService: shopService,
                    isOpeningTime: true,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sunny,
                          size: 18.w,
                          color: AppTheme.primaryBlue,
                        ),
                        SizedBox(width: 8.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocationUtils.translate('Opening Time'),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              shopService.openingHour.value,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14.w,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // 结束营业时间
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(
                    context: context,
                    shopService: shopService,
                    isOpeningTime: false,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.nightlight,
                          size: 18.w,
                          color: AppTheme.primaryBlue,
                        ),
                        SizedBox(width: 8.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocationUtils.translate('Closing Time'),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              shopService.closingHour.value,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14.w,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            LocationUtils.translate('Set shop opening and closing hours'),
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
      );
    });
  }

  /// 选择时间
  Future<void> _selectTime({
    required BuildContext context,
    required ShopService shopService,
    required bool isOpeningTime,
  }) async {
    // 解析当前时间字符串
    String currentTime = isOpeningTime 
        ? shopService.openingHour.value 
        : shopService.closingHour.value;
    
    final parts = currentTime.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
    final minute = parts.length >= 2 ? int.tryParse(parts[1]) ?? 0 : 0;
    
    final TimeOfDay initialTime = TimeOfDay(hour: hour, minute: minute);
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
       
            ),
            timePickerTheme: TimePickerThemeData(
              // 表盘上的数字样式（固定大小）
              dialTextStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              // 小时和分钟的文本样式（固定大小）
              hourMinuteTextStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              // AM/PM 文本样式（固定大小）
              dayPeriodTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              // 帮助文本样式（固定大小）
              helpTextStyle: TextStyle(
                fontSize: 14,
              ),
              // 输入框装饰主题
              inputDecorationTheme: InputDecorationTheme(
                contentPadding: EdgeInsets.all(8),
              ),
            ),
            // 设置按钮主题以固定按钮大小
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                iconSize: 24, // 固定图标按钮大小
                minimumSize: Size(48, 48), // 固定按钮最小尺寸
                padding: EdgeInsets.all(12), // 固定内边距
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                minimumSize: Size(80, 40), // 固定文本按钮最小尺寸
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 固定内边距
                textStyle: TextStyle(
                  fontSize: 14, // 固定按钮文字大小
                ),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(80, 40), // 固定按钮最小尺寸
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 固定内边距
                textStyle: TextStyle(
                  fontSize: 14, // 固定按钮文字大小
                ),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context),
            child: child!,
          ),
        );
      },
    );
    
    if (picked != null) {
      // 格式化时间为 HH:mm 格式
      final formattedHour = picked.hour.toString().padLeft(2, '0');
      final formattedMinute = picked.minute.toString().padLeft(2, '0');
      final formattedTime = '$formattedHour:$formattedMinute';
      
      if (isOpeningTime) {
        shopService.updateOpeningHour(formattedTime);
        shopService.openingHourController.text = formattedTime;
      } else {
        // 验证结束时间必须在开始时间之后
        final openingParts = shopService.openingHour.value.split(':');
        final openingHour = openingParts.isNotEmpty 
            ? int.tryParse(openingParts[0]) ?? 9 
            : 9;
        final openingMinute = openingParts.length >= 2 
            ? int.tryParse(openingParts[1]) ?? 0 
            : 0;
        
        final openingTimeInMinutes = openingHour * 60 + openingMinute;
        final closingTimeInMinutes = picked.hour * 60 + picked.minute;
        
        if (closingTimeInMinutes <= openingTimeInMinutes) {
          // 显示错误提示
          Get.snackbar(
            LocationUtils.translate('Error'),
            LocationUtils.translate('Closing time must be after opening time'),
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );
          return;
        }
        
        shopService.updateClosingHour(formattedTime);
        shopService.closingHourController.text = formattedTime;
      }
    }
  }

  /// 获取国家显示名称
  String _getCountryDisplayName(Country country) {
    switch (country) {
      case Country.china:
        return 'China (中国)';
      case Country.usa:
        return 'United States (美国)';
      case Country.japan:
        return 'Japan (日本)';
      case Country.uk:
        return 'United Kingdom (英国)';
      case Country.canada:
        return 'Canada (加拿大)';
      case Country.australia:
        return 'Australia (澳大利亚)';
    }
  }

}
