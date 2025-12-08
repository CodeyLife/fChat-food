import 'dart:async';
import '../utils/debug.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import 'package:fchatapi/webapi/FChatFileObj.dart';
import 'package:fchatapi/util/JsonUtil.dart';
import '../models/order.dart';
import 'constants.dart';

/// 文件操作工具类
/// 统一管理所有文件操作，避免重复代码和错误
class FileUtils {

  /// 确保文件名有.json后缀
  /// [filename] 文件名
  /// 返回: 如果文件名没有后缀则添加.json，如果有后缀则原样返回
  static String ensureJsonExtension(String filename) {
    // 检查文件名是否包含点号（表示有后缀）
    // 如果包含点号且最后一个点号不在第一个字符位置，则认为有后缀
    int lastDotIndex = filename.lastIndexOf('.');
    if (lastDotIndex > 0 && lastDotIndex < filename.length - 1) {
      // 有后缀，原样返回
      return filename;
    }
    // 没有后缀，添加.json
    return '$filename.json';
  }
  
  /// 新增文件
  /// [fileMD] 文件目录枚举
  /// [data] 要保存的数据内容
  /// [fileId] 文件ID（用于标识文件）
  /// [filename] 文件名（可选，如果不提供会自动生成）
  /// 返回: 成功返回新的文件名，失败返回null
  static Future<bool> createFile(FChatFileMD fileMD, String data, String filename) async {
    try {
      // 确保文件名有.json后缀
      filename = ensureJsonExtension(filename);
      
      // 创建文件对象
      FChatFileObj fileObj = FChatFileObj();
      fileObj.filemd = fileMD;
      fileObj.filename = filename;

      // 使用writeData方法创建文件
      final completer = Completer<bool>();
      
      // FChatFileObj.writeData 参数: data, label, callback
      fileObj.writeData(
        data,
        filename,
        (result) {
          try {
            completer.complete(true);
          } catch (e) {
            Debug.logError('解析服务器返回结果失败: $e');
            completer.complete(false);
          }
        },
      );
      
      return await completer.future;
    } catch (e) {
      Debug.logError('创建文件失败: $e', Exception('创建文件失败'));
      return false;
    }
  }

  /// 修改文件
  /// [fileMD] 文件目录枚举
  /// [filename] 要修改的文件名
  /// [data] 新的数据内容
  /// [fileId] 文件ID（用于标识文件）
  /// 返回: 成功返回文件名，失败返回null
  static Future<bool> updateFile(FChatFileMD fileMD, String filename, String data) async {
    try {
      // 确保文件名有.json后缀
      filename = ensureJsonExtension(filename);

      // 创建文件对象
      FChatFileObj fileObj = FChatFileObj();
      fileObj.filemd = fileMD;
      fileObj.filename = filename;
      
      // 使用writeData方法修改文件（使用现有文件名进行覆盖）
      final completer = Completer<bool>();
      
      fileObj.writeData(
        data,
        filename, // 文件名
        (result) {
          try {
            completer.complete(true);
          } catch (e) {
            Debug.logError('解析服务器返回结果失败: $e', Exception('解析服务器返回结果失败'));
            completer.complete(false);
          }
        },
      );
      
      return await completer.future;
    } catch (e) {
      PhoneUtil.applog('修改文件失败: $e');
      return false;
    }
  }

  /// 删除文件
  /// [fileMD] 文件目录枚举
  /// [filename] 要删除的文件名
  /// 返回: 成功返回true，失败返回false
  static Future<bool> deleteFile(FChatFileMD fileMD, String filename) async {
    try {
      // 确保文件名有.json后缀
      filename = ensureJsonExtension(filename);
       
       // 创建文件对象
      FChatFileObj fileObj = FChatFileObj();
      fileObj.filemd = fileMD;
      fileObj.filename = filename;
      
      // 使用delFile方法删除文件
      final completer = Completer<bool>();
      
      // 构建路径：如果 fileMD.name 不以斜杠结尾，需要添加斜杠
      String path;
      if (fileMD.name.endsWith('/')) {
        path = "${fileMD.name}$filename";
      } else {
        path = "${fileMD.name}/$filename";
      }
      Debug.log('删除文件路径: $path');
      fileObj.delFile(path, (result) {
        Debug.log('删除文件$path 结果: $result');
        completer.complete(true);
      });
      
      return await completer.future;
    } catch (e) {
      Debug.logError('删除文件失败: $e'); 
      return false;
    }
  }

