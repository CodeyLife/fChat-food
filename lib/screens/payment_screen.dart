import 'dart:async';
import '../services/shop_service.dart';
import '../widgets/translate_text_widget.dart';
import 'package:fchatapi/FChatApiSdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../models/address.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/user_info.dart';
import '../services/payment_service.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../utils/debug.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/luckin_components.dart';
import '../widgets/async_image_widget.dart';
import 'delivery_address_screen.dart';
import 'download_app_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Order order;
  final bool isFromCart; // 是否来自购物车

  const PaymentScreen({
    super.key,
    required this.order,
    this.isFromCart = true, // 默认为true，保持向后兼容
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {

  final TextEditingController _notesController = TextEditingController();

  bool _isProcessing = false;
  DeliveryAddress? _selectedAddress;
  OrderType _orderType = OrderType.dineIn;
  
  // 配送限制检查结果
  bool _isWithinDeliveryRange = true;
  bool _meetsMinimumOrder = true;
  String _deliveryDistanceText = '';

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// 初始化支付
  void _initializePayment() {
    // 检查是否提供外卖服务，如果不提供则默认设置为堂食
    final shopService = Get.find<ShopService>();
    if (!shopService.shop.value.enableDelivery) {
      _orderType = OrderType.dineIn;
    }
    // 设置默认地址
    _setDefaultAddress();
  }
  
  /// 设置默认地址
  void _setDefaultAddress() {
    final userService = Get.find<UserService>();
    final userInfo = userService.currentUser;
    
    if (userInfo != null && userInfo.addresses.isNotEmpty) {
      // 找到默认地址
      final defaultAddress = userInfo.addresses.firstWhere(
        (addr) => addr.isDefault,
        orElse: () => userInfo.addresses.first,
      );
      if (mounted) {
        setState(() {
          _selectedAddress = defaultAddress;
          _checkDeliveryLimits();
        });
      }
    }
  }

  /// 检查配送限制
  void _checkDeliveryLimits() {
    if (_orderType != OrderType.delivery || _selectedAddress == null) {
      return;
    }

    final shopService = Get.find<ShopService>();
    final shop = shopService.shop.value;
    
    // 创建用户地址的Address对象
    final userAddress = _selectedAddress!.address;
    
    // 计算距离
    final distance = shop.address.getDistance(userAddress);
    _deliveryDistanceText = Address.formatDistance(distance);
    
    // 检查配送距离
    _isWithinDeliveryRange = distance <= shop.maxDeliveryDistance;
    
    // 检查最低订单金额
    _meetsMinimumOrder = widget.order.subtotal >= shop.minimumOrderAmount;
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检查用户是否登录
    final userService = Get.find<UserService>();
    final userInfo = userService.currentUser;
    
    if (userInfo == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(LocationUtils.translate('Download App')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const DownloadAppScreen(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: CommonWidget.appBar(title: LocationUtils.translate('Confirm Order'), context: context),

      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 收货信息
                  _buildShippingInfo(),
                  
                  SizedBox(height: 16.h),
                  
                  // 订单商品
                  _buildOrderItems(),
                  
                  SizedBox(height: 16.h),
                  
                  // 订单备注
                  _buildOrderNotes(),
                  
                  SizedBox(height: 16.h),
                  
                  // 订单摘要
                  _buildOrderSummary(),
                ],
              ),
            ),
          ),
          
          // 底部支付按钮
          _buildPaymentButton(),
        ],
      ),
    );
  }

  /// 构建收货信息
  Widget _buildShippingInfo() {
    return Column(
      children: [
        // 订单类型选择卡片
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: _buildOrderTypeSelector(),
        ),
        
        // 地址选择卡片（仅外卖时显示）
        if (_orderType == OrderType.delivery) ...[
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.w),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 地址标题和管理按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20.w,
                          color: AppTheme.primaryBlue,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Delivery Address',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _navigateToAddressManagement,
                      icon: Icon(Icons.edit, size: 16.w),
                      label: Text(LocationUtils.translate('Manage')),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16.h),
                
                // 地址选择
                GetX<UserService>(
                  builder: (userService) {
                    final userInfo = userService.currentUser;
                    
                    if (userInfo == null || userInfo.addresses.isEmpty) {
                      return _buildNoAddressCard();
                    }
                    
                    // 如果已选中地址，显示地址详情卡片
                    if (_selectedAddress != null) {
                      return Column(
                        children: [
                          _buildSelectedAddressCard(_selectedAddress!),
                          SizedBox(height: 12.h),
                          _buildAddressDropdown(userInfo.addresses),
                          // 配送限制提示
                          if (_orderType == OrderType.delivery && _selectedAddress != null)
                            _buildDeliveryLimitsCard(),
                        ],
                      );
                    }
                    
                    return _buildAddressDropdown(userInfo.addresses);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 构建订单类型选择器
  Widget _buildOrderTypeSelector() {
    final shopService = Get.find<ShopService>();
    final enableDelivery = shopService.shop.value.enableDelivery;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shopping_cart,
              size: 20.w,
              color: AppTheme.primaryBlue,
            ),
            SizedBox(width: 8.w),
            Text(
              LocationUtils.translate('Order Type'),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _buildOrderTypeOption(
                OrderType.dineIn,
                LocationUtils.translate('Dine In'),
                Icons.restaurant,
              ),
            ),
            if (enableDelivery) ...[
              SizedBox(width: 12.w),
              Expanded(
                child: _buildOrderTypeOption(
                  OrderType.delivery,
                  LocationUtils.translate('Delivery'),
                  Icons.delivery_dining,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 构建订单类型选项
  Widget _buildOrderTypeOption(OrderType type, String label, IconData icon) {
    final isSelected = _orderType == type;
    
    return GestureDetector(
      onTap: () {
        // 如果店铺不提供外卖服务，不允许选择外卖选项
        final shopService = Get.find<ShopService>();
        if (type == OrderType.delivery && !shopService.shop.value.enableDelivery) {
          return;
        }
        
        if (mounted) {
          setState(() {
            _orderType = type;
            // 如果切换到堂食，清空选中的地址
            if (type == OrderType.dineIn) {
              _selectedAddress = null;
              _isWithinDeliveryRange = true;
              _meetsMinimumOrder = true;
              _deliveryDistanceText = '';
            } else {
              // 如果切换到外卖，重新设置默认地址
              _setDefaultAddress();
            }
          });
        }
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withValues(alpha:0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8.w),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24.w,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey[600],
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryBlue : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建无地址卡片
  Widget _buildNoAddressCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.w),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_off,
            size: 48.w,
            color: Colors.grey[400],
          ),
          SizedBox(height: 8.h),
          Text(
            LocationUtils.translate('No delivery address'),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          ElevatedButton.icon(
            onPressed: _navigateToAddressManagement,
            icon: Icon(Icons.add, size: 16.w),
            label: Text(LocationUtils.translate('Add Address')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建选中地址卡片
  Widget _buildSelectedAddressCard(DeliveryAddress address) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(8.w),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 地址头部
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 20.w,
                color: AppTheme.primaryBlue,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  LocationUtils.translate('Selected Delivery Address'),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              if (address.isDefault)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    LocationUtils.translate('Default'),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 12.h),
          
          // 收货人信息
          Row(
            children: [
              Text(
                address.name,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                address.phone,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8.h),
          
          // 详细地址
          Text(
            address.addressString,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          
        ],
      ),
    );
  }

  /// 构建地址下拉框
  Widget _buildAddressDropdown(List<DeliveryAddress> addresses) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.w),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DeliveryAddress>(
          value: _selectedAddress,
          isExpanded: true,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          hint: Text(
            LocationUtils.translate('Please select delivery address'),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
          items: addresses.map((address) {
            return DropdownMenuItem<DeliveryAddress>(
              value: address,
              child: Container(
                constraints: BoxConstraints(
                  minHeight: 40.h,
                  maxHeight: 50.h,
                ),
                child: Row(
                  children: [
                    // 地址图标
                    Icon(
                      Icons.location_on,
                      size: 16.w,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8.w),
                    // 地址信息 - 所有文本在一行
                    Expanded(
                      child: Row(
                        children: [
                          // 姓名
                          Text(
                            address.name,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(width: 8.w),
                          // 电话
                          Text(
                            address.phone,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(width: 8.w),
                          // 地址
                          Expanded(
                            child: Text(
                              address.addressString,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 默认标识
                    if (address.isDefault) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          LocationUtils.translate('Default'),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (DeliveryAddress? newValue) {
            if (mounted) {
              setState(() {
                _selectedAddress = newValue;
                _checkDeliveryLimits();
              });
            }
          },
        ),
      ),
    );
  }
  
  /// 跳转到地址管理页面
  void _navigateToAddressManagement() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeliveryAddressScreen(),
      ),
    );
    
    // 如果从地址管理页面返回，重新设置默认地址
    if (result == true) {
      _setDefaultAddress();
    }
  }

  /// 构建配送限制提示卡片
  Widget _buildDeliveryLimitsCard() {
    final shopService = Get.find<ShopService>();
    final shop = shopService.shop.value;
    
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: !_isWithinDeliveryRange 
            ? Colors.red[50] 
            : Colors.green[50],
        borderRadius: BorderRadius.circular(8.w),
        border: Border.all(
          color: !_isWithinDeliveryRange 
              ? Colors.red[300]! 
              : Colors.green[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                !_isWithinDeliveryRange 
                    ? Icons.warning 
                    : Icons.check_circle,
                size: 16.w,
                color: !_isWithinDeliveryRange 
                    ? Colors.red[600] 
                    : Colors.green[600],
              ),
              SizedBox(width: 8.w),
              Text(
                LocationUtils.translate('Delivery Information'),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: !_isWithinDeliveryRange 
                      ? Colors.red[700] 
                      : Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          
          // 距离信息
          Text(
            '${LocationUtils.translate("Distance")}: $_deliveryDistanceText',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey[700],
            ),
          ),
          
          // 配送距离限制
          if (!_isWithinDeliveryRange) ...[
            SizedBox(height: 4.h),
            Text(
              'Delivery distance exceeds maximum range (${shop.maxDeliveryDistance.toStringAsFixed(1)}km)',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          
          // 配送费信息提示
          if (!_meetsMinimumOrder) ...[
            SizedBox(height: 4.h),
            Text(
              '${LocationUtils.translate("Order amount below free delivery threshold, delivery fee required")}\n${LocationUtils.translate("Free delivery threshold")}: ${ShopService.symbol.value}${shop.minimumOrderAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.orange[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          
          // 成功提示
          if (_isWithinDeliveryRange && _meetsMinimumOrder) ...[
            SizedBox(height: 4.h),
            Text(
              LocationUtils.translate('Delivery available to this address'),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建订单商品
  Widget _buildOrderItems() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocationUtils.translate('Order Items'),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
          SizedBox(height: 12.h),
          
          ...widget.order.items.map((item) => _buildOrderItem(item)),
        ],
      ),
    );
  }

  /// 构建订单商品项
  Widget _buildOrderItem(OrderItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          // 商品图片
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6.w),
            ),
            child: item.imageBytes != null
                ? AsyncImageWidget(
                    initialBytes: item.imageBytes!,
                    width: 50.w,
                    height: 50.w,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(6.w),
                    errorWidget: Icon(
                      Icons.coffee,
                      size: 30.w,
                      color: Colors.grey[400],
                    ),
                  )
                : Icon(
                    Icons.coffee,
                    size: 30.w,
                    color: Colors.grey[400],
                  ),
          ),
          SizedBox(width: 12.w),
          
          // 商品信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryBlue,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  '${LocationUtils.translate('Quantity')}: ${item.quantity}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // 价格
       Text(
            '${ShopService.symbol.value}${item.subtotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          )
        ,
        ],
      ),
    );
  }


  /// 构建订单备注
  Widget _buildOrderNotes() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocationUtils.translate('Order Notes'),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: LocationUtils.translate('Please enter order notes (optional)'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.w),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// 构建订单摘要
  Widget _buildOrderSummary() {
    // 根据当前订单类型动态计算配送费
    final shopService = Get.find<ShopService>();
    final calculatedShippingFee = shopService.shop.value.calculateShippingFee(
      widget.order.subtotal,
      orderType: _orderType,
    );
    final calculatedTotal = widget.order.subtotal + calculatedShippingFee;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('Total Price', widget.order.subtotal.toStringAsFixed(2)),
          _buildSummaryRow('Shipping Fee', calculatedShippingFee.toStringAsFixed(2)),
          Divider(height: 1.h),
          _buildSummaryRow(
            'Total',
            calculatedTotal.toStringAsFixed(2),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// 构建摘要行
  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            LocationUtils.translate(label),
            style: TextStyle(
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.primaryBlue : Colors.grey[700],
            ),
          ),
    Text(
            "${ShopService.symbol.value}$value",
            style: TextStyle(
              fontSize: isTotal ? 18.sp : 14.sp,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.red[600] : Colors.grey[700],
            ),
          )
       ,
        ],
      ),
    );
  }

  /// 构建支付按钮
  Widget _buildPaymentButton() {
    return GetBuilder<ShopService>(
      builder: (shopService) {
        final isShopOpen = shopService.shop.value.isOpen;
        final isWithinBusinessHours = shopService.shop.value.isWithinBusinessHours();
        final canPlaceOrder = isShopOpen && isWithinBusinessHours;
        
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 店铺关闭提示
              if (!canPlaceOrder)
                Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !isShopOpen ? Icons.storefront : Icons.access_time,
                        size: 16.w,
                        color: Colors.orange[700],
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          !isShopOpen
                              ? LocationUtils.translate('Shop is currently closed')
                              : LocationUtils.translate('Shop is currently closed. Business hours: ${shopService.shop.value.openingHour} - ${shopService.shop.value.closingHour}'),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  // 总价
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        // 根据当前订单类型动态计算总价
                        final shopService = Get.find<ShopService>();
                        final calculatedShippingFee = shopService.shop.value.calculateShippingFee(
                          widget.order.subtotal,
                          orderType: _orderType,
                        );
                        final calculatedTotal = widget.order.subtotal + calculatedShippingFee;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocationUtils.translate('Total'),
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${ShopService.symbol.value}${calculatedTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[600],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(width: 16.w),
                  
                  // 支付按钮
                  ElevatedButton(
                    onPressed: _canProceedWithPayment() ? (_isProcessing ? null : _processPayment) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canProceedWithPayment() ? AppTheme.primaryBlue : Colors.grey[400],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _getPaymentButtonText(),
                            style: TextStyle(fontSize: 16.sp),
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 检查是否可以继续支付
  bool _canProceedWithPayment() {
    final shopService = Get.find<ShopService>();
    final shop = shopService.shop.value;
    
    // 检查店铺是否营业（isOpen 字段）
    if (!shop.isOpen) {
      return false; // 店铺手动关闭
    }
    
    // 检查营业时间
    if (!shop.isWithinBusinessHours()) {
      return false; // 不在营业时间内
    }
    
    if (_orderType == OrderType.dineIn) {
      return true; // 堂食订单总是可以支付（营业时间内且店铺开放）
    }
    
    if (_orderType == OrderType.delivery) {
      // 外卖订单只需要检查配送距离，不再限制最低金额
      return _isWithinDeliveryRange;
    }
    
    return true;
  }

  /// 获取支付按钮文本
  String _getPaymentButtonText() {
    final shopService = Get.find<ShopService>();
    final shop = shopService.shop.value;
    
    // 检查店铺是否营业（isOpen 字段）
    if (!shop.isOpen) {
      return LocationUtils.translate('Shop Closed');
    }
    
    // 检查营业时间
    if (!shop.isWithinBusinessHours()) {
      return LocationUtils.translate('Shop Closed');
    }
    
    if (_orderType == OrderType.dineIn) {
      return LocationUtils.translate('Pay');
    }
    
    if (_orderType == OrderType.delivery) {
      if (!_isWithinDeliveryRange) {
        return LocationUtils.translate('Out of Range');
      }
      return LocationUtils.translate('Pay');
    }
    
    return LocationUtils.translate('Pay');
  }

  /// 处理支付
  Future<void> _processPayment() async {
    // 步骤1：验证表单
    if (!_validateForm()) {
      return;
    }

    // 步骤2：环境检查
    if (!FChatApiSdk.isFchatBrower && PaymentService.useRealPayment) {
      _showFChatPaymentDialog();
      // 非FChat环境也要创建订单并跳转，只是不进行实际支付
    }

    if (!mounted) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // 准备订单数据
      final updatedOrder = await _prepareOrderData();

      final paymentResult = await _executePayment(updatedOrder);
      if (paymentResult) {
          // 处理购物车
         await _handleCartAfterOrderCreation();
      } 

 
      
    } catch (e) {
      Debug.logError('处理支付', e);
      if (mounted) {
        _showError('处理订单失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// 准备订单数据
  Future<Order> _prepareOrderData() async {
    // 创建收货地址（仅外卖订单需要）
    ShippingAddress? shippingAddress;
    if (_orderType == OrderType.delivery && _selectedAddress != null) {
      shippingAddress = ShippingAddress(
        id: _selectedAddress!.id,
        address: _selectedAddress!.address,
      );
    }

    // 根据当前订单类型重新计算配送费
    final shopService = Get.find<ShopService>();
    final calculatedShippingFee = shopService.shop.value.calculateShippingFee(
      widget.order.subtotal,
      orderType: _orderType,
    );
    final calculatedTotal = widget.order.subtotal + calculatedShippingFee;

    // 更新订单类型、地址信息和配送费
    final updatedOrder = widget.order.copyWith(
      orderType: _orderType,
      shippingAddress: shippingAddress,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      status: OrderStatus.pending, // 确保订单状态为未支付
    );
    
    // 由于 copyWith 不能直接修改 shippingFee 和 totalAmount，需要手动创建新订单
    return Order(
      id: updatedOrder.id,
      orderNumber: updatedOrder.orderNumber,
      userId: updatedOrder.userId,
      items: updatedOrder.items,
      subtotal: updatedOrder.subtotal,
      shippingFee: calculatedShippingFee,
      totalAmount: calculatedTotal,
      status: updatedOrder.status,
      orderType: updatedOrder.orderType,
      shippingAddress: updatedOrder.shippingAddress,
      paymentId: updatedOrder.paymentId,
      notes: updatedOrder.notes,
      isPrinted: updatedOrder.isPrinted,
      createdAt: updatedOrder.createdAt,
      updatedAt: updatedOrder.updatedAt,
    );
  }

  /// 订单创建后处理购物车
  Future<void> _handleCartAfterOrderCreation() async {
    if (widget.isFromCart) {
      // 从购物车购买，清空购物车
      final cartController = Get.find<CartController>();
      cartController.clearCart();
      Debug.log('购物车已清空');
    } else {
      // 立即购买，不清空购物车
      Debug.log('立即购买，不清空购物车');
    }
  }

  /// 执行支付
  Future<bool> _executePayment(Order order) async {
    // 创建收货地址（仅外卖订单需要）
    ShippingAddress? shippingAddress;
    if (_orderType == OrderType.delivery && _selectedAddress != null) {
      shippingAddress = ShippingAddress(
        id: _selectedAddress!.id,
        address: _selectedAddress!.address,
      );
    }

    if (FChatApiSdk.isFchatBrower || !PaymentService.useRealPayment) {
      // FChat环境：执行实际支付
      final paymentResult = await _processFChatPayment(order, shippingAddress);
      if (paymentResult.isSuccess) {
        return true;
      } else {
        return false;
      }
      
    } else {
      // 非FChat环境：不进行支付处理
      Debug.log('非FChat环境，跳过支付处理');
      // 非FChat环境立即重置处理状态
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
    return false;
  }

  /// 验证表单
  bool _validateForm() {
    // 只有外卖订单才需要验证地址
    if (_orderType == OrderType.delivery && _selectedAddress == null) {
      _showError('请选择收货地址');
      return false;
    }
    
    return true;
  }

  /// 处理FChat环境中的支付
  Future<PaymentResult> _processFChatPayment(Order updatedOrder, ShippingAddress? shippingAddress) async {
    // 创建支付请求
    final paymentRequest = PaymentRequest(
      orderId: updatedOrder.id,
      orderNumber: updatedOrder.orderNumber,
      amount: updatedOrder.totalAmount,
      description: updatedOrder.orderNumber,
      customerPhone: shippingAddress?.phone ?? '',
      customerName: shippingAddress?.name ?? '',
    );

    // 发起支付
     return  await PaymentService().createPayment(paymentRequest, context: context, order: updatedOrder);

  }


  /// 显示FChat支付提示对话框
  void _showFChatPaymentDialog() {
      Get.dialog(
      AlertDialog(
        title: TranslateText('请在FChat中支付'),
        content: TranslateText('此功能需要在FChat应用中使用，请切换到FChat应用完成支付'),
        actions: [
          TextButton(onPressed: () {Get.back();}, child: TranslateText('OK')),
        ],
      ),
    );

  }

  /// 显示错误信息
  void _showError(String message) {
    SnackBarUtils.showError(context, message);
  }
}
