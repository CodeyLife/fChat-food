import 'dart:async';
import 'package:fchatapi/util/JsonUtil.dart';

import '../models/user_info.dart';
import '../services/user_service.dart';
import 'package:get/get.dart';
import '../models/order.dart';
import '../utils/debug.dart';
import '../utils/location.dart';
import 'unified_order_service.dart';
import 'package:fchatapi/appapi/AppStorageApi.dart';
import 'package:fchatapi/webapi/StripeUtil/WebPayUtil.dart';
import 'payment_callback_service.dart';

/// 订单监控服务
/// 负责定时获取订单并检测变化，提供全局订单状态管理
class OrderMonitorService extends GetxController {
  /// 获取OrderMonitorService实例
  static OrderMonitorService get instance => Get.find<OrderMonitorService>();

  // 统一的响应式订单列表 - 唯一数据源
  final RxList<Order> _orders = <Order>[].obs; // 统一的订单列表
  final RxBool ismodify = false.obs;
  final RxBool _hasNewOrders = false.obs;
  final RxBool _hasOrderStatusChanges = false.obs;
  final RxBool _isUpdatingOrders = false.obs; // 是否正在更新订单
  final RxBool _isInitialized = false.obs; // 是否已初始化
  
  // 待验证订单的定时器管理
  final Map<String, Timer> _verificationTimers = {}; // paymentId 到定时器的映射
  final Map<String, Order> _pendingVerificationOrders = {}; // paymentId 到订单对象的映射

  /// 是否有新订单
  bool get hasNewOrders => _hasNewOrders.value;
  
  /// 是否有订单状态变化
  bool get hasOrderStatusChanges => _hasOrderStatusChanges.value;
  
  /// 是否有任何订单变化（新订单或状态变化）
  bool get hasAnyOrderChanges => _hasNewOrders.value || _hasOrderStatusChanges.value;
  
