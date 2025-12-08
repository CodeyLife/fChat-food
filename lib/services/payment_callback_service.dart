import 'dart:async';
import 'package:fchatapi/util/PhoneUtil.dart';
import '../models/order.dart';
import '../utils/debug.dart';

import 'cart_service.dart';
import 'user_service.dart';

/// 支付成功回调处理服务
/// 统一处理支付成功后的各种逻辑
class PaymentCallbackService {
  
  /// 处理支付成功回调
  /// [order] - 订单对象（已创建）
  /// [isNewOrder] - 是否为新订单（true: 从购物车创建的新订单, false: 支付待支付订单）
  /// [cartController] - 购物车控制器（已废弃，购物车在订单创建时清空）
  /// [userService] - 用户服务（仅新订单时需要）
  /// [shouldClearCart] - 是否清空购物车（已废弃，购物车在订单创建时清空）
  static Future<bool> handlePaymentSuccess({
    required Order order,
    required bool isNewOrder,
    CartController? cartController, // 保留参数以保持向后兼容，但不再使用
    UserService? userService,
    OrderStatus state = OrderStatus.paid,
    bool shouldClearCart = true, // 保留参数以保持向后兼容，但不再使用
  }) async {
    try {
      Debug.log('开始处理支付成功回调: ${order.orderNumber}');

      if (isNewOrder) {
        unawaited(_handleNewOrderPaymentSuccess(order, cartController, userService, shouldClearCart));
      } 
      return true;
    } catch (e) {
      Debug.logError('处理支付成功回调失败: $e');
      return false;
    }
  }
  
  /// 处理新订单支付成功
  static Future<bool> _handleNewOrderPaymentSuccess(
    Order order, 
    CartController? cartController, 
    UserService? userService,
    bool shouldClearCart
  ) async {
    try {
      PhoneUtil.applog('处理新订单支付成功: ${order.orderNumber}');
  
      // 注意：订单已经在支付成功回调中创建
      // 这里只需要处理支付成功后的其他逻辑
      
      // 1. 清空购物车（根据参数决定）
      if (shouldClearCart && cartController != null) {
        Debug.log('开始清空购物车');
        cartController.clearCart();
        PhoneUtil.applog('购物车已清空');
        Debug.log('购物车已清空');
      } else if (!shouldClearCart) {
        Debug.log('立即购买，不清空购物车');
      }
      
      // 2. 给予下单奖励经验
      if (userService != null) {
        await userService.giveOrderReward(order.totalAmount);
        PhoneUtil.applog('已给予下单奖励经验: ${order.totalAmount}');
      }

      
      PhoneUtil.applog('新订单支付成功处理完成: ${order.orderNumber}');
      Debug.log('_handleNewOrderPaymentSuccess 处理完成，返回true');
      return true;
      
    } catch (e) {
      PhoneUtil.applog('处理新订单支付成功失败: $e');
      return false;
    }
  }
  

}
