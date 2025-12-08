import '../services/config_service.dart';
// import '../utils/debug.dart';
import 'package:fchatapi/FChatApiSdk.dart';
import 'package:fchatapi/appapi/TranslateApi.dart';
import 'package:fchatapi/util/Translate.dart';


class LocationUtils {

  static late final bool inChina;

  static Future<void> readLocation() async
  {
    TranslateApi("").read((value){
      // Debug.log("读取翻译缓存: $value");
    });
  }

  
  static String translate(String text) {
      if(inChina){
       // return "翻译 $text";
        return text;
      }else{
        if(ConfigService.isTest && FChatApiSdk.isFchatBrower) {
          TranslateApi(text).send((value) {
         
          });
          }
        return Translate.show(text);
      }
  }
}





