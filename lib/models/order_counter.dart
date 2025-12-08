/// 订单计数器模型
/// 用于维护当日订单数量，生成订单号
class OrderCounter {
  /// 当日订单数量
  int dailyOrderCount;
  
  /// 最后重置订单计数器的日期（格式：YYYY-MM-DD）
  String lastOrderCountResetDate;

  OrderCounter({
    this.dailyOrderCount = 0,
    this.lastOrderCountResetDate = "",
  });

  /// 从JSON构建对象
  factory OrderCounter.fromJson(Map<String, dynamic> json) {
    return OrderCounter(
      dailyOrderCount: (json['dailyOrderCount'] as num?)?.toInt() ?? 0,
      lastOrderCountResetDate: json['lastOrderCountResetDate'] as String? ?? "",
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'dailyOrderCount': dailyOrderCount,
      'lastOrderCountResetDate': lastOrderCountResetDate,
    };
  }

  /// 获取下一个订单号
  /// 返回格式化的订单号（0001-9999）
  /// 如果日期变化，自动重置计数器
  /// 超过9999后重新从0001开始
  String getNextOrderNumber() {
    try {
      // 获取当前日期（格式：YYYY-MM-DD）
      final now = DateTime.now();
      final currentDate = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      // 检查是否是新的日期，如果是则重置计数器
      if (lastOrderCountResetDate != currentDate) {
        dailyOrderCount = 0;
        lastOrderCountResetDate = currentDate;
      }
      
      // 递增计数器
      dailyOrderCount++;
      
      // 如果超过9999，重新从1开始
      if (dailyOrderCount > 9999) {
        dailyOrderCount = 1;
      }
      
      // 返回4位数字格式的订单号
      return dailyOrderCount.toString().padLeft(4, '0');
    } catch (e) {
      // 出错时返回默认值0001
      return "0001";
    }
  }
}

