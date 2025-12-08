import 'dart:typed_data';
import 'package:fchat_food/utils/file_utils.dart';
import 'package:fchatapi/util/Tools.dart';
import 'package:fchatapi/webapi/FChatFileObj.dart';
import '../utils/constants.dart';
import '../utils/debug.dart';
import '../utils/location.dart';
import 'address.dart';


/// 订单状态枚举
enum OrderStatus {
  pending,    // 待支付
  paid,       // 已支付
  processing, // 处理中
  readyForPickup, // 待取餐（堂食）
  outForDelivery, // 配送中（外卖）
  completed,  // 已完成
  cancelled,  // 已取消
  refunded,   // 已退款
  timeout,
}


/// 订单类型枚举
enum OrderType {
  dineIn,     // 堂食
  delivery,   // 外卖
}

/// 订单商品项
class OrderItem {
  /// 商品ID
  final String productId;
  /// 商品名称
  final String productName;
  /// 商品单价，单位为元
  final double price;
  /// 商品数量
  final int quantity;
  /// 商品图片字节数据
  final Uint8List? imageBytes;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.imageBytes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      quantity: json['quantity'] ?? 1,
      imageBytes: json['imageBytes'] != null ? Uint8List.fromList(List<int>.from(json['imageBytes'])) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
     // 'imageBytes': imageBytes?.toList(),
    };
  }

  /// 计算小计金额
  double get subtotal => price * quantity;
}

/// 配送地址
class ShippingAddress {
  /// 地址ID
  final String id;
  /// 地址信息（使用Address模型）
  final Address address;
  /// 是否为默认地址
  final bool isDefault;

  ShippingAddress({
    required this.id,
    required this.address,
    this.isDefault = false,
  });

  /// 获取收货人姓名
  String get name => address.contact.value;
  
  /// 获取收货人电话
  String get phone => address.phone.value;
  
  /// 获取详细地址
  String get addressString => address.address.value;

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      id: json['id'] ?? '',
      address: Address.fromJson(json['address'] ?? {}),
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address.toJson(),
      'isDefault': isDefault,
    };
  }
}

