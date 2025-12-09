import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import '../services/config_service.dart';
import '../services/order_monitor_service.dart';
import '../services/user_service.dart';
import '../services/shop_service.dart';
import '../services/order_counter_service.dart';
import '../utils/debug.dart';
import '../utils/location.dart';
import 'package:fchatapi/appapi/PrintOrderApi.dart';
import 'package:fchatapi/appapi/VoiceSpeark.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import 'package:fchatapi/util/Translate.dart';
import 'package:fchatapi/util/JsonUtil.dart';
import 'package:fchatapi/webapi/PushOrder/PrintObj.dart' as fchatapi;
import 'package:fchatapi/webapi/PushOrder/PushOrderObj.dart';
import 'package:fchatapi/webapi/PushOrder/PushUtil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../models/order.dart';
import '../utils/file_utils.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

/// 订单推送类型枚举
enum OrderPushType {
  newOrder,      // 新订单
  statusUpdate,  // 订单状态更新
  orderRemoved,  // 订单移除
}

/// 订单推送数据
class OrderPushData {
  final String orderId;      // 订单唯一ID
  final OrderPushType type;  // 推送类型

  OrderPushData({
    required this.orderId,
    required this.type,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'type': type.name,
    };
  }

  /// 从JSON创建
  factory OrderPushData.fromJson(Map<String, dynamic> json) {
    return OrderPushData(
      orderId: json['orderId'] ?? '',
      type: OrderPushType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OrderPushType.newOrder,
      ),
    );
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 从JSON字符串创建
  factory OrderPushData.fromJsonString(String jsonString) {
    return OrderPushData.fromJson(jsonDecode(jsonString));
  }
}

/// 统一订单管理服务
/// 处理订单的文件操作，数据源由OrderMonitorService管理
class UnifiedOrderService {
  static bool _isRefreshing = false;
  
  // 打印队列相关变量
  static final Queue<Order> _printQueue = Queue<Order>();
  static bool _isPrinting = false;
  static final Map<String, List<Completer<void>>> _printCompleters = {};

  /// 初始化服务（现在由OrderMonitorService负责）
  static Future<void> initialize() async {
    // 初始化逻辑已移至OrderMonitorService
    Debug.log('统一订单服务初始化完成');
  }

