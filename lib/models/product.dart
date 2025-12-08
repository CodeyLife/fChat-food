import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:fchatapi/util/Tools.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import 'package:fchatapi/util/JsonUtil.dart';
import '../services/image_cache_service.dart';

import '../utils/image_utils.dart';

/// 图片方向枚举
enum ImageOrientation { landscape, portrait, square }

/// 商品审核状态枚举
enum ProductApprovalStatus { 
  pending,    // 待审核
  approved,   // 已通过
  rejected    // 已拒绝
}

/// 图片对象
class ImageObj {
  Uint8List? byte;
  String md5 = "";
  ImageOrientation orientation = ImageOrientation.square;
  
  // 状态管理：避免重复读取
  bool _isLoading = false;
  final List<void Function(String)> _pendingCallbacks = [];

  ImageObj(this.md5);

  /// 读取图片数据（集成全局缓存服务）
  void readObj(void Function(String) state) {
    // 如果已经有本地缓存数据，直接返回
    if (byte != null && byte!.isNotEmpty) {
      state(getBase64());
      return;
    }
    
    // 如果正在加载中，将回调添加到等待队列
    if (_isLoading) {
      _pendingCallbacks.add(state);
      return;
    }
    
    // 开始加载
    _isLoading = true;

    // 使用全局缓存服务读取图片
    _getImageFromCacheService(state);
  }
  
  /// 通过缓存服务获取图片
  void _getImageFromCacheService(void Function(String) state) async {
    // 导入缓存服务（延迟导入避免循环依赖）
    final cacheService = Get.find<ImageCacheService>();
    
    try {
      final cachedBytes = await cacheService.getImage(md5);
      if (cachedBytes != null && cachedBytes.isNotEmpty) {
        // 更新本地缓存
        byte = cachedBytes;
        
        // 通知所有等待的回调
        for (var callback in _pendingCallbacks) {
          callback(getBase64());
        }
      } else {
        // 缓存服务加载失败，通知所有回调
        for (var callback in _pendingCallbacks) {
          callback('');
        }
      }
      
      // 清空等待队列
      _pendingCallbacks.clear();
      _isLoading = false;
    } catch (e) {
      // 图片加载异常，通知所有回调
      for (var callback in _pendingCallbacks) {
        callback('');
      }
      
      // 清空等待队列
      _pendingCallbacks.clear();
      _isLoading = false;
    }
  }

  /// 获取图片字节数据
  Uint8List getByte() {
    return byte ?? Uint8List(0);
  }
  
  /// 动态获取 base64 字符串
  String getBase64() {
    if (byte != null && byte!.isNotEmpty) {
      return base64Encode(byte!);
    }
    return '';
  }

  /// 获取JSON表示
  Map<String, dynamic> getJson() {
    Map<String, dynamic> map = {};
    map.putIfAbsent(md5, () => orientation.name);
    return map;
  }

  /// 从JSON创建ImageObj
  factory ImageObj.fromJson(Map<String, dynamic> json) {
    final imageObj = ImageObj(json['md5'] ?? '');
    // 如果有 base64 数据，解码为字节
    if (json['base64'] != null && json['base64'].toString().isNotEmpty) {
      final bytes = ImageUtils.safeBase64Decode(json['base64']);
      if (bytes != null) {
        imageObj.byte = bytes;
      }
    }
    imageObj.orientation = ImageOrientation.values.firstWhere(
      (e) => e.name == (json['orientation'] ?? 'square'),
      orElse: () => ImageOrientation.square,
    );
    return imageObj;
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'md5': md5,
      'base64': getBase64(), // 动态生成 base64
      'orientation': orientation.name,
    };
  }
}

/// 商品图片对象
class ProductImage {
  final String id;
  final Uint8List imageData;
  final String base64;
  final String filename;
  final DateTime createdAt;

