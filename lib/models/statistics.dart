import '../../models/order.dart';

/// 基础统计数据模型
class OrderStatistics {
  /// 订单总数
  final int totalOrders;
  /// 总收入金额
  final double totalRevenue;
  /// 平均订单金额
  final double averageOrderAmount;
  /// 已完成订单数
  final int completedOrders;
  /// 已取消订单数
  final int cancelledOrders;
  /// 已支付订单数
  final int paidOrders;
  /// 待支付订单数
  final int pendingOrders;
  /// 支付成功率
  final double paymentSuccessRate;

  OrderStatistics({
    required this.totalOrders,
    required this.totalRevenue,
    required this.averageOrderAmount,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.paidOrders,
    required this.pendingOrders,
    required this.paymentSuccessRate,
  });

  factory OrderStatistics.empty() {
    return OrderStatistics(
      totalOrders: 0,
      totalRevenue: 0.0,
      averageOrderAmount: 0.0,
      completedOrders: 0,
      cancelledOrders: 0,
      paidOrders: 0,
      pendingOrders: 0,
      paymentSuccessRate: 0.0,
    );
  }
}

/// 商品销量项
class ProductSaleItem {
  /// 商品ID
  final String productId;
  /// 商品名称
  final String productName;
  /// 销售数量
  final int quantity;
  /// 销售金额
  final double revenue;
  /// 占比
  final double percentage;

  ProductSaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.revenue,
    required this.percentage,
  });
}

/// 时段统计数据
class HourlyStatistics {
  /// 小时（0-23）
  final int hour;
  /// 订单数量
  final int orderCount;
  /// 订单金额
  final double revenue;

  HourlyStatistics({
    required this.hour,
    required this.orderCount,
    required this.revenue,
  });
}

/// 订单状态分布项
class OrderStatusDistribution {
  /// 订单状态
  final OrderStatus status;
  /// 数量
  final int count;
  /// 占比
  final double percentage;

  OrderStatusDistribution({
    required this.status,
    required this.count,
    required this.percentage,
  });
}

/// 订单类型分布项
class OrderTypeDistribution {
  /// 订单类型
  final OrderType orderType;
  /// 数量
  final int count;
  /// 占比
  final double percentage;

  OrderTypeDistribution({
    required this.orderType,
    required this.count,
    required this.percentage,
  });
}

/// 完整统计数据模型
class StatisticsData {
  /// 基础统计数据
  final OrderStatistics orderStatistics;
  /// 商品销量排行（前10名）
  final List<ProductSaleItem> topProducts;
  /// 时段统计数据
  final List<HourlyStatistics> hourlyData;
  /// 订单状态分布
  final List<OrderStatusDistribution> statusDistribution;
  /// 订单类型分布
  final List<OrderTypeDistribution> typeDistribution;
  /// 统计日期
  final DateTime date;

  StatisticsData({
    required this.orderStatistics,
    required this.topProducts,
    required this.hourlyData,
    required this.statusDistribution,
    required this.typeDistribution,
    required this.date,
  });

  factory StatisticsData.empty(DateTime date) {
    return StatisticsData(
      orderStatistics: OrderStatistics.empty(),
      topProducts: [],
      hourlyData: [],
      statusDistribution: [],
      typeDistribution: [],
      date: date,
    );
  }

  /// 是否有数据
  bool get hasData => orderStatistics.totalOrders > 0;
}