  /// 读取目录中的所有文件
  /// [fileMD] 文件目录枚举
  /// 返回: 文件列表，失败返回空列表
  static Future<List<Map<String,dynamic>>> readDirectory(FChatFileMD fileMD) async {
    try {

      final completer = Completer<List<Map<String,dynamic>>>();
      bool isCompleted = false;

      List<Map<String,dynamic>> files = [];
      // 使用 FChatFileArrObj 而不是 FChatApiSdk.filearrobj
      FChatFileArrObj fileArrObj = FChatFileArrObj();
      fileArrObj.readMD((value) {
        if (isCompleted) return;
        isCompleted = true;
        try {
          // Debug.log('目录 ${fileMD.name} 中找到 ${value.length} 个文件');
          for(FChatFileObj file in value){
            if(file.filedata != null && file.filedata!.isNotEmpty){
              files.add(JsonUtil.strtoMap(file.filedata!));
            }
          }
          completer.complete(files);
        } catch (e) {
          Debug.logError('处理目录文件时发生错误: $e', Exception('处理目录文件时发生错误'));
          completer.complete([]);
        }

      }, md: fileMD.name);
      
      return await completer.future;
    } catch (e) {
      Debug.logError('读取目录失败: $e', Exception('读取目录失败'));
      return [];
    }
  }

  ///删除文件夹下所有文件
  static Future<bool> deleteDirectory(FChatFileMD fileMD) async {
      var files = await getDirectoryFilePaths(fileMD);
      final completers = files.map((file) => deleteFile(fileMD, file)).toList();
      final results = await Future.wait(completers);
      return results.every((result) => result);
  }

  /// 获取目录下的文件路径列表（轻量级）
  /// [fileMD] 文件目录枚举
  /// 返回: 文件路径列表，失败返回空列表
  static Future<List<String>> getDirectoryFilePaths(FChatFileMD fileMD) async {
    try {

      final completer = Completer<List<String>>();
      bool isCompleted = false;
      
      // 使用 FChatFileArrObj 而不是 FChatApiSdk.filearrobj
      FChatFileArrObj fileArrObj = FChatFileArrObj();
      fileArrObj.readMDthb((filePaths) {
        if (isCompleted) return;
        isCompleted = true;
        
        try {
          // 确保类型转换正确
          List<String> paths = filePaths.cast<String>();
        
          completer.complete(paths);
        } catch (e) {
          PhoneUtil.applog('处理目录文件路径时发生错误: $e');
          completer.complete([]);
        }
      }, md: fileMD.name);
      
      return await completer.future;
    } catch (e) {
      PhoneUtil.applog('获取目录文件路径失败: $e');
      return [];
    }
  }

  /// 读取文件内容
  /// [fileMD] 文件目录枚举
  /// [filename] 文件名
  /// 返回: 成功返回解码后的Map数据，文件不存在或读取失败返回null
  static Future<Map<String, dynamic>?> readFile(FChatFileMD fileMD, String filename) async {
    try {
      filename = ensureJsonExtension(filename);
      final completer = Completer<Map<String, dynamic>?>();
      FChatFileObj fileObj = FChatFileObj();
      fileObj.filemd = fileMD;
      fileObj.filename = filename;
      
      // 构建路径：如果 fileMD.name 不以斜杠结尾，需要添加斜杠
      String path;
      if (fileMD.name.endsWith('/')) {
        path = "${fileMD.name}$filename";
      } else {
        path = "${fileMD.name}/$filename";
      }
      
      fileObj.readFile(path, (value) {
        try {
          if (value.isEmpty || value == "err") {
            completer.complete(null);
            return;
          }
          
          // 解码Base64数据
          String data = JsonUtil.getbase64(value);
          final datamap = JsonUtil.strtoMap(data);
          completer.complete(datamap);
        } catch (e) {
          Debug.logError('解析文件内容失败: $e', Exception('解析文件内容失败'));
          completer.complete(null);
        }
      });
      
      return await completer.future;
    } catch (e) {
      Debug.logError('读取文件失败: $e', Exception('读取文件失败'));
      return null;
    }
  }

  static Future<String?> readFileString(FChatFileMD fileMD, String filename) async {
      filename = ensureJsonExtension(filename);
      final completer = Completer<String?>();
      FChatFileObj fileObj = FChatFileObj();
      fileObj.filemd = fileMD;
      fileObj.filename = filename;
      
      // 构建路径：如果 fileMD.name 不以斜杠结尾，需要添加斜杠
      String path;
      if (fileMD.name.endsWith('/')) {
        path = "${fileMD.name}$filename";
      } else {
        path = "${fileMD.name}/$filename";
      }
      
      fileObj.readFile(path, (value) {
        try {
          if (value.isEmpty || value == "err") {
            completer.complete(null);
            return;
          }
          
          // 解码Base64数据
          String data = JsonUtil.getbase64(value);
          completer.complete(data);
        } catch (e) {
          Debug.logError('解析文件内容失败: $e', Exception('解析文件内容失败'));
          completer.complete(null);
        }
      });
      
      return await completer.future;

  }

