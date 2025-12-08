import '../services/shop_service.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quickalert/quickalert.dart';
import 'package:card_swiper/card_swiper.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../services/payment_service.dart';
import '../services/image_cache_service.dart';
import '../utils/debug.dart';
import '../widgets/async_image_widget.dart';
import '../widgets/video_player_widget.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/snackbar_utils.dart';

class ProductDetailScreen extends StatefulWidget {
  final CoffeeProduct product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

/// 混合媒体项类型
enum MediaType { video, image }

/// 混合媒体项
class MediaItem {
  final MediaType type;
  final String? videoUrl;
  final ImageObj? imageObj;
  
  MediaItem.video(this.videoUrl) : type = MediaType.video, imageObj = null;
  MediaItem.image(this.imageObj) : type = MediaType.image, videoUrl = null;
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _currentMediaIndex = 0;
  bool _isProcessing = false;
  final SwiperController _swiperController = SwiperController();
  final List<MediaItem> _mediaItems = [];

  @override
  void initState() {
    super.initState();
    _initializeMediaItems();
    _preloadProductImages();
  }

  /// 初始化媒体项列表
  void _initializeMediaItems() {
    _mediaItems.clear();
    
    // 如果有视频URL，将视频作为第一个项目
    if (widget.product.videoUrl.isNotEmpty) {
      _mediaItems.add(MediaItem.video(widget.product.videoUrl));
    }
    
    // 添加所有图片
    final images = widget.product.productImages?.images ?? [];
    for (var image in images) {
      _mediaItems.add(MediaItem.image(image));
    }
  }

  /// 预加载商品的所有图片到缓存
  void _preloadProductImages() {
    try {
      final imageCacheService = Get.find<ImageCacheService>();
      final images = widget.product.productImages?.images ?? [];
      
      Debug.log('🖼️ 开始预加载商品图片: ${widget.product.name} (${images.length}张)');
      
      // 预加载所有图片
      for (var imageObj in images) {
        if (imageObj.md5.isNotEmpty) {
          imageCacheService.preloadImage(imageObj.md5);
          Debug.log('📸 预加载图片: ${imageObj.md5}');
        }
      }
      
      Debug.log('✅ 商品图片预加载完成: ${widget.product.name}');
    } catch (e) {
      Debug.log('❌ 预加载商品图片失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 可滚动的内容区域
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 商品图片轮播
                      _buildImageCarousel(),
                      
                      // 商品信息（包含描述）
                      _buildProductInfo(),
                      
                      // 为底部操作栏预留空间，确保内容不会被遮挡
                      SizedBox(height: 200.h),
                    ],
                  ),
                ),
                
