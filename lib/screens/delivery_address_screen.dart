import '../../widgets/luckin_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quickalert/quickalert.dart';
import 'package:get/get.dart';
import '../models/user_info.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../utils/debug.dart';
import '../utils/location.dart';
import 'edit_address_screen.dart';

/// 外卖地址管理页面
class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar:CommonWidget.appBar(title: LocationUtils.translate('Delivery Address Management'), context: context,
             actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddAddressDialog,
          ),
        ],),
      body: GetX<UserService>(
        builder: (userService) {
          final userInfo = userService.currentUser;
          if (userInfo == null) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B4513)),
              ),
            );
          }

          final addresses = userInfo.addresses;
          
          if (addresses.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return _buildAddressCard(address);
            },
          );
        },
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 80.w,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            LocationUtils.translate('No delivery addresses'),
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            LocationUtils.translate('Add addresses for quick ordering'),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: _showAddAddressDialog,
            icon: const Icon(Icons.add),
            label: Text(LocationUtils.translate('Add Address'), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建地址卡片
  Widget _buildAddressCard(DeliveryAddress address) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 地址头部
            Row(
              children: [
                // 默认标识
                if (address.isDefault) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(4.w),
                    ),
                    child: Text(
                      LocationUtils.translate('Default'),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                
                // 收货人姓名
                Expanded(
                  child: Text(
                    address.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                
                // 操作按钮
                PopupMenuButton<String>(
                  onSelected: (value) => _handleAddressAction(value, address),
                  itemBuilder: (context) => [
                     PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text(LocationUtils.translate('Edit'), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    if (!address.isDefault)
                       PopupMenuItem(
                        value: 'set_default',
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 18),
                            SizedBox(width: 8),
                            Text(LocationUtils.translate('Set as Default'), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                     PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text(LocationUtils.translate('Delete'), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8.h),
            
            // 联系电话
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 16.w,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8.w),
                Text(
                  address.phone,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 4.h),
            
            // 详细地址
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16.w,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    address.addressString,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            
            
            // 备注信息
            if (address.notes.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(
                    Icons.note,
                    size: 16.w,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      address.notes,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 显示添加地址页面
  void _showAddAddressDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditAddressScreen(address: null),
      ),
    );
  }

  /// 显示编辑地址页面
  void _showEditAddressDialog(DeliveryAddress address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAddressScreen(address: address),
      ),
    );
  }

  /// 处理地址操作
  void _handleAddressAction(String action, DeliveryAddress address) {
    switch (action) {
      case 'edit':
        _showEditAddressDialog(address);
        break;
      case 'set_default':
        _setDefaultAddress(address.id);
        break;
      case 'delete':
        _deleteAddress(address);
        break;
    }
  }

  /// 设置默认地址
  Future<void> _setDefaultAddress(String addressId) async {
    try {
      final userService = Get.find<UserService>();
      final success = await userService.setDefaultAddress(addressId);
      if (success) {
        _showSuccessMessage(LocationUtils.translate('Default address set successfully'));
      } else {
        _showErrorMessage(LocationUtils.translate('Default address set failed'));
      }
    } catch (e) {
      _showErrorMessage('${LocationUtils.translate('Error setting default address')}: $e');
    }
  }

  /// 删除地址
  void _deleteAddress(DeliveryAddress address) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: LocationUtils.translate('Confirm Delete'),
      text: LocationUtils.translate('Are you sure you want to delete this address?'),
      confirmBtnText: LocationUtils.translate('Delete'),
      cancelBtnText: LocationUtils.translate('Cancel'),
      onConfirmBtnTap: () async {
        Navigator.of(context).pop();
         final userService = Get.find<UserService>();
          Debug.log('开始删除地址: ${address.id}');
          
          final success = await userService.removeDeliveryAddress(address.id);
          Debug.log('删除结果: $success');
    });
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