  ProductImage({
    required this.id,
    required this.imageData,
    required this.base64,
    required this.filename,
    required this.createdAt,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] ?? '',
      imageData: Uint8List.fromList([]), // 需要从base64重新生成
      base64: json['base64'] ?? '',
      filename: json['filename'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'base64': base64,
      'filename': filename,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// 商品图片集合
class ProductGallery {
  final List<ImageObj> images = [];
  final Map<int, ImageOrientation> imageOrientations = {};

  ProductGallery();

  ProductGallery.fromJson(Map<String, dynamic> json) {

    List<String> md5List = json.keys.toList();
    
    for (String md5 in md5List) {
      ImageObj imageObj = ImageObj(md5);
      // 解析图片方向
      String orientationStr = 'square';
      
      // 处理嵌套的图片数据结构
      final imageData = json[md5];
      if (imageData is String) {
        // 直接是字符串格式: {"md5": "square"}
        orientationStr = imageData;
      } else if (imageData is Map) {
        // 嵌套格式: {"md5": {"md5": "square"}}
        final nestedData = imageData[md5];
        if (nestedData is String) {
          orientationStr = nestedData;
        }
      }
      
      imageObj.orientation = ImageOrientation.values.firstWhere(
        (e) => e.name == orientationStr,
        orElse: () => ImageOrientation.square,
      );
      images.add(imageObj);
    
    }

  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = {};
    for (ImageObj img in images) {
      map.putIfAbsent(img.md5, () => img.orientation.name);
    }
    return map;
  }

  /// 获取图片数据（匹配mall项目的getImages方法）
  Map getImages() {
    Map map = {};
    for (ImageObj img in images) {
      map.putIfAbsent(img.md5, () => img.getJson());
    }
    return map;
  }

  void addImage(ImageObj image) {
    if (images.length >= 9) {
      PhoneUtil.applog("最多只能添加9张图片");
      return;
    }
    images.add(image);
  }

  void removeImage(int index) {
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
    }
  }

  /// 获取图片方向
  ImageOrientation? getImageOrientation(int index) {
    if (index < 0 || index >= images.length) {
      return null;
    }
    return images[index].orientation;
  }
}

/// 咖啡商品类
class CoffeeProduct {
  String id;
  String name;
  double price;
  String description;
  ProductGallery? productImages;
  String videoUrl;
  bool status; // true: 上架, false: 下架
  ProductApprovalStatus approvalStatus; // 审核状态
  String category;
  DateTime createdAt;
  DateTime updatedAt;

  CoffeeProduct({
    required this.name,
    required this.price,
    required this.description,
    this.productImages,
    this.videoUrl = '',
    this.status = true, // 默认上架
    this.approvalStatus = ProductApprovalStatus.pending, // 默认待审核
    this.category = '咖啡',
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? Tools.generateRandomString(30),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory CoffeeProduct.fromJson(Map<String, dynamic> json) {
    return CoffeeProduct(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      productImages: json['Images'] != null 
          ? ProductGallery.fromJson(json['Images']) 
          : null,
      videoUrl: json['videourl'] ?? '',
      status: json['status'] ?? true, // 默认上架
      approvalStatus: ProductApprovalStatus.values.firstWhere(
        (e) => e.name == (json['approvalStatus'] ?? 'pending'),
        orElse: () => ProductApprovalStatus.pending,
      ),
      category: json['category'] ?? '咖啡',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'Images': productImages?.getImages(),
      'videourl': videoUrl,
      'status': status,
      'approvalStatus': approvalStatus.name,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 更新商品信息
  void update({
    String? name,
    double? price,
    String? description,
    String? videoUrl,
    bool? status,
    String? category,
  }) {
    if (name != null) this.name = name;
    if (price != null) this.price = price;
    if (description != null) this.description = description;
    if (videoUrl != null) this.videoUrl = videoUrl;
    if (status != null) this.status = status;
    if (category != null) this.category = category;
    updatedAt = DateTime.now();
  }

  /// 更新审核状态
  void updateApprovalStatus(ProductApprovalStatus newStatus) {
    approvalStatus = newStatus;
    updatedAt = DateTime.now();
  }

  /// 添加图片
  void addImage(ImageObj image) {
    productImages ??= ProductGallery();
    productImages!.addImage(image);
    updatedAt = DateTime.now();
  }

  /// 删除图片
  void removeImage(int index) {
    productImages?.removeImage(index);
    updatedAt = DateTime.now();
  }

  /// 获取主要图片的字节数据
  Uint8List? getMainImageBytes() {
    if (productImages?.images.isNotEmpty == true) {
      final imageObj = productImages!.images.first;
      // 如果已经有缓存的字节数据，直接返回
      if (imageObj.byte != null && imageObj.byte!.isNotEmpty) {
        return imageObj.byte;
      }
      // 如果没有缓存数据，触发异步加载
      imageObj.readObj((base64Data) {
        // 这里可以触发UI更新，但getMainImageBytes是同步方法
        // 所以我们需要在调用方处理异步加载
      });
      return null; // 暂时返回null，等待异步加载完成
    }
    return null;
  }
  
  /// 异步获取主要图片的字节数据
  Future<Uint8List?> getMainImageBytesAsync() async {
    if (productImages?.images.isNotEmpty == true) {
      final imageObj = productImages!.images.first;
      // 如果已经有缓存的字节数据，直接返回
      if (imageObj.byte != null && imageObj.byte!.isNotEmpty) {
        return imageObj.byte;
      }
      // 异步加载图片数据
      final completer = Completer<Uint8List?>();
      imageObj.readObj((base64Data) {
        if (base64Data.isNotEmpty) {
          final bytes = ImageUtils.safeBase64Decode(base64Data);
          completer.complete(bytes);
        } else {
          completer.complete(null);
        }
      });
      return await completer.future;
    }
    return null;
  }

  /// 获取主要图片的ImageObj
  ImageObj? getMainImageObj() {
    if (productImages?.images.isNotEmpty == true) {
      return productImages!.images.first;
    }
    return null;
  }

  /// 获取商品状态文本
  String getStatusText() {
    return status ? '上架' : '下架';
  }

  /// 获取状态颜色
  String getStatusColor() {
    return status ? 'green' : 'red';
  }

  /// 获取审核状态文本
  String getApprovalStatusText() {
    switch (approvalStatus) {
      case ProductApprovalStatus.pending:
        return '待审核';
      case ProductApprovalStatus.approved:
        return '已通过';
      case ProductApprovalStatus.rejected:
        return '已拒绝';
    }
  }

  /// 获取审核状态颜色
  String getApprovalStatusColor() {
    switch (approvalStatus) {
      case ProductApprovalStatus.pending:
        return 'orange';
      case ProductApprovalStatus.approved:
        return 'green';
      case ProductApprovalStatus.rejected:
        return 'red';
    }
  }

  /// 检查是否已通过审核
  bool get isApproved => approvalStatus == ProductApprovalStatus.approved;

  /// 检查是否待审核
  bool get isPendingApproval => approvalStatus == ProductApprovalStatus.pending;

  /// 检查是否被拒绝
  bool get isRejected => approvalStatus == ProductApprovalStatus.rejected;

  @override
  String toString() {
    return JsonUtil.maptostr(toJson());
  }
}
