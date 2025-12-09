
import '../main.dart';
import '../services/order_monitor_service.dart';
import '../services/shop_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../models/order.dart';

import '../services/app_state_service.dart';
import '../services/unified_order_service.dart';
import '../services/payment_service.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/debug.dart';
import '../utils/snackbar_utils.dart';

import '../utils/debouncer.dart';
import '../widgets/luckin_components.dart';
import 'qr_code_screen.dart';
import 'flappy_bird_game_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with TickerProviderStateMixin {
  // 搜索相关
  final RxString _searchQuery = ''.obs;
  final TextEditingController _searchController = TextEditingController();
  
  // 搜索防抖器
  late final Debouncer _searchDebouncer = Debouncer(delay: Duration(milliseconds: 300));
  // 加载防抖器
  late final Debouncer _loadDebouncer = Debouncer(delay: Duration(milliseconds: 100));
  
  // 防止重复加载
  final RxBool _isLoading = false.obs;

  // 保存 OrderMonitorService 引用
  OrderMonitorService? _orderMonitorService;
  
  // 流动进度条动画控制器
  late final AnimationController _flowingProgressController;

  @override
  void initState() {
    super.initState();
    // 初始化 OrderMonitorService
    _orderMonitorService = OrderMonitorService.instance;
    
    // 初始化流动进度条动画控制器
    _flowingProgressController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }
  

  @override
  void didChangeDependencies()  {
    super.didChangeDependencies();
    // 清除订单提醒
    _clearOrderAlerts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer.dispose();
    _loadDebouncer.dispose();
    _flowingProgressController.dispose();
    
    super.dispose();
  }



  /// 加载订单数据
  Future<void> _loadOrders({bool forceRefresh = false}) async {
    // 防止重复加载
    if (_isLoading.value && !forceRefresh) {
      return;
    }
    
    _isLoading.value = true;
    
    try {
      // 使用OrderMonitorService统一管理订单数据
      if (forceRefresh) {
        await _orderMonitorService!.refreshOrders();
      }
    } catch (e) {
      Debug.log('订单加载失败: $e');
      if (mounted) {
        try {
          _showError('加载订单失败: $e');
        } catch (error) {
          Debug.log('显示错误信息失败: $error');
        }
      }
    } finally {
      _isLoading.value = false;
    }
  }

  /// 搜索订单（使用防抖机制）
  Future<void> _searchOrders(String query) async {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchQuery.value = query;
        }
      });
    }
    
    _searchDebouncer.call(() async {
      if (!mounted) return;
      
      if (query.isEmpty) {
        // 搜索为空时，重新加载所有订单
        await _loadOrders();
        return;
      }
    });
  }
  
  /// 显示错误信息
  void _showError(String message) {
    if (mounted) {
      try {
        SnackBarUtils.showError(context, message);
      } catch (e) {
        // Widget 已经被销毁，忽略错误
        Debug.log('显示错误信息时出错: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body:
      Column(
            children: [
              // 顶部搜索栏
              _buildSearchBar(),
              // 订单列表
              Expanded(
                child: Obx(() {
                  final orderService = OrderMonitorService.instance;
                  final orders = orderService.orders;
              
                  if(orders.isEmpty){
                    return _buildEmptyOrders();
                  }
                 
                  // 如果没有订单，显示空状态
                  return _buildOrderList(_getOrders());
                }),
              ),
            ],
          ),
    );
  }
  
  List<Order> _getOrders() {
    final orderService = OrderMonitorService.instance;
    final orders = orderService.orders;
    final userService = Get.find<UserService>();
    if(userService.currentUser == null){
      return [];
    }else{
      return userService.isAdmin?  orders.where((order) => order.userId == userService.currentUser?.userId).toList():orders;
    }
  
  }
  
  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      color: AppTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: LocationUtils.translate('Search order number or product name...'),
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textHint,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.textHint,
                  size: 20.w,
                ),
                suffixIcon: Obx(() => _searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.textHint,
                          size: 20.w,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _searchOrders('');
                        },
                      )
                    : const SizedBox.shrink(),
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.xl,
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.xl,
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.xl,
                  borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                filled: true,
                fillColor: AppTheme.background,
              ),
              onChanged: _searchOrders,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          IconButton(
            onPressed: () => _loadOrders(forceRefresh: true),
            icon: Icon(
              Icons.refresh,
              color: AppTheme.primaryBlue,
              size: 24.w,
            ),
            tooltip: LocationUtils.translate('Refresh'),
          ),
          SizedBox(width: AppSpacing.xs),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FlappyBirdGameScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.sports_esports,
              color: AppTheme.primaryBlue,
              size: 24.w,
            ),
            tooltip: LocationUtils.translate('Play Game'),
          ),
        ],
      ),
    );
  }

  /// 构建订单列表
  Widget _buildOrderList(List<Order> orders) {
    // 处理搜索过滤
    List<Order> filteredOrders = orders;
    if (_searchQuery.value.isNotEmpty) {
      filteredOrders = orders.where((order) {
        return order.orderNumber.toLowerCase().contains(_searchQuery.value.toLowerCase()) ||
               order.items.any((item) => 
                 item.productName.toLowerCase().contains(_searchQuery.value.toLowerCase()));
      }).toList();
    }
    
    if (filteredOrders.isEmpty) {
      return _buildEmptyOrders();
    }

    return RefreshIndicator(
      onRefresh: () => _loadOrders(forceRefresh: true),
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 12.w,
          right: 12.w,
          top: 12.w,
          bottom: 12.w,
        ),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  /// 构建空订单页面
  Widget _buildEmptyOrders() {
    return LuckinEmptyState(
      icon: Icons.receipt_long_outlined,
      title: LocationUtils.translate('No Orders'),
      subtitle: LocationUtils.translate('Go shopping for your favorite products'),
      buttonText: LocationUtils.translate('Go Shopping'),
      onButtonTap: () {
        // 切换到菜单页面
        AppStateService().switchToPage(1);
      },
    );
  }

  /// 构建订单卡片
  Widget _buildOrderCard(Order order) {
    final isPending = order.status == OrderStatus.pending;
    
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppRadius.lg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(2, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 卡片内容
          Column(
            children: [
              // 订单头部
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    // 处理中提示（仅 pending 状态显示）
                    if (isPending)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                        margin: EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: AppRadius.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              LocationUtils.translate('Order is being processed'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // 订单号行
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${LocationUtils.translate('Order Number')}: ${order.orderNumber}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status).withValues(alpha:0.1),
                            borderRadius: AppRadius.sm,
                          ),
                          child: Text(
                            order.getStatusText(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _getStatusColor(order.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          
          // 商品列表
          ...order.items.map((item) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha:0.1),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(
                      Icons.local_cafe,
                      size: 24.w,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          '${LocationUtils.translate('Quantity')}: ${item.quantity}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                    '${ShopService.instance.shop.value.symbol.value}${item.subtotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentRed,
                    ),
                  )
                ,
                ],
              ),
            );
          }),
          
          // 订单备注
          if (order.notes != null && order.notes!.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 16.w,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${LocationUtils.translate('Notes')}: ${order.notes}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // 订单底部
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12.r),
                bottomRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${LocationUtils.translate('Total')} ${order.items.length} ${LocationUtils.translate('items')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${LocationUtils.translate('Total')}: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
               Text(
                      '${ShopService.symbol.value}${order.totalAmount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentRed,
                      ),
                    )
                  ,
                  ],
                ),
              ],
            ),
          ),
          
          // 待取餐状态的操作按钮
          if (order.status == OrderStatus.readyForPickup)
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showPickupQR(order),
                    icon: Icon(Icons.qr_code, size: 16.w),
                    label: Text(LocationUtils.translate('Show Pickup Code')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.sm,
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          // 流动进度条覆盖层（仅 pending 状态显示，覆盖整个卡片）
          if (isPending)
            Positioned.fill(
              child: _FlowingProgressBar(
                controller: _flowingProgressController,
                color: AppTheme.primaryBlue,
              ),
            ),
        ],
      ),
    );
  }

  /// 获取状态颜色
  Color _getStatusColor(OrderStatus status) {
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

  /// 取消订单
  void _cancelOrder(Order order) {
    // 显示确认弹窗
    showDialog(
      context: context,
      barrierDismissible: false, // 阻止点击外部关闭
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // 阻止返回键关闭
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.w),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade600,
                  size: 24.w,
                ),
                SizedBox(width: 8.w),
                Text(
                  LocationUtils.translate('Confirm Cancel Order'),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${LocationUtils.translate('Order Number')}: ${order.orderNumber}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  LocationUtils.translate('are you sure you want to cancel this order?'),
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  LocationUtils.translate('After cancellation, it cannot be recovered, please proceed with caution.'),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 关闭弹窗
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                ),
                child: Text(
                  LocationUtils.translate('Cancel'),
                  style: TextStyle(fontSize: 14.sp),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // 关闭弹窗
                  
                  // 显示处理中的弹窗
                  _showProcessingDialog();
                  
                  // 执行取消订单操作
                  var success = await UnifiedOrderService.cancelOrder(order);
                  
                  // 关闭处理中弹窗
                  Navigator.of(navigatorKey.currentContext!).pop();
                  
                  if (success) {

                    SnackBarUtils.showSuccess(LocationUtils.translate('Order Cancel Success'));
                  } else {
                    _showErrorMessage(LocationUtils.translate('Order Cancel Failed'));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.w),
                  ),
                ),
                child: Text(
                  'Confirm Cancel',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示处理中的弹窗
  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.w),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Processing...',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Please wait, do not close the page',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 显示错误消息
  void _showErrorMessage(String message) {
    SnackBarUtils.showErrorWithIcon(context, message);
  }

  /// 显示支付二维码
  void _showPaymentQR(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRCodeScreen(
          title: LocationUtils.translate('Order Payment'),
          data: order.orderNumber,
          type: QRCodeType.payment,
          extraData: {
            'amount': order.totalAmount,
          },
        ),
      ),
    );
  }

  /// 显示取餐码
  /// 使用订单的唯一ID (order.id) 生成二维码
  void _showPickupQR(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRCodeScreen(
          title: LocationUtils.translate('Pickup Code'),
          data: order.id, // 传递订单唯一ID
          type: QRCodeType.order,
          extraData: {
            'orderNumber': order.orderNumber, // 订单号仅用于显示
          },
        ),
      ),
    );
  }

  /// 支付订单
  void _payOrder(Order order) async {
    if (_orderMonitorService == null) {
      _showError('Order Monitor Service Not Initialized');
      return;
    }
    
    // 等待更新完成
    await _orderMonitorService!.waitForUpdateComplete();
    
    try {
      if(mounted){
      // 使用统一支付服务
      await PaymentService.processPayment(
        order: order,
        source: PaymentSource.orderPay,
          context: context,
          isFromCart: false,
        );
      }
    } catch (e) {
      _showError('支付失败: $e');
    }
  }

  /// 清除订单提醒
  void _clearOrderAlerts() {
    if (_orderMonitorService != null) {
      _orderMonitorService!.clearAllAlerts();
    }
  }

}

/// 流动进度条 Widget
/// 用于显示订单处理中的流动动画效果，覆盖整个卡片
class _FlowingProgressBar extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _FlowingProgressBar({
    required this.controller,
    this.color = AppTheme.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            final cardHeight = constraints.maxHeight;
            // 计算流动条的位置，使其从左到右循环流动
            final offsetX = (controller.value * 2 - 1) * cardWidth;
            
            return IgnorePointer(
              child: ClipRRect(
                borderRadius: AppRadius.lg,
                child: Stack(
                  children: [
                    // 流动的渐变层 - 覆盖整个卡片高度
                    Transform.translate(
                      offset: Offset(offsetX, 0),
                      child: Container(
                        width: cardWidth * 0.6,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              color.withValues(alpha: 0.15),
                              color.withValues(alpha: 0.3),
                              color.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
