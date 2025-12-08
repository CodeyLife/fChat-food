import '../services/app_state_service.dart';
import '../services/shop_service.dart';
import '../services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../services/cart_service.dart';
import '../services/payment_service.dart';
import '../utils/debug.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/screen_util.dart';
import '../widgets/luckin_components.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: GetBuilder<CartController>(
          builder: (cartController) {
            return cartController.items.isEmpty ? _buildEmptyCart() : _buildCartList(cartController);
          },
        ),
      ),
    );
  }

  /// 构建空购物车页面
  Widget _buildEmptyCart() {
    return LuckinEmptyState(
      icon: Icons.shopping_cart_outlined,
      title: LocationUtils.translate('Cart is empty'),
      subtitle: LocationUtils.translate('Go shopping for your favorite products'),
      buttonText: LocationUtils.translate('Go Shopping'),
      onButtonTap: () {
         AppStateService().switchToPage(1);
      },
    );
  }

  /// 构建购物车列表
  Widget _buildCartList(CartController cartController) {
    final columns = AppScreenUtil.getLandscapeCartColumns(context);
    
    return Column(
      children: [
        Expanded(
          child: columns > 1 
              ? _buildCartGrid(cartController, columns)
              : _buildCartListView(cartController),
        ),
        _buildCheckoutBar(cartController),
      ],
    );
  }

  /// 构建购物车网格布局（横屏）
  Widget _buildCartGrid(CartController cartController, int columns) {
    return GridView.builder(
      padding: EdgeInsets.all(AppSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.5,
      ),
      itemCount: cartController.items.length,
      itemBuilder: (context, index) {
        final item = cartController.items[index];
        return LuckinCartItem(
          name: item.product.name,
          price: item.product.price.toStringAsFixed(2),
          quantity: item.quantity,
          imageBytes: item.product.getMainImageBytes(),
          onIncrease: () => _increaseQuantity(item.product.id, cartController),
          onDecrease: () => _decreaseQuantity(item.product.id, cartController),
          onRemove: () => _removeItem(item.product.id, cartController),
        );
      },
    );
  }

  /// 构建购物车列表布局（竖屏）
  Widget _buildCartListView(CartController cartController) {
    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.lg),
      itemCount: cartController.items.length,
      itemBuilder: (context, index) {
        final item = cartController.items[index];
        return LuckinCartItem(
          name: item.product.name,
          price: item.product.price.toStringAsFixed(2),
          quantity: item.quantity,
          imageBytes: item.product.getMainImageBytes(),
          onIncrease: () => _increaseQuantity(item.product.id, cartController),
          onDecrease: () => _decreaseQuantity(item.product.id, cartController),
          onRemove: () => _removeItem(item.product.id, cartController),
        );
      },
    );
  }


  /// 构建结算栏
  Widget _buildCheckoutBar(CartController cartController) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        boxShadow: AppShadows.xl,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.primaryBlue.withValues(alpha:0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
         
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
              Text(
                    '${LocationUtils.translate('Total')}: ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                   Text(
                      '${ShopService.instance.shop.value.symbol.value}${cartController.totalPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentRed,
                      ),
                    ),
            Spacer(),
            Container(
              decoration: BoxDecoration(
                gradient: cartController.totalPrice > 0 
                    ? AppTheme.primaryGradient 
                    : LinearGradient(
                        colors: [
                          AppTheme.textHint,
                          AppTheme.textHint.withValues(alpha:0.7),
                        ],
                      ),
                borderRadius: AppRadius.lg,
                boxShadow: cartController.totalPrice > 0 ? AppShadows.button : null,
              ),
              child: ElevatedButton(
                onPressed: cartController.totalPrice > 0 ? () => _checkout(cartController) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.lg,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  LocationUtils.translate('Checkout'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 减少数量
  void _decreaseQuantity(String productId, CartController cartController) {
    final currentQuantity = cartController.getItemQuantity(productId);
    if (currentQuantity > 1) {
      cartController.updateQuantity(productId, currentQuantity - 1);
    } else {
      cartController.removeItem(productId);
    }
  }

  /// 增加数量
  void _increaseQuantity(String productId, CartController cartController) {
    final currentQuantity = cartController.getItemQuantity(productId);
    cartController.updateQuantity(productId, currentQuantity + 1);
  }

  /// 删除商品
  void _removeItem(String productId, CartController cartController) {
    cartController.removeItem(productId);
  }


  /// 结算
  Future<void> _checkout(CartController cartController) async {
    try {
      // 使用配置服务获取当前用户ID
      final userId = UserService.instance.currentUser?.userId ?? '';
      
      // 创建订单（异步，先获取订单号）
      final order = await cartController.createOrder(userId: userId);
      
      // 使用统一支付服务
      PaymentService.processPayment(
        order: order,
        source: PaymentSource.cart,
        context: context,
        isFromCart: true,
      );
    } catch (e) {
      Debug.showUserFriendlyError('创建订单失败: $e');
    }
  }
}
