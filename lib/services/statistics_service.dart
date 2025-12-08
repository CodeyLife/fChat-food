import 'dart:async';
import 'package:fchat_food/utils/constants.dart';
import 'package:fchat_food/utils/file_utils.dart';

import '../models/order.dart';
import '../models/statistics.dart';
import '../utils/debug.dart';
import 'package:intl/intl.dart';

/// 统计数据服务类
class StatisticsService {
  /// 根据日期读取订单数据
  static Future<List<Order>> loadOrdersByDate(DateTime date) async {
    try {
      Debug.log('开始读取日期 ${DateFormat('yyyy-MM-dd').format(date)} 的订单数据');
      
      // 生成日期目录名
      final dateString = DateFormat('yyyyMMdd').format(date);
      final directoryName = 'buy$dateString';
      Debug.log('目录名称: $directoryName');
      final maps = await FileUtils.readDirectory(AppConstants.getBuyDayMD());
      List<Order> orders = [];
      for(Map<String, dynamic> map in maps){
        final order = Order.fromJson(map);
        orders.add(order);
      }
      return orders;
    } catch (e) {
      Debug.log('读取订单数据失败: $e');
      return [];
    }
  }

  /// 分析订单数据
  static StatisticsData analyzeOrders(List<Order> orders, DateTime date) {
    if (orders.isEmpty) {
      return StatisticsData.empty(date);
    }

    // 基础统计数据
    final orderStatistics = _calculateOrderStatistics(orders);
    
    // 商品销量排行
    final topProducts = _calculateTopProducts(orders);
    
    // 时段统计数据
    final hourlyData = _calculateHourlyStatistics(orders);
    
    // 订单状态分布
    final statusDistribution = _calculateStatusDistribution(orders);
    
    // 订单类型分布
    final typeDistribution = _calculateTypeDistribution(orders);

    return StatisticsData(
      orderStatistics: orderStatistics,
      topProducts: topProducts,
      hourlyData: hourlyData,
      statusDistribution: statusDistribution,
      typeDistribution: typeDistribution,
      date: date,
    );
  }

  /// 计算基础统计数据
  static OrderStatistics _calculateOrderStatistics(List<Order> orders) {
    final totalOrders = orders.length;
    final totalRevenue = orders.fold(0.0, (sum, order) => sum + order.totalAmount);
    final averageOrderAmount = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    
    final completedOrders = orders.where((o) => o.status == OrderStatus.completed).length;
    final cancelledOrders = orders.where((o) => o.status == OrderStatus.cancelled).length;
    final paidOrders = orders.where((o) => o.status != OrderStatus.pending).length;
    final pendingOrders = orders.where((o) => o.status == OrderStatus.pending).length;
    final paymentSuccessRate = totalOrders > 0 ? (paidOrders / totalOrders) * 100 : 0.0;

    return OrderStatistics(
      totalOrders: totalOrders,
      totalRevenue: totalRevenue,
      averageOrderAmount: averageOrderAmount,
      completedOrders: completedOrders,
      cancelledOrders: cancelledOrders,
      paidOrders: paidOrders,
      pendingOrders: pendingOrders,
      paymentSuccessRate: paymentSuccessRate,
    );
  }

  /// 计算商品销量排行
  static List<ProductSaleItem> _calculateTopProducts(List<Order> orders) {
    Map<String, ProductSaleItem> productMap = {};
    
    for (Order order in orders) {
      for (OrderItem item in order.items) {
        if (productMap.containsKey(item.productId)) {
          final existing = productMap[item.productId]!;
          productMap[item.productId] = ProductSaleItem(
            productId: item.productId,
            productName: item.productName,
            quantity: existing.quantity + item.quantity,
            revenue: existing.revenue + item.subtotal,
            percentage: 0.0, // 稍后计算
          );
        } else {
          productMap[item.productId] = ProductSaleItem(
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            revenue: item.subtotal,
            percentage: 0.0, // 稍后计算
          );
        }
      }
    }
    
    // 计算总销量和占比
    final totalQuantity = productMap.values.fold(0, (sum, item) => sum + item.quantity);
    
    // 更新占比并排序
    List<ProductSaleItem> products = productMap.values.map((item) {
      return ProductSaleItem(
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        revenue: item.revenue,
        percentage: totalQuantity > 0 ? (item.quantity / totalQuantity) * 100 : 0.0,
      );
    }).toList();
    
    // 按销量降序排列，取前10名
    products.sort((a, b) => b.quantity.compareTo(a.quantity));
    return products.take(10).toList();
  }

  /// 计算时段统计数据
  static List<HourlyStatistics> _calculateHourlyStatistics(List<Order> orders) {
    Map<int, int> hourOrderCount = {};
    Map<int, double> hourRevenue = {};
    
    // 初始化24小时数据
    for (int hour = 0; hour < 24; hour++) {
      hourOrderCount[hour] = 0;
      hourRevenue[hour] = 0.0;
    }
    
    // 统计每个时段的订单
    for (Order order in orders) {
      final hour = order.createdAt.hour;
      hourOrderCount[hour] = (hourOrderCount[hour] ?? 0) + 1;
      hourRevenue[hour] = (hourRevenue[hour] ?? 0.0) + order.totalAmount;
    }
    
    // 转换为列表
    List<HourlyStatistics> hourlyData = [];
    for (int hour = 0; hour < 24; hour++) {
      hourlyData.add(HourlyStatistics(
        hour: hour,
        orderCount: hourOrderCount[hour] ?? 0,
        revenue: hourRevenue[hour] ?? 0.0,
      ));
    }
    
    return hourlyData;
  }

  /// 计算订单状态分布
  static List<OrderStatusDistribution> _calculateStatusDistribution(List<Order> orders) {
    Map<OrderStatus, int> statusCount = {};
    
    // 统计各状态订单数量
    for (Order order in orders) {
      statusCount[order.status] = (statusCount[order.status] ?? 0) + 1;
    }
    
    final totalOrders = orders.length;
    
    // 转换为分布数据
    List<OrderStatusDistribution> distribution = [];
    for (OrderStatus status in OrderStatus.values) {
      final count = statusCount[status] ?? 0;
      if (count > 0) {
        distribution.add(OrderStatusDistribution(
          status: status,
          count: count,
          percentage: totalOrders > 0 ? (count / totalOrders) * 100 : 0.0,
        ));
      }
    }
    
    return distribution;
  }

  /// 计算订单类型分布
  static List<OrderTypeDistribution> _calculateTypeDistribution(List<Order> orders) {
    Map<OrderType, int> typeCount = {};
    
    // 统计各类型订单数量
    for (Order order in orders) {
      typeCount[order.orderType] = (typeCount[order.orderType] ?? 0) + 1;
    }
    
    final totalOrders = orders.length;
    
    // 转换为分布数据
    List<OrderTypeDistribution> distribution = [];
    for (OrderType type in OrderType.values) {
      final count = typeCount[type] ?? 0;
      if (count > 0) {
        distribution.add(OrderTypeDistribution(
          orderType: type,
          count: count,
          percentage: totalOrders > 0 ? (count / totalOrders) * 100 : 0.0,
        ));
      }
    }
    
    return distribution;
  }
}