/// 订单类
class Order {
  /// 订单ID，系统内部唯一标识
  final String id;
  /// 订单号，基于时间戳生成的用户可见订单编号
  String orderNumber;
  /// 用户ID，订单所属用户
  final String userId;
  /// 订单商品列表
  final List<OrderItem> items;
  /// 商品小计金额，单位为元
  final double subtotal;
  /// 配送费，单位为元
  final double shippingFee;
  /// 订单总金额，单位为元
  final double totalAmount;
  /// 订单状态
  OrderStatus status;
  /// 订单类型（堂食/外卖）
  final OrderType orderType;
  /// 配送地址（外卖订单需要）
  final ShippingAddress? shippingAddress;
  /// 支付ID，关联支付记录
  String? paymentId;
  /// 订单备注
  final String? notes;
  /// 是否已经打印
  final bool isPrinted;
  /// 订单创建时间
  final DateTime createdAt;
  /// 订单更新时间
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.items,
    required this.subtotal,
    this.shippingFee = 0.0,
    required this.totalAmount,
    this.status = OrderStatus.pending,
    this.orderType = OrderType.delivery,
    this.shippingAddress,
    this.paymentId,
    this.notes,
    this.isPrinted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      userId: json['userId'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromJson(item))
          .toList(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      shippingFee: (json['shippingFee'] ?? 0.0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      orderType: OrderType.values.firstWhere(
        (e) => e.name == json['orderType'],
        orElse: () => OrderType.delivery,
      ),
      shippingAddress: json['shippingAddress'] != null
          ? ShippingAddress.fromJson(json['shippingAddress'])
          : null,
      paymentId: json['paymentId'],
      notes: json['notes'],
      isPrinted: json['isPrinted'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'totalAmount': totalAmount,
      'status': status.name,
      'orderType': orderType.name,
      'shippingAddress': shippingAddress?.toJson(),
      'paymentId': paymentId,
      'notes': notes,
      'isPrinted': isPrinted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 创建新订单
  factory Order.create({
    required String userId,  /// 用户ID
    required List<OrderItem> items,  /// 商品列表
    required double subtotal,  /// 商品小计
    double shippingFee = 0.0,  /// 配送费，默认为0
    OrderType orderType = OrderType.delivery,  /// 订单类型，默认为外卖
    ShippingAddress? shippingAddress,  /// 配送地址
    String? notes,  /// 订单备注
    String? orderNumber,  /// 订单号（可选，默认为空字符串，在支付成功保存前才获取）
  }) {
    final id = Tools.generateRandomString(30);
    final totalAmount = subtotal + shippingFee;

    return Order(
      id: id,
      orderNumber: orderNumber ?? '',
      userId: userId,
      items: items,
      subtotal: subtotal,
      shippingFee: shippingFee,
      totalAmount: totalAmount,
      orderType: orderType,
      shippingAddress: shippingAddress,
      notes: notes,
    );
  }

  /// 更新订单状态
  Order copyWith({
    OrderStatus? status,  /// 订单状态
    String? paymentId,  /// 支付ID
    String? notes,  /// 订单备注
    OrderType? orderType,  /// 订单类型
    ShippingAddress? shippingAddress,  /// 配送地址
    bool? isPrinted,  /// 是否已经打印
    String? orderNumber,  /// 订单号
  }) {
    return Order(
      id: id,
      orderNumber: orderNumber ?? this.orderNumber,
      userId: userId,
      items: items,
      subtotal: subtotal,
      shippingFee: shippingFee,
      totalAmount: totalAmount,
      status: status ?? this.status,
      orderType: orderType ?? this.orderType,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentId: paymentId ?? this.paymentId,
      notes: notes ?? this.notes,
      isPrinted: isPrinted ?? this.isPrinted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// 直接更新订单状态
  void updateStatus(OrderStatus newStatus) {
    status = newStatus;
  }

  /// 从另一个订单对象复制所有内容到当前对象
  /// 注意：由于很多字段是 final 的，此方法只能更新可修改的字段
  /// 可修改的字段包括：orderNumber, status, paymentId, filename
  void copyFrom(Order other) {
    orderNumber = other.orderNumber;
    status = other.status;
    paymentId = other.paymentId;
  }
  Future<void> updateInService() async {
    final tempOrder = (await Order.readOrderWithOrderId(id));
    if(tempOrder == null){
      Debug.logError('更新订单: $id 失败', Exception('更新订单: $id 失败'));
      return;
    }
    Debug.log('更新服务器订单信息到本地: ${tempOrder.orderNumber} ${tempOrder.status}');
    copyFrom(tempOrder);
  //  OrderMonitorService.instance.updateOrder(this);
  }

  static Future<Order?> readOrderWithOrderId(String orderId) async {
    final file =  await FileUtils.readFile(AppConstants.tmporder, orderId);
    if(file != null){
      return Order.fromJson(file);
    }
    return null;
  }

/// 获取状态文本
String getStatusText() {
  switch (status) {
    case OrderStatus.pending:
      return LocationUtils.translate('Pending');
    case OrderStatus.paid:
      return LocationUtils.translate('Paid');
    case OrderStatus.processing:
      return LocationUtils.translate('Processing');
    case OrderStatus.readyForPickup:
      return LocationUtils.translate('Ready');
    case OrderStatus.outForDelivery:
      return LocationUtils.translate('Delivering');
    case OrderStatus.completed:
      return LocationUtils.translate('Completed');
    case OrderStatus.cancelled:
      return LocationUtils.translate('Cancelled');
    case OrderStatus.refunded:
      return LocationUtils.translate('Refunded');
    case OrderStatus.timeout:
      return LocationUtils.translate('Expired');
  }
}


  /// 获取订单类型文本
  String getOrderTypeText() {
    switch (orderType) {
      case OrderType.dineIn:
        return LocationUtils.translate('Dine In');
      case OrderType.delivery:
        return LocationUtils.translate('Takeaway');
    }
  }

  /// 是否可以支付（只有待支付状态的订单可以支付）
  bool get canPay => status == OrderStatus.pending;

  /// 是否可以取消（只有待支付状态的订单可以取消）
  bool get canCancel => status == OrderStatus.pending;

  /// 是否可以退款（已支付或已完成的订单可以退款）
  bool get canRefund => status == OrderStatus.paid || status == OrderStatus.completed;

  /// 根据订单类型获取下一个状态
  OrderStatus getNextStatus() {
    switch (status) {
      case OrderStatus.pending:
        return OrderStatus.paid;  // 待支付 -> 已支付
      case OrderStatus.paid:
        return OrderStatus.processing;  // 已支付 -> 处理中
      case OrderStatus.processing:
        // 根据订单类型决定下一个状态
        return orderType == OrderType.dineIn 
            ? OrderStatus.readyForPickup   // 堂食：处理中 -> 待取餐
            : OrderStatus.outForDelivery;  // 外卖：处理中 -> 配送中
      case OrderStatus.readyForPickup:
      case OrderStatus.outForDelivery:
        return OrderStatus.completed;  // 待取餐/配送中 -> 已完成
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return status; // 终态，不再变化
      case OrderStatus.timeout:
        return status;
    }
  }

  /// 判断订单是否已完成（需要存储到购买记录目录）
  /// 包括已完成、已取消、已退款状态的订单
  bool get isCompleted {
    final result = status == OrderStatus.completed || 
                   status == OrderStatus.cancelled || 
                   status == OrderStatus.timeout ||
                   status == OrderStatus.refunded;
    
    // 调试信息
    if (result) {
      Debug.log('订单 $orderNumber 被识别为已完成订单，状态: ${status.name}');
    }
    
    return result;
  }

  /// 判断订单是否正在进行中（需要存储到临时订单目录）
  /// 与isCompleted相反，表示订单还在处理流程中
  bool get isInProgress {
    return !isCompleted;
  }

  /// 获取订单存储目录
  /// 已完成的订单存储到购买记录目录，其他存储到临时订单目录
  FChatFileMD get storageDirectory {
    return isCompleted ? AppConstants.getBuyDayMD() : AppConstants.tmporder;
  }

  @override
  String toString() {
    return 'Order(id: $id, orderNumber: $orderNumber, status: ${status.name}, totalAmount: $totalAmount)';
  }
}
