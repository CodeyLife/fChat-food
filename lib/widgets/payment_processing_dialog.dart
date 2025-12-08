import 'package:flutter/material.dart';

import '../utils/location.dart';
/// 支付处理弹窗组件
/// 用于显示支付过程中的状态信息
class PaymentProcessingDialog extends StatefulWidget {
  final String title;
  final String message;
  final Color color;
  final bool showLoading;

  const PaymentProcessingDialog({
    super.key,
    this.title = 'processing...',
    this.message = 'please wait, do not close the page',
    this.color = Colors.blue,
    this.showLoading = true,
  });

  @override
  State<PaymentProcessingDialog> createState() => _PaymentProcessingDialogState();
}

class _PaymentProcessingDialogState extends State<PaymentProcessingDialog>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 旋转动画控制器
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // 脉冲动画控制器
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // 开始动画
    if (widget.showLoading) {
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // 阻止返回键关闭弹窗
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标区域
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha:0.1),
                ),
                child: widget.showLoading
                    ? AnimatedBuilder(
                        animation: _rotationAnimation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationAnimation.value * 2 * 3.14159,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Icon(
                                    Icons.payment,
                                    size: 40,
                                    color: widget.color,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      )
                    : Icon(
                        widget.color == Colors.green
                            ? Icons.check_circle
                            : widget.color == Colors.red
                                ? Icons.error
                                : Icons.warning,
                        size: 40,
                        color: widget.color,
                      ),
              ),
              
              const SizedBox(height: 20),
              
              // 标题
              Text(
                LocationUtils.translate(widget.title),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // 消息内容
              Text(
                LocationUtils.translate(widget.message),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              if (widget.showLoading) ...[
                const SizedBox(height: 20),
                
                // 进度指示器
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
