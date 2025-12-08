
import '../../services/statistics_service.dart';
import '../../widgets/charts/bar_chart_widget.dart';
import '../../widgets/charts/pie_chart_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/order.dart';
import '../../models/statistics.dart';
import '../../utils/app_theme.dart';
import '../../utils/location.dart';
import '../../widgets/statistics_card.dart';

/// 统计页面组件
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateTime _selectedDate = DateTime.now();
  StatisticsData? _statisticsData;
  List<Order> _orders = [];
  final RxBool _isLoading = false.obs;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatisticsData();
  }

  Future<void> _loadStatisticsData() async {
    setState(() {
      _isLoading.value = true;
      _errorMessage = null;
    });

    try {
      final orders = await StatisticsService.loadOrdersByDate(_selectedDate);
      final statisticsData = StatisticsService.analyzeOrders(orders, _selectedDate);
      
      // Sort orders by createdAt in descending order (most recent first)
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      if (mounted) {
        setState(() {
          _statisticsData = statisticsData;
          _orders = orders;
          _isLoading.value = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading.value = false;
        });
      }
    }
  }


  void _showDatePicker(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 420.w, // 增加宽度，给星期文本更多空间
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Table Calendar
              TableCalendar<dynamic>(
                firstDay: DateTime(2020),
                lastDay: DateTime.now(),
                focusedDay: _selectedDate,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDate, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                  });
                  _loadStatisticsData();
                  Navigator.of(context).pop();
                },
                // 自定义星期显示
                daysOfWeekHeight: 35.h, // 设置星期行的高度
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: EdgeInsets.all(2.w),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: EdgeInsets.all(2.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: EdgeInsets.all(2.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(
                    color: Colors.red[400],
                    fontSize: 14.sp,
                  ),
                  defaultTextStyle: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black87,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: AppTheme.primaryBlue,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    fontSize: 11.sp, // 减小字体大小
                    fontWeight: FontWeight.w500, // 减轻字重
                    color: Colors.grey[600],
                  ),
                  weekendStyle: TextStyle(
                    fontSize: 11.sp, // 减小字体大小
                    fontWeight: FontWeight.w500, // 减轻字重
                    color: Colors.red[400],
                  ),
                ),
                rowHeight: 45.h, // 增加行高，给星期文本更多垂直空间
                availableGestures: AvailableGestures.all,
              ),
              
              SizedBox(height: 20.h),
              
              // 按钮区域
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 取消按钮
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(LocationUtils.translate('Cancel')),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // 确认按钮
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(LocationUtils.translate('Confirm')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期选择器
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 日期图标
                Icon(
                  Icons.calendar_today,
                  size: 20.w,
                  color: AppTheme.primaryBlue,
                ),
                SizedBox(width: 12.w),
                
                // 日期显示
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocationUtils.translate('Select Statistics Date'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        DateFormat('yyyy-MM-dd EEEE').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 选择按钮
                GestureDetector(
                  onTap: () => _showDatePicker(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16.w,
                          color: AppTheme.primaryBlue,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          LocationUtils.translate('Select'),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // 统计内容容器（带边框）
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(

            ),
            child: Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w,  bottom: 16.h),
              child: _isLoading.value
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _statisticsData == null || !_statisticsData!.hasData
                          ? _buildEmptyState()
                          : _buildStatisticsContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 400.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
            SizedBox(height: 16.h),
            Text(
              LocationUtils.translate('Loading statistics data...'),
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 400.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.w,
              color: Colors.red[400],
            ),
            SizedBox(height: 16.h),
            Text(
              LocationUtils.translate('Failed to load data'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _errorMessage ?? LocationUtils.translate('Unknown error'),
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _loadStatisticsData,
              icon: Icon(Icons.refresh, size: 18.w),
              label: Text(LocationUtils.translate('Retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 400.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              LocationUtils.translate('No Data'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '${LocationUtils.translate('No order data for')} ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsContent() {
    final data = _statisticsData!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 基础数据卡片
        _buildBasicStatisticsCards(data.orderStatistics),
        
        SizedBox(height: 20.h),
        
        // 商品销量排行
        _buildTopProductsCard(data.topProducts),
        
        SizedBox(height: 20.h),
        
        // 图表区域
        _buildChartsSection(data),
        
        SizedBox(height: 20.h),
        
        // 订单列表
        _buildOrderListCard(),
      ],
    );
  }

  Widget _buildBasicStatisticsCards(OrderStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocationUtils.translate('Basic Statistics'),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12.h),
        // 使用单列布局，每个卡片占据最大宽度
        Column(
          children: [
            StatisticsCard(
              title: LocationUtils.translate('Total Orders'),
              value: stats.totalOrders.toString(),
              icon: Icons.receipt_long,
              iconColor: AppTheme.primaryBlue,
            ),
            SizedBox(height: 12.h),
            StatisticsCard(
              title: LocationUtils.translate('Total Revenue'),
              value: '\$${stats.totalRevenue.toStringAsFixed(2)}',
              icon: Icons.attach_money,
              iconColor: Colors.green,
            ),
            SizedBox(height: 12.h),
            StatisticsCard(
              title: LocationUtils.translate('Average Order'),
              value: '\$${stats.averageOrderAmount.toStringAsFixed(2)}',
              icon: Icons.trending_up,
              iconColor: Colors.orange,
            ),
            SizedBox(height: 12.h),
            StatisticsCard(
              title: LocationUtils.translate('Payment Success Rate'),
              value: '${stats.paymentSuccessRate.toStringAsFixed(1)}%',
              icon: Icons.check_circle,
              iconColor: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopProductsCard(List<ProductSaleItem> topProducts) {
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
              LocationUtils.translate('Top Products'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12.h),
            if (topProducts.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32.w),
                  child: Text(
                    LocationUtils.translate('No product data'),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              )
            else
              ...topProducts.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return ProductSaleCard(
                  productName: product.productName,
                  quantity: product.quantity,
                  revenue: product.revenue,
                  percentage: product.percentage,
                  rank: index + 1,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListCard() {
    if (_orders.isEmpty) {
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
                LocationUtils.translate('All Orders'),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12.h),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32.w),
                  child: Text(
                    LocationUtils.translate('No orders'),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 4.w, right: 4.w, top: 6.h, bottom: 6.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocationUtils.translate('All Orders'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12.h),
            ..._orders.map((order) => _buildOrderRow(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderRow(Order order) {
    // Build items string, truncate if too long
    String itemsText = order.items.map((item) => '${item.productName} x${item.quantity}').join(', ');
    if (itemsText.length > 50) {
      itemsText = '${itemsText.substring(0, 47)}...';
    }

    // Format order time
    final timeText = DateFormat('HH:mm').format(order.createdAt);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.only(left: 4.w, right: 4.w, top: 4.h, bottom: 4.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
     
          
          // Items (truncated)
          Expanded(
            flex: 4,
            child: Text(
              itemsText,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          SizedBox(width: 8.w),
          
          // Total price
          Expanded(
            flex: 2,
            child: Text(
              '\$${order.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          
          SizedBox(width: 8.w),
          
          // Order time
          Expanded(
            flex: 1,
            child: Text(
              timeText,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          
          SizedBox(width: 8.w),
          
          // Detail button
          ElevatedButton(
            onPressed: () => _showOrderDetailDialog(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              minimumSize: Size(0, 28.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
            child: Text(
              LocationUtils.translate('Detail'),
              style: TextStyle(
                fontSize: 11.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Order Details')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Order basic info
              _buildOrderInfoRow(LocationUtils.translate('Order Number'), order.orderNumber),
              _buildOrderInfoRow('User ID', order.userId),
              _buildOrderInfoRow(LocationUtils.translate('Status'), order.getStatusText()),
              _buildOrderInfoRow(LocationUtils.translate('Total Amount'), '\$${order.totalAmount.toStringAsFixed(2)}'),
              _buildOrderInfoRow(LocationUtils.translate('Order Time'), _formatDateTime(order.createdAt)),
              if (order.updatedAt != order.createdAt)
                _buildOrderInfoRow(LocationUtils.translate('Updated At'), _formatDateTime(order.updatedAt)),
              
              SizedBox(height: 16.h),
              
              // Items list
              if (order.items.isNotEmpty) ...[
                Text(
                  LocationUtils.translate('Product List:'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                ...order.items.map((item) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.productName} x${item.quantity}'),
                        Text('\$${item.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                }),
              ],
              
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Text(
                  '${LocationUtils.translate('Notes')}: ${order.notes}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocationUtils.translate('Close')),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 13.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[900],
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  Widget _buildChartsSection(StatisticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocationUtils.translate('Data Analysis'),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 6.h),
        
        // 时段分析柱状图
        BarChartWidget(
          data: data.hourlyData,
          title: '${LocationUtils.translate('Hourly Order Distribution')})',
        ),
        
        SizedBox(height: 8.h),
        
        // 订单类型分布饼图
        PieChartWidget(
          typeData: data.typeDistribution,
          title: LocationUtils.translate('Order Type Distribution'),
          isStatusChart: false,
        ),
      ],
    );
  }
}

