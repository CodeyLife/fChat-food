import 'dart:async';
import './services/order_monitor_service.dart';
import './services/unified_order_service.dart';
import './widgets/translate_text_widget.dart';
import 'package:fchatapi/appapi/BaseJS.dart';

import 'utils/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fchatapi/FChatApiSdk.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import 'controllers/admin_controller.dart';
import 'screens/main_screen.dart';
import 'screens/orders_screen.dart';
import 'services/cart_service.dart';
import 'services/image_cache_service.dart';
import 'services/indexeddb_service.dart';
import 'services/payment_service.dart';
import 'services/promo_service.dart';
import 'services/app_state_service.dart';
import 'services/product_category_service.dart';
import 'services/user_service.dart';
import 'services/shop_service.dart';
import 'services/order_counter_service.dart';
import 'utils/app_theme.dart';
import 'utils/screen_util.dart';
import 'services/language_service.dart';
import 'services/config_service.dart';
import 'package:get/get.dart';

// 全局导航键
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化配置服务
  await ConfigService.init();
  // // Web环境错误处理
  // if (kIsWeb) {
  //   // 设置全局错误处理
  //   FlutterError.onError = (FlutterErrorDetails details) {
  //     // 如果是geolocator相关的错误，记录但不崩溃
  //     if (details.exception.toString().contains('geolocator')) {
  //       debugPrint('Geolocator error suppressed for Web compatibility: ${details.exception}');
  //       return;
  //     }
  //     // 其他错误正常处理
  //     FlutterError.presentError(details);
  //   };
  // }
  
  runApp(const CoffeeShopApp());
}

class CoffeeShopApp extends StatelessWidget {
  const CoffeeShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
    //  minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true, // 使用继承的MediaQuery
      designSize: AppScreenUtil.getDesignSize(context),
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => PaymentService()),
            ChangeNotifierProvider(create: (_) => AppStateService()),
          ],
          child: GetMaterialApp(
            title: 'fChat-food',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            home: const AppWrapper(),
            routes: {
              '/orders': (context) => const OrdersScreen(),
            },
            theme: AppTheme.theme,
          ),
        );
      },
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isLoading = true;
  bool _initSuccess = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {

      // 使用Completer等待登录回调完成
      final completer = Completer<bool>();
      
      // 调用FChatApiSdk.init并等待回调
      int completeCount = 0;
      await FChatApiSdk.init(
        ConfigService.presetUserId,
        ConfigService.presetUserToken,

        (webState) async {
          completeCount ++;
            if (completeCount == 2) {
              completer.complete(true);
            }
        },
        (appState) async {
           completeCount ++;
            if (completeCount == 2) {
              completer.complete(true);
            }
        },
        appname: 'shop',
      );
      
      // 等待登录回调完成
      final loginSuccess = await completer.future;
      if (loginSuccess) {
       FChatBridge.init();
       FChatBridge.onMessage.listen((msg) {
        PhoneUtil.applog("💬 来自 fChat app JS 的消息: $msg");
        UnifiedOrderService.parseOrderPushData(msg);
      });
        // 初始化用户服务
       Get.put(UserService(), permanent: true);
         // 注册 IndexedDB 服务
       Get.put(IndexedDBService(), permanent: true);
       // 注册图片缓存服务
       Get.put(ImageCacheService(), permanent: true);
       //注册订单管理
       Get.put(OrderMonitorService(),permanent: true);
       //注册店铺数据
       Get.put(ShopService(), permanent: true);
       //注册订单计数器服务
       Get.put(OrderCounterService(), permanent: true);
       //注册优惠卷服务
       Get.put(PromoService(), permanent: true);
       // 注册语言服务
       Get.put(LanguageService(), permanent: true); 
       // 注册AdminController
       Get.put(AdminController(), permanent: true);
       // 注册购物车控制器
       Get.put(CartController(), permanent: true);
 
        // 初始化商品分类服务
       _initializeProductCategoryService();
        
       await LocationUtils.readLocation();

        
        setState(() {
          _initSuccess = true;
          _isLoading = false;
        });
      } else {
        PhoneUtil.applog('FChatApiSdk登录失败');
        setState(() {
          _initSuccess = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      PhoneUtil.applog('FChatApiSdk初始化失败: $e');
      setState(() {
        _initSuccess = false;
        _isLoading = false;
      });
    }
  }

  /// 初始化商品分类服务
  Future<void> _initializeProductCategoryService() async {
    try {
      // 初始化商品分类服务
      await ProductCategoryService.initialize();

    } catch (e) {
      PhoneUtil.applog('商品分类服务初始化失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {

    if (_isLoading) {
      return  Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
              SizedBox(height: 16),
              'Initializing application...'.translateText(   style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.primaryBlue,
                ),),
            ],
          ),
        ),
      );
    }

    if (!_initSuccess) {
      return  Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),

              'Application initialization failed'.translateText(   style: TextStyle(
                fontSize: 18,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),),
              SizedBox(height: 8),
              'Please refresh the page and try again'.translateText(   style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),),
            ],
          ),
        ),
      );
    }

    return const MainScreen();
  }
}