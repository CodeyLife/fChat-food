import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../models/order_counter.dart';
import '../utils/constants.dart';
import '../utils/file_utils.dart';
import '../utils/debug.dart';

/// 订单计数器服务
/// 负责管理订单计数器的文件读写和订单号生成
class OrderCounterService extends GetxController {
  static OrderCounterService get instance => Get.find<OrderCounterService>();
  
  final Rx<OrderCounter> _counter = OrderCounter().obs;
  final RxBool _isLoading = false.obs;
  final RxBool _isSaving = false.obs;

  /// 获取当前计数器
  OrderCounter get counter => _counter.value;
  
  /// 是否正在加载
  bool get isLoading => _isLoading.value;
  
  /// 是否正在保存
  bool get isSaving => _isSaving.value;


  /// 加载订单计数器
  /// 每次调用都会重新读取文件，确保获取最新的订单计数器状态
  Future<void> loadOrderCounter() async {
    try {
      _isLoading.value = true;
      
      // 使用getDirectoryFirstFile方法读取第一个文件
      final counterString = await FileUtils.readFile(AppConstants.orderCounterMD, 'order_counter');
      if (counterString != null) {
        final counter = OrderCounter.fromJson(counterString);
        _counter.value = counter;
        Debug.log('订单计数器加载成功: dailyOrderCount=${counter.dailyOrderCount}, lastOrderCountResetDate=${counter.lastOrderCountResetDate}');
      } else {
        Debug.log('未找到订单计数器文件，使用默认设置');
        _counter.value = OrderCounter();
        //创建订单计数器文件
        FileUtils.createFile(AppConstants.orderCounterMD, jsonEncode(_counter.value.toJson()), 'order_counter');
      }
    } catch (e) {
      Debug.log('加载订单计数器失败: $e');
      // 使用默认值
      _counter.value = OrderCounter();
    } finally {
      _isLoading.value = false;
    }
  }

  /// 保存订单计数器
  Future<bool> saveOrderCounter() async {
    try {
      _isSaving.value = true;
      
      // 将订单计数器转换为JSON
      final counterJson = _counter.value.toJson();
      final counterJsonString = jsonEncode(counterJson);

      // 使用saveToFirstFile方法保存到第一个 更新文件
      return  await FileUtils.updateFile(AppConstants.orderCounterMD, 'order_counter', counterJsonString);
    } catch (e) {
      Debug.log('保存订单计数器失败: $e');
      return false;
    } finally {
      _isSaving.value = false;
    }
  }

  /// 获取下一个订单号（同步方法，不保存）
  /// 返回格式化的订单号（0001-9999）
  /// 注意：此方法不会重新加载文件，需要先调用 loadOrderCounter() 确保文件已读取
  /// 调用此方法后需要调用 saveOrderCounter() 保存
  String getNextOrderNumberSync() {
    try {
      return _counter.value.getNextOrderNumber();
    } catch (e) {
      Debug.log('获取订单号失败: $e');
      // 出错时返回默认值0001
      return "0001";
    }
  }

  /// 获取下一个订单号（不保存）
  /// 返回格式化的订单号（0001-9999）
  /// 会先重新读取文件，确保获取最新的订单计数器状态
  Future<String> getNextOrderNumber() async {
    try {
      // 重新加载文件，确保获取最新的订单计数器状态
      await loadOrderCounter();
      
      // 获取下一个订单号（会自动更新计数器）
      final orderNumber = getNextOrderNumberSync();
      
      unawaited(saveOrderCounter()); //不阻塞主线程
      // 不再自动保存，需要在支付成功后手动保存
      return orderNumber;
    } catch (e) {
      Debug.log('获取订单号失败: $e');
      // 出错时返回默认值0001
      return "0001";
    }
  }
}

