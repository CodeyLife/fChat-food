import 'dart:async';
import 'package:fchat_food/utils/constants.dart';
import 'package:fchat_food/utils/file_utils.dart';
import '../utils/location.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fchatapi/appapi/PayObj.dart';
import 'package:fchatapi/util/JsonUtil.dart';
import '../models/payment.dart';
import '../models/order.dart';
import '../widgets/payment_processing_dialog.dart';
import 'navigation_service.dart';
import 'order_counter_service.dart';
import 'order_monitor_service.dart';
import 'unified_order_service.dart';
import 'payment_callback_service.dart';
import 'user_service.dart';
import 'shop_service.dart';
import '../screens/payment_screen.dart';
import '../utils/debug.dart';

/// 支付入口类型
enum PaymentSource {
  buyNow,      // 立即购买
  cart,        // 购物车结算
  orderPay,    // 订单立即支付
}

/// 统一支付服务
/// 整合所有支付入口的逻辑，提供统一的支付处理
/// 注意：实际支付功能已恢复，支持App支付和Web支付
/// 通过构造函数参数控制使用实际支付还是模拟支付
class PaymentService extends ChangeNotifier {


  /// 创建支付请求
  Future<PaymentResult> createPayment(PaymentRequest request, {BuildContext? context, Order? order}) async {
    try {
      
      // 不再在支付前创建订单，而是将订单信息传递给支付回调处理
      PaymentResult result;
       result = await _createAppPayment(request, order!);
      _showPaymentResultDialog(result);
      if(result.isSuccess){
        //这里的订单可能已经被更新了,所以需要重新读取订单
        await order.updateInService();
         if(order.orderNumber.isEmpty)
          {
            order.orderNumber = await OrderCounterService.instance.getNextOrderNumber();
          }
          if(order.status == OrderStatus.pending)
          {
            order.status = OrderStatus.paid;
          }
          OrderMonitorService.instance.updateOrder(order);
            //跳转到订单页面
          NavigationService.switchToOrdersPage();
        // 更新订单文件
          bool success = await FileUtils.updateOrderInTemp(order);
          if(success){
           //push订单消息
            unawaited(UnifiedOrderService.pushOrder(order, OrderPushType.newOrder));
          }
      
       
      }else
      {
        if( order.id.isNotEmpty){
           unawaited(FileUtils.deleteFile(AppConstants.tmporder, order.id));
        }
      }

      return result;
    } catch (e) {
      Debug.log('创建支付请求失败: $e');
      final result = PaymentResult(
        paymentId: '',
        status: PaymentStatus.failed,
        message: LocationUtils.translate('Failed to create payment request: \$e'),
      );
      
      // 显示支付结果弹窗
      _showPaymentResultDialog(result);
      
      return result;
    }
  }



