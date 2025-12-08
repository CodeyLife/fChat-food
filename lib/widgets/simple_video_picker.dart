// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import '../utils/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fchatapi/util/PhoneUtil.dart';
import 'package:fchatapi/webapi/FChatFileObj.dart';
import '../utils/app_theme.dart';
import '../utils/debug.dart';
import '../utils/constants.dart';
import '../utils/snackbar_utils.dart';
import 'video_player_widget.dart';

class SimpleVideoPicker extends StatefulWidget {
  final String? selectedVideoUrl;
  final Function(String?) onVideoChanged;
  final double? width;
  final double? height;

  const SimpleVideoPicker({
    super.key,
    this.selectedVideoUrl,
    required this.onVideoChanged,
    this.width,
    this.height,
  });

  @override
  State<SimpleVideoPicker> createState() => _SimpleVideoPickerState();
}

class _SimpleVideoPickerState extends State<SimpleVideoPicker> {
  bool _isUploading = false;
  String? _videoPreviewUrl;

  @override
  void initState() {
    super.initState();
    _videoPreviewUrl = widget.selectedVideoUrl;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 200.h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频预览区域
          Expanded(
            child: _buildVideoPreview(),
          ),
          SizedBox(height: 12.h),
          // 操作按钮
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// 构建视频预览
  Widget _buildVideoPreview() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: _videoPreviewUrl != null && _videoPreviewUrl!.isNotEmpty
            ? _buildVideoPlayer()
            : _buildEmptyState(),
      ),
    );
  }

  /// 构建视频播放器
  Widget _buildVideoPlayer() {
    return Stack(
      children: [
        // 视频播放器
        Positioned.fill(
          child: VideoPlayerWidget(
            videoUrl: _videoPreviewUrl!,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // 上传状态覆盖层
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:0.5),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      LocationUtils.translate('Uploading...'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 根据可用高度动态调整内容
              double availableHeight = constraints.maxHeight;
              
              // 更精细的空间判断
              bool isExtremelySmall = availableHeight < 60;
              bool isVerySmall = availableHeight < 80;
              bool isSmall = availableHeight < 120;
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isExtremelySmall) ...[
                    Icon(
                      Icons.videocam_outlined,
                      size: isSmall ? 20.w : (isVerySmall ? 24.w : 32.w),
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: isSmall ? 2.h : (isVerySmall ? 4.h : 6.h)),
                  ],
                  Flexible(
                    child: Text(
                      LocationUtils.translate('no video'),
                      style: TextStyle(
                        fontSize: isExtremelySmall ? 8.sp : (isSmall ? 10.sp : 12.sp),
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isExtremelySmall) ...[
                    SizedBox(height: 1.h),
                    Flexible(
                      child: Text(
                        LocationUtils.translate('support MP4、MOV、AVI format'),
                        style: TextStyle(
                          fontSize: isExtremelySmall ? 6.sp : (isSmall ? 8.sp : 10.sp),
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: isExtremelySmall ? 1 : (isSmall ? 1 : 2),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }


  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        ElevatedButton.icon(
          onPressed: _selectVideo,
          icon: Icon(Icons.video_library, size: 16.w),
          label: Text(LocationUtils.translate('Select Video')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            minimumSize: Size(0, 36.h),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _recordVideo,
          icon: Icon(Icons.videocam, size: 16.w),
          label: Text(LocationUtils.translate('Record Video')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            minimumSize: Size(0, 36.h),
          ),
        ),
        if (_videoPreviewUrl != null && _videoPreviewUrl!.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _removeVideo,
            icon: Icon(Icons.delete, size: 16.w),
            label: Text(LocationUtils.translate('Delete Video')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              minimumSize: Size(0, 36.h),
            ),
          ),
      ],
    );
  }

  /// 选择视频文件
  void _selectVideo() {
    // 创建文件输入元素
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'video/*';
    uploadInput.multiple = false;
    
    uploadInput.onChange.listen((e) {
      final List<html.File>? files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        _processSelectedVideo(files.first);
      }
    });
    
    uploadInput.click();
  }

  /// 录制视频
  void _recordVideo() {
    // 创建文件输入元素，限制为录制
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'video/*';
    uploadInput.setAttribute('capture', 'camera');
    
    uploadInput.onChange.listen((e) {
      final List<html.File>? files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        _processSelectedVideo(files.first);
      }
    });
    
    uploadInput.click();
  }

  /// 处理选择的视频文件
  void _processSelectedVideo(html.File file) {
    // 检查文件大小（5MB限制）
    if (file.size > 5 * 1024 * 1024) {
      _showMessage(LocationUtils.translate('video file size cannot exceed 5MB'));
      return;
    }

    // 检查文件类型
    if (!file.type.startsWith('video/')) {
      _showMessage(LocationUtils.translate('please select a valid video file format'));
      return;
    }

    // 检查文件扩展名，确保是支持的格式
    String fileName = file.name.toLowerCase();
    if (!fileName.endsWith('.mp4') && !fileName.endsWith('.webm') && !fileName.endsWith('.ogg')) {
      _showMessage(LocationUtils.translate('please select MP4、WebM or OGG format video file'));
      return;
    }

    Debug.log("选择的视频文件信息:");
    Debug.log("文件名: ${file.name}");
    Debug.log("文件类型: ${file.type}");
    Debug.log("文件大小: ${file.size} bytes");

    setState(() {
      _isUploading = true;
    });

    _uploadVideo(file);
  }

  /// 上传视频
  void _uploadVideo(html.File file) async {
    try {
    
      FChatFileObj vobj = FChatFileObj();
      vobj.ispublic = true;  // 设置为公开访问
      vobj.filemd = AppConstants.video;
      
      await vobj.writeFile(file, (value) {
        PhoneUtil.applog('video upload return status: $value');
        
        // 使用回调返回的value作为视频URL
        if (value.isNotEmpty) {
          setState(() {
            _isUploading = false;
            _videoPreviewUrl = value;
          });

          // 通知父组件
          widget.onVideoChanged(value);
          
          _showMessage(LocationUtils.translate('video upload success'));
          PhoneUtil.applog('视频上传成功, URL: $value');
        } else {
          setState(() {
            _isUploading = false;
          });
          _showMessage(LocationUtils.translate('video upload failed, please try again'));
          PhoneUtil.applog('视频上传失败，返回值为空');
        }
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      
      PhoneUtil.applog('视频上传失败: $e');
      _showMessage(LocationUtils.translate('video upload failed: $e'));
    }
  }


  /// 删除视频
  void _removeVideo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocationUtils.translate('确认删除')),
        content: Text(LocationUtils.translate('确定要删除当前视频吗？')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocationUtils.translate('取消')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _videoPreviewUrl = null;
              });
              widget.onVideoChanged(null);
            },
            child: Text(LocationUtils.translate('OK'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  /// 显示消息
  void _showMessage(String message) {
    SnackBarUtils.showInfo(context, message);
  }
}