                // 固定在左上角的返回按钮
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16.h,
                  left: 16.w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(200),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 3,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      iconSize: 24.r,
                      padding: EdgeInsets.all(8),
                      constraints: BoxConstraints(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 底部操作栏
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  /// 构建媒体轮播
  Widget _buildImageCarousel() {
    return Container(
      height: 300.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryBlue.withValues(alpha:0.05),
            Colors.grey[50]!,
          ],
        ),
      ),
      child: Stack(
        children: [
          _mediaItems.isEmpty
              ? _buildPlaceholderImage()
              : Swiper(
                  controller: _swiperController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  pagination: SwiperPagination(
                    builder: DotSwiperPaginationBuilder(
                      color: Colors.white.withValues(alpha:0.4),
                      activeColor: AppTheme.primaryBlue,
                      size: 8.0,
                      activeSize: 10.0,
                      space: 6.0,
                    ),
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return _buildMediaItem(_mediaItems[index]);
                  },
                  itemCount: _mediaItems.length,
                  duration: 300,
                  loop: _mediaItems.length > 1,
                  scrollDirection: Axis.horizontal,
                  onIndexChanged: (index) {
                    setState(() {
                      _currentMediaIndex = index;
                    });
                  },
                ),
          
          // 媒体数量指示器
          if (_mediaItems.length > 1)
            Positioned(
              top: 16.h,
              right: 16.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16.w),
                ),
                child: Text(
                  '${_currentMediaIndex + 1}/${_mediaItems.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建媒体项
  Widget _buildMediaItem(MediaItem mediaItem) {
    return Container(
      width: double.infinity,
      height: 300.h,
      decoration: BoxDecoration(
      //  borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
    //    borderRadius: BorderRadius.circular(12.w),
        child: mediaItem.type == MediaType.video
            ? _buildVideoPlayer(mediaItem.videoUrl!)
            : _buildImageWidget(mediaItem.imageObj!),
      ),
    );
  }

  /// 构建视频播放器
  Widget _buildVideoPlayer(String videoUrl) {
    return VideoPlayerWidget(
      videoUrl: videoUrl,
      width: double.infinity,
      height: 300.h,
      borderRadius: 0,
    );
  }

  /// 构建图片组件
  Widget _buildImageWidget(ImageObj image) {
    return AsyncImageWidget(
      imageobj: image,
      width: double.infinity,
      height: 300.h,
      fit: BoxFit.cover,
    );
  }

  /// 构建占位图片
  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 300.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryBlue.withValues(alpha:0.1),
            AppTheme.primaryBlue.withValues(alpha:0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_cafe_outlined,
            size: 60.w,
            color: AppTheme.primaryBlue.withValues(alpha:0.3),
          ),
          SizedBox(height: 12.h),
          Text(
            '暂无商品图片',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建商品信息
  Widget _buildProductInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 0.w),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha:0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品价格
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
           Text(widget.product.name,
           style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
           ),),
           Spacer(),
           Text(
                '${ShopService.symbol.value}${widget.product.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 241, 87, 87),
                ),
              )
            ],
          ),
          // 分类标签
          if (widget.product.category.isNotEmpty)
                   Text(
                  widget.product.category,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
          
          SizedBox(height: 20.h),
          
          // 商品描述
          Text(
            widget.product.description,
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.textSecondary,
              height: 1.7,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha:0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha:0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 使用Flexible和Wrap来确保按钮不会换行
          LayoutBuilder(
            builder: (context, constraints) {
         
                return Column(
                  children: [
                    // 数量选择
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _quantity > 1 ? _decreaseQuantity : null,
                            icon: Icon(Icons.remove, size: 20.w),
                            color: _quantity > 1 ? AppTheme.primaryBlue : Colors.grey,
                          ),
                          SizedBox(
                            width: 40.w,
                            child: Text(
                              '$_quantity',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _increaseQuantity,
                            icon: Icon(Icons.add, size: 20.w),
                            color: AppTheme.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 12.h),
                    
                    // 按钮行
                    Row(
                      children: [
                        // 加入购物车按钮
                        Expanded(
                          child: Container(
                            height: 48.h,
                            decoration: BoxDecoration(
                              gradient: widget.product.status 
                                  ? AppTheme.primaryGradient
                                  : LinearGradient(
                                      colors: [Colors.grey.shade400, Colors.grey.shade500],
                                    ),
                              borderRadius: BorderRadius.circular(12.w),
                              boxShadow: widget.product.status ? [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withValues(alpha:0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ] : null,
                            ),
                            child: ElevatedButton.icon(
                              onPressed: (widget.product.status && !_isProcessing) ? _addToCart : null,
                              icon: _isProcessing 
                                ? SizedBox(
                                    width: 16.w,
                                    height: 16.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.shopping_cart, size: 18.w),
                              label: Text(
                                _isProcessing ? '${LocationUtils.translate('Processing')}...' : '${LocationUtils.translate('Add to cart')} ',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),  
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.w),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: 8.w),
                        
                        // 立即购买按钮
                        Expanded(
                          child: Container(
                            height: 48.h,
                            decoration: BoxDecoration(
                              gradient: widget.product.status 
                                  ? LinearGradient(
                                      colors: [
                                        Colors.orange.shade600,
                                        Colors.orange.shade500,
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: [Colors.grey.shade400, Colors.grey.shade500],
                                    ),
                              borderRadius: BorderRadius.circular(12.w),
                              boxShadow: widget.product.status ? [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha:0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ] : null,
                            ),
                            child: ElevatedButton.icon(
                              onPressed: (widget.product.status && !_isProcessing) ? _buyNow : null,
                              icon: _isProcessing 
                                ? SizedBox(
                                    width: 16.w,
                                    height: 16.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.flash_on, size: 18.w),
                              label: Text(
                                _isProcessing ? '${LocationUtils.translate('Processing')}...' : LocationUtils.translate('Buy'),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.w),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
            },
          ),
        ],
      ),
    );
  }


  /// 减少数量
  void _decreaseQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  /// 增加数量
  void _increaseQuantity() {
    setState(() {
      _quantity++;
    });
  }

  /// 加入购物车
  void _addToCart() async {

    try {

      // 添加到购物车
      final cartController = Get.find<CartController>();
      cartController.addItem(widget.product, quantity: _quantity);
      
      // 打印调试信息
      Debug.log('购物车商品数量: ${cartController.itemCount}');
      Debug.log('购物车商品列表: ${cartController.items.map((item) => '${item.product.name} x ${item.quantity}').join(', ')}');
    
      Get.back(
        closeOverlays: true,
      );
      SnackBarUtils.showSuccess(
        LocationUtils.translate('${widget.product.name} x $_quantity Added to cart'),
      );

    } catch (e) {
        Debug.log('加入购物车失败: $e');
        Get.snackbar('Failed', '$e');
       
    } 
  }

  /// 立即购买
  void _buyNow() async {

    try {
      // 显示加载状态
      setState(() {
        _isProcessing = true;
      });
      
      // 创建订单项
      final orderItem = OrderItem(
        productId: widget.product.id,
        productName: widget.product.name,
        price: widget.product.price,
        quantity: _quantity,
        imageBytes: widget.product.getMainImageBytes(),
      );

      // 获取当前用户ID
        final userService = Get.find<UserService>();
      final currentUser = userService.currentUser;
      final userId = currentUser?.userId ?? '';

      // 使用统一支付服务
      await PaymentService.createOrderAndPay(
        items: [orderItem],
        source: PaymentSource.buyNow,
        context: context,
        userId: userId,
        orderType: OrderType.delivery,
        subtotal: widget.product.price * _quantity,
      );
    } catch (e) {
      Debug.logError('立即购买', e);
      if (mounted) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: LocationUtils.translate('Failed Action'),
          text: LocationUtils.translate('failed buy now: \$e'),
          confirmBtnText: LocationUtils.translate('OK'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
