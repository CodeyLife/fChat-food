import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:fchatapi/util/Translate.dart';

import '../utils/debug.dart';


/// 语言管理服务
class LanguageService extends GetxController {
  static LanguageService get instance => Get.find<LanguageService>();
  
  // 当前语言
  final RxString _currentLanguage = 'en'.obs;
  String get currentLanguage => _currentLanguage.value;
  
  // 当前语言显示名称 - 响应式
  final RxString _currentLanguageDisplayName = 'English'.obs;
  String get currentLanguageDisplayName => _currentLanguageDisplayName.value;
  
  // 语言变化通知 - 用于触发UI刷新
  final RxInt _languageChangeTrigger = 0.obs;
  int get languageChangeTrigger => _languageChangeTrigger.value;
  

  
  @override
  void onInit() {
    super.onInit();
    _loadLanguage();
  }

  
  /// 更新语言显示名称
  void _updateDisplayName() {
    // 使用 FChatApi 的 Translate 类获取语言显示名称
    if (Translate.nowlanguage != null) {
      _currentLanguageDisplayName.value = Translate.nowlanguage!.name;
      return;
    }
    // 如果 nowlanguage 为空，尝试从支持的语言列表中查找
    final supportedLanguages = Translate.gettranslatesupport();
    for (var lang in supportedLanguages) {
      if (lang.isoCode == _currentLanguage.value) {
        _currentLanguageDisplayName.value = lang.name;
        return;
      }
    }
    // 如果找不到，返回语言代码的大写形式
    _currentLanguageDisplayName.value = _currentLanguage.value.toUpperCase();
  }
  
  /// 更新语言（供Translate类调用）
  void updateLanguage(String languageCode) {
    changeLanguage(languageCode);
  }
  
  /// 加载保存的语言设置
  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('selected_language');
      if (savedLanguage == null) {
         return;
      }
      _currentLanguage.value = savedLanguage;
      Translate.language = savedLanguage;
      Translate.nowlanguage = Translate.gettranslatesupport().firstWhere(
        (element) => element.isoCode == savedLanguage,
        orElse: () => Translate.gettranslatesupport().first,
      );
      _currentLanguageDisplayName.value = Translate.nowlanguage!.name;
      Debug.log(('加载语言设置: $savedLanguage'));
    } catch (e) {
      Debug.log('加载语言设置失败: $e');
    }
  }
  
  /// 切换语言
  Future<void>  changeLanguage(String languageCode) async {
    try {
 
      _currentLanguage.value = languageCode;
      
      // 更新Translate类
      Translate.language = languageCode;
        Debug.log('切换语言: $languageCode');
      // 更新当前语言对象
      final supportedLanguages = Translate.gettranslatesupport();
      for (var lang in supportedLanguages) {
        if (lang.isoCode == languageCode) {
          Translate.nowlanguage = lang;
          break;
        }
      }
      
      // 更新显示名称
      _updateDisplayName();
      
      // 保存到本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', languageCode);
      

      // 更新GetX的locale
      Get.updateLocale(Locale(languageCode));
      
      // 触发语言变化通知，让UI组件重新构建
      _languageChangeTrigger.value++;
      
      // 发送全局语言变化通知
      update();


      // 强制刷新所有GetX控制器和页面
      Get.forceAppUpdate();
      
   
    } catch (e) {
      Debug.log('切换语言失败: $e');
    }
  }


}
