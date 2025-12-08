import 'dart:async';
import 'dart:typed_data';
import '../utils/debug.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/product.dart';
import '../services/image_cache_service.dart';

class AsyncImageWidget extends StatefulWidget {
  final ImageObj? imageobj;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Uint8List? initialBytes;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AsyncImageWidget({
    super.key,
    this.imageobj,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.initialBytes,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  }) : assert(imageobj != null || initialBytes != null, 'Either imageobj or initialBytes must be provided');

  @override
  State<AsyncImageWidget> createState() => _AsyncImageWidgetState();
}

class _AsyncImageWidgetState extends State<AsyncImageWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;
  
  @override
  void initState() {
    super.initState();
    _loadImage();
  }
  
  @override
  void didUpdateWidget(AsyncImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageobj?.md5 != widget.imageobj?.md5 ||
        oldWidget.initialBytes != widget.initialBytes) {
      _loadImage();
    }
  }
  
  Future<void> _loadImage() async {
    // 重置状态
    setState(() {
      _isLoading = true;
      _hasError = false;
      _imageBytes = null;
    });
    
    // 如果直接提供了字节数据，直接显示
    if (widget.initialBytes != null && widget.imageobj == null) {
      if (mounted) {
        setState(() {
          _imageBytes = widget.initialBytes;
          _isLoading = false;
        });
      }
      return;
    }
    
    // 如果没有提供 imageobj，返回错误占位符
    if (widget.imageobj == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }
    
    // 使用缓存服务加载图片
    try {
      final cacheService = ImageCacheService.instance;
      final md5 = widget.imageobj!.md5;
      
      final bytes = await cacheService.getImage(md5);
      
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
          _hasError = bytes == null || bytes.isEmpty;
        });
      }
    } catch (e) {
      Debug.log('加载图片失败: ${widget.imageobj?.md5}, 错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根据状态决定显示什么
    if (_isLoading) {
      return _buildPlaceholder();
    }
    
    if (_hasError || _imageBytes == null) {
      return _buildErrorPlaceholder();
    }
    
    return _buildImage(_imageBytes);
  }
  

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[100]!,
            Colors.grey[200]!,
            Colors.grey[100]!,
          ],
        ),
        borderRadius: widget.borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 32.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8.h),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 40.w,
            ),
            SizedBox(height: 8.h),
            Text(
              'failed',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return _buildErrorPlaceholder();
    }
    
    Widget imageWidget = Image.memory(
      bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return _buildSimpleErrorPlaceholder();
      },
    );
    
    // 如果有圆角，添加 ClipRRect
    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }

  Widget _buildSimpleErrorPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.red,
          size: 40.w,
        ),
      ),
    );
  }

}
