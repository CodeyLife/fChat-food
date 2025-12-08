import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:fchatapi/util/Tools.dart';
import 'package:fchatapi/webapi/FChatFileObj.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/product.dart';
import '../utils/location.dart';
import '../utils/app_theme.dart';
import '../utils/debug.dart';
import '../utils/constants.dart';
import '../services/image_cache_service.dart';

/// 独立的图片项组件，避免 FutureBuilder 无限重建
class _BannerImageItem extends StatefulWidget {
  final ImageObj image;
  final Widget Function() onError;
  final Widget Function() onLoading;

  const _BannerImageItem({
    required this.image,
    required this.onError,
    required this.onLoading,
  });

  @override
  State<_BannerImageItem> createState() => _BannerImageItemState();
}

class _BannerImageItemState extends State<_BannerImageItem> 
    with AutomaticKeepAliveClientMixin {
  
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  @override
  void didUpdateWidget(_BannerImageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当图片 MD5 改变时才重新加载
    if (oldWidget.image.md5 != widget.image.md5) {
      _initializeImage();
    }
  }

  Future<void> _initializeImage() async {
    if (_isInitialized) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 如果已经有字节数据，直接使用
      if (widget.image.byte != null && widget.image.byte!.isNotEmpty) {
        _imageBytes = widget.image.byte;
      } else {
        // 从缓存服务加载
        final cacheService = ImageCacheService.instance;
        _imageBytes = await cacheService.getImage(widget.image.md5);
        
        // 更新 ImageObj 的字节数据
        if (_imageBytes != null && _imageBytes!.isNotEmpty) {
          widget.image.byte = _imageBytes;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _imageBytes == null || _imageBytes!.isEmpty;
          _isInitialized = true;
        });
      }
    } catch (e) {
      Debug.log('图片加载失败: ${widget.image.md5}, 错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，因为使用了 AutomaticKeepAliveClientMixin
    
    if (_isLoading) {
      return widget.onLoading();
    }
    
    if (_hasError || _imageBytes == null || _imageBytes!.isEmpty) {
      return widget.onError();
    }

    try {
      return Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        // 添加图片压缩，减少内存占用
        cacheWidth: 1024,
        cacheHeight: 1024,
        errorBuilder: (context, error, stackTrace) {
          Debug.log('图片显示失败: $error');
          return widget.onError();
        },
      );
    } catch (e) {
      Debug.log('图片显示异常: $e');
      return widget.onError();
    }
  }
}

/// 轮播广告图片选择器 - 专为轮播广告设计的响应式图片选择组件
class BannerImagePicker extends StatefulWidget {
  final List<ImageObj> selectedImages;
  final Function(List<ImageObj>) onImagesChanged;
  final int maxImages;

  const BannerImagePicker({
    super.key,
    required this.selectedImages,
    required this.onImagesChanged,
    this.maxImages = 5,
  });

  @override
  State<BannerImagePicker> createState() => _BannerImagePickerState();
}

