import '../widgets/luckin_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../models/user_info.dart';
import '../models/address.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../utils/debug.dart';
import '../utils/location.dart';

/// 地址编辑页面
class EditAddressScreen extends StatefulWidget {
  final DeliveryAddress? address; // 如果为null，则是添加新地址；否则是编辑地址

  const EditAddressScreen({super.key, this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // 响应式地址文本
  final RxString _addressText = ''.obs;
  
  // 保存经纬度
  double _latitude = 0.0;
  double _longitude = 0.0;
  
  // 保存URL
  String _url = '';
  
  bool _isDefault = false;
  
  // 保存状态
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// 初始化数据
  void _initializeData() {
    if (widget.address != null) {
      // 编辑模式：加载现有数据
      _nameController.text = widget.address!.name;
      _phoneController.text = widget.address!.phone;
      _addressText.value = widget.address!.addressString;
      _notesController.text = widget.address!.notes;
      _isDefault = widget.address!.isDefault;
      _latitude = widget.address!.address.latitude.value;
      _longitude = widget.address!.address.longitude.value;
      _url = widget.address!.address.url.value;
    } else {
      // 添加模式：设置默认姓名
      final userService = Get.find<UserService>();
      final userInfo = userService.currentUser;
      if (userInfo != null) {
        _nameController.text = userInfo.username;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: CommonWidget.appBar(
        title: widget.address == null 
            ? LocationUtils.translate('Add Address') 
            : LocationUtils.translate('Edit Address'),
        context: context,
      ),
      // 让系统自动处理键盘弹出时的布局调整
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // 表单内容
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              // 添加键盘滚动行为，确保输入时不会出现布局问题
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              // 防止过度滚动，提供更好的用户体验
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 收货人姓名
                  TextField(
                    key: const ValueKey('recipient_name'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: LocationUtils.translate('Recipient Name'),
                      hintText: LocationUtils.translate('Please enter recipient name'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                      prefixIcon: const Icon(Icons.person),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // 联系电话
                  TextField(
                    key: const ValueKey('phone_number'),
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: LocationUtils.translate('Phone Number'),
                      hintText: LocationUtils.translate('Please enter phone number'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                      prefixIcon: const Icon(Icons.phone),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // 详细地址（只读，通过GPS获取）
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8.w),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.grey[600],
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              LocationUtils.translate('Detailed Address'),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _getCurrentLocation,
                              icon: Icon(Icons.my_location, size: 20.w),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.all(8.w),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6.w),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Obx(() => Text(
                          _addressText.value.isEmpty 
                              ? LocationUtils.translate('Click "Get Location" to obtain address')
                              : _addressText.value,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: _addressText.value.isEmpty 
                                ? Colors.grey[500] 
                                : Colors.black87,
                            fontStyle: _addressText.value.isEmpty 
                                ? FontStyle.italic 
                                : FontStyle.normal,
                          ),
                        )),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // 备注
                  TextField(
                    key: const ValueKey('notes'),
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: LocationUtils.translate('Notes (Optional)'),
                      hintText: LocationUtils.translate('Please enter notes'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                      prefixIcon: const Icon(Icons.note),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  
                  // 只在编辑地址时显示设为默认地址选项
                  if (widget.address != null) ...[
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8.w),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          LocationUtils.translate('Set as default address'),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _isDefault,
                        onChanged: (value) {
                          setState(() {
                            _isDefault = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // 底部按钮
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48.h, // 固定按钮高度
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.w),
                        ),
                      ),
                      child: Text(
                        LocationUtils.translate('Cancel'),
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: SizedBox(
                    height: 48.h, // 固定按钮高度
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.w),
                        ),
                      ),
                      child: _isSaving 
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            LocationUtils.translate('Save'),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取当前位置
  void _getCurrentLocation() {
    // 创建一个临时的Address对象来获取位置
    final tempAddress = Address();
    tempAddress.getCurrentLocation(
      onSuccess: () {
        Debug.log('地址更新完成: ${tempAddress.address.value}');
        // 更新响应式变量和经纬度
        _addressText.value = tempAddress.address.value;
        _latitude = tempAddress.latitude.value;
        _longitude = tempAddress.longitude.value;
        // 保存URL
        _url = tempAddress.url.value;
      },
      onError: () {
        Debug.log('获取位置失败');
      },
    );
  }

  /// 保存地址
  Future<void> _saveAddress() async {
    if (!_validateForm() || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final userService = Get.find<UserService>();
      final userInfo = userService.currentUser;
      
      // 如果是添加新地址，检查是否已有地址，如果没有则设为默认地址
      bool isDefault = _isDefault;
      if (widget.address == null && userInfo != null) {
        // 添加新地址时，如果当前没有地址，则第一个地址自动设为默认
        isDefault = userInfo.addresses.isEmpty;
      }
      
      // 创建Address对象（包含经纬度）
      final addressData = Address(
        address: _addressText.value.trim(),
        latitude: _latitude,
        longitude: _longitude,
        contact: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        notes: _notesController.text.trim(),
        url: _url,
      );

      final address = DeliveryAddress(
        id: widget.address?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        address: addressData,
        isDefault: isDefault
      );

      bool success;
      if (widget.address != null) {
        success = await userService.updateDeliveryAddress(widget.address!.id, address);
      } else {
        success = await userService.addDeliveryAddress(address);
      }

      if (success) {
        if(mounted) {
          Navigator.of(context).pop();
        }
        _showSuccessMessage(
          widget.address != null 
              ? LocationUtils.translate('Address updated successfully') 
              : LocationUtils.translate('Address added successfully')
        );
      } else {
        _showErrorMessage(
          widget.address != null 
              ? LocationUtils.translate('Address update failed') 
              : LocationUtils.translate('Address add failed')
        );
      }
    } catch (e) {
      _showErrorMessage('${LocationUtils.translate('Error saving address')}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 验证表单
  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      _showErrorMessage(LocationUtils.translate('Please enter the recipient name'));
      return false;
    }
    
    if (_phoneController.text.trim().isEmpty) {
      _showErrorMessage(LocationUtils.translate('Please enter the phone number'));
      return false;
    }
    
    if (_addressText.value.trim().isEmpty) {
      _showErrorMessage(LocationUtils.translate('Please get location first by clicking "Get Location" button'));
      return false;
    }
    
    return true;
  }

  /// 显示成功消息
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  /// 显示错误消息
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
      ),
    );
  }
}

