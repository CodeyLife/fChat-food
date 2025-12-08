import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/statistics.dart';
import '../../utils/app_theme.dart';
import '../../utils/location.dart';

/// 柱状图组件
class BarChartWidget extends StatelessWidget {
  final List<HourlyStatistics> data;
  final String title;
  final double? maxValue;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
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
            SizedBox(height: 12.h),
            SizedBox(
              height: 200.h,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue ?? _getMaxValue(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final index = group.x.toInt();
                        if (index >= 0 && index < data.length) {
                          final hour = data[index].hour;
                          final count = data[index].orderCount;
                          return BarTooltipItem(
                            '${hour.toString().padLeft(2, '0')}:00\n$count ${LocationUtils.translate('orders')}',
                            TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                            ),
                          );
                        }
                        return BarTooltipItem(
                          'N/A',
                          TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.length) {
                            final hour = data[index].hour;
                            if (hour % 4 == 0) { // 每4小时显示一个标签
                              return Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                style: TextStyle(
                                  fontSize: 12.sp, // 更小的字体
                                  color: Colors.grey[600],
                                  height: 0.9, // 更小的行高
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _getLeftTitlesInterval(), // 控制左侧标签间隔
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _getBarGroups(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getHorizontalInterval(), // 控制水平网格线间隔
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[200]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups() {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: item.orderCount.toDouble(),
            color: AppTheme.primaryBlue,
            width: 12.w,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ],
      );
    }).toList();
  }

  double _getMaxValue() {
    if (data.isEmpty) return 10;
    final maxCount = data.map((e) => e.orderCount).reduce((a, b) => a > b ? a : b);
    return (maxCount * 1.2).ceilToDouble(); // 留20%余量
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
              height: 200.h, // 与正常状态保持一致的高度
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 48.w,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'No data',
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

  /// 计算水平网格线间隔
  double _getHorizontalInterval() {
    final maxVal = maxValue ?? _getMaxValue();
    
    // 根据最大值动态计算合适的间隔
    if (maxVal <= 5) {
      return 1.0; // 小数值，每1个单位一条线
    } else if (maxVal <= 20) {
      return 2.0; // 中等数值，每2个单位一条线
    } else if (maxVal <= 50) {
      return 5.0; // 较大数值，每5个单位一条线
    } else if (maxVal <= 100) {
      return 10.0; // 大数值，每10个单位一条线
    } else {
      return (maxVal / 10).ceil().toDouble(); // 超大数值，动态计算
    }
  }

  /// 计算左侧标签间隔
  double _getLeftTitlesInterval() {
    final maxVal = maxValue ?? _getMaxValue();
    
    // 根据最大值动态计算合适的标签间隔
    if (maxVal <= 5) {
      return 1.0; // 显示 0, 1, 2, 3, 4, 5
    } else if (maxVal <= 10) {
      return 2.0; // 显示 0, 2, 4, 6, 8, 10
    } else if (maxVal <= 20) {
      return 5.0; // 显示 0, 5, 10, 15, 20
    } else if (maxVal <= 50) {
      return 10.0; // 显示 0, 10, 20, 30, 40, 50
    } else if (maxVal <= 100) {
      return 20.0; // 显示 0, 20, 40, 60, 80, 100
    } else {
      return (maxVal / 5).ceil().toDouble(); // 超大数值，显示5个标签
    }
  }

}