  /// 是否正在更新订单
  bool get isUpdatingOrders => _isUpdatingOrders.value;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized.value;
  
@override onInit() {
  super.onInit();
  initialize();
}

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized.value) return;
    await initOrders();
  
  }

  Future<void> initOrders()async{
    _orders.clear();
                  // 等待用户服务初始化完成
      await _waitForUserReady();
    var orders = await loadAllOrders();
      var user = UserService.instance.currentUser!;
       if(!user.isAdmin()){
          //不是管理员 ，剔除非用户订单
          orders = orders.where((order) => order.userId == user.userId).toList();
       }
    _orders.assignAll(orders);
    _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _orders.refresh();
     _isInitialized.value = true;
    update();
    
    // 初始化完成后，执行启动时验证
    verifyAllCachedOrders();
  }

  /// 等待用户服务准备就绪
  Future<void> _waitForUserReady() async {

    while (UserService.instance.currentUser == null) {

      // 等待一段时间后再次检查
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// 加载所有订单（仅返回，不修改_orders）
  Future<List<Order>> loadAllOrders() async {
    try {
      final orders = await UnifiedOrderService.loadAllOrders();
      Debug.log('成功加载 ${orders.length} 个订单');
      return orders;
    } catch (e) {
      Debug.log('加载订单失败: $e');
      rethrow;
    }
  }
  
  /// 判断订单是否已创建 ，存在则返回true，不存在则返回false
  Future<bool> isOrderCreated(Order order)
  async {
    await refreshOrders();
    return _orders.any((o) => o.id == order.id);
  }

  void addOrder(Order order){
    _orders.add(order);
    // 添加后重新排序，确保按创建时间排序
    _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 最新的在前
    _orders.refresh();
    update();
  }
  
  void removeOrder(Order order){
    _orders.removeWhere((o) => o.id == order.id);
    _orders.refresh();
    update();
  }
  void updateOrder(Order order){
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _orders[index] = order;  // 替换整个订单对象
       _orders.refresh();
       update();
    }else{
      addOrder(order);
      
    }
   
  
  }

  void appSave(Order order){
    AppStorageApi("app_order",order.paymentId!,JsonUtil.maptostr(order.toJson())).save((value){
      Debug.log('订单保存app成功: ${order.orderNumber} -> $value');
    });
  }
  Future<Order?> appRead(String paymentId) async {
    final completer = Completer<Order?>();
    bool isCompleted = false;
    
    AppStorageApi("app_order",paymentId,"").read((value){
      if (isCompleted) return; // 防止重复处理
      
      try {
        Debug.log('订单读取app成功: $value');
        
        // 解析返回的 JSON 字符串
        if (value.isEmpty) {
          Debug.log('订单读取app失败: value为空');
          if (!completer.isCompleted) {
            completer.complete(null);
            isCompleted = true;
          }
          return;
        }
        
        // 第一步：解析外层 JSON，获取 paymentId 对应的值
        Map<String, dynamic> storageMap = Map<String, dynamic>.from(JsonUtil.strtoMap(value));
        
        // 第二步：根据 paymentId 获取对应的转义后的订单 JSON 字符串
        if (!storageMap.containsKey(paymentId)) {
          Debug.log('订单读取app失败: 未找到对应的paymentId: $paymentId');
          if (!completer.isCompleted) {
            completer.complete(null);
            isCompleted = true;
          }
          return;
        }
        
        String escapedOrderJson = storageMap[paymentId] as String;
        if (escapedOrderJson.isEmpty) {
          Debug.log('订单读取app失败: paymentId对应的值为空');
          if (!completer.isCompleted) {
            completer.complete(null);
            isCompleted = true;
          }
          return;
        }
        
        // 第三步：解析转义后的订单 JSON 字符串
        Map<String, dynamic> orderData = Map<String, dynamic>.from(JsonUtil.strtoMap(escapedOrderJson));
        
        // 第四步：创建订单对象
        Order order = Order.fromJson(orderData);
        
        Debug.log('订单解析成功: ${order.orderNumber}, paymentId: ${order.paymentId}');
        
        // 完成 Future 并返回订单对象
        if (!completer.isCompleted) {
          completer.complete(order);
          isCompleted = true;
        }
        
      } catch (e) {
        Debug.logError('订单读取app解析失败', e);
        if (!completer.isCompleted) {
          completer.completeError(e);
          isCompleted = true;
        }
      }
    });
    
    return completer.future;
  }
  
  /// 读取所有缓存的订单数据，获取所有的 paymentId
  Future<Map<String, Order>> appReadAll() async {
    final completer = Completer<Map<String, Order>>();
    bool isCompleted = false;
    
    // 传入空的 paymentId 来读取所有数据
    AppStorageApi("app_order", "", "").read((value) {
      if (isCompleted) return;
      
      try {
        // Debug.log('读取所有缓存订单: $value');

        // 解析外层 JSON，获取所有 paymentId 和对应的订单数据
        Map<String, dynamic> storageMap = Map<String, dynamic>.from(JsonUtil.strtoMap(value));
        
        Map<String, Order> ordersMap = {};
        
        // 遍历所有 paymentId
        for (String paymentId in storageMap.keys) {
          if(paymentId == "status"){
            continue;
          }
          try {
            String escapedOrderJson = storageMap[paymentId] as String;
            if (escapedOrderJson.isEmpty) {
              Debug.log('paymentId $paymentId 对应的值为空，跳过');
              continue;
            }
            
            // 解析转义后的订单 JSON 字符串
            Map<String, dynamic> orderData = Map<String, dynamic>.from(JsonUtil.strtoMap(escapedOrderJson));
            
            // 创建订单对象
            Order order = Order.fromJson(orderData);
            ordersMap[paymentId] = order;
            
            Debug.log('成功解析订单: ${order.id}, paymentId: $paymentId');
          } catch (e) {
            Debug.logError('解析 paymentId $paymentId 的订单失败', e);
          }
        }
        
        if (!completer.isCompleted) {
          completer.complete(ordersMap);
          isCompleted = true;
        }
      } catch (e) {
        Debug.logError('读取所有缓存订单失败', e);
        if (!completer.isCompleted) {
          completer.complete({});
          isCompleted = true;
        }
      }
    });
    
    return completer.future;
  }
  
  void appDelete(String paymentId){
    AppStorageApi("app_order",paymentId,"").delfile((value){
      Debug.log('订单删除app成功: $value');
    });
  }
  
  /// 启动订单支付验证
  /// [paymentId] 支付ID
  /// [order] 订单对象
  void startPaymentVerification(String paymentId, Order order) {
    // 如果已经在验证中，先停止旧的验证
    if (_verificationTimers.containsKey(paymentId)) {
      Debug.log('paymentId $paymentId 已经在验证中，先停止旧验证');
      stopPaymentVerification(paymentId);
    }
    
    // 保存订单信息
    _pendingVerificationOrders[paymentId] = order;
    
    Debug.log('启动订单支付验证: paymentId=$paymentId, orderId=${order.id}');
    
    // 创建定时器，每30秒验证一次
    final timer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      await _performVerification(paymentId, timer);
    });
    
    _verificationTimers[paymentId] = timer;
    
    // 立即执行一次验证
    _performVerification(paymentId, timer);
  }
  
  /// 停止订单支付验证
  /// [paymentId] 支付ID
  void stopPaymentVerification(String paymentId) {
    final timer = _verificationTimers.remove(paymentId);
    if (timer != null) {
      timer.cancel();
      Debug.log('停止订单支付验证: paymentId=$paymentId');
    }
    
    _pendingVerificationOrders.remove(paymentId);
  }
  
  /// 处理支付验证结果
  /// [order] 订单对象
  /// [paymentId] 支付ID
  /// [verifyPayObj] 验证结果
  /// [shouldStopVerification] 是否停止定时验证（用于定时验证场景）
  Future<void> _handleVerificationResult(Order order, String paymentId, VerifyPayObj verifyPayObj, {bool shouldStopVerification = false}) async {
    if (verifyPayObj.ispay) {
      // 验证成功
      Debug.log('订单支付验证成功: paymentId=$paymentId, orderId=${order.id}');
      
      // 如果需要停止定时验证
      if (shouldStopVerification) {
        stopPaymentVerification(paymentId);
      }
      
      // 检查订单是否在订单列表中
      final orderExists = _orders.any((o) => o.id == order.id || o.paymentId == paymentId);
      
      if (!orderExists) {
        // 订单不在列表中，需要创建订单
        Debug.log('订单不在列表中，开始创建订单: orderId=${order.id}');
        
        try {

          order.status = OrderStatus.paid;
          order.paymentId = paymentId;
          
          // 创建订单
           bool success = await UnifiedOrderService.addOrder(order);
           if(success){
              // 调用支付成功回调
            final userService = UserService.instance;
            await PaymentCallbackService.handlePaymentSuccess(
              order: order,
              isNewOrder: true,
              cartController: null,
              userService: userService,
              shouldClearCart: false,
            );
            
            // 推送订单消息
            UnifiedOrderService.pushOrder(order, OrderPushType.newOrder);
          
          } else {
            Debug.logError('订单创建失败', 'filename is null or empty');
          }
        } catch (e) {
          Debug.logError('处理验证成功的订单失败', e);
        }
      } else {
        Debug.log('订单已在列表中，无需创建: orderId=${order.id}');
      }
      
      // 清理缓存
      appDelete(paymentId);
    } else {
      // 验证失败，检查订单是否超时（超过10分钟）
      final now = DateTime.now();
      final timeDiff = now.difference(order.createdAt);
      Debug.log('订单支付验证失败或未支付: paymentId=$paymentId, orderId=${order.id}');
      
      if (timeDiff.inMinutes >= 10) {
        Debug.log('订单支付验证失败且超过10分钟，判定支付失败并移除: paymentId=$paymentId, orderId=${order.id}');
        appDelete(paymentId);
        if (shouldStopVerification) {
          stopPaymentVerification(paymentId);
        }
      } else {
        // 验证失败但未超时，继续等待下次验证
        Debug.log('订单支付验证失败，继续等待: paymentId=$paymentId, orderId=${order.id},剩余时间: ${ 600 -timeDiff.inSeconds}秒钟');
      }
    }
  }
  
  /// 执行支付验证
  /// [paymentId] 支付ID
  /// [timer] 定时器对象
  Future<void> _performVerification(String paymentId, Timer timer) async {
    try {
      final order = _pendingVerificationOrders[paymentId];
      if (order == null) {
        Debug.log('订单不存在，停止验证: paymentId=$paymentId');
        stopPaymentVerification(paymentId);
        return;
      }
      
      // 验证支付状态
      VerifyPayObj verifyPayObj = await verifyPaymentId(paymentId);
      
      // 处理验证结果（需要停止定时验证）
      await _handleVerificationResult(order, paymentId, verifyPayObj, shouldStopVerification: true);
    } catch (e) {
      Debug.logError('执行支付验证失败: paymentId=$paymentId', e);
    }
  }
  
  /// 验证单个 paymentId 的支付状态
  /// [paymentId] 支付ID
  /// 返回验证结果，包含 ispay 字段
  Future<VerifyPayObj> verifyPaymentId(String paymentId) async {
    try {
      Debug.log('开始验证支付: $paymentId');
      VerifyPayObj verifyPayObj = await WebPayUtil.isverifyPay("", paymentId);
      Debug.log('支付验证结果: paymentId=${verifyPayObj.payid}, ispay=${verifyPayObj.ispay}');
      return verifyPayObj;
    } catch (e) {
      Debug.logError('验证支付失败: $paymentId', e);
      // 返回一个默认的验证对象，表示验证失败
      VerifyPayObj verifyPayObj = VerifyPayObj();
      verifyPayObj.payid = paymentId;
      verifyPayObj.ispay = false;
      return verifyPayObj;
    }
  }
  
  /// 验证所有缓存的订单支付状态（启动时调用）
  /// 读取所有缓存的订单，对每个 paymentId 进行验证，并处理验证结果
  Future<void> verifyAllCachedOrders() async {
    try {
      Debug.log('开始验证所有缓存的订单支付状态（启动时验证）');
      
      // 等待订单管理初始化完毕
      if (!_isInitialized.value) {
        Debug.log('订单管理尚未初始化，等待初始化完成');
        int waitCount = 0;
        while (!_isInitialized.value && waitCount < 100) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }
        if (!_isInitialized.value) {
          Debug.log('等待订单管理初始化超时');
          return;
        }
      }
      
      // 读取所有缓存的订单
      Map<String, Order> ordersMap = await appReadAll();
      
      if (ordersMap.isEmpty) {
        Debug.log('没有找到缓存的订单');
        return;
      }
      
      Debug.log('找到 ${ordersMap.length} 个缓存的订单，开始启动定时验证');
      
      // 对每个 paymentId 启动定时验证
      for (String paymentId in ordersMap.keys) {
        try {
          Order? order = ordersMap[paymentId];
          if (order == null ) {
            Debug.log('订单  为空，跳过: $paymentId');
            continue;
          }

          // 启动定时验证（使用与支付时相同的逻辑）
          startPaymentVerification(paymentId, order);
          
        } catch (e) {
          Debug.logError('启动订单定时验证失败: $paymentId', e);
           appDelete(paymentId);
        }
      }
      
      Debug.log('所有缓存的订单定时验证已启动');
    } catch (e) {
      Debug.logError('验证所有缓存订单失败', e);
    }
  }
  
  


