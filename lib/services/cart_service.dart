import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../services/shop_service.dart';
import '../utils/debug.dart';

/// 购物车控制器 - 使用GetX状态管理
class CartController extends GetxController {

  // 购物车商品列表 - 使用GetX响应式变量
  final RxList<CartItem> _items = <CartItem>[].obs;
  
  
  // 批量操作标志
  bool _isBatchOperation = false;
  
  // 本地存储键名
  static const String _cartKey = 'cart_items';
  
  // SharedPreferences实例
  SharedPreferences? _prefs;

  /// 购物车商品列表 - GetX响应式
  List<CartItem> get items => _items;

  /// 购物车商品数量 - GetX响应式
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// 购物车总价 - GetX响应式
  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  @override
  void onInit() {
    super.onInit();
    _initializeCart();
  }

  /// 初始化购物车服务
  Future<void> _initializeCart() async {
    try {
      // Debug.log('开始初始化购物车服务...');
      _prefs = await SharedPreferences.getInstance();
      await _loadCartFromStorage();
      // Debug.log('购物车服务初始化完成，当前商品数量: ${_items.length}');
    } catch (e) {
      Debug.logError('购物车服务初始化失败', e);
    }
  }

  /// 添加商品到购物车
  void addItem(CoffeeProduct product, {int quantity = 1}) {
    try {
      Debug.log('添加商品到购物车: ${product.name} x $quantity');
      
      // 验证输入参数
      if (product.id.isEmpty) {
        Debug.logWarning('商品ID为空，无法添加到购物车');
        return;
      }
      
      if (quantity <= 0) {
        Debug.logWarning('商品数量必须大于0');
        return;
      }
      
      // 检查商品是否已存在
      final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
      
      if (existingIndex >= 0) {
        // 更新数量
        _items[existingIndex].quantity += quantity;
        Debug.log('更新商品数量: ${_items[existingIndex].quantity}');
        // 手动触发RxList更新
        _items.refresh();
        update(); // 触发GetX控制器更新
      } else {
        // 添加新商品
        final cartItem = CartItem(
          product: product,
          quantity: quantity,
        );
        _items.add(cartItem);
        Debug.log('添加新商品: ${product.name}');
        update(); // 触发GetX控制器更新
      }
      
      _saveCartToStorage();
    } catch (e) {
      Debug.logError('添加商品到购物车', e);
      // 确保在出错时也通知监听器，避免UI状态不一致
      _saveCartToStorage();
    }
  }

  /// 更新商品数量
  void updateQuantity(String productId, int quantity) {
    try {
      PhoneUtil.applog('更新商品数量: $productId -> $quantity');
      
      final index = _items.indexWhere((item) => item.product.id == productId);
      
      if (index >= 0) {
        if (quantity <= 0) {
          // 数量为0或负数，移除商品
          _items.removeAt(index);
          PhoneUtil.applog('移除商品: $productId');
          update(); // 触发GetX控制器更新
        } else {
          // 更新数量
          _items[index].quantity = quantity;
          PhoneUtil.applog('更新商品数量成功: $quantity');
          // 手动触发RxList更新
          _items.refresh();
          update(); // 触发GetX控制器更新
        }
        
        _saveCartToStorage();
      } else {
        PhoneUtil.applog('未找到商品: $productId');
      }
    } catch (e) {
      PhoneUtil.applog('更新商品数量失败: $e');
    }
  }

  /// 移除商品
  void removeItem(String productId) {
    try {
      PhoneUtil.applog('移除商品: $productId');
      
      _items.removeWhere((item) => item.product.id == productId);
      update(); // 触发GetX控制器更新
      _saveCartToStorage();
    } catch (e) {
      PhoneUtil.applog('移除商品失败: $e');
    }
  }

  /// 清空购物车
  void clearCart() {
    try {
      PhoneUtil.applog('清空购物车');
      
      _items.clear();
      update(); // 触发GetX控制器更新
      _clearCartStorage(); // 同时清空本地存储
      _saveCartToStorage();
    } catch (e) {
      PhoneUtil.applog('清空购物车失败: $e');
    }
  }