  /// 加载所有订单（从临时订单目录）并返回订单列表
  static Future<List<Order>> loadAllOrders() async {
    _isRefreshing = true;
    try {
      final List<Order> orders = [];
      final maps = await FileUtils.readDirectory(AppConstants.tmporder);
      bool isAdmin = UserService.instance.currentUser!.isAdmin();
      for(Map<String, dynamic> map in maps){
        final order = Order.fromJson(map);
          // 文件名现在就是order.id，不需要单独设置 
                //先判断这个订单是否存在
                final tempOrder = orders.firstWhereOrNull((o) => o.id == order.id);
                if(tempOrder != null){
                  //判断哪个订单的更新时间更晚
                  if(tempOrder.updatedAt.isAfter(order.updatedAt)){
                    //已经存在的订单更晚 ，删除该订单，并继续处理后面的
                    FileUtils.deleteFile(AppConstants.tmporder, order.id);
                    continue;
                  }else{
                    //新的订单更晚，更新该订单
                    //删除老订单
                    FileUtils.deleteFile(AppConstants.tmporder, tempOrder.id);
                    orders.remove(tempOrder);
                  }
                }
                // 检查订单是否超时（超过12小时）
                if (_isOrderTimeout(order)) {
                  PhoneUtil.applog("发现超时订单: ${order.orderNumber}，创建时间: ${order.createdAt}，准备设置为超时状态");
                  
                  // 异步更新订单状态为超时
                    updateOrderStatusAndSave(order, OrderStatus.timeout).then((success) {
                    if (success) {
                      PhoneUtil.applog("已成功设置订单为超时状态: ${order.orderNumber}");
                    } else {
                      PhoneUtil.applog("设置订单超时状态失败: ${order.orderNumber}");
                    }
                  }).catchError((e) {
                    PhoneUtil.applog("设置订单超时状态失败: ${order.orderNumber}, 错误: $e");
                  });
                  
                  // 超时的订单不添加到orders中
                  continue;
                }
                
                // 检查订单是否已完成
                if (isOrderCompleted(order)) {
                  PhoneUtil.applog("发现已完成的订单: ${order.orderNumber}，状态: ${order.status.name}，准备移动到购买记录目录");
                  
                  // 异步移动已完成的订单
                  moveCompletedOrderToBuyDayMD(order).then((success) {
                    if (success) {
                      PhoneUtil.applog("已成功移动订单到购买记录目录: ${order.orderNumber}");
                    } else {
                      PhoneUtil.applog("移动订单到购买记录目录失败: ${order.orderNumber}");
                    }
                  }).catchError((e) {
                    PhoneUtil.applog("移动订单到购买记录目录失败: ${order.orderNumber}, 错误: $e");
                  });
                  
                  // 已完成的订单不添加到orders中
                } else {
                  //如果订单号为空，则不添加到orders中
                  if(order.orderNumber.isEmpty){
                     continue;
                  }
                  // 只有正在进行的订单才添加到orders中
                  orders.add(order);
                  
                  // 检查订单是否需要打印：状态为paid且未打印
                  if ( isAdmin && order.status == OrderStatus.paid && !order.isPrinted) {
                    PhoneUtil.applog("发现未打印的已支付订单: ${order.orderNumber}，准备打印");
                    // 异步打印订单（不阻塞加载流程）
                    pushPrintOrder(order).catchError((e) {
                      PhoneUtil.applog("打印订单失败: ${order.orderNumber}, 错误: $e");
                    });
                  }
                }
      }
  
      _isRefreshing = false;
      return orders;
    } catch (e) {
      Debug.logError('加载临时订单失败: $e');
      _isRefreshing = false;
      return [];
    }
  }

  static Future<List<Order>> simpleLoadAllOrders() async {
    final objs = await FileUtils.readDirectory(AppConstants.tmporder);
    final List<Order> orders = [];
    for(Map<String, dynamic> file in objs){
 // 解码Base64数据
                final order = Order.fromJson(file);
                orders.add(order);
    }
    return orders;
  }