  /// 检查文件是否存在
  /// [fileMD] 文件目录枚举
  /// [filename] 文件名
  /// 返回: 存在返回true，不存在返回false
  static Future<bool> fileExists(FChatFileMD fileMD, String filename) async {
    try {
      // 确保文件名有.json后缀
      filename = ensureJsonExtension(filename);
      
      var files = await getDirectoryFilePaths(fileMD);
      for(String file in files){
        if(file.split('/').last == filename){
          return true;
        }
      }
      return false;
    } catch (e) {
      PhoneUtil.applog('检查文件是否存在失败: $e');
      return false;
    }
  }

  /// 批量删除文件
  /// [fileMD] 文件目录枚举
  /// [filenames] 要删除的文件名列表
  /// 返回: 成功删除的文件数量
  static Future<int> deleteFiles(FChatFileMD fileMD, List<String> filenames) async {
    try {
      PhoneUtil.applog('开始批量删除文件: ${filenames.length} 个文件');
      
      int successCount = 0;
      
      for (String filename in filenames) {
        try {
          bool result = await deleteFile(fileMD, filename);
          if (result) {
            successCount++;
            PhoneUtil.applog('文件删除成功: $filename');
          } else {
            PhoneUtil.applog('文件删除失败: $filename');
          }
        } catch (e) {
          PhoneUtil.applog('删除文件时发生错误: $filename, $e');
        }
      }
      
      PhoneUtil.applog('批量删除完成: $successCount/${filenames.length} 个文件删除成功');
      return successCount;
    } catch (e) {
      PhoneUtil.applog('批量删除文件失败: $e');
      return 0;
    }
  }

  /// 清空目录中的所有文件
  /// [fileMD] 文件目录枚举
  /// 返回: 成功删除的文件数量
  static Future<int> clearDirectory(FChatFileMD fileMD) async {
    try {
      Debug.log('开始清空目录: ${fileMD.name}');
      
      // 先读取目录中的所有文件
      List<String> files = await getDirectoryFilePaths(fileMD);
      
      if (files.isEmpty) {
        Debug.log('目录为空，无需删除');
        return 0;
      }
        
      // 提取文件名列表
      List<String> filenames = files.map((filePath) {
        // 获取最后一个/分割的部分作为文件名
        return filePath.split('/').last;
      }).toList();
      
      // 批量删除
      return await deleteFiles(fileMD, filenames);
    } catch (e) {
      Debug.logError('清空目录失败: $e', Exception('清空目录失败'));
      return 0;
    }
  }

  // ==================== 订单文件操作专用方法 ====================

  /// 保存订单到临时订单目录
  /// [order] 订单对象
  /// 返回: 成功返回新的文件名，失败返回null
  static Future<bool> saveOrderToTemp(Order order) async {
    try {
      Debug.log('开始保存订单到临时目录: ${order.orderNumber}');
      
      // 将订单转换为JSON字符串
      String orderJson = JsonUtil.maptostr(order.toJson());

      // 调用通用文件创建方法
      bool result = await createFile(
        AppConstants.tmporder, // 使用订单的存储目录
        orderJson,
        order.id, // 使用订单的文件名
      );
      return result;
    } catch (e) {
      Debug.logError('保存订单到临时目录失败: $e', Exception('保存订单到临时目录失败'));
      return false;
    }
  }

  /// 更新临时订单文件
  /// [order] 订单对象
  /// 返回: 成功返回true，失败返回false
  static Future<bool> updateOrderInTemp(Order order) async {
    try {
      // 将订单转换为JSON字符串
      String orderJson = JsonUtil.maptostr(order.toJson());
      if(order.id.isEmpty){
        Debug.logError('要更新状态的订单文件名不存在,请仔细检查bug: ${order.orderNumber}', Exception('要更新状态的订单文件名不存在,请仔细检查bug'));
      }

      // 使用现有文件名进行更新
      bool result = await updateFile(
        AppConstants.tmporder, // 使用订单的存储目录
        order.id, // 使用订单的文件名
        orderJson,
      );
      return result;
    } catch (e) {
      Debug.logError('更新临时订单失败: $e', Exception('更新临时订单失败'));
      return false;
    }
  }

