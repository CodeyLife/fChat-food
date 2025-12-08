import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/location.dart';
import '../utils/debug.dart';

class FlappyBirdGameScreen extends StatefulWidget {
  const FlappyBirdGameScreen({super.key});

  @override
  State<FlappyBirdGameScreen> createState() => _FlappyBirdGameScreenState();
}

class _FlappyBirdGameScreenState extends State<FlappyBirdGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _gameController;
  DateTime? _lastUpdateTime;
  
  // 小鸟相关
  double _birdY = 0.5; // 小鸟的垂直位置（0-1之间，0.5表示屏幕中间）
  double _birdVelocity = 0.0; // 小鸟的垂直速度
  static const double _gravity = 0.0003; // 重力加速度（降低）
  static const double _jumpStrength = -0.008; // 跳跃力度（增强）
  
  // 管道相关
  final List<Pipe> _pipes = [];
  static const double _pipeWidth = 80.0;
  static const double _pipeGap = 250.0; // 管道之间的间隙（固定像素值）
  static const double _pipeSpeedPixels = 120.0; // 管道移动速度（固定像素/秒）
  static const double _pipeSpacingPixels = 300.0; // 管道之间的水平间距（固定像素值，初始值）
  static const double _minPipeSpacingPixels = 150.0; // 管道之间的最小水平间距（固定像素值）
  static const double _spacingReductionPerScore = 2.0; // 每得1分减少的间距（像素）
  double _pipeSpawnTimer = 0.0;
  double _pipeSpawnInterval = 0.0; // 管道生成间隔（秒），根据分数动态计算
  
  // 游戏状态
  GameState _gameState = GameState.waiting;
  int _score = 0;
  int _bestScore = 0;
  
  // 本地存储键名
  static const String _bestScoreKey = 'flappy_bird_best_score';
  SharedPreferences? _prefs;
  
  @override
  void initState() {
    super.initState();
    _gameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60 FPS
    )..addListener(_gameLoop);
    
    // 初始化并加载最佳分数
    _initializeStorage();
  }
  
  /// 初始化本地存储
  Future<void> _initializeStorage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadBestScore();
      // 计算管道生成间隔（基于固定像素间距）
      _calculatePipeSpawnInterval();
    } catch (e) {
      Debug.logError('初始化本地存储失败', e);
    }
  }
  
  /// 计算管道生成间隔（根据分数动态调整，使管道间距在不同屏幕宽度下保持一致）
  void _calculatePipeSpawnInterval() {
    if (!mounted) return;
    // 根据分数计算当前间距：初始间距 - (分数 * 每分减少的间距)
    // 但不能小于最小间距
    final currentSpacing = (_pipeSpacingPixels - (_score * _spacingReductionPerScore))
        .clamp(_minPipeSpacingPixels, _pipeSpacingPixels);
    
    // 管道间距 = 管道速度 * 生成间隔
    // 实际间距应该是：管道间距 + 管道宽度
    final totalSpacing = currentSpacing + _pipeWidth;
    _pipeSpawnInterval = totalSpacing / _pipeSpeedPixels;
  }
  
  @override
  void dispose() {
    _gameController.dispose();
    super.dispose();
  }
  
  /// 从本地存储加载最佳分数
  Future<void> _loadBestScore() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedBestScore = _prefs?.getInt(_bestScoreKey) ?? 0;
      if (mounted) {
        setState(() {
          _bestScore = savedBestScore;
        });
      }
      Debug.log('加载最佳分数: $_bestScore');
    } catch (e) {
      Debug.logError('加载最佳分数失败', e);
    }
  }
  
  /// 保存最佳分数到本地存储
  Future<void> _saveBestScore() async {
    try {
      if (_score > _bestScore) {
        _bestScore = _score;
        _prefs ??= await SharedPreferences.getInstance();
        await _prefs?.setInt(_bestScoreKey, _bestScore);
        Debug.log('保存最佳分数: $_bestScore');
      }
    } catch (e) {
      Debug.logError('保存最佳分数失败', e);
    }
  }
  
  void _gameLoop() {
    if (_gameState != GameState.playing) return;
    
    final now = DateTime.now();
    final deltaTime = _lastUpdateTime != null
        ? now.difference(_lastUpdateTime!).inMilliseconds / 1000.0
        : 0.016; // 默认16ms
    _lastUpdateTime = now;
    
    setState(() {
      // 更新小鸟物理
      _birdVelocity += _gravity * deltaTime * 60; // 标准化到60fps
      _birdY += _birdVelocity;
      
      // 检查边界碰撞
      if (_birdY < 0.0 || _birdY > 1.0) {
        _gameOver();
        return;
      }
      
      // 更新管道
      // 根据分数重新计算生成间隔（难度递增）
      _calculatePipeSpawnInterval();
      
      _pipeSpawnTimer += deltaTime;
      if (_pipeSpawnTimer >= _pipeSpawnInterval) {
        _spawnPipe();
        _pipeSpawnTimer = 0.0;
      }
      
      // 移动管道（使用固定像素速度）
      final screenWidth = MediaQuery.of(context).size.width;
      final pipeSpeedRatio = (_pipeSpeedPixels * deltaTime) / screenWidth; // 将像素速度转换为比例
      for (var pipe in _pipes) {
        pipe.x -= pipeSpeedRatio;
      }
      
      // 移除屏幕外的管道（管道位置是相对于屏幕宽度的比例）
      _pipes.removeWhere((pipe) => pipe.x * screenWidth + _pipeWidth < 0);
      
      // 检查碰撞
      _checkCollisions();
      
      // 检查得分（小鸟通过管道）
      final birdX = 0.2 * screenWidth; // 小鸟的实际像素位置
      for (var pipe in _pipes) {
        final pipeRight = pipe.x * screenWidth + _pipeWidth;
        // 当管道的右边缘已经在小鸟左侧时，说明小鸟已经通过了管道
        if (!pipe.passed && pipeRight < birdX) {
          pipe.passed = true;
          _score++;
        }
      }
    });
  }
  
  void _spawnPipe() {
    final random = Random();
    final screenHeight = MediaQuery.of(context).size.height;

    final minGapTop = 100.0; // 最小间隙顶部位置（像素）
    final maxGapTop = screenHeight - _pipeGap - 100.0; // 最大间隙顶部位置（像素）
    final gapTopPixels = minGapTop + random.nextDouble() * (maxGapTop - minGapTop);
    final gapBottomPixels = gapTopPixels + _pipeGap;
    
    // 转换为比例值（0-1之间）
    final gapTop = gapTopPixels / screenHeight;
    final gapBottom = gapBottomPixels / screenHeight;
    
    _pipes.add(Pipe(
      x: 1.0,
      gapTop: gapTop,
      gapBottom: gapBottom,
    ));
  }
  
  void _checkCollisions() {
    final birdX = 0.2; // 小鸟的水平位置
    final birdSize = 40.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final birdTop = _birdY * screenHeight - birdSize / 2;
    final birdBottom = _birdY * screenHeight + birdSize / 2;
    final screenWidth = MediaQuery.of(context).size.width;
    
    for (var pipe in _pipes) {
      final pipeLeft = pipe.x * screenWidth;
      final pipeRight = pipeLeft + _pipeWidth;
      final birdLeft = birdX * screenWidth - birdSize / 2;
      final birdRight = birdX * screenWidth + birdSize / 2;
      
      // 检查水平重叠
      if (birdRight > pipeLeft && birdLeft < pipeRight) {
        // 检查垂直碰撞
        final gapTop = pipe.gapTop * screenHeight;
        final gapBottom = pipe.gapBottom * screenHeight;
        
        if (birdTop < gapTop || birdBottom > gapBottom) {
          _gameOver();
          return;
        }
      }
    }
  }
  
  void _jump() {
    if (_gameState == GameState.waiting) {
      _startGame();
    } else if (_gameState == GameState.playing) {
      setState(() {
        _birdVelocity = _jumpStrength;
      });
    }
  }
  
  void _startGame() {

    _calculatePipeSpawnInterval();
    setState(() {
      _gameState = GameState.playing;
      _birdY = 0.5;
      _birdVelocity = 0.0;
      _pipes.clear();
      _score = 0;
      _pipeSpawnTimer = _pipeSpawnInterval * 0.7; 
      _lastUpdateTime = DateTime.now();
    });
    _gameController.repeat();
  }
  
  void _gameOver() {
    _gameController.stop();
    _saveBestScore();
    setState(() {
      _gameState = GameState.gameOver;
    });
  }
  
  void _resetGame() {
    setState(() {
      _gameState = GameState.waiting;
      _birdY = 0.5;
      _birdVelocity = 0.0;
      _pipes.clear();
      _score = 0;
      _pipeSpawnTimer = 0.0;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[300],
      body: GestureDetector(
        onTap: _jump,
        child: SafeArea(
          child: Stack(
            children: [
              // 游戏背景
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.lightBlue[200]!,
                      Colors.lightBlue[400]!,
                    ],
                  ),
                ),
              ),
              
              // 游戏元素
              CustomPaint(
                painter: GamePainter(
                  birdY: _birdY,
                  pipes: _pipes,
                  pipeWidth: _pipeWidth,
                  pipeGap: _pipeGap,
                ),
                size: Size.infinite,
              ),
              
              // UI覆盖层
              Column(
                children: [
                  // 分数显示
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${LocationUtils.translate('Score')}: $_score',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        if (_bestScore > 0)
                          Text(
                            '${LocationUtils.translate('Best')}: $_bestScore',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // 游戏状态提示
                  if (_gameState == GameState.waiting)
                    Container(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        children: [
                          Text(
                            LocationUtils.translate('Flappy Bird'),
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            LocationUtils.translate('Tap to start'),
                            style: TextStyle(
                              fontSize: 18.sp,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_gameState == GameState.gameOver)
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            LocationUtils.translate('Game Over'),
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            '${LocationUtils.translate('Score')}: $_score',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (_bestScore > 0) ...[
                            SizedBox(height: 8.h),
                            Text(
                              '${LocationUtils.translate('Best Score')}: $_bestScore',
                              style: TextStyle(
                                fontSize: 20.sp,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                          SizedBox(height: 24.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.textSecondary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24.w,
                                    vertical: 12.h,
                                  ),
                                ),
                                child: Text(
                                  LocationUtils.translate('Exit'),
                                  style: TextStyle(fontSize: 16.sp),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              ElevatedButton(
                                onPressed: () {
                                  _resetGame();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24.w,
                                    vertical: 12.h,
                                  ),
                                ),
                                child: Text(
                                  LocationUtils.translate('Play Again'),
                                  style: TextStyle(fontSize: 16.sp),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: 32.h),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 游戏状态枚举
enum GameState {
  waiting,
  playing,
  gameOver,
}

// 管道类
class Pipe {
  double x;
  double gapTop;
  double gapBottom;
  bool passed;
  
  Pipe({
    required this.x,
    required this.gapTop,
    required this.gapBottom,
    this.passed = false,
  });
}

// 游戏绘制器
class GamePainter extends CustomPainter {
  final double birdY;
  final List<Pipe> pipes;
  final double pipeWidth;
  final double pipeGap;
  
  GamePainter({
    required this.birdY,
    required this.pipes,
    required this.pipeWidth,
    required this.pipeGap,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 绘制小鸟
    final birdX = size.width * 0.2;
    final birdYPos = size.height * birdY;
    final birdRadius = 20.0;
    
    // 小鸟身体（黄色圆形）
    final birdPaint = Paint()
      ..color = Colors.yellow[700]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(birdX, birdYPos),
      birdRadius,
      birdPaint,
    );
    
    // 小鸟眼睛
    final eyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(birdX + 5, birdYPos - 5),
      3,
      eyePaint,
    );
    
    // 小鸟嘴巴
    final beakPath = Path()
      ..moveTo(birdX + birdRadius, birdYPos)
      ..lineTo(birdX + birdRadius + 8, birdYPos - 3)
      ..lineTo(birdX + birdRadius + 8, birdYPos + 3)
      ..close();
    final beakPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;
    canvas.drawPath(beakPath, beakPaint);
    
    // 绘制管道
    final pipePaint = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.fill;
    
    for (var pipe in pipes) {
      final pipeX = pipe.x * size.width;
      
      // 上管道
      canvas.drawRect(
        Rect.fromLTWH(
          pipeX,
          0,
          pipeWidth,
          pipe.gapTop * size.height,
        ),
        pipePaint,
      );
      
      // 下管道
      canvas.drawRect(
        Rect.fromLTWH(
          pipeX,
          pipe.gapBottom * size.height,
          pipeWidth,
          size.height - (pipe.gapBottom * size.height),
        ),
        pipePaint,
      );
      
      // 管道边缘装饰
      final edgePaint = Paint()
        ..color = Colors.green[800]!
        ..style = PaintingStyle.fill;
      
      // 上管道边缘
      canvas.drawRect(
        Rect.fromLTWH(
          pipeX,
          pipe.gapTop * size.height - 10,
          pipeWidth,
          10,
        ),
        edgePaint,
      );
      
      // 下管道边缘
      canvas.drawRect(
        Rect.fromLTWH(
          pipeX,
          pipe.gapBottom * size.height,
          pipeWidth,
          10,
        ),
        edgePaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