  /// 推送订单消息给管理员
  /// [order] 订单对象
  /// [type] 推送类型（新订单、订单状态更新、订单移除）
  static Future<void> pushOrder(Order order, OrderPushType type, {bool pushAdmin = true}) async {

    final recevieIds = pushAdmin ? await UserService.adminUserIds : [order.userId];
    // 创建订单推送数据
    final pushData = OrderPushData(
      orderId: order.id,
      type: type,
    );
    // 根据推送类型设置消息体
    String body;
    switch (type) {
      case OrderPushType.newOrder:
        // 构建商品信息
        String itemsInfo;
        if (order.items.length == 1) {
          // 单个商品：显示完整信息
          itemsInfo = "${order.items[0].productName} x${order.items[0].quantity}";
        } else if (order.items.length > 1) {
          // 多个商品：显示前2个，然后"...and more"
          itemsInfo = order.items.sublist(0, 2)
              .map((item) => "${item.productName} x${item.quantity}")
              .join(', ') + 
              (order.items.length > 2 ? '... ${LocationUtils.translate("and")} ${order.items.length - 2} ${LocationUtils.translate("more")}' : '');
        } else {
          itemsInfo = '';
        }
        
        // 格式：您有一个新的订单，[商品信息] 总计 xx
        body = "${LocationUtils.translate("New order notification")},$itemsInfo ${LocationUtils.translate("Total")} ${ShopService.symbol.value}${order.totalAmount}";
        break;
      case OrderPushType.statusUpdate:
        if(pushAdmin){
          body = "${LocationUtils.translate("Order status updated")},${order.status.name}";
        }else{
          // 根据订单状态设置人性化的用户提示语
          switch(order.status) {
            case OrderStatus.paid:
              body = LocationUtils.translate("Your order has been confirmed! We're preparing it now.");
              break;
            case OrderStatus.processing:
              body = LocationUtils.translate("We're preparing your order now, please wait a moment.");
              break;
            case OrderStatus.readyForPickup:
              body = LocationUtils.translate("Your order is ready! You can pick it up now.");
              break;
            case OrderStatus.outForDelivery:
              body = LocationUtils.translate("Your order is on the way! The delivery person will arrive soon.");
              break;
           default:
            body = LocationUtils.translate("Your order status has been updated.");
            break;
          }
        }
        break;
      case OrderPushType.orderRemoved:
       if(!pushAdmin){
         switch(order.status) {
            case OrderStatus.completed:
              body = LocationUtils.translate("Your order has been completed! Thank you for your order.");
              break;
            case OrderStatus.cancelled:
              body = LocationUtils.translate("Your order has been cancelled.");
              break;
            case OrderStatus.refunded:
              body = LocationUtils.translate("Your order has been refunded.");
              break;
            case OrderStatus.timeout:
              body = LocationUtils.translate("Your order has expired.");
              break;
            case OrderStatus.pending:
              body = LocationUtils.translate("Your order is pending payment.");
              break;
            default:
              body = LocationUtils.translate("Your order has been removed.");
              break;
         }
       }else
       {
        body = LocationUtils.translate("Order removed");
       }
     
        break;
    }
    
    final PushOrderObj pushOrderObj = PushOrderObj(
      ConfigService.presetUserId,
      UserService.instance.currentUser!.userId,
      recevieIds,
      "${ShopService.instance.shop.value.name} ${LocationUtils.translate("Order")}: ${order.orderNumber}",
      body,
      order.paymentId ?? '',
      pushData.toJsonString(),
    );

    Debug.log('pushOrderObj: ${pushOrderObj.toJson().toString()}');
    PushUtil.creatPushOrder(pushOrderObj);  //创建并发送
  }

  //推送打印订单
  static Future<void> pushPrintOrder(Order order) async {
    // 创建 Completer 用于等待该订单打印完成
    final completer = Completer<void>();
    
    // 将 completer 添加到列表中（支持同一订单的多个打印请求）
    _printCompleters.putIfAbsent(order.id, () => []).add(completer);
    
    // 将订单添加到队列
    _printQueue.add(order);
    Debug.log('订单已添加到打印队列: ${order.orderNumber}，队列长度: ${_printQueue.length}');
    
    // 如果当前没有正在打印的任务，启动队列处理
    if (!_isPrinting) {
      _processPrintQueue();
    }
    
    // 等待该订单打印完成
    return completer.future;
  }
  