  /// 获取商品数量
  int getItemQuantity(String productId) {
    final item = _items.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => CartItem(product: CoffeeProduct(name: '', price: 0, description: ''), quantity: 0),
    );
    return item.quantity;
  }

  /// 检查商品是否在购物车中
  bool hasItem(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  /// 创建订单
  Future<Order> createOrder({
    required String userId,
    ShippingAddress? shippingAddress,
    String? notes,
    OrderType orderType = OrderType.delivery,
  }) async {
    try {
      PhoneUtil.applog('创建订单，商品数量: ${_items.length}');
      
      // 转换购物车商品为订单项
      final orderItems = _items.map((cartItem) {
        return OrderItem(
          productId: cartItem.product.id,
          productName: cartItem.product.name,
          price: cartItem.product.price,
          quantity: cartItem.quantity,
          imageBytes: cartItem.product.getMainImageBytes(),
        );
      }).toList();

      // 计算总价
      final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);
      
      // 计算配送费（根据店铺设置）
      final shopService = Get.find<ShopService>();
      final shippingFee = shopService.shop.value.calculateShippingFee(subtotal, orderType: orderType);

      // 创建订单（订单号在支付成功保存前才获取）
      final order = Order.create(
        userId: userId,
        items: orderItems,
        subtotal: subtotal,
        shippingFee: shippingFee,
        orderType: orderType,
        shippingAddress: shippingAddress,
        notes: notes,
        // orderNumber 不传递，默认为空字符串，在支付成功保存前才获取
      );

      PhoneUtil.applog('订单创建成功: ${order.id}');
      return order;
    } catch (e) {
      PhoneUtil.applog('创建订单失败: $e');
      rethrow;
    }
  }

  /// 开始批量操作
  void beginBatchOperation() {
    _isBatchOperation = true;
  }
  
  /// 结束批量操作
  void endBatchOperation() {
    _isBatchOperation = false;
    _notifyCartChanged();
  }

  /// 手动保存购物车到本地存储
  Future<void> saveCartToStorage() async {
    await _saveCartToStorage();
  }

  /// 手动从本地存储加载购物车
  Future<void> loadCartFromStorage() async {
    await _loadCartFromStorage();
  }

  /// 手动清空本地存储
  Future<void> clearCartStorage() async {
    await _clearCartStorage();
  }

  /// 调试方法：检查本地存储状态
  Future<void> debugStorageStatus() async {
    try {
      Debug.log('=== 购物车本地存储调试信息 ===');
      if (_prefs == null) {
        Debug.log('SharedPreferences 未初始化');
        return;
      }
      
      final jsonString = _prefs!.getString(_cartKey);
      if (jsonString == null || jsonString.isEmpty) {
        // Debug.log('本地存储中没有购物车数据');
      } else {
        // Debug.log('本地存储中有购物车数据，长度: ${jsonString.length}');
        Debug.log('本地存储数据: $jsonString');
      }
      
      Debug.log('当前购物车商品数量: ${_items.length}');
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        Debug.log('商品 $i: ${item.product.name} x ${item.quantity}');
      }
      Debug.log('=== 调试信息结束 ===');
    } catch (e) {
      Debug.logError('检查本地存储状态失败', e);
    }
  }

  /// 测试方法：添加测试商品并保存
  Future<void> testAddAndSave() async {
    try {
      Debug.log('开始测试添加商品并保存...');
      
      // 添加一个测试商品
      final testProduct = CoffeeProduct(
        name: '测试咖啡 ${DateTime.now().millisecondsSinceEpoch}',
        price: 25.0,
        description: '这是一个测试商品',
      );
      
      addItem(testProduct, quantity: 1);
      Debug.log('测试商品已添加到购物车');
      
      // 等待一下让保存操作完成
      await Future.delayed(Duration(milliseconds: 500));
      
      // 检查本地存储状态
      await debugStorageStatus();
      
    } catch (e) {
      Debug.logError('测试添加商品失败', e);
    }
  }

  /// 强制更新UI（用于调试）
  void forceUpdate() {
    _items.refresh();
    update(); // 手动触发GetX控制器更新
  }

  /// 测试响应式更新
  void testReactiveUpdate() {
    Debug.log('测试响应式更新 - 当前商品数量: $itemCount');
    update();
    Debug.log('已触发update()方法');
  }
  
  /// 保存购物车到本地存储
  Future<void> _saveCartToStorage() async {
    try {
      Debug.log('开始保存购物车数据到本地存储...');
      if (_prefs == null) {
        Debug.logWarning('SharedPreferences 未初始化，无法保存数据');
        return;
      }
      
      // 将购物车数据序列化为JSON
      final cartData = _items.map((item) => {
        'product': item.product.toJson(),
        'quantity': item.quantity,
      }).toList();
      
      Debug.log('准备保存 ${cartData.length} 个商品数据');
      final jsonString = jsonEncode(cartData);
      Debug.log('JSON字符串长度: ${jsonString.length}');
      
      await _prefs!.setString(_cartKey, jsonString);
      
      Debug.log('购物车数据已保存到本地存储');
    } catch (e) {
      Debug.logError('保存购物车数据失败', e);
    }
  }

  /// 从本地存储加载购物车
  Future<void> _loadCartFromStorage() async {
    try {
      // Debug.log('开始从本地存储加载购物车数据...');
      if (_prefs == null) {
        Debug.logWarning('SharedPreferences 未初始化，无法加载数据');
        return;
      }
      
      final jsonString = _prefs!.getString(_cartKey);
      // Debug.log('从本地存储读取的JSON字符串: ${jsonString?.substring(0, jsonString.length > 100 ? 100 : jsonString.length)}...');
      
      if (jsonString == null || jsonString.isEmpty) {
        // Debug.log('本地存储中没有购物车数据');
        return;
      }
      
      final List<dynamic> cartData = jsonDecode(jsonString);
      Debug.log('解析出 ${cartData.length} 个商品数据');
      _items.clear();
      
      for (int i = 0; i < cartData.length; i++) {
        try {
          final itemData = cartData[i];
          final product = CoffeeProduct.fromJson(itemData['product']);
          final quantity = itemData['quantity'] as int;
          
          _items.add(CartItem(
            product: product,
            quantity: quantity,
          ));
          Debug.log('成功添加商品: ${product.name} x $quantity');
        } catch (e) {
          Debug.logWarning('解析购物车商品 $i 失败: $e');
          continue;
        }
      }
      
      Debug.log('从本地存储加载了 ${_items.length} 个商品');
      // GetX会自动处理UI更新，不需要手动通知
    } catch (e) {
      Debug.logError('加载购物车数据失败', e);
    }
  }

  /// 清空本地存储的购物车数据
  Future<void> _clearCartStorage() async {
    try {
      if (_prefs == null) return;
      
      await _prefs!.remove(_cartKey);
      Debug.log('本地存储的购物车数据已清空');
    } catch (e) {
      Debug.logError('清空本地存储失败', e);
    }
  }

  /// 保存购物车数据（GetX自动处理UI更新）
  void _notifyCartChanged() {
    // 如果是批量操作，延迟保存
    if (_isBatchOperation) return;
    
    // 立即保存到本地存储（重要数据需要立即保存）
    _saveCartToStorage();
  }


}

/// 购物车商品项
class CartItem {
  final CoffeeProduct product;
  int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  /// 计算小计
  double get subtotal => product.price * quantity;

  /// 复制并更新数量
  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  String toString() {
    return 'CartItem(product: ${product.name}, quantity: $quantity, subtotal: $subtotal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && 
           other.product.id == product.id && 
           other.quantity == quantity;
  }

  @override
  int get hashCode => product.id.hashCode ^ quantity.hashCode;
}
