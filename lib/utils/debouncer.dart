import 'dart:async';
import 'package:flutter/foundation.dart';

/// 防抖器工具类
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// 执行防抖操作
  void call(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  /// 取消防抖操作
  void cancel() {
    _timer?.cancel();
  }

  /// 检查是否有待执行的操作
  bool get isActive => _timer?.isActive ?? false;

  /// 立即执行并取消防抖
  void flush(VoidCallback callback) {
    _timer?.cancel();
    callback();
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// 节流器工具类
class Throttler {
  final Duration delay;
  Timer? _timer;
  bool _isThrottling = false;

  Throttler({this.delay = const Duration(milliseconds: 500)});

  /// 执行节流操作
  void call(VoidCallback callback) {
    if (_isThrottling) return;
    
    _isThrottling = true;
    callback();
    
    _timer?.cancel();
    _timer = Timer(delay, () {
      _isThrottling = false;
    });
  }

  /// 取消节流操作
  void cancel() {
    _timer?.cancel();
    _isThrottling = false;
  }

  /// 检查是否正在节流
  bool get isThrottling => _isThrottling;

  void dispose() {
    _timer?.cancel();
  }
}