  /// 处理打印队列
  static Future<void> _processPrintQueue() async {
    // 如果正在打印或队列为空，直接返回
    if (_isPrinting || _printQueue.isEmpty) {
      return;
    }
    
    // 从队列中取出订单
    final order = _printQueue.removeFirst();
    _isPrinting = true;
    
    Debug.log('开始打印订单: ${order.orderNumber}，队列中剩余: ${_printQueue.length}');
    
    // 等待 shopName 不为空
    int maxWaitAttempts = 60; // 最多等待30次（约15秒）
    int waitAttempts = 0;
    while (ShopService.instance.shopName.value.isEmpty && waitAttempts < maxWaitAttempts) {
      await Future.delayed(const Duration(milliseconds: 500));
      waitAttempts++;
      if (waitAttempts % 10 == 0) {
        Debug.log('等待店铺名称加载中... (${waitAttempts * 500}ms)');
      }
    }
    
    // 如果等待超时仍未加载，记录警告但继续执行
    if (ShopService.instance.shopName.value.isEmpty) {
      Debug.logError('店铺名称未加载，使用默认值继续打印订单: ${order.orderNumber}');
    }
    
    // 创建打印对象
    // 将本地 OrderType 映射到 fchatapi 的 OrderType
    // fchatapi 使用 takeout 而不是 delivery
    final fchatApiOrderType = order.orderType == OrderType.delivery 
        ? fchatapi.OrderType.takeout 
        : fchatapi.OrderType.dineIn;
    
    final fchatapi.PrintOrderObj neworder = fchatapi.PrintOrderObj(
      orderType: fchatApiOrderType, // 订单类型
      orderId: order.id, // 订单ID
      dateTime: order.createdAt.toIso8601String(), // 订单创建时间（转换为字符串）
      paymentMethod: order.paymentId ?? '', // 支付方式/支付ID
      title: ShopService.instance.shopName.value.isNotEmpty 
          ? ShopService.instance.shopName.value 
          : 'Shop', // 默认值
      items: order.items.map((item) => "${item.productName} x${item.quantity}  \$${item.price}").toList(),
      total: "total: ${ShopService.symbol.value}${order.totalAmount}",
      message: _buildOrderMessage(order), // 根据订单类型构建消息
      logoBase64: "",   //图片base64
      qrLink: order.orderType == OrderType.delivery 
          ? (order.shippingAddress?.address.url.value.isNotEmpty == true 
              ? order.shippingAddress!.address.url.value 
              : "https://maps.google.com/maps?q=${order.shippingAddress?.address.latitude.value},${order.shippingAddress?.address.longitude.value}&z=17&hl=en")
          : "", // 无二维码
      languageType: fchatapi.PrintLanguageType.values.firstWhere(
        (e) => e.name == Translate.nowlanguage!.isoCode,
        orElse: () => fchatapi.PrintLanguageType.en,
      ),
    );

    // 执行打印
    PrintOrderApi(neworder).print((value) async {
      // 完成当前打印任务
      _isPrinting = false;
      // 获取并移除该订单的所有 Completer
      final completers = _printCompleters.remove(order.id);

      if (value == PrintStatus.Complete) {
        Debug.log('打印订单成功: ${order.orderNumber}');
        // 更新订单的isPrinted字段并保存
        final updatedOrder = order.copyWith(isPrinted: true);
        Debug.log("更新订单打印状态: ${updatedOrder.orderNumber} ${updatedOrder.status} ${updatedOrder.isPrinted}");
        final success = await FileUtils.updateOrderInTemp(updatedOrder);
        if (success) {
          // 订单已保存成功
          Debug.log('订单打印状态已更新: ${updatedOrder.orderNumber}');
          // 更新OrderMonitorService中的订单
          OrderMonitorService.instance.updateOrder(updatedOrder);
          Debug.log('订单打印状态已更新并保存: ${order.orderNumber}');
        } else {
          Debug.logError('保存订单打印状态失败: ${order.orderNumber}');
        }
        
        // 完成所有等待该订单的 Completer
        for (final completer in completers ?? []) {
          completer.complete();
        }
      } else {
        
        Debug.logError('打印订单失败: ${order.orderNumber}, 错误: $value');
        // 打印失败时也完成所有等待该订单的 Completer（跳过并继续）
        for (final completer in completers ?? []) {
          completer.complete();
        }
      }
      
      // 继续处理队列中的下一个订单
      if (_printQueue.isNotEmpty) {
        _processPrintQueue();
      }
    });
  }
   
  /// 构建订单消息
  static String _buildOrderMessage(Order order) {
    // 添加订单号和订单类型在最上面
    final header = "${order.orderNumber}(${LocationUtils.translate(order.orderType.name)})";
    
    if (order.orderType == OrderType.dineIn) {
      // 堂食订单：只显示备注
      return "$header\n${order.notes ?? ''}";
    } else if (order.orderType == OrderType.delivery && order.shippingAddress != null) {
      // 外卖订单：显示备注、姓名、电话、地址
      final shippingAddress = order.shippingAddress!;
      final List<String> messageParts = [];
      
      // 添加备注
      if (order.notes != null && order.notes!.isNotEmpty) {
        messageParts.add('notes: ${order.notes}');
      }
      
      // 添加配送信息
      messageParts.add('name: ${shippingAddress.name}');
      messageParts.add('phone: ${shippingAddress.phone}');
      messageParts.add('address: ${shippingAddress.addressString}');
      
      return "$header\n${messageParts.join('\n')}";
    }
    
    return "$header\n${order.notes ?? ''}";
  }

