import 'package:flutter/material.dart';
import '../utils/location.dart';
/// 翻译文本组件
/// 功能与 Text 组件完全一致，但会自动调用 LocationUtils.translate 进行文本翻译
/// 支持响应式翻译，当语言变化时会自动更新显示内容
class TranslateText extends StatelessWidget {
  /// 要翻译的文本
  final String text;
  
  /// 文本样式
  final TextStyle? style;
  
  /// 文本对齐方式
  final TextAlign? textAlign;
  
  /// 文本方向
  final TextDirection? textDirection;
  
  /// 是否自动换行
  final bool? softWrap;
  
  /// 文本溢出处理方式
  final TextOverflow? overflow;
  
  /// 文本缩放因子
  final double? textScaleFactor;
  
  /// 最大行数
  final int? maxLines;
  
  /// 文本语义标签
  final String? semanticsLabel;
  
  /// 文本宽度因子
  final TextWidthBasis? textWidthBasis;
  
  /// 文本高度行为
  final TextHeightBehavior? textHeightBehavior;


  const TranslateText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,

  });

  /// 创建一个不进行翻译的 TranslateText（等同于普通 Text）
  const TranslateText.raw(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,

  });

  @override
  Widget build(BuildContext context) {

    // 普通翻译模式
    final translatedText = LocationUtils.translate(text);
    return _buildText(translatedText);
  }

  /// 构建 Text 组件
  Widget _buildText(String displayText) {
    return Text(
      displayText,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }
}

/// 翻译文本的扩展方法
/// 可以直接在 String 上调用 .translateText() 来创建 TranslateText 组件
extension TranslateTextExtension on String {
  /// 创建翻译文本组件
  TranslateText translateText({
    Key? key,
    TextStyle? style,
    TextAlign? textAlign,
    TextDirection? textDirection,
    bool? softWrap,
    TextOverflow? overflow,
    double? textScaleFactor,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,

  }) {
    return TranslateText(
      this,
      key: key,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      textScaleFactor: textScaleFactor,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,

    );
  }
}