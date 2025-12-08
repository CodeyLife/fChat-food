import 'package:fchatapi/webapi/FChatFileObj.dart';
import 'package:fchatapi/util/DateUtil.dart';

/// 应用常量配置
class AppConstants {
  // API配置
  static const String apiBaseUrl = 'https://fchat.us/';
  
  // 主题颜色
  static const int primaryColorValue = 0xFF1976D2;
  static const String primaryColorHex = '#1976D2';
  
  // 支付配置
  static const String merchantId = 'coffee_shop_merchant';
  static const String returnUrl = 'https://your-domain.com/payment/return';
  static const String notifyUrl = 'https://your-domain.com/payment/notify';
  
  static const int maxProductImages = 9;
  static const int autoScrollIntervalSeconds = 3;
  
  // 文件操作超时配置
  static const Duration fileOperationTimeout = Duration(seconds: 10);
  static const Duration paymentTimeout = Duration(minutes: 5);
  
  // UI配置
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultElevation = 2.0;

  // 扩展的文件夹定义

  static  FChatFileMD customermd = CustomFChatFileMD('customermd');    // 客服文件夹
  static  FChatFileMD shipermd = CustomFChatFileMD('shipermd');        // 商家信息文件夹
  static  FChatFileMD ztomd = CustomFChatFileMD('ztomd');              // 中通快递文件夹
  static  FChatFileMD nationmd = CustomFChatFileMD('nationmd');        // 国家货币文件夹
  static  FChatFileMD expressmd = CustomFChatFileMD('expressmd');      // 快递文件夹
  static  FChatFileMD authmd = CustomFChatFileMD('authmd');            // 授权账户文件夹
  static  FChatFileMD productlabels = CustomFChatFileMD('productlabels');            // 商品标签
  static FChatFileMD shopmd = CustomFChatFileMD('shopmd');             //店铺信息
  static FChatFileMD orderCounterMD = CustomFChatFileMD('orderCounterMD'); //订单计数器
  static FChatFileMD adminUserMD = CustomFChatFileMD('adminUserMD');   //拥有管理员权限的用户id文件夹
  
  static FChatFileMD ordermd = CustomFChatFileMD('ordermd'); //订单文件夹
  static FChatFileMD tmporder = CustomFChatFileMD('tmporder'); //临时订单文件夹
  static FChatFileMD product = CustomFChatFileMD('product'); //商品文件夹
  static FChatFileMD image = CustomFChatFileMD('image'); //图片文件夹
  static FChatFileMD video = CustomFChatFileMD('video');

  static FChatFileMD get usermd =>CustomFChatFileMD('user');
  
  // 动态生成的文件夹
  static FChatFileMD getDayMD() {
    String day = DateUtil.getlastinttoYYYYMMDD(0);
    if (day.isEmpty) {
      // 如果日期获取失败，使用当前日期作为备用
      day = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    }
    return CustomFChatFileMD(day);  // 按日期命名的文件夹
  }
  
  static FChatFileMD getBuyDayMD() {
    String day = DateUtil.getlastinttoYYYYMMDD(0);
    if (day.isEmpty) {
      // 如果日期获取失败，使用当前日期作为备用
      day = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    }
    day = "buy$day";
    return CustomFChatFileMD(day);  // 购买记录按日期命名的文件夹
  }

}