  /// 解析订单推送数据
  /// [data] 推送数据的Base64编码的JSON字符串
  /// 返回解析后的 OrderPushData 对象
  static Future<void> parseOrderPushData(String data) async {
    bool isPresetUser = UserService.instance.currentUser!.userId == ConfigService.presetUserId;
    try {
      // 先解码Base64
      String decodedData = JsonUtil.getbase64(data);
      if(isPresetUser){
        //是服务号id 判断这个json是不是订单json
        try
        {
          Map<String, dynamic> orderData = JsonUtil.strtoMap(decodedData);
          var order = Order.fromJson(orderData);
          if(order.id.isNotEmpty){  
           try {
                order.status = OrderStatus.paid;
                   order.orderNumber = await OrderCounterService.instance.getNextOrderNumber();
                   OrderMonitorService.instance.updateOrder(order);
                   Debug.log("服务器解析支付push的订单数据");
                  await FileUtils.updateOrderInTemp(order);
                  pushPrintOrder(order);
              } catch (e) {
                Debug.logError('处理订单失败', e);
              }
          return;
          }

        }catch(_){
        
        }
      }
      // 使用正则表达式提取 data 字段后的 JSON 对象
      // 匹配 "data" 后的第一个 { 到对应的 }（支持嵌套）
      // 支持格式：data: { 或 "data": { 或 "data":"{
      final regex = RegExp(r'"?data"?\s*:\s*"?(\{)', dotAll: true);
      final match = regex.firstMatch(decodedData);
      
      OrderPushData? orderPushData;
      
      if (match != null) {
        // 找到了 data 字段后的第一个 {
        int startIndex = match.end - 1; // { 的位置
        int braceCount = 0;
        int endIndex = startIndex;
        
        // 从第一个 { 开始，找到对应的闭合 }
        for (int i = startIndex; i < decodedData.length; i++) {
          if (decodedData[i] == '{') {
            braceCount++;
          } else if (decodedData[i] == '}') {
            braceCount--;
            if (braceCount == 0) {
              endIndex = i;
              break;
            }
          }
        }
        
        if (braceCount == 0 && endIndex > startIndex) {
          // 成功找到匹配的 }，提取 JSON 字符串
          final dataJsonString = decodedData.substring(startIndex, endIndex + 1);
          Debug.log('通过正则表达式提取的 data JSON: $dataJsonString');
          
          // 直接将提取的 JSON 解析为 OrderPushData
          try {
            orderPushData = OrderPushData.fromJsonString(dataJsonString);
          } catch (e) {
            Debug.logError('解析提取的 OrderPushData JSON 失败', e);
            Debug.log('尝试解析的 JSON 字符串: $dataJsonString');
            // 如果直接解析失败，继续尝试完整解析方式
            orderPushData = null;
          }
        }
      }
      
      // 如果通过正则表达式提取失败，尝试完整解析方式
      if (orderPushData == null) {
        Debug.log('使用完整解析方式');
        // 先解析为 PushOrderObj 的 JSON
        Map<String, dynamic> pushOrderObjJson;
        try {
          pushOrderObjJson = jsonDecode(decodedData) as Map<String, dynamic>;
          Debug.log('PushOrderObj JSON 解析成功，字段: ${pushOrderObjJson.keys.toList()}');
        } catch (e) {
          Debug.logError('解析 PushOrderObj JSON 失败', e);
          Debug.log('尝试解析的 JSON 字符串: $decodedData');
          OrderMonitorService.instance.initOrders();
          return;
        }
        
        // 从 PushOrderObj 中取出 data 字段
        dynamic dataValue = pushOrderObjJson['data'];
        
        if (dataValue == null) {
          Debug.logError('PushOrderObj 中未找到 data 字段', null);
          Debug.log('PushOrderObj JSON 的所有字段: ${pushOrderObjJson.keys.toList()}');
              OrderMonitorService.instance.initOrders();
          return;
        }
        
        String finalDataString;
        
        // 处理 data 字段可能是字符串或对象的情况
        if (dataValue is String) {
          // 如果是字符串，可能是 JSON 字符串或 Base64 编码的字符串
          Debug.log('data 字段是字符串类型: $dataValue');
          try {
            // 先尝试直接解析为 JSON，验证是否是有效的 JSON 字符串
            jsonDecode(dataValue);
            // 如果成功，说明是 JSON 字符串，直接使用
            finalDataString = dataValue;
          } catch (e) {
            // 如果解析失败，尝试 Base64 解码
            try {
              finalDataString = JsonUtil.getbase64(dataValue);
              Debug.log('data 字段 Base64 解码后: $finalDataString');
            } catch (e2) {
              Debug.logError('data 字段既不是有效的 JSON 字符串也不是 Base64', e2);
                  OrderMonitorService.instance.initOrders();
              return;
            }
          }
        } else if (dataValue is Map) {
          // 如果 data 字段已经是解析后的对象，直接转换为 JSON 字符串
          Debug.log('data 字段是对象类型，转换为 JSON 字符串');
          finalDataString = jsonEncode(dataValue);
        } else {
          Debug.logError('data 字段类型不支持: ${dataValue.runtimeType}', null);
              OrderMonitorService.instance.initOrders();
          return;
        }
        
        Debug.log('最终用于解析的 data 字符串: $finalDataString');
        
        // 解析 data 字段为 OrderPushData
        try {
          orderPushData = OrderPushData.fromJsonString(finalDataString);
        } catch (e) {
          Debug.logError('解析 OrderPushData 失败', e);
              OrderMonitorService.instance.initOrders();
          return;
        }
      }
      
      // 使用局部变量，此时 orderPushData 已经保证不为 null（如果为 null 会在上面 return）
      final finalOrderPushData = orderPushData;
      
      if(finalOrderPushData.type == OrderPushType.newOrder){
        if(isPresetUser){
           return;
        }
        Order? order = await Order.readOrderWithOrderId(finalOrderPushData.orderId);
        if(order != null){
            OrderMonitorService.instance.updateOrder(order);
            OrderMonitorService.instance.setStateChange(true);
            if(order.isPrinted == false){
              pushPrintOrder(order);
             Voicespeark().speark(LocationUtils.translate('you have a new order,please check it'), (value) {
             // 处理语音播放的回调
             Debug.log('语音播放状态: $value');
           });
            }
        }else{
          Debug.log("订单${finalOrderPushData.orderId}无法读取，不触发打印了");
        }
       }else if(finalOrderPushData.type == OrderPushType.statusUpdate){
        Order? order = await Order.readOrderWithOrderId(finalOrderPushData.orderId);
        
       
        if(order != null){  
          OrderMonitorService.instance.updateOrder(order);
          OrderMonitorService.instance.setStateChange(false);
          //判断需不需要弹窗提示
          if(order.userId == UserService.instance.currentUser!.userId && (order.status == OrderStatus.readyForPickup || order.status == OrderStatus.outForDelivery)){
            _showOrderStatusDialog(order);
          }
        }else{
           Debug.log("订单${finalOrderPushData.orderId}无法读取（filename已过期且通过orderId也找不到），不触发更新了");
        }
       }else  if(finalOrderPushData.type == OrderPushType.orderRemoved){
        try {
          final order = OrderMonitorService.instance.orders.firstWhere(
            (order) => order.id == finalOrderPushData.orderId,
            orElse: () => throw StateError('No element found'),
          );
          OrderMonitorService.instance.removeOrder(order);
        } catch (e) {
          Debug.logError('找不到要移除的订单: ${finalOrderPushData.orderId}', e);
        }
       }
    } catch (e) {
      Debug.logError('解析订单推送数据失败', e);
          OrderMonitorService.instance.initOrders();
    }
  }