  /// 创建App支付
  Future<PaymentResult> _createAppPayment(PaymentRequest request, Order order) async {
    try {

      // 创建FChat支付对象
       final map  = order.toJson();
       final payObj = PayObj(order:JsonUtil.maptostr(map));

      // FChat API期望amount为字符串（元为单位的小数）
      payObj.amount = request.amount.toStringAsFixed(2);
      payObj.paytext = request.description;
      order.paymentId = payObj.getPayid();
     //保存订单到服务器临时订单
      final orderCreated = await UnifiedOrderService.addOrder(order, generateOrderNumber: false);
      if(!orderCreated){
        return PaymentResult(
          paymentId: '',
          status: PaymentStatus.failed,
          message: LocationUtils.translate('Failed to create payment request: \$e'),
        );
      }
      // 使用Completer等待支付回调
      final completer = Completer<PaymentResult>();
    

            //先保存订单到app
      OrderMonitorService.instance.appSave(order);
     
      // 发起支付
      payObj.pay((value) async {
        try {
          Debug.log('收到App支付回调: $value');
          
          // 解析支付回调数据
          final Map<String, dynamic> recmap = JsonUtil.strtoMap(value);
          
          // 处理status字段：成功时为bool true，失败时为string
          final dynamic statusValue = recmap["status"];
          bool isSuccess = false;
          String? failureReason;
          
          if (statusValue is bool) {
            isSuccess = statusValue;
          } else if (statusValue is String) {
            // 失败时是字符串，记录失败原因
            isSuccess = false;
            failureReason = statusValue;
            Debug.log('支付失败，状态值: $statusValue');
          } else if (statusValue == null) {
            isSuccess = false;
            failureReason = 'status is null';
          }
          
          // 无论成功还是失败，都要清理缓存和停止验证
          final paymentIdForCleanup = order.paymentId ?? recmap["payid"] ?? "";
          
          if(!isSuccess){
            // 根据失败原因判断状态类型
            PaymentStatus failureStatus = PaymentStatus.cancelled;
            String errorMessage = LocationUtils.translate('Payment cancelled');
            
            if (failureReason != null) {
              final reasonLower = failureReason.toLowerCase();
              Debug.log('支付失败原因: $reasonLower');
              
              // 根据不同的失败字符串设置相应的状态
              if (reasonLower.contains('cancel') || reasonLower.contains('cancelled')) {
                failureStatus = PaymentStatus.cancelled;
                errorMessage = LocationUtils.translate('Payment cancelled');
              } else if (reasonLower.contains('timeout')) {
                failureStatus = PaymentStatus.timeout;
                errorMessage = LocationUtils.translate('Payment timeout');
              } else if (reasonLower.contains('err') || reasonLower.contains('error')) {
                failureStatus = PaymentStatus.failed;
                errorMessage = LocationUtils.translate('Payment error: $failureReason');
              } else {
                // 其他错误情况
                failureStatus = PaymentStatus.failed;
                errorMessage = LocationUtils.translate('Payment failed: $failureReason');
              }
            }
            
            // 支付回调执行（失败），清理缓存和停止验证
            if (paymentIdForCleanup.isNotEmpty) {
              OrderMonitorService.instance.stopPaymentVerification(paymentIdForCleanup);
              OrderMonitorService.instance.appDelete(paymentIdForCleanup);
            }
            
            completer.complete(PaymentResult(
              paymentId: '',
              status: failureStatus,
              message: errorMessage,
            ));
            return;
          }

          final String payid = recmap["payid"] ?? "";
          if (payid.isEmpty) {
            Debug.log('支付回调缺少payid');
            // 支付回调执行（缺少payid），清理缓存和停止验证
            final paymentIdForCleanup = order.paymentId ?? "";
            if (paymentIdForCleanup.isNotEmpty) {
              OrderMonitorService.instance.stopPaymentVerification(paymentIdForCleanup);
              OrderMonitorService.instance.appDelete(paymentIdForCleanup);
            }
            completer.complete(PaymentResult(
              paymentId: '',
              status: PaymentStatus.failed,
              message: LocationUtils.translate('Payment callback missing payid'),
            ));
            return;
          }
          
          // 支付回调执行（成功），清理缓存和停止验证
          OrderMonitorService.instance.stopPaymentVerification(payid);
          OrderMonitorService.instance.appDelete(payid);
          
          // 创建支付成功结果
          final result = PaymentResult(
            paymentId: payid,
            status: PaymentStatus.success,
            message: LocationUtils.translate('App payment successful'),
            data: {
              'orderId': request.orderId,
              'amount': request.amount,
              'returnUrl': "",
              'order': order.toJson(), // 将订单信息包含在支付结果中
            },
          );
      
          completer.complete(result);
          
        } catch (e) {
          Debug.log('处理App支付回调失败: $e');
          // 支付回调执行（异常），清理缓存和停止验证
          final paymentIdForCleanup = order.paymentId ?? "";
          if (paymentIdForCleanup.isNotEmpty) {
            OrderMonitorService.instance.stopPaymentVerification(paymentIdForCleanup);
            OrderMonitorService.instance.appDelete(paymentIdForCleanup);
          }
          if(!completer.isCompleted){
             completer.complete(PaymentResult(
            paymentId: '',
            status: PaymentStatus.failed,
            message: LocationUtils.translate('Failed to process payment callback: \$e'),
            ));
          }
        }
      });
       // 启动支付验证（每30秒验证一次）
      OrderMonitorService.instance.startPaymentVerification(order.paymentId!, order);
      // 等待支付结果，设置超时
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          Debug.log('App支付超时');
          return PaymentResult(
            paymentId: '',
            status: PaymentStatus.timeout,
            message: LocationUtils.translate('Payment timeout'),
          );
        },
      );

    } catch (e) {
      Debug.log('App支付失败: $e');
      return PaymentResult(
        paymentId: '',
        status: PaymentStatus.failed,
        message: LocationUtils.translate('App payment failed: \$e'),
      );
    }
  }


  /// 验证支付结果
  Future<bool> verifyPayment(String paymentId) async {
    try {
      Debug.log('验证支付结果: $paymentId');
      
      // 这里应该调用后端API验证支付结果
      // 暂时返回true表示验证成功
      return true;
    } catch (e) {
      Debug.log('验证支付结果失败: $e');
      return false;
    }
  }



  /// 取消支付
  Future<void> cancelPayment(String paymentId) async {
    try {
      Debug.log('取消支付: $paymentId');
      
      // 这里应该调用支付API取消支付
      // 具体实现根据支付API进行
      
    } catch (e) {
      Debug.log('取消支付失败: $e');
    }
  }

  /// 获取支付状态
  Future<PaymentStatus> getPaymentStatus(String paymentId) async {
    try {
      Debug.log('获取支付状态: $paymentId');
      
      // 这里应该调用支付API查询支付状态
      // 暂时返回成功状态
      return PaymentStatus.success;
    } catch (e) {
      Debug.log('获取支付状态失败: $e');
      return PaymentStatus.failed;
    }
  }



  /// 显示支付结果弹窗
  void _showPaymentResultDialog(PaymentResult result) {
    try {
      // 使用 Get 获取当前 context
      final context = Get.context;
      if (context == null) {
        Debug.log('无法获取当前 context，跳过支付结果弹窗显示');
        return;
      }

      String title;
      String message;
      Color color;
      bool showLoading = false;

      switch (result.status) {
        case PaymentStatus.success:
          title = 'Success';
          message = 'Payment completed, we will process the order soon...';
          color = Colors.green;
          break;
        case PaymentStatus.failed:
          title = 'Failed';
          message = result.message ?? 'Payment failed, please try again';
          color = Colors.red;
          break;
        case PaymentStatus.cancelled:
          title = 'Cancelled';
          message = 'User cancelled payment';
          color = Colors.orange;
          break;
        case PaymentStatus.timeout:
          title = 'Timeout';
          message = 'Payment timeout, please try again';
          color = Colors.orange;
          break;
        default:
          title = 'Exception';
          message = 'Unknown error occurred during payment';
          color = Colors.red;
      }

      // 显示支付结果弹窗
      Get.dialog(
        PaymentProcessingDialog(
          title: title,
          message: message,
          color: color,
          showLoading: showLoading,
        ),
        // barrierDismissible: true,
      );

      // 延迟关闭弹窗
      Future.delayed(const Duration(seconds: 3), () {
        if (Get.isDialogOpen == true) {
          Get.back();
        }
      });

    } catch (e) {
      Debug.log('显示支付结果弹窗失败: $e');
    }
  }

  /// 统一支付处理
  /// [order] 订单对象
  /// [source] 支付来源
  /// [context] 上下文
  /// [isFromCart] 是否来自购物车（用于购物车清空逻辑）
  static Future<void> processPayment({
    required Order order,
    required PaymentSource source,
    required BuildContext context,
    bool isFromCart = false,
  }) async {
    try {
      Debug.log('统一支付服务: 开始处理支付，来源: $source');
      
      switch (source) {
        case PaymentSource.buyNow:
        case PaymentSource.cart:
          // 立即购买和购物车结算：跳转到PaymentScreen
          await _processPaymentWithScreen(
            order: order,
            source: source,
            context: context,
            isFromCart: isFromCart,
          );
          break;
          
        case PaymentSource.orderPay:
          // 订单立即支付：直接处理支付
          await _processOrderPayment(
            order: order,
            context: context,
          );
          break;
      }
    } catch (e) {
      Debug.log('统一支付服务: 支付处理失败: $e');
      if(context.mounted) {
         Debug.showUserFriendlyError('支付处理失败: $e');
      }
    }
  }

  /// 通过PaymentScreen处理支付（立即购买和购物车）
  static Future<void> _processPaymentWithScreen({
    required Order order,
    required PaymentSource source,
    required BuildContext context,
    required bool isFromCart,
  }) async {
    Debug.log('统一支付服务: 通过PaymentScreen处理支付');
        // 跳转到支付页面
    Get.to(() => PaymentScreen(
          order: order,
          isFromCart: isFromCart,
        ),
      );


  }

  /// 直接处理订单支付（订单立即支付）
  static Future<void> _processOrderPayment({
    required Order order,
    required BuildContext context,
  }) async {
    Debug.log('统一支付服务: 直接处理订单支付');

    try {
      // 创建支付请求
      final paymentRequest = PaymentRequest(
        orderId: order.id,
        orderNumber: order.orderNumber,
        amount: order.totalAmount,
        description: 'order.orderNumber',
        customerPhone: order.shippingAddress?.phone ?? '',
        customerName: order.shippingAddress?.name ?? '',
      );

      // 发起支付（支付结果弹窗现在在 PaymentService 中处理）
      final paymentService = PaymentService();
      final result = await paymentService.createPayment(paymentRequest, context: context, order: order);

      // 如果支付成功，处理订单状态更新
      if (result.isSuccess) {
         // 通知订单状态变化，触发页面刷新
          OrderMonitorService.instance.setUpdatingOrders(false);
          
          // 支付成功，使用统一的回调处理服务
          final userService = Get.find<UserService>();
          unawaited(PaymentCallbackService.handlePaymentSuccess(
            order: order,
            isNewOrder: false, // 这是待支付订单的支付
            cartController: null, // 订单支付不需要清空购物车
            userService: userService,
            shouldClearCart: false,
          ));
          
         
      }
      // 支付失败的情况已经在 PaymentService 中通过弹窗处理了
      
    } catch (e) {
      Debug.log('统一支付服务: 订单支付失败: $e');
      
      if (context.mounted) {
        Debug.showUserFriendlyError('支付过程中发生错误: $e');
      }
    }
  }


  /// 创建订单并处理支付（用于立即购买和购物车）
  static Future<void> createOrderAndPay({
    required List<OrderItem> items,
    required PaymentSource source,
    required BuildContext context,
    required String userId,
    required OrderType orderType,
    double? subtotal,
  }) async {
    try {
      Debug.log('统一支付服务: 创建订单并支付，来源: $source');
      
      // 检查上下文是否仍然有效
      if (!context.mounted) {
        Debug.logWarning('统一支付服务: 上下文已失效，取消操作');
        return;
      }
      
      // 计算商品小计
      final calculatedSubtotal = subtotal ?? items.fold(0.0, (sum, item) => sum! + (item.price * item.quantity));
      
      // 计算配送费
      final shopService = Get.find<ShopService>();
      final shippingFee = shopService.shop.value.calculateShippingFee(calculatedSubtotal!, orderType: orderType);
      
      // 创建订单（订单号在支付成功保存前才获取）
      final order = Order.create(
        userId: userId,
        items: items,
        subtotal: calculatedSubtotal,
        shippingFee: shippingFee,
        orderType: orderType,
        // orderNumber 不传递，默认为空字符串，在支付成功保存前才获取
      );

      // 再次检查上下文
      if (!context.mounted) {
        Debug.logWarning('统一支付服务: 上下文已失效，取消支付处理');
        return;
      }

      // 处理支付
      await processPayment(
        order: order,
        source: source,
        context: context,
        isFromCart: source == PaymentSource.cart,
      );
    } catch (e) {
      Debug.logError('统一支付服务: 创建订单并支付', e);
      if(context.mounted) {
         Debug.showUserFriendlyError('创建订单失败: $e');
      }
    }
  }

}
