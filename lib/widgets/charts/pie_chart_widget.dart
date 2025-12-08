import '../../utils/location.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/statistics.dart';
import '../../models/order.dart';
import '../../utils/app_theme.dart';

/// 饼图组件
class PieChartWidget extends StatelessWidget {
  final List<OrderStatusDistribution>? statusData;
  final List<OrderTypeDistribution>? typeData;
  final String title;
  final bool isStatusChart;

  const PieChartWidget({
    super.key,
    this.statusData,
    this.typeData,
    required this.title,
    this.isStatusChart = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = isStatusChart ? statusData : typeData;
    
    if (data == null || data.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                // 饼图
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 200.h,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            // 可以添加点击交互
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40.r,
                        sections: _getSections(data),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                // 图例
                Expanded(
                  flex: 1,
                  child: _buildLegend(data),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getSections(dynamic data) {
    final colors = [
      AppTheme.primaryBlue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.cyan,
      Colors.amber,
      Colors.teal,
    ];

    List<PieChartSectionData> sections = [];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final color = colors[i % colors.length];
      
      sections.add(PieChartSectionData(
        color: color,
        value: item.percentage,
        title: '${item.percentage.toStringAsFixed(1)}%',
        radius: 50.r,
        titleStyle: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    return sections;
  }

  Widget _buildLegend(dynamic data) {
    final colors = [
      AppTheme.primaryBlue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.cyan,
      Colors.amber,
      Colors.teal,
    ];

    List<Widget> legendItems = [];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final color = colors[i % colors.length];
      
      String label;
      if (isStatusChart) {
        label = _getStatusLabel(item.status);
      } else {
        label = _getTypeLabel(item.orderType);
      }
      
      legendItems.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Row(
            children: [
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  LocationUtils.translate(label),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${item.count}',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: legendItems,
    );
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.paid:
        return 'Paid';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.timeout:
        return 'Timeout';
    }
  }

  String _getTypeLabel(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return 'Dine In';
      case OrderType.delivery:
        return 'Delivery';
    }
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart,
                      size: 48.w,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      LocationUtils.translate('No data'),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