  /// 移动订单到购买记录目录
  /// [order] 订单对象
  /// 返回: 成功返回true，失败返回false
  static Future<bool> moveOrderToBuyDay(Order order) async {
    try {

      // 将订单转换为JSON字符串
      String orderJson = JsonUtil.maptostr(order.toJson());

      // 保存到购买记录目录
      bool result = await createFile(
        AppConstants.getBuyDayMD(), // 购买记录目录
        orderJson,
        order.id,
      );
      
      if (result) {

        // 如果提供了原始文件，删除临时目录中的文件
        if (order.id.isNotEmpty) {
          bool deleteSuccess = await deleteFile(
            AppConstants.tmporder, // 临时订单目录
            order.id,
          );
          
          if (deleteSuccess) {

          } else {
            Debug.logError('临时订单文件删除失败: ${order.orderNumber}', Exception('临时订单文件删除失败'));
          }
        }
        
        return true;
      } else {
        Debug.logError('订单保存到购买记录目录失败: ${order.orderNumber}', Exception('订单保存到购买记录目录失败'));
        return false;
      }
    } catch (e) {
      Debug.logError('移动订单到购买记录目录失败: $e', Exception('移动订单到购买记录目录失败'));
      return false;
    }
  }

  /// 删除订单文件
  /// [order] 订单对象
  /// 返回: 成功返回true，失败返回false
  static Future<bool> deleteOrderFile(Order order) async {
    try {
      Debug.log('开始删除订单文件: ${order.orderNumber}');
      
      bool success = await deleteFile(
        AppConstants.tmporder, // 使用订单的存储目录
        order.id, // 使用订单的文件名
      );
      
      if (success) {
        Debug.log('订单文件删除成功: ${order.orderNumber}');
      } else {
        Debug.logError('订单文件删除失败: ${order.orderNumber}', Exception('订单文件删除失败'));
      }
      
      return success;
    } catch (e) {
      Debug.logError('删除订单文件失败: $e', Exception('删除订单文件失败'));
      return false;
    }
  }

  /// 批量删除订单文件
  /// [orders] 订单列表
  /// 返回: 成功删除的订单数量
  static Future<int> deleteOrderFiles(List<Order> orders) async {
    try {
      Debug.log('开始批量删除订单文件: ${orders.length} 个订单');
      
      int successCount = 0;
      
      for (Order order in orders) {
        try {
          bool result = await deleteOrderFile(order);
          if (result) {
            successCount++;
          }
        } catch (e) {
          Debug.logError('删除订单文件时发生错误: ${order.orderNumber}, $e', Exception('删除订单文件时发生错误'));
        }
      }
      
      Debug.log('批量删除订单文件完成: $successCount/${orders.length} 个订单删除成功');
      return successCount;
    } catch (e) {
      Debug.logError('批量删除订单文件失败: $e', Exception('批量删除订单文件失败'));
      return 0;
    }
  }

  /// 清空临时订单目录
  /// 返回: 成功删除的文件数量
  static Future<int> clearTempOrders() async {
    try {
      Debug.log('开始清空临时订单目录');
      return await clearDirectory(AppConstants.tmporder);
    } catch (e) {
      Debug.logError('清空临时订单目录失败: $e', Exception('清空临时订单目录失败'));
      return 0;
    }
  }

  /// 清空购买记录目录
  /// 返回: 成功删除的文件数量
  static Future<int> clearBuyDayOrders() async {
    try {
      Debug.log('开始清空购买记录目录');
      return await clearDirectory(AppConstants.getBuyDayMD());
    } catch (e) {
      PhoneUtil.applog('清空购买记录目录失败: $e');
      return 0;
    }
  }

  /// 检查临时订单文件是否存在
  /// [filename] 文件名
  /// 返回: 文件存在返回true，不存在返回false
  static Future<bool> checkTempOrderFileExists(String filename) async {
    try {
      PhoneUtil.applog('检查临时订单文件是否存在: $filename');
      
      final completer = Completer<bool>();
      
      // 使用 FChatFileArrObj 而不是 FChatApiSdk.filearrobj
      FChatFileArrObj fileArrObj = FChatFileArrObj();
      fileArrObj.readMD((value) {
        try {
          // value是List<FChatFileObj>，需要检查文件名是否存在
          bool exists = value.any((fileObj) => fileObj.filename == filename);
          PhoneUtil.applog('临时订单文件存在性检查结果: $exists');
          completer.complete(exists);
        } catch (e) {
          PhoneUtil.applog('检查临时订单文件存在性失败: $e');
          completer.complete(false);
        }
      }, md: AppConstants.tmporder.name);
      
      return await completer.future;
    } catch (e) {
      PhoneUtil.applog('检查临时订单文件存在性异常: $e');
      return false;
    }
  }

  /// 删除临时订单文件
  /// [filename] 文件名
  /// 返回: 删除成功返回true，失败返回false
  static Future<bool> deleteTempOrderFile(String filename) async {
    try {
      PhoneUtil.applog('开始删除临时订单文件: $filename');
      return await deleteFile(AppConstants.tmporder, filename);
    } catch (e) {
      PhoneUtil.applog('删除临时订单文件失败: $e');
      return false;
    }
  }

}