/// 手动刷新订单
  Future<void> refreshOrders() async {
    Debug.showLoadingDialog(Get.context!, message: LocationUtils.translate('Refreshing orders...'));
     while(ismodify.value){
      await Future.delayed(const Duration(milliseconds: 100));
    }
     await _checkOrderChanges(UserService.instance.currentUser!);
     Get.until((route) => route.isFirst);
  }

  /// 同步订单列表（手动刷新时使用）
  /// 注意：订单变化通知由推送机制处理，这里只同步订单列表，不触发通知
  Future<void> _checkOrderChanges(UserInfo currentUser) async {
    // 1. 获取最新订单
    List<Order> currentOrders = await loadAllOrders();

    // 2. 根据用户角色过滤订单
    if (!currentUser.isAdmin()) {
      currentOrders = currentOrders.where((order) => order.userId == currentUser.userId).toList();
    }
    
    // 3. 更新订单列表并排序（不设置状态标志，不触发通知）
    _orders.assignAll(currentOrders);
    _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 最新的在前
    _orders.refresh();
    update();
  }
  


/// 设置订单状态变化的红点提示
/// [isNewOrder] 是否是新订单
  void setStateChange(bool isNewOrder){
    if(isNewOrder){
      _hasNewOrders.value = true;
    }else
    {
      _hasOrderStatusChanges.value = true;
    }
  }

  /// 获取订单列表（统一接口）
  RxList<Order> get orders => _orders;
  

  /// 清除新订单提醒
  void clearNewOrdersAlert() {
    _hasNewOrders.value = false;
  }

  /// 清除订单状态变化提醒
  void clearStatusChangesAlert() {
    _hasOrderStatusChanges.value = false;
  }

  /// 清除所有提醒
  void clearAllAlerts() {
    _hasNewOrders.value = false;
    _hasOrderStatusChanges.value = false;
  }

  /// 重置监控状态（用于用户切换或角色变化）
  void resetMonitoring() {
    _orders.clear();
    _hasNewOrders.value = false;
    _hasOrderStatusChanges.value = false;
    _isInitialized.value = false; // 重置初始化标志
    Debug.log('订单监控状态已重置');
  }


  /// 设置正在更新订单标志
  void setUpdatingOrders(bool isUpdating) {
    _isUpdatingOrders.value = isUpdating;
    Debug.log('设置更新订单标志: $isUpdating');
     update();
  }

  /// 等待更新完成
  Future<void> waitForUpdateComplete() async {
    while (_isUpdatingOrders.value) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

}
