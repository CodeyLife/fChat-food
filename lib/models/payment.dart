
/// 支付环境枚举
enum PaymentEnvironment {
  web,  // Web环境
  app,  // App环境
}

/// 支付状态枚举
enum PaymentStatus {
  pending,    // 待支付
  processing, // 支付中
  success,    // 支付成功
  failed,     // 支付失败
  cancelled,  // 支付取消
  timeout,    // 支付超时
}

/// 支付结果
class PaymentResult {
  /// 支付ID，唯一标识一次支付
  final String paymentId;
  /// 支付状态
  final PaymentStatus status;
  /// 支付结果消息，如错误信息或成功提示
  final String? message;
  /// 支付相关的额外数据，如交易号、银行流水号等
  final Map<String, dynamic>? data;
  /// 支付结果时间戳
  final DateTime timestamp;

  PaymentResult({
    required this.paymentId,
    required this.status,
    this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      paymentId: json['paymentId'] ?? '',
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.failed,
      ),
      message: json['message'],
      data: json['data'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'status': status.name,
      'message': message,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 是否支付成功
  bool get isSuccess => status == PaymentStatus.success;

  /// 是否支付失败
  bool get isFailed => status == PaymentStatus.failed || status == PaymentStatus.cancelled || status == PaymentStatus.timeout;
}

/// 支付配置
class PaymentConfig {
  /// 商户ID，用于标识商户身份
  final String merchantId;
  /// 支付完成后的跳转URL（同步回调）
  final String returnUrl;
  /// 支付结果通知URL（异步回调）
  final String notifyUrl;
  /// 应用ID，用于App环境下的支付
  final String? appId;
  /// 应用密钥，用于App环境下的签名验证
  final String? appSecret;

  PaymentConfig({
    required this.merchantId,
    required this.returnUrl,
    required this.notifyUrl,
    this.appId,
    this.appSecret,
  });

  factory PaymentConfig.fromJson(Map<String, dynamic> json) {
    return PaymentConfig(
      merchantId: json['merchantId'] ?? '',
      returnUrl: json['returnUrl'] ?? '',
      notifyUrl: json['notifyUrl'] ?? '',
      appId: json['appId'],
      appSecret: json['appSecret'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId,
      'returnUrl': returnUrl,
      'notifyUrl': notifyUrl,
      'appId': appId,
      'appSecret': appSecret,
    };
  }
}

/// 支付请求数据
class PaymentRequest {
  /// 订单ID，系统内部唯一标识
  final String orderId;
  /// 订单号，用于展示给用户的订单编号
  final String orderNumber;
  /// 支付金额，单位为元
  final double amount;
  /// 订单描述信息
  final String description;
  /// 客户手机号，用于支付验证
  final String? customerPhone;
  /// 客户姓名
  final String? customerName;
  /// 额外数据，用于传递自定义参数
  final Map<String, dynamic>? extraData;

  PaymentRequest({
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.description,
    this.customerPhone,
    this.customerName,
    this.extraData,
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return PaymentRequest(
      orderId: json['orderId'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      customerPhone: json['customerPhone'],
      customerName: json['customerName'],
      extraData: json['extraData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'amount': amount,
      'description': description,
      'customerPhone': customerPhone,
      'customerName': customerName,
      'extraData': extraData,
    };
  }
}

/// 支付回调数据
class PaymentCallback {
  /// 支付ID，与支付请求中的paymentId对应
  final String paymentId;
  /// 订单ID，与支付请求中的orderId对应
  final String orderId;
  /// 实际支付金额，单位为元
  final double amount;
  /// 支付状态
  final PaymentStatus status;
  /// 回调消息，如支付成功或失败的原因
  final String? message;
  /// 原始回调数据，包含支付平台返回的完整信息
  final Map<String, dynamic>? rawData;
  /// 回调时间戳
  final DateTime timestamp;

  PaymentCallback({
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.status,
    this.message,
    this.rawData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory PaymentCallback.fromJson(Map<String, dynamic> json) {
    return PaymentCallback(
      paymentId: json['paymentId'] ?? '',
      orderId: json['orderId'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.failed,
      ),
      message: json['message'],
      rawData: json['rawData'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'orderId': orderId,
      'amount': amount,
      'status': status.name,
      'message': message,
      'rawData': rawData,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}