  /// 验证订单是否已完成（统一验证函数）
  static bool isOrderCompleted(Order order) {
    return order.status == OrderStatus.completed || 
           order.status == OrderStatus.cancelled || 
           order.status == OrderStatus.refunded ||
           order.status == OrderStatus.timeout;
  }

  /// 检查订单是否超时（超过12小时）
  static bool _isOrderTimeout(Order order) {

    if (isOrderCompleted(order) || order.status != OrderStatus.pending) {
      return false;
    }
    
    final now = DateTime.now();
    final timeDifference = now.difference(order.createdAt);
    
    // 检查是否超过12小时（43200秒）
    return timeDifference.inHours >= 12;
  }

  /// 获取所有正在进行的订单
  static Future<List<Order>> getAllInProgressOrders() async {
    if(_isRefreshing){
      while(_isRefreshing){
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } 
    return List.from(OrderMonitorService.instance.orders);
  }


  /// 根据订单唯一ID获取订单
  /// [orderId] 订单的唯一ID (order.id), 不是订单号 (orderNumber)
  static Future<Order?> getOrderById(String orderId) async {
    try {
      return OrderMonitorService.instance.orders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => throw StateError('No element found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// 更新订单状态
  static Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    OrderMonitorService.instance.ismodify.value = true;
    
    try {
      final order = OrderMonitorService.instance.orders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => throw StateError('No element found'),
      );
      return await updateOrderStatusAndSave(order, newStatus);
    } catch (e) {
      Debug.logError('订单不存在: $orderId', e);
      return false;
    }
  }

  /// 更新订单状态并保存
  static Future<bool> updateOrderStatusAndSave(Order order,OrderStatus newStatus) async {
     OrderMonitorService.instance.ismodify.value = true;
      try {
        // 直接更新订单状态
        order.updateStatus(newStatus);
        
        // 检查订单是否变为已完成状态
        if (isOrderCompleted(order)) {
          Debug.log('订单状态更新为已完成: ${order.orderNumber}，状态: ${newStatus.name}');
          // 移动订单到购买记录目录
          final moveSuccess = await moveCompletedOrderToBuyDayMD(order);
          OrderMonitorService.instance.ismodify.value = false;
        
          if (moveSuccess) {
            // 从OrderMonitorService中移除订单
            OrderMonitorService.instance.removeOrder(order);
            //通知用户订单已移动到购买记录目录
            pushOrder(order, OrderPushType.orderRemoved, pushAdmin: false);
            Debug.log('订单已移动到购买记录目录并从界面移除: ${order.orderNumber}');
            return true;
          } else {
            Debug.log('移动订单到购买记录目录失败: ${order.orderNumber}');
            return false;
          }
        } else {
          // 更新订单状态并保存到临时订单目录
          final saveSuccess = await FileUtils.updateOrderInTemp(order);
          OrderMonitorService.instance.ismodify.value = false;
          if (saveSuccess) {
            OrderMonitorService.instance.updateOrder(order);
            //通知用户订单状态已更新
            pushOrder(order, OrderPushType.statusUpdate, pushAdmin: false);
            return true;
          } else {
            return false;
          }
        }
      } catch(e){
        Debug.log('更新订单状态并保存失败: $e');
        return false;
      } finally{
        OrderMonitorService.instance.ismodify.value = false;
      }
    }


  /// 移动已完成的订单到购买记录目录
  static Future<bool> moveCompletedOrderToBuyDayMD(Order order) async {
    try {
      Debug.log('开始移动已完成的订单到购买记录目录: ${order.orderNumber}');
      
      // 使用统一的文件操作工具类
      bool success = await FileUtils.moveOrderToBuyDay(order);
      
      if (success) {
        Debug.log('订单移动完成: ${order.orderNumber}');
      } else {
        Debug.log('订单移动失败: ${order.orderNumber}');
      }
      
      return success;
    } catch (e) {
      Debug.logError('移动订单到购买记录目录失败: $e');
      return false;
    }
  }


  /// 取消订单
  static Future<bool> cancelOrder(Order order) async {
    var success = await updateOrderStatus(order.id, OrderStatus.cancelled);
    if(success){
      OrderMonitorService.instance.removeOrder(order);
      return true;
    }
    return success;
  }

  /// 完成订单并移除
  static Future<bool> completeAndRemoveOrder(Order order) async {
    try {
      Debug.log('开始完成订单: ${order.orderNumber}');
      
      // 更新订单状态为已完成
      // 注意：updateOrderStatus会自动将订单从临时订单目录移动到购买记录目录
      bool statusUpdated = await updateOrderStatus(order.id, OrderStatus.completed);
      if (!statusUpdated) {
        Debug.log('更新订单状态失败: ${order.orderNumber}');
        return false;
      }
      
      Debug.log('订单完成成功: ${order.orderNumber}');
      return true;
    } catch (e) {
      Debug.logError('完成订单失败: $e');
      return false;
    }
  }



  /// 清除缓存
  static void clearCache() {
    // 缓存清除逻辑已移至OrderMonitorService
    Debug.log('统一订单服务缓存已清除');
  }

  /// 删除所有订单数据
  static Future<bool> deleteAllOrders() async {
    try {
        Debug.log('开始删除所有订单数据');
      
      // 使用FileUtils的专用方法删除订单文件
      int tempCount = await FileUtils.clearTempOrders();
        Debug.log('临时订单目录删除了 $tempCount 个文件');
      
      int buyRecordCount = await FileUtils.clearBuyDayOrders();
        Debug.log('购买记录目录删除了 $buyRecordCount 个文件');
      
      // 清空OrderMonitorService中的订单列表
      OrderMonitorService.instance.resetMonitoring();
      
      bool success = tempCount >= 0 && buyRecordCount >= 0;
       Debug.log('删除所有订单数据${success ? '成功' : '部分失败'}');
      
      return success;
    } catch (e) {
      Debug.logError('删除所有订单数据失败', e);
      return false;
    }
  }

  /// 添加订单到临时订单目录
  static Future<bool> addOrder(Order order,{bool generateOrderNumber = true}) async {
    try {

      if (order.orderNumber.isEmpty && generateOrderNumber) {
        final orderCounterService = OrderCounterService.instance;
        final orderNumber = await orderCounterService.getNextOrderNumber();
        order.orderNumber = orderNumber;
        Debug.log('订单号已更新: $orderNumber');
      }
      
      Debug.log('创建订单到临时订单目录: ${order.orderNumber}');
      bool success = await FileUtils.saveOrderToTemp(order);
      if(success){
         OrderMonitorService.instance.addOrder(order);
         return true;
      }
        return false;
    } catch (e) {
      Debug.logError('创建订单到临时订单目录失败', e);
      return false;
    }
  }

  /// 显示订单状态更新弹窗
  static void _showOrderStatusDialog(Order order) {
    String title;
    String message;
    IconData icon;
    Color iconColor;

    if (order.status == OrderStatus.readyForPickup) {
      title = LocationUtils.translate('Order Ready for Pickup');
      message = LocationUtils.translate('Your order #${order.orderNumber} is ready for pickup!');
      icon = Icons.restaurant;
      iconColor = Colors.green;
    } else if (order.status == OrderStatus.outForDelivery) {
      title = LocationUtils.translate('Order Out for Delivery');
      message = LocationUtils.translate('Your order #${order.orderNumber} is out for delivery!');
      icon = Icons.delivery_dining;
      iconColor = Colors.blue;
    } else {
      return; // 不需要显示弹窗的状态
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24.w,
            ),
            SizedBox(width: 8.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14.sp,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text(
                LocationUtils.translate('OK'),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false, // 必须点击确认才能关闭
    );
  }

}