class _BannerImagePickerState extends State<BannerImagePicker> {
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isUploading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 轮播图片容器
        _buildBannerContainer(),
        SizedBox(height: 12.h),
        // 指示器
        _buildPageIndicator(),
        SizedBox(height: 12.h),
        // 控制按钮
        _buildControlButtons(),
      ],
    );
  }

  /// 构建轮播图片容器
  Widget _buildBannerContainer() {
    final hasImages = widget.selectedImages.isNotEmpty;
    
    // 计算响应式高度：使用屏幕宽度的 40% 左右，但保持 16:9 的宽高比
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = (screenWidth - 48.w) * 0.4; // 48 是左右 padding
    
    return Container(
      height: bannerHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: hasImages
          ? _buildImageCarousel()
          : _buildEmptyPlaceholder(),
    );
  }

  /// 构建图片轮播
  Widget _buildImageCarousel() {
    return Stack(
      children: [
        // 轮播视图
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemCount: widget.selectedImages.length,
          // 优化性能：限制预加载范围
          allowImplicitScrolling: false,
          physics: const PageScrollPhysics(),
          itemBuilder: (context, index) {
            return _buildBannerItem(widget.selectedImages[index], index);
          },
        ),
        // 上传状态遮罩
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 构建空占位符
  Widget _buildEmptyPlaceholder() {
    return GestureDetector(
      onTap: _selectFromGallery,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 48.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8.h),
            Text(
              LocationUtils.translate('Add Banner Image'),
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              LocationUtils.translate('Tap to select images'),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建轮播图片项
  Widget _buildBannerItem(ImageObj image, int index) {
    return Container(
      margin: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Stack(
        children: [
          // 图片
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: _buildImagePreview(image),
            ),
          ),
          // 删除按钮
          Positioned(
            top: 8.h,
            right: 8.w,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16.w,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图片预览
  Widget _buildImagePreview(ImageObj image) {
    return _BannerImageItem(
      image: image,
      onError: _buildErrorPlaceholder,
      onLoading: _buildLoadingPlaceholder,
    );
  }


  /// 构建加载占位符
  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
        ),
      ),
    );
  }

  /// 构建错误占位符
  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 48.w,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  /// 构建控制按钮
  Widget _buildControlButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 判断是否为窄屏
        final isNarrow = constraints.maxWidth < 400;
        
        return IntrinsicHeight(
          child: Row(
            children: [
              // 添加图片按钮
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectFromGallery,
                  icon: Icon(Icons.add_photo_alternate, size: 16.w),
                  label: Text(
                    isNarrow ? LocationUtils.translate('Add') : LocationUtils.translate('Add Images'),
                    style: TextStyle(fontSize: 13.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
                    minimumSize: Size(0, 48.h), // 设置最小高度
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // 拍照按钮
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: Icon(Icons.camera_alt, size: 16.w),
                  label: Text(
                    isNarrow ? LocationUtils.translate('Photo') : LocationUtils.translate('Take Photo'),
                    style: TextStyle(fontSize: 13.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
                    minimumSize: Size(0, 48.h), // 设置最小高度
                  ),
                ),
              ),
              // 清除按钮（只有有图片时才显示）
              if (widget.selectedImages.isNotEmpty) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearAllImages,
                    icon: Icon(Icons.clear_all, size: 16.w),
                    label: Text(
                      isNarrow ? LocationUtils.translate('Clear') : LocationUtils.translate('Clear All'),
                      style: TextStyle(fontSize: 13.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
                      minimumSize: Size(0, 48.h), // 设置最小高度
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 构建分页指示器
  Widget _buildPageIndicator() {
    if (widget.selectedImages.length <= 1) {
      return SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.selectedImages.length,
        (index) => GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: Container(
            width: _currentPage == index ? 24.w : 8.w,
            height: 8.h,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? AppTheme.primaryBlue
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
      ),
    );
  }

  /// 从相册选择图片
  void _selectFromGallery() async {
    if (widget.selectedImages.length >= widget.maxImages) {
      _showMessage('${LocationUtils.translate('Maximum')} ${widget.maxImages} ${LocationUtils.translate('images allowed')}');
      return;
    }

    try {
      final remaining = widget.maxImages - widget.selectedImages.length;
      final List<XFile> images = await _picker.pickMultiImage(
        limit: remaining,
      );
      if (images.isNotEmpty) {
        await _processSelectedImages(images);
      }
    } catch (e) {
      _showMessage('${LocationUtils.translate('Error selecting images')}: $e');
    }
  }

  /// 拍照
  void _takePhoto() async {
    if (widget.selectedImages.length >= widget.maxImages) {
      _showMessage('${LocationUtils.translate('Maximum')} ${widget.maxImages} ${LocationUtils.translate('images allowed')}');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _processSelectedImages([image]);
      }
    } catch (e) {
      _showMessage('${LocationUtils.translate('Error taking photo')}: $e');
    }
  }

  /// 压缩图片（如果需要）
  /// [bytes] 原始图片字节数据
  /// [fileName] 文件名
  /// [originalWidth] 图片原始宽度
  /// [originalHeight] 图片原始高度
  /// 返回压缩后的字节数据
  Future<Uint8List> _compressImageIfNeeded(Uint8List bytes, String fileName, int originalWidth, int originalHeight) async {
    const int maxSizeBytes = 1024 * 1024; // 1MB
    
    // 如果图片小于1MB，直接返回
    if (bytes.length <= maxSizeBytes) {
      Debug.log('图片 $fileName 小于1MB，无需压缩');
      return bytes;
    }
    
    Debug.log('图片 $fileName 大小为 ${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB，实际尺寸: ${originalWidth}x$originalHeight，开始压缩');
    
    // 根据原始文件大小选择压缩策略
    final double originalSizeMB = bytes.length / 1024 / 1024;
    List<int> qualityLevels;
    
    if (originalSizeMB <= 10) {

      qualityLevels = [90, 80, 70, 60];
    } 
    else {
      qualityLevels = [70, 60, 50, 40];
    }
    
    // 使用图片实际尺寸作为初始尺寸
    int currentMaxWidth = originalWidth;
    int currentMaxHeight = originalHeight;

    //在一开始把尺寸降到最大1920
    if(currentMaxWidth>1280){
      final scale = 1280 / currentMaxWidth;
      currentMaxWidth = 1280;
      currentMaxHeight = (currentMaxHeight * scale).toInt();
    }
    
    for (int i = 0; i < qualityLevels.length; i++) {
      final int quality = qualityLevels[i];
      
    // 压缩图片，每次尝试时同时降低尺寸和质量
        final compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          quality: quality,
          keepExif: false, // 移除EXIF数据以减小文件大小
          minWidth: currentMaxWidth,
          minHeight: currentMaxHeight,
          format: CompressFormat.webp, 
        );
           Debug.log('图片 $fileName 压缩成功，质量: $quality%，尺寸: ${currentMaxWidth}x$currentMaxHeight}，压缩后大小: ${(compressedBytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
        if (compressedBytes.length <= maxSizeBytes) {
       
          return compressedBytes;
        }
        
        // 如果压缩后仍然太大，下次尝试时降低尺寸
        if (i < qualityLevels.length - 1) {
          currentMaxWidth = (currentMaxWidth * 0.8).toInt();
          currentMaxHeight = (currentMaxHeight * 0.8).toInt();
          // 确保最小尺寸
          if (currentMaxWidth < 300) {
            currentMaxWidth = 300;
          }
          if (currentMaxHeight < 300) {
            currentMaxHeight = 300;
          }
        }else{
          return bytes;
        }

    }

    // 如果所有压缩都失败，返回原始数据
    Debug.log('图片 $fileName 压缩失败，使用原始数据');
    return bytes;
  }

  /// 处理选择的图片
  Future<void> _processSelectedImages(List<XFile> images) async {
    if (widget.selectedImages.length + images.length > widget.maxImages) {
      _showMessage('${LocationUtils.translate('Maximum')} ${widget.maxImages} ${LocationUtils.translate('images allowed')}');
      return;
    }

    // 显示压缩提示
    _showCompressionDialog();

    setState(() {
      _isUploading = true;
    });

    List<ImageObj> newImages = [];

    for (XFile image in images) {
      try {
        // 读取原始图片字节数据
        final originalBytes = await image.readAsBytes();
        
        // 获取图片实际尺寸
        int originalWidth = 1920; // 默认值
        int originalHeight = 1440; // 默认值
        
        try {
          final imageData = await decodeImageFromList(originalBytes);
          originalWidth = imageData.width;
          originalHeight = imageData.height;
        } catch (e) {
          Debug.log('无法获取图片 ${image.name} 尺寸，使用默认值: ${originalWidth}x$originalHeight');
        }
        
        // 压缩图片（如果需要）
        final processedBytes = await _compressImageIfNeeded(originalBytes, image.name, originalWidth, originalHeight);

        // 创建ImageObj - 使用随机字符串作为初始md5
        ImageObj imageObj = ImageObj(Tools.generateRandomString(32));
        
        // 生成临时MD5
        imageObj.md5 = Tools.generateRandomString(32);
        
        // 存储处理后的字节数据
        imageObj.byte = processedBytes;
        
        // 上传图片到服务器获取真实的MD5
        await _uploadImageToServer(imageObj, image);
        
        newImages.add(imageObj);
        Debug.log('轮播图片处理完成: ${image.name}, MD5: ${imageObj.md5}');
      } catch (e) {
        Debug.log('轮播图片处理失败: ${image.name}, 错误: $e');
        _showMessage('${LocationUtils.translate('Error processing image')} ${image.name}: $e');
      }
    }

    // 更新图片列表
    List<ImageObj> updatedImages = List.from(widget.selectedImages);
    updatedImages.addAll(newImages);
    
    setState(() {
      _isUploading = false;
    });

    // 关闭压缩提示弹窗
    _hideCompressionDialog();

    widget.onImagesChanged(updatedImages);
    
    if (newImages.isNotEmpty) {
      _showMessage('${LocationUtils.translate('Successfully added')} ${newImages.length} ${LocationUtils.translate('images')}');
      
      // 滚动到新添加的图片
      if (_pageController.hasClients) {
        _pageController.jumpToPage(updatedImages.length - 1);
      }
    }
  }

  /// 上传图片到服务器获取真实MD5
  Future<void> _uploadImageToServer(ImageObj imageObj, XFile file) async {
    try {
      // 读取文件字节
      final bytes = await file.readAsBytes();
      
      // 创建html.File对象（Web平台）
      // 使用html.Blob创建文件，模拟从文件输入获取的文件
      final blob = html.Blob([bytes]);
      final htmlFile = html.File([blob], file.name, {
        'type': 'image/jpeg'
      });
      
      // 设置文件类型
      FChatFileObj fileObj = FChatFileObj();
      fileObj.filemd = AppConstants.image;
      
      // 上传图片到服务器
      await fileObj.writeFile(htmlFile, (value) {
        Debug.log('轮播图片上传状态: $value');
      });
      
      // 更新为服务器返回的文件名
      imageObj.md5 = fileObj.filename;
      
      Debug.log('轮播图片上传成功, MD5: ${imageObj.md5}');
    } catch (e) {
      Debug.log('轮播图片上传失败: $e');
      // 如果上传失败，保留本地生成的随机MD5
      Debug.log('使用本地生成的MD5: ${imageObj.md5}');
    }
  }

  /// 删除图片
  void _removeImage(int index) {
    List<ImageObj> updatedImages = List.from(widget.selectedImages);
    updatedImages.removeAt(index);
    
    // 调整当前页
    if (index < _currentPage) {
      setState(() {
        _currentPage--;
      });
    } else if (index == _currentPage && updatedImages.isNotEmpty && _currentPage >= updatedImages.length) {
      setState(() {
        _currentPage = updatedImages.length - 1;
      });
    }
    
    widget.onImagesChanged(updatedImages);
    
    // 如果还有图片，跳转到当前页
    if (updatedImages.isNotEmpty && _pageController.hasClients) {
      _pageController.jumpToPage(_currentPage);
    }
  }

  /// 清空所有图片
  void _clearAllImages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('Confirm Clear')),
        content: Text(LocationUtils.translate('Are you sure you want to clear all images?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('Cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onImagesChanged([]);
            },
            child: Text(
              LocationUtils.translate('Confirm'),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示消息
  void _showMessage(String message) {
    Get.snackbar(
      LocationUtils.translate('Notice'),
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.primaryBlue,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
  }

  /// 显示压缩提示弹窗
  void _showCompressionDialog() {
    Get.dialog(
      PopScope(
        canPop: false, // 禁止返回键关闭
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(LocationUtils.translate('Compressing images...')),
            ],
          ),
        ),
      ),
      barrierDismissible: false, // 禁止点击外部关闭
    );
  }

  /// 关闭压缩提示弹窗
  void _hideCompressionDialog() {
    if (Get.isDialogOpen == true) {
      Get.back();
    }
  }
}

