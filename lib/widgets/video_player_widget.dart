import '../utils/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'dart:html' as html;
import '../utils/app_theme.dart';
import '../utils/debug.dart';


class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final bool autoPlay;
  final bool loop;
  final int borderRadius;
  final VoidCallback? onPause;
  final VoidCallback? onStop;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.autoPlay = true,
    this.loop = true,
    this.onPause,
    this.onStop,
    this.borderRadius = 8,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isDisposed = false;
  bool _hasError = false;
  bool _isInitialized = false;
  String? _currentVideoUrl;

  @override
  void initState() {
    super.initState();
    _currentVideoUrl = widget.videoUrl;
    // 延迟初始化，避免首次渲染阻塞
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo();
    });
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当 videoUrl 真正改变时才重新初始化
    if (oldWidget.videoUrl != widget.videoUrl) {
      _currentVideoUrl = widget.videoUrl;
      _disposeController();
      _initializeVideo();
    }
  }

  void _disposeController() {
    if (_videoController != null) {
      _videoController!.removeListener(_updatePlayingState);
      _videoController!.pause();
      _videoController!.dispose();
      _videoController = null;
    }
    _isInitialized = false;
    _hasError = false;
  }

  void _initializeVideo() {
    if (_isDisposed || !mounted || _currentVideoUrl == null || _currentVideoUrl!.isEmpty) {
      return;
    }

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(_currentVideoUrl!));
      
      _videoController!.initialize().then((_) {
        if (!_isDisposed && mounted && _videoController != null) {
          // 设置循环播放
          _videoController!.setLooping(widget.loop);
          
          setState(() {
            _isInitialized = true;
            _hasError = false;
          });
          
          // 根据 autoPlay 参数决定是否自动播放
          if (widget.autoPlay) {
            _videoController!.play();
          }
        }
      }).catchError((error) {
        Debug.log("视频加载失败: $error");
        if (!_isDisposed && mounted) {
          setState(() {
            _hasError = true;
            _isInitialized = true;
          });
        }
      });

      // 监听视频播放状态变化
      _videoController!.addListener(_updatePlayingState);
    } catch (e) {
      Debug.log("视频初始化失败: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = true;
        });
      }
    }
  }

  void _updatePlayingState() {
    if (_isDisposed || !mounted || _videoController == null) return;
    if (_videoController!.value.isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = _videoController!.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeController();
    widget.onStop?.call();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isDisposed || !mounted || _videoController == null) return;
    
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      setState(() {
        _isPlaying = false;
      });
      widget.onPause?.call();
    } else {
      _videoController!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius.r),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius.r),
        child: Stack(
          children: [

            Positioned.fill(
              child: _videoController != null && 
                     _videoController!.value.isInitialized && 
                     !_isDisposed && 
                     _isInitialized
                  ? AspectRatio(
                      aspectRatio: 9 / 16, // 使用与mall项目相同的竖屏比例
                      child: Stack(
                        children: [
                          // 视频播放器
                          VideoPlayer(_videoController!),
                          // 覆盖的播放/暂停按钮 - 参考mall项目的样式
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: GestureDetector(
                              onTap: _togglePlayPause,
                              child: Container(
                                width: 64.w,
                                height: 64.w,
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(128),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 32.w, // 调整图标大小
                                  color: Colors.white, // 使用白色更清晰
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildLoadingWidget(), // 如果视频未初始化，显示加载状态
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius.r),
        color: Colors.grey[200],
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
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'loading video...',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius.r),
        color: Colors.grey[200],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 32.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8.h),
            Text(
              'Video loading failed',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Please check your network connection or video format',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _retryVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  ),
                  child: Text(LocationUtils.translate('Retry')),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: _openVideoInBrowser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  ),
                  child: Text(LocationUtils.translate('open in browser')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 重试视频加载
  void _retryVideo() {
    if (_isDisposed || !mounted) return;
    
    setState(() {
      _hasError = false;
      _isInitialized = false;
    });
    
    _disposeController();
    _initializeVideo();
  }

  /// 在浏览器中打开视频
  void _openVideoInBrowser() {
    // 在Web环境中，直接在新窗口中打开视频URL
    if (kIsWeb) {
      html.window.open(widget.videoUrl, '_blank');
    }
  }
}
