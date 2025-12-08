import 'dart:async';
import 'dart:convert';
import '../../widgets/translate_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../models/order.dart';
import '../../services/unified_order_service.dart';
import '../../services/order_monitor_service.dart';
import '../../services/shop_service.dart';
import '../../utils/debug.dart';
import '../../utils/app_theme.dart';
import '../../utils/location.dart';
import 'package:fchatapi/appapi/Scanapi.dart';
import 'package:fchatapi/FChatApiSdk.dart';

import '../../utils/screen_util.dart';
import '../../utils/file_utils.dart';
import '../../services/config_service.dart';
import '../main_screen.dart';

// 布局常量
class _LayoutConstants {
  // 卡片间距
  static const double cardSpacing = 12.0;
  static const double cardRunSpacing = 8.0;
  
  // 容器内边距
  static const double containerPadding = 6.0;
  static const double containerLeftPadding = 16.0; // 左侧专用间距
  
  // 卡片默认宽度
  static const double defaultCardWidth = 350.0;

}

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  String _orderSearchQuery = '';
  int _selectedOrderStatusIndex = 0;
  late final ShopService shopService;
  
  final List<String> _orderStatusFilters = ['All', 'Pending Payment', 'Paid', 'Processing', 'Ready for Pickup', 'Out for Delivery'];
  final TextEditingController _orderSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    shopService = ShopService.instance;
  }

  @override
  void dispose() {
    _orderSearchController.dispose();
    

    super.dispose();
  }

  /// 搜索订单
  void _searchOrders(String query) {
    setState(() {
      _orderSearchQuery = query;
    });
  }

  /// 根据状态筛选订单
  void _filterOrdersByStatus(int statusIndex) {
    setState(() {
      _selectedOrderStatusIndex = statusIndex;
    });
  }

  void _scanOrder() async {
    try {
      if (FChatApiSdk.isFchatBrower) {
        _fchatScan();
      } else {
        // 非fchat环境，显示提示框
        _showNonFchatDialog();
      }
    } catch (e) {
      Debug.log('扫码失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocationUtils.translate('扫码失败: \$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _fchatScan() {
    Scanapi().scan((value) {
      Debug.log("扫码返回内容$value");
      var map = jsonDecode(value);
      _handleScanResult(map["qrcode"]);
    });
  }

  /// 显示非fchat环境提示对话框
  void _showNonFchatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 24.w),
            SizedBox(width: 8.w),
            'scan function is not available'.translateText(),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'scan function is only available in fchat environment'.translateText(   style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondary,
            ),),
            SizedBox(height: 16.h),
            'please use the manual input function'.translateText(   style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary,), textAlign: TextAlign.center,),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('取消')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualInputDialog();
            },
            child: Text(LocationUtils.translate('手动输入')),
          ),
        ],
      ),
    );
  }

  /// 显示手动输入对话框
  void _showManualInputDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('manual input order number')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: LocationUtils.translate('please input order number'),
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final orderId = controller.text.trim();
              if (orderId.isNotEmpty) {
                Navigator.pop(context);
                _handleScanResult(orderId);
              }
            },
            child: Text(LocationUtils.translate('confirm')),
          ),
        ],
      ),
    );
  }

  /// 处理扫描结果
  /// 扫描的二维码包含订单的唯一ID (order.id), 通过唯一ID查找订单
  Future<void> _handleScanResult(String scannedData) async {
    try {
      // 解析扫描结果，提取订单唯一ID
      // 二维码格式: coffee_shop://order/{order.id}
      String orderId = scannedData;
      
      // 如果是URL格式，提取订单唯一ID
      if (scannedData.startsWith('coffee_shop://order/')) {
        orderId = scannedData.replaceFirst('coffee_shop://order/', '');
      }
      
      // 显示统一的处理对话框（不关闭扫描页面）
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.qr_code_scanner, color: AppTheme.primaryBlue, size: 24.w),
              SizedBox(width: 8.w),
              Text(LocationUtils.translate('Processing Order')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
              SizedBox(height: 16.h),
              Text(
                LocationUtils.translate('verifying and loading order details...'),
                style: TextStyle(fontSize: 14.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                LocationUtils.translate('checking order... please wait...'),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
      
      // 通过订单唯一ID查找订单
      Order? foundOrder = await UnifiedOrderService.getOrderById(orderId);
      
      // 如果通过唯一ID没找到，尝试通过刷新所有订单后再次查找
      if (foundOrder == null) {
        await UnifiedOrderService.loadAllOrders();
        foundOrder = await UnifiedOrderService.getOrderById(orderId);
      }
       
      
      // 如果找到了订单，显示订单详情弹窗
      if (foundOrder != null) {
        Debug.log('通过唯一ID找到订单: ${foundOrder.orderNumber} (唯一ID: ${foundOrder.id})');
        
        // 关闭处理对话框
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
        // 显示订单详情对话框
        // ignore: use_build_context_synchronously
        _showOrderDetailDialog(context, foundOrder);
        return;
      }

      // 如果没找到订单，显示未找到对话框
      Debug.log('通过唯一ID未找到订单: $orderId');
      

      // 关闭处理对话框
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      
      // 获取当前所有订单用于显示
      final orders = await UnifiedOrderService.getAllInProgressOrders();
  
      _showOrderNotFound(Get.context!, orderId, orders);

    } catch (e) {
       Get.offUntil(GetPageRoute(page: () => MainScreen()), (route) => route.isFirst);
      _showError(Get.context!, '${LocationUtils.translate('Failed to process scan result')}: $e');
    }
  }

  /// 显示订单未找到的对话框
  void _showOrderNotFound(BuildContext context, String orderId, List<Order> orders) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Order Not Found')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${LocationUtils.translate('Order')} ID: $orderId'),
            SizedBox(height: 16.h),
            Text(
              '${LocationUtils.translate('Current in-progress orders')}:'),
            SizedBox(height: 8.h),
            ...orders.take(5).map((order) => Padding(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              child: Text(
                '• ${order.orderNumber} (${order.getStatusText()})'),
            )),
            if (orders.length > 5)
              Text(
                '${LocationUtils.translate('... and')} ${orders.length - 5} ${LocationUtils.translate('more orders')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('Close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualInputDialog();
            },
            child: Text(LocationUtils.translate('Manual Input')),
          ),
        ],
      ),
    );
  }

  /// 显示订单详情对话框
  void _showOrderDetailDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocationUtils.translate('Order Details')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 订单基本信息
              _buildOrderInfoRow(LocationUtils.translate('Order Number'), order.orderNumber),
              _buildOrderInfoRow('User ID', order.userId),
              _buildOrderInfoRow(LocationUtils.translate('Status'), order.getStatusText()),
              _buildOrderInfoRow(LocationUtils.translate('Total Amount'), '\$${order.totalAmount.toStringAsFixed(2)}'),
              _buildOrderInfoRow(LocationUtils.translate('Items Count'), '${order.items.length} items'),
              _buildOrderInfoRow(LocationUtils.translate('Order Time'), _formatDateTime(order.createdAt)),
              
              SizedBox(height: 16.h),
              
              // 商品列表
              if (order.items.isNotEmpty) ...[
                Text(
                  'Items:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                ...order.items.map((item) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  child: Text(LocationUtils.translate('• ${item.productName} x${item.quantity}')),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(LocationUtils.translate('Cancel')),
          ),
          if (order.status == OrderStatus.readyForPickup)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _completeOrder(context, order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: Text(LocationUtils.translate('Complete Order')),
            ),
        ],
      ),
    );
  }

  /// 构建订单信息行
  Widget _buildOrderInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 完成订单
  void _completeOrder(BuildContext context, Order order) async {
    try {
      // 显示等待对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(LocationUtils.translate('Completing Order')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
              SizedBox(height: 16.h),
              Text(LocationUtils.translate('Please wait while we complete order #${order.orderNumber}...')),
            ],
          ),
        ),
      );

      // 完成并移除订单
      bool success = await UnifiedOrderService.completeAndRemoveOrder(order);
      
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
      
       if (context.mounted) {
          if (success) {
        // 显示底部消息提示
        _showSuccessSnackBar(context, '${LocationUtils.translate('Order')} #${order.orderNumber} ${LocationUtils.translate('completed successfully!')}');
      } else {
       
          _showErrorSnackBar(context, '${LocationUtils.translate('Failed to complete order')}. ${LocationUtils.translate('Please try again.')}');
       
      }
       }
    
    } catch (e) {
        Debug.log('Error completing order: $e');
    }
  }

  /// 显示成功消息提示
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// 显示错误消息提示
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// 显示错误信息
  void _showError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('error')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('OK')),
          ),
        ],
      ),
    );
  }

  /// 清空临时订单文件
  Future<void> _clearTempOrders() async {
    if (!mounted) return;
    
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24.w),
            SizedBox(width: 8.w),
            Text(LocationUtils.translate('Confirm Delete')),
          ],
        ),
        content: Text(
          LocationUtils.translate('Are you sure you want to delete all temporary order files? This action cannot be undone.'),
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocationUtils.translate('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: Text(LocationUtils.translate('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
            SizedBox(width: 16.w),
            Text(
              LocationUtils.translate('Deleting temporary order files...'),
              style: TextStyle(fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );

    try {
      // 删除所有临时订单文件
      int deletedCount = await FileUtils.clearTempOrders();
      
      if (!mounted) return;
      Navigator.pop(context);

      // 刷新订单列表
      OrderMonitorService.instance.refreshOrders();

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${LocationUtils.translate('Deleted')} $deletedCount ${LocationUtils.translate('temporary order files')}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      
      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${LocationUtils.translate('Failed to delete temporary order files')}: $e',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[600],
          duration: Duration(seconds: 3),
        ),
      );
      Debug.log('删除临时订单文件失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 订单搜索栏
        _buildOrderSearchBar(),
        // 订单状态筛选
        _buildOrderStatusFilter(),

        // 订单列表
        Expanded(
          child: _buildOrderList(),
        ),
      ],
    );
  }

  /// 构建订单搜索栏
  Widget _buildOrderSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          // 扫描按钮
          Container(
            margin: EdgeInsets.only(right: 8.w),
            child: ElevatedButton.icon(
              onPressed: _scanOrder,
              icon: Icon(
                Icons.qr_code_scanner,
                size: 16.w,
                color: Colors.white,
              ),
              label: TranslateText(
                'Scan',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                minimumSize: Size(0, 40.h), // 设置最小高度
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                elevation: 1,
              ),
            ),
          ),
          // 订单总数量显示
          Obx(() {
            final orderService = OrderMonitorService.instance;
            final orders = orderService.orders;
            return Container(
              height: 40.h, // 设置固定高度与按钮一致
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20.r), // 与按钮圆角一致
              ),
              child: Center(
                child: Text(
                  '${LocationUtils.translate('OrderNum')}:${orders.length}',
                  style: TextStyle(
                    fontSize: 12.sp, // 与按钮文字大小一致
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
          SizedBox(width: 8.w),
          // 搜索框
          Expanded(
            child: SizedBox(
              height: 40.h, // 设置固定高度与其他元素一致
              child: TextField(
                controller: _orderSearchController,
                decoration: InputDecoration(
                  hintText: LocationUtils.translate('Search orders...'),
                  hintStyle: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                    size: 16.w,
                  ),
                  suffixIcon: _orderSearchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _orderSearchController.clear();
                            _searchOrders('');
                          },
                          child: Icon(
                            Icons.clear,
                            color: Colors.grey[400],
                            size: 16.w,
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true, // 减少内部padding
                ),
                onChanged: _searchOrders,
              ),
            ),
          ),
          // 刷新按钮
          Container(
            margin: EdgeInsets.only(left: 8.w),
            child: ElevatedButton.icon(
              onPressed: () {
                // 刷新订单数据
                OrderMonitorService.instance.refreshOrders();
              },
              icon: Icon(Icons.refresh, size: 16.w),
              label: TranslateText(
                'Refresh',
                style: TextStyle(fontSize: 12.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                minimumSize: Size(0, 40.h), // 设置最小高度
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
            ),
          ),
          // 测试模式下显示删除临时订单按钮
          if (ConfigService.isTest)
            Container(
              margin: EdgeInsets.only(left: 8.w),
              child: ElevatedButton.icon(
                onPressed: () => _clearTempOrders(),
                icon: Icon(Icons.delete_sweep, size: 16.w),
                label: TranslateText(
                  'Clear All',
                  style: TextStyle(fontSize: 12.sp),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  minimumSize: Size(0, 40.h), // 设置最小高度
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建订单状态筛选
  Widget _buildOrderStatusFilter() {
    return Container(
      height: 40.h,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _orderStatusFilters.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedOrderStatusIndex;
          return Container(
            margin: EdgeInsets.only(right: 6.w),
            child: ElevatedButton(
              onPressed: () {
                _filterOrdersByStatus(index);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected 
                    ? AppTheme.primaryBlue 
                    : Colors.white,
                foregroundColor: isSelected 
                    ? Colors.white 
                    : AppTheme.primaryBlue,
                elevation: isSelected ? 1 : 0,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Text(
                 LocationUtils.translate(_orderStatusFilters[index]),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  /// 构建订单列表
  Widget _buildOrderList() {
    return Obx(() {
      // 直接从OrderMonitorService获取最新订单
      final orderService = OrderMonitorService.instance;
      final allOrders = orderService.orders; // 获取所有订单
      
      // 应用搜索过滤
      List<Order> filteredOrders = allOrders.where((order) {
        if (_orderSearchQuery.isEmpty) return true;
        
        // 搜索订单号
        if (order.orderNumber.toLowerCase().contains(_orderSearchQuery.toLowerCase())) {
          return true;
        }
        
        // 搜索用户ID
        if (order.userId.toLowerCase().contains(_orderSearchQuery.toLowerCase())) {
          return true;
        }
        
        // 搜索商品名称
        for (var item in order.items) {
          if (item.productName.toLowerCase().contains(_orderSearchQuery.toLowerCase())) {
            return true;
          }
        }
        
        // 搜索备注
        if (order.notes != null && order.notes!.toLowerCase().contains(_orderSearchQuery.toLowerCase())) {
          return true;
        }
        
        return false;
      }).toList();
      
      // 应用状态筛选
      if (_selectedOrderStatusIndex > 0) {
        final statusFilter = _orderStatusFilters[_selectedOrderStatusIndex];
        filteredOrders = filteredOrders.where((order) {
          switch (statusFilter) {
            case 'Pending Payment':
              return order.status == OrderStatus.pending;
            case 'Paid':
              return order.status == OrderStatus.paid;
            case 'Processing':
              return order.status == OrderStatus.processing;
            case 'Ready for Pickup':
              return order.status == OrderStatus.readyForPickup;
            case 'Out for Delivery':
              return order.status == OrderStatus.outForDelivery;
            default:
              return true;
          }
        }).toList();
      }
      
      if (filteredOrders.isEmpty) {
        return SizedBox(
          height: 200.h,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64.w,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16.h),
                Text(
                  allOrders.isEmpty ? 'No order data' : 'No orders match your search',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 检测屏幕宽度，决定使用单列还是网格布局
   
      final isWideScreen = AppScreenUtil.isLandscape(context);
      
        if (isWideScreen) {
          // 宽屏模式：使用自适应高度布局
          return LayoutBuilder(
            builder: (context, constraints) {
              // 计算容器可用宽度（减去padding）
              final availableWidth = constraints.maxWidth - (_LayoutConstants.containerPadding * 2).w;
              
              // 计算每行能放多少个卡片的默认宽度
              final cardsPerRow = (availableWidth / _LayoutConstants.defaultCardWidth.w).floor();
              
              // 计算实际卡片宽度
              final cardWidth = cardsPerRow > 0 
                ? (availableWidth - (cardsPerRow - 1) * _LayoutConstants.cardSpacing.w * 4) / cardsPerRow
                : _LayoutConstants.defaultCardWidth.w;
              
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: _LayoutConstants.containerLeftPadding.w ,  // 使用专用左侧间距常量
                  right: _LayoutConstants.containerPadding.w,
                  top: _LayoutConstants.containerPadding.w,
                  bottom: _LayoutConstants.containerPadding.w,
                ),
                child: _buildGridLayout(filteredOrders, cardWidth),
              );
            },
          );
        } else {
        // 窄屏模式：使用列表布局
        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 0.h),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index];
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: _buildAdminOrderCard(order, isWideScreen: false),
            );
          },
        );
      }
    });
  }

  /// 构建网格布局（左上对齐）
  Widget _buildGridLayout(List<Order> orders, double cardWidth) {
    if (orders.isEmpty) return SizedBox.shrink();
    
    // 计算每行能放多少个卡片
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (_LayoutConstants.containerPadding * 2).w; // 减去padding
    final cardsPerRow = (availableWidth / cardWidth).floor();
    
    List<Widget> rows = [];
    
    for (int i = 0; i < orders.length; i += cardsPerRow) {
      List<Widget> rowChildren = [];
      
      for (int j = 0; j < cardsPerRow && (i + j) < orders.length; j++) {
        rowChildren.add(
          SizedBox(
            width: cardWidth,
            child: _buildAdminOrderCard(orders[i + j], isWideScreen: true),
          ),
        );
        
        // 添加水平间距（除了最后一个）
        if (j < cardsPerRow - 1 && (i + j + 1) < orders.length) {
          rowChildren.add(SizedBox(width: _LayoutConstants.cardSpacing.w));
        }
      }
      
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        ),
      );
      
      // 添加垂直间距（除了最后一行）
      if (i + cardsPerRow < orders.length) {
        rows.add(SizedBox(height: _LayoutConstants.cardRunSpacing.h));
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  /// 构建管理用订单卡片
  Widget _buildAdminOrderCard(Order order, {bool isWideScreen = false}) {
    return Card(
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha:0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(isWideScreen ? 16.w : 12.w),
        child: isWideScreen 
          ? _buildWideScreenCard(order)
          : _buildNarrowScreenCard(order),
      ),
    );
  }

  /// 构建宽屏模式下的订单卡片
  Widget _buildWideScreenCard(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：订单号和状态
        Row(
          children: [
            Expanded(
              child: Text(
                '${LocationUtils.translate('Order')}: ${order.orderNumber}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _getOrderStatusColor(order.status).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                order.getStatusText(),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: _getOrderStatusColor(order.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12.h),
        
        // 第二行：内容按垂直布局 - 订单数量、单价、总价、时间
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：订单数量和单价
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${LocationUtils.translate('Items')}: ',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${order.items.length}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${LocationUtils.translate('Unit Price')}: ',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${shopService.shop.value.symbol.value}${(order.totalAmount / order.items.fold(0, (sum, item) => sum + item.quantity)).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8.h),
            
            // 第二行：总价和时间
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${LocationUtils.translate('Total')}: ',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${shopService.shop.value.symbol.value}${order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${LocationUtils.translate('Time')}: ',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _formatDateTime(order.createdAt),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // 备注（始终显示）
            SizedBox(height: 8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.note_outlined,
                  size: 14.w,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    '${LocationUtils.translate('Notes')}: ${order.notes != null && order.notes!.isNotEmpty ? order.notes! : LocationUtils.translate('None')}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        SizedBox(height: 12.h),
        
        // 第三行：操作按钮
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4.w,
          runSpacing: 4.h,
          children: _buildOrderActionButtons(order, isWideScreen: true),
        ),
      ],
    );
  }

  /// 构建窄屏模式下的订单卡片
  Widget _buildNarrowScreenCard(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 订单头部信息
        Row(
          children: [
            Expanded(
              child: Text(
                '${LocationUtils.translate('Order Number')}: ${order.orderNumber}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: _getOrderStatusColor(order.status).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
               order.getStatusText(),
                style: TextStyle(
                  fontSize: 10.sp,
                  color: _getOrderStatusColor(order.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        
        // 订单商品信息
        ...order.items.take(2).map((item) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 1.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: TextStyle(fontSize: 11.sp),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  ' x${item.quantity}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '${shopService.shop.value.symbol.value}${item.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          );
        }),
        
        if (order.items.length > 2)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 1.h),
            child: Text(
              '... and ${order.items.length - 2} ${LocationUtils.translate('more items')}',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[500],
              ),
            ),
          ),
        
        // 订单备注（始终显示）
        SizedBox(height: 4.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.note_outlined,
              size: 12.w,
              color: Colors.grey[500],
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                '${LocationUtils.translate('Notes')}: ${order.notes != null && order.notes!.isNotEmpty ? order.notes! : LocationUtils.translate('None')}',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 6.h),
        
        // 订单金额和支付方式
        Row(
          children: [
            Expanded(
              child: Text(
                LocationUtils.translate(LocationUtils.translate('Total')),
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${shopService.shop.value.symbol.value}${order.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 4.h),
        
        // 订单时间
        Text(
          _formatDateTime(order.createdAt),
          style: TextStyle(
            fontSize: 9.sp,
            color: Colors.grey[500],
          ),
        ),
        
        SizedBox(height: 8.h),
        
        // 操作按钮
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4.w,
          runSpacing: 3.h,
          children: _buildOrderActionButtons(order, isWideScreen: false),
        ),
      ],
    );
  }

  /// 构建订单操作按钮
  List<Widget> _buildOrderActionButtons(Order order, {bool isWideScreen = false}) {
    List<Widget> buttons = [];
    
    // 主要操作按钮
    if (order.status == OrderStatus.pending) {
      buttons.addAll([
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(order, OrderStatus.paid),
          icon: Icon(Icons.check_circle, size: isWideScreen ? 16.w : 16.w),
          label: Text(LocationUtils.translate('Confirm Payment'), style: TextStyle(fontSize:10.sp)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 12.w : 8.w, vertical: isWideScreen ? 8.h : 4.h),
            minimumSize: Size(0, isWideScreen ? 32.h : 24.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(order, OrderStatus.cancelled),
          icon: Icon(Icons.cancel, size: isWideScreen ? 16.w : 12.w),
          label: Text(LocationUtils.translate('Cancel'), style: TextStyle(fontSize: 10.sp)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 12.w : 8.w, vertical: isWideScreen ? 8.h : 4.h),
            minimumSize: Size(0, isWideScreen ? 32.h : 24.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      ]);
    }
    
    if (order.status == OrderStatus.paid) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(order, OrderStatus.processing),
          icon: Icon(Icons.play_arrow, size: isWideScreen ? 16.w : 12.w),
          label: Text(LocationUtils.translate('Start Processing'), style: TextStyle(fontSize: isWideScreen ? 12.sp : 10.sp)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16.w : 8.w, vertical: isWideScreen ? 8.h : 4.h),
            minimumSize: Size(0, isWideScreen ? 32.h : 24.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      );
    }
    
    if (order.status == OrderStatus.processing) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(order, order.orderType == OrderType.dineIn 
              ? OrderStatus.readyForPickup 
              : OrderStatus.outForDelivery),
          icon: Icon(order.orderType == OrderType.dineIn ? Icons.restaurant : Icons.delivery_dining, size: isWideScreen ? 16.w : 12.w),
          label: Text(order.orderType == OrderType.dineIn ? LocationUtils.translate('Ready for Pickup') : LocationUtils.translate('Start Delivery'), style: TextStyle(fontSize: isWideScreen ? 12.sp : 10.sp)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16.w : 8.w, vertical: isWideScreen ? 8.h : 4.h),
            minimumSize: Size(0, isWideScreen ? 32.h : 24.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      );
    }
    
    if (order.status == OrderStatus.readyForPickup || order.status == OrderStatus.outForDelivery) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(order, OrderStatus.completed),
          icon: Icon(Icons.check_circle_outline, size: isWideScreen ? 16.w : 12.w),
          label: Text(LocationUtils.translate('Complete Order'), style: TextStyle(fontSize: isWideScreen ? 12.sp : 10.sp)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16.w : 8.w, vertical: isWideScreen ? 8.h : 4.h),
            minimumSize: Size(0, isWideScreen ? 32.h : 24.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      );
    }
    
    // 打印按钮
    buttons.add(
      ElevatedButton.icon(
        onPressed: () => _showPrintConfirmationDialog(context, order),
        icon: Icon(Icons.print, size: isWideScreen ? 16.w : 12.w),
        label: Text(LocationUtils.translate('Print'), style: TextStyle(fontSize: isWideScreen ? 12.sp : 10.sp)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16.w : 8.w, vertical: isWideScreen ? 8.h : 4.h),
          minimumSize: Size(0, isWideScreen ? 32.h : 24.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      ),
    );
    
    // 详情按钮
    buttons.add(
      ElevatedButton.icon(
        onPressed: () => _showOrderDetails(order),
        icon: Icon(Icons.info_outline, size: isWideScreen ? 16.w : 12.w),
        label: Text(LocationUtils.translate('Details'), style: TextStyle(fontSize: isWideScreen ? 12.sp : 10.sp)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[600],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16.w : 8.w, vertical: isWideScreen ? 8.h : 4.h),
          minimumSize: Size(0, isWideScreen ? 32.h : 24.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      ),
    );
    
    return buttons;
  }

  /// 获取订单状态颜色
  Color _getOrderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.paid:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.purple;
      case OrderStatus.readyForPickup:
        return Colors.amber;
      case OrderStatus.outForDelivery:
        return Colors.cyan;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.grey;
      case OrderStatus.timeout:
         return Colors.grey;
    }
  }


  /// 更新订单状态
  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    if (!mounted) return;
    
    final orderMonitorService = OrderMonitorService.instance;  

    // 显示加载弹窗
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20.w,
              height: 20.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            ),
            SizedBox(width: 16.w),
            Text(
              'Updating order status...',
              style: TextStyle(fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
    }
    // 等待更新完成
    await orderMonitorService.waitForUpdateComplete();
    
    try {
      final success = await UnifiedOrderService.updateOrderStatus(
        order.id,
        newStatus,
      );

      if (mounted) {
        Get.until((route) => route.isFirst);
        if (success) {
          // 显示成功消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocationUtils.translate('Order status updated successfully')),
              backgroundColor: Colors.green[600],
            ),
          );
        } else {
          // 显示失败消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocationUtils.translate('Failed to update order status, please try again')),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    } catch (e) {
      // 关闭加载弹窗
      if (mounted) {
        Navigator.pop(context);
        
        // 显示错误消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocationUtils.translate('Update failed: \$e')),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  /// 显示订单详情
  void _showOrderDetails(Order order) {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Order Details')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${LocationUtils.translate('Order Number')}: ${order.orderNumber}'),
              Text('${LocationUtils.translate('User ID')}: ${order.userId}'),
              Text('${LocationUtils.translate('Status')}: ${order.getStatusText()}'),
              Text('${LocationUtils.translate('Created At')}: ${_formatDateTime(order.createdAt)}'),
         
              Text('${LocationUtils.translate('Updated At')}: ${_formatDateTime(order.updatedAt)}'),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text('${LocationUtils.translate('Notes')}: ${order.notes}', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
              SizedBox(height: 16.h),
              Text(LocationUtils.translate('Product List:'), style: TextStyle(fontWeight: FontWeight.bold)),
              ...order.items.map((item) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(LocationUtils.translate('${item.productName} x${item.quantity}')),
                    Text(LocationUtils.translate('${shopService.shop.value.symbol.value}${item.subtotal.toStringAsFixed(2)}'))
                     ,
                    ],
                  ),
                );
              }),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(LocationUtils.translate('Subtotal:')),
                   Text(LocationUtils.translate('${shopService.shop.value.symbol.value}${order.subtotal.toStringAsFixed(2)}'))
                ,
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(LocationUtils.translate('Delivery Fee:')),
               Text(LocationUtils.translate('${shopService.shop.value.symbol.value}${order.shippingFee.toStringAsFixed(2)}'))
                ],
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(LocationUtils.translate('Total:'), style: TextStyle(fontWeight: FontWeight.bold)),
                 Text('${shopService.shop.value.symbol.value}${order.totalAmount.toStringAsFixed(2)}', 
                       style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[600]))
                ],
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          TextButton(
            onPressed: () => _showPrintConfirmationDialog(context, order),
            child: Text(LocationUtils.translate('Print')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('Close')),
          ),
        ],
      ),
    );
  }

  /// 显示打印确认对话框
  void _showPrintConfirmationDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.print, color: AppTheme.primaryBlue, size: 24.w),
            SizedBox(width: 8.w),
            Text(LocationUtils.translate('Print Order')),
          ],
        ),
        content: Text(
          '${LocationUtils.translate('Do you want to print this order')}? (${order.orderNumber})',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(LocationUtils.translate('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _handlePrintOrder(context, order);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(LocationUtils.translate('Confirm')),
          ),
        ],
      ),
    );
  }

  /// 处理打印订单
  Future<void> _handlePrintOrder(BuildContext context, Order order) async {
    try {
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
              SizedBox(width: 16.w),
              Text(
                LocationUtils.translate('Printing order...'),
                style: TextStyle(fontSize: 14.sp),
              ),
            ],
          ),
        ),
      );

      // 调用打印服务
      await UnifiedOrderService.pushPrintOrder(order);

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.pop(context);
        
        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '${LocationUtils.translate('Order')} ${order.orderNumber} ${LocationUtils.translate('print request sent successfully')}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) {
        Navigator.pop(context);
        
        // 显示错误消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '${LocationUtils.translate('Failed to print order')}: $e',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: Duration(seconds: 3),
          ),
        );
      }
      Debug.log('打印订单失败: $e');
    }
  }

}