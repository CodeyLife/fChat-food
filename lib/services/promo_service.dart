import 'package:get/get.dart';
import 'package:fchatapi/appapi/PromoObj.dart';
import 'dart:convert';

import '../utils/debug.dart';

class PromoService  extends GetxController
{
  // 响应式优惠券列表 - 直接存储 PromoObj 对象
  var promos = <PromObj>[].obs;
  
  @override
  void onInit() {
     PromoApi().receive((value){
 
      // 解析优惠券数据
      List<PromObj> promoList = [];
      
      // 检查返回值是否有效，避免解析错误消息
      if (value.isEmpty || value == 'err' || value == 'null' || value == 'error') {
        // Debug.log("优惠券API返回错误值: $value");
        promos.value = [];
        return;
      }
       Debug.log("获取优惠券数据: $value");
      try {
        // 将 JSON 字符串解析为 Map
        Map<String, dynamic> jsonMap = jsonDecode(value);
        
        // 打印 state 字段
        Debug.log("state: ${jsonMap['state']}");
        
        // 遍历解析后的 Map
        jsonMap.forEach((key, val) {
          if (key != 'state') {
            try {
              // 将 JSON 数据转换为 PromoObj 对象
                // 直接存储 Map 数据，但保持 PromoObj 结构
             promoList.add(PromObj.fromJson(val as Map<String, dynamic>));
            } catch (e) {
              Debug.log("解析优惠券 $key 时出错: $e");
            }
          }
        });
      } catch (e) {
        Debug.log("解析 JSON 字符串时出错: $e");
      }
      
      // 更新响应式列表
      promos.value = promoList;
      Debug.log("获得 ${promoList.length} 张优惠券");
    });

    super.onInit();
  }
}
