import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../home/pages/home_page.dart';
import '../onboarding/onboarding_page.dart';
import '../../core/manager/chuchu_user_info_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_image.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final Animation<double> _firstChuStroke;
  late final Animation<double> _firstChuFill;
  late final Animation<double> _secondChuStroke;
  late final Animation<double> _secondChuFill;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    
    const double totalDuration = 1.5;
    _mainController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (totalDuration * 1000).toInt()),
    );

    _firstChuStroke = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(0.0, 0.6 / totalDuration, curve: Curves.easeInOut),
      ),
    );

    _firstChuFill = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(0.0, 0.6 / totalDuration, curve: Curves.easeInOut),
      ),
    );

    _secondChuStroke = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(0.1 / totalDuration, 0.7 / totalDuration, curve: Curves.easeInOut),
      ),
    );

    _secondChuFill = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(0.1 / totalDuration, 0.7 / totalDuration, curve: Curves.easeInOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(0.0, 0.33 / totalDuration, curve: Curves.easeOut),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(0.0, 0.33 / totalDuration, curve: Curves.easeOut),
      ),
    );

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(1.2 / totalDuration, 1.0, curve: Curves.easeIn),
      ),
    );
    
    _mainController.forward();

    Future.delayed(Duration(milliseconds: (1.25 * 1000).toInt()), () {
      if (mounted) {
        final bool isLogin = ChuChuUserInfoManager.sharedInstance.isLogin;
        final Widget targetPage = isLogin 
            ? const HomePage() 
            : const OnboardingPage();
        
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => targetPage,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return child;
            },
          ),
        );
      }
    });
  }


  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgLight,
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeOut,
            child:               Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -40),
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: CommonImage(
                            iconName: 'logo_bg.png',
                            width: 160,
                            height: 160,
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -40),
                      child: SizedBox(
                        width: 400,
                        height: 100,
                        child: CustomPaint(
                          painter: _ChuChuTextPainter(
                            firstChuStroke: _firstChuStroke.value,
                            firstChuFill: _firstChuFill.value,
                            secondChuStroke: _secondChuStroke.value,
                            secondChuFill: _secondChuFill.value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          );
        },
      ),
    );
  }
}

class _ChuChuTextPainter extends CustomPainter {
  final double firstChuStroke;
  final double firstChuFill;
  final double secondChuStroke;
  final double secondChuFill;

  _ChuChuTextPainter({
    required this.firstChuStroke,
    required this.firstChuFill,
    required this.secondChuStroke,
    required this.secondChuFill,
  });

  @override
  void paint(Canvas canvas, Size size) {

    final firstChuSvgPath = "M69.6818 49.3636H50.4545C50.3182 47.7727 49.9545 46.3295 49.3636 45.0341C48.7955 43.7386 48 42.625 46.9773 41.6932C45.9773 40.7386 44.7614 40.0114 43.3295 39.5114C41.8977 38.9886 40.2727 38.7273 38.4545 38.7273C35.2727 38.7273 32.5795 39.5 30.375 41.0455C28.1932 42.5909 26.5341 44.8068 25.3977 47.6932C24.2841 50.5795 23.7273 54.0455 23.7273 58.0909C23.7273 62.3636 24.2955 65.9432 25.4318 68.8295C26.5909 71.6932 28.2614 73.8523 30.4432 75.3068C32.625 76.7386 35.25 77.4545 38.3182 77.4545C40.0682 77.4545 41.6364 77.2386 43.0227 76.8068C44.4091 76.3523 45.6136 75.7045 46.6364 74.8636C47.6591 74.0227 48.4886 73.0114 49.125 71.8295C49.7841 70.625 50.2273 69.2727 50.4545 67.7727L69.6818 67.9091C69.4545 70.8636 68.625 73.875 67.1932 76.9432C65.7614 79.9886 63.7273 82.8068 61.0909 85.3977C58.4773 87.9659 55.2386 90.0341 51.375 91.6023C47.5114 93.1705 43.0227 93.9545 37.9091 93.9545C31.5 93.9545 25.75 92.5795 20.6591 89.8295C15.5909 87.0795 11.5795 83.0341 8.625 77.6932C5.69318 72.3523 4.22727 65.8182 4.22727 58.0909C4.22727 50.3182 5.72727 43.7727 8.72727 38.4545C11.7273 33.1136 15.7727 29.0795 20.8636 26.3523C25.9545 23.6023 31.6364 22.2273 37.9091 22.2273C42.3182 22.2273 46.375 22.8295 50.0795 24.0341C53.7841 25.2386 57.0341 27 59.8295 29.3182C62.625 31.6136 64.875 34.4432 66.5795 37.8068C68.2841 41.1705 69.3182 45.0227 69.6818 49.3636ZM92.5722 63.5455V93H73.754V23.1818H91.8903V50.5909H92.4358C93.6176 47.25 95.5835 44.6477 98.3335 42.7841C101.084 40.8977 104.39 39.9545 108.254 39.9545C111.959 39.9545 115.174 40.7955 117.902 42.4773C120.652 44.1591 122.777 46.4773 124.277 49.4318C125.799 52.3864 126.549 55.7727 126.527 59.5909V93H107.709V63.5455C107.731 60.9545 107.084 58.9205 105.765 57.4432C104.47 55.9659 102.618 55.2273 100.209 55.2273C98.6858 55.2273 97.3449 55.5682 96.1858 56.25C95.0494 56.9091 94.1631 57.8636 93.5267 59.1136C92.9131 60.3409 92.5949 61.8182 92.5722 63.5455ZM164.971 70.0909V40.6364H183.789V93H165.926V83.0455H165.38C164.244 86.3864 162.255 89 159.414 90.8864C156.573 92.75 153.198 93.6818 149.289 93.6818C145.63 93.6818 142.426 92.8409 139.676 91.1591C136.948 89.4773 134.823 87.1591 133.301 84.2045C131.801 81.25 131.039 77.8636 131.016 74.0455V40.6364H149.835V70.0909C149.857 72.6818 150.516 74.7159 151.812 76.1932C153.13 77.6705 154.971 78.4091 157.335 78.4091C158.903 78.4091 160.255 78.0795 161.391 77.4205C162.551 76.7386 163.437 75.7841 164.051 74.5568C164.687 73.3068 164.994 71.8182 164.971 70.0909Z";
    

    final secondChuSvgPath = "M242.69 34.3636H223.462C223.326 32.7727 222.962 31.3295 222.371 30.0341C221.803 28.7386 221.008 27.625 219.985 26.6932C218.985 25.7386 217.769 25.0114 216.337 24.5114C214.906 23.9886 213.281 23.7273 211.462 23.7273C208.281 23.7273 205.587 24.5 203.383 26.0455C201.201 27.5909 199.542 29.8068 198.406 32.6932C197.292 35.5795 196.735 39.0455 196.735 43.0909C196.735 47.3636 197.303 50.9432 198.44 53.8295C199.599 56.6932 201.269 58.8523 203.451 60.3068C205.633 61.7386 208.258 62.4545 211.326 62.4545C213.076 62.4545 214.644 62.2386 216.031 61.8068C217.417 61.3523 218.621 60.7045 219.644 59.8636C220.667 59.0227 221.496 58.0114 222.133 56.8295C222.792 55.625 223.235 54.2727 223.462 52.7727L242.69 52.9091C242.462 55.8636 241.633 58.875 240.201 61.9432C238.769 64.9886 236.735 67.8068 234.099 70.3977C231.485 72.9659 228.246 75.0341 224.383 76.6023C220.519 78.1705 216.031 78.9545 210.917 78.9545C204.508 78.9545 198.758 77.5795 193.667 74.8295C188.599 72.0795 184.587 68.0341 181.633 62.6932C178.701 57.3523 177.235 50.8182 177.235 43.0909C177.235 35.3182 178.735 28.7727 181.735 23.4545C184.735 18.1136 188.781 14.0795 193.871 11.3523C198.962 8.60227 204.644 7.22727 210.917 7.22727C215.326 7.22727 219.383 7.82954 223.087 9.03409C226.792 10.2386 230.042 12 232.837 14.3182C235.633 16.6136 237.883 19.4432 239.587 22.8068C241.292 26.1705 242.326 30.0227 242.69 34.3636ZM265.58 48.5455V78H246.762V8.18182H264.898V35.5909H265.444C266.625 32.25 268.591 29.6477 271.341 27.7841C274.091 25.8977 277.398 24.9545 281.262 24.9545C284.966 24.9545 288.182 25.7955 290.91 27.4773C293.66 29.1591 295.785 31.4773 297.285 34.4318C298.807 37.3864 299.557 40.7727 299.535 44.5909V78H280.716V48.5455C280.739 45.9545 280.091 43.9205 278.773 42.4432C277.478 40.9659 275.625 40.2273 273.216 40.2273C271.694 40.2273 270.353 40.5682 269.194 41.25C268.057 41.9091 267.171 42.8636 266.535 44.1136C265.921 45.3409 265.603 46.8182 265.58 48.5455ZM337.979 55.0909V25.6364H356.797V78H338.933V68.0455H338.388C337.252 71.3864 335.263 74 332.422 75.8864C329.581 77.75 326.206 78.6818 322.297 78.6818C318.638 78.6818 315.433 77.8409 312.683 76.1591C309.956 74.4773 307.831 72.1591 306.308 69.2045C304.808 66.25 304.047 62.8636 304.024 59.0455V25.6364H322.842V55.0909C322.865 57.6818 323.524 59.7159 324.82 61.1932C326.138 62.6705 327.979 63.4091 330.342 63.4091C331.911 63.4091 333.263 63.0795 334.399 62.4205C335.558 61.7386 336.445 60.7841 337.058 59.5568C337.695 58.3068 338.002 56.8182 337.979 55.0909Z";

    final scaleX = size.width / 444.0;
    final scaleY = size.height / 114.0;
    final scale = math.min(scaleX, scaleY) * 0.95; // Larger scale for bigger text
    

    final firstChuPath = _parseSvgPath(firstChuSvgPath, 1.0);
    final secondChuPath = _parseSvgPath(secondChuSvgPath, 1.0);
    

    final firstBounds = firstChuPath.getBounds();
    final secondBounds = secondChuPath.getBounds();
    

    final totalWidth = (firstBounds.width + secondBounds.width) * scale;
    final startX = (size.width - totalWidth) / 2;

    final centerY = size.height * 0.3;
    

    final firstPath = firstChuPath.transform(
      (Matrix4.identity()
        ..scale(scale)
        ..translate(
          startX / scale - firstBounds.left,
          centerY / scale - (firstBounds.top + firstBounds.height / 2)))
        .storage,
    );
    

    final secondPath = secondChuPath.transform(
      (Matrix4.identity()
        ..scale(scale)
        ..translate(
          (startX + firstBounds.width * scale) / scale - secondBounds.left,
          centerY / scale - (secondBounds.top + secondBounds.height / 2)))
        .storage,
    );
    

    _drawPathWithGradientStrokeAndSolidFill(
      canvas: canvas,
      path: firstPath,
      gradientColors: kGradientColors,
      fillColor: kTitleColor,
      strokeProgress: firstChuStroke,
      fillProgress: firstChuFill,
    );


    _drawPathWithStrokeAndFillGradient(
      canvas: canvas,
      path: secondPath,
      gradientColors: [
        Color(0xFFF6339A),
        Color(0xFF9810FA),
      ],
      strokeProgress: secondChuStroke,
      fillProgress: secondChuFill,
    );
  }

  Path _parseSvgPath(String svgPathData, double scale) {
    try {
      final path = _parseSvgPathData(svgPathData);
      
      if (scale != 1.0) {
        final matrix = Matrix4.identity()..scale(scale);
        return path.transform(matrix.storage);
      }
      
      return path;
    } catch (e) {
      return Path();
    }
  }

  Path _parseSvgPathData(String pathData) {
    final path = Path();
    final regex = RegExp(r'([MmLlHhVvCcZz])([^MmLlHhVvCcZz]*)');
    final matches = regex.allMatches(pathData);
    
    double currentX = 0;
    double currentY = 0;
    
    for (final match in matches) {
      final command = match.group(1)!;
      final valuesStr = match.group(2)?.trim() ?? '';
      
      if (valuesStr.isEmpty && command != 'Z' && command != 'z') continue;
      
      final numbers = _parseNumbers(valuesStr);
      
      switch (command) {
        case 'M':
          if (numbers.length >= 2) {
            currentX = numbers[0];
            currentY = numbers[1];
            path.moveTo(currentX, currentY);
            for (int i = 2; i < numbers.length - 1; i += 2) {
              currentX = numbers[i];
              currentY = numbers[i + 1];
              path.lineTo(currentX, currentY);
            }
          }
          break;
        case 'm':
          if (numbers.length >= 2) {
            currentX += numbers[0];
            currentY += numbers[1];
            path.moveTo(currentX, currentY);
            for (int i = 2; i < numbers.length - 1; i += 2) {
              currentX += numbers[i];
              currentY += numbers[i + 1];
              path.lineTo(currentX, currentY);
            }
          }
          break;
        case 'L':
          for (int i = 0; i < numbers.length - 1; i += 2) {
            currentX = numbers[i];
            currentY = numbers[i + 1];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'l':
          for (int i = 0; i < numbers.length - 1; i += 2) {
            currentX += numbers[i];
            currentY += numbers[i + 1];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'H':
          for (final x in numbers) {
            currentX = x;
            path.lineTo(currentX, currentY);
          }
          break;
        case 'h':
          for (final x in numbers) {
            currentX += x;
            path.lineTo(currentX, currentY);
          }
          break;
        case 'V':
          for (final y in numbers) {
            currentY = y;
            path.lineTo(currentX, currentY);
          }
          break;
        case 'v':
          for (final y in numbers) {
            currentY += y;
            path.lineTo(currentX, currentY);
          }
          break;
        case 'C':
          for (int i = 0; i < numbers.length - 5; i += 6) {
            final x1 = numbers[i];
            final y1 = numbers[i + 1];
            final x2 = numbers[i + 2];
            final y2 = numbers[i + 3];
            currentX = numbers[i + 4];
            currentY = numbers[i + 5];
            path.cubicTo(x1, y1, x2, y2, currentX, currentY);
          }
          break;
        case 'c':
          for (int i = 0; i < numbers.length - 5; i += 6) {
            final x1 = currentX + numbers[i];
            final y1 = currentY + numbers[i + 1];
            final x2 = currentX + numbers[i + 2];
            final y2 = currentY + numbers[i + 3];
            currentX += numbers[i + 4];
            currentY += numbers[i + 5];
            path.cubicTo(x1, y1, x2, y2, currentX, currentY);
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }
    
    return path;
  }

  List<double> _parseNumbers(String str) {
    final numbers = <double>[];
    final regex = RegExp(r'-?\d+\.?\d*');
    final matches = regex.allMatches(str);
    for (final match in matches) {
      final num = double.tryParse(match.group(0) ?? '');
      if (num != null) {
        numbers.add(num);
      }
    }
    return numbers;
  }

  double _getPathLength(Path path) {
    final metrics = path.computeMetrics();
    double totalLength = 0;
    for (final metric in metrics) {
      totalLength += metric.length;
    }
    return totalLength;
  }

  void _drawPathWithGradientStrokeAndSolidFill({
    required Canvas canvas,
    required Path path,
    required List<Color> gradientColors,
    required Color fillColor,
    required double strokeProgress,
    required double fillProgress,
  }) {
    final bounds = path.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }
    
    if (strokeProgress < 1.0) {
      final strokeLength = _getPathLength(path);
      if (strokeLength > 0) {
        final dashOffset = strokeLength * strokeProgress;
        
        final dashedPath = dashPath(
          path,
          dashArray: CircularIntervalList<double>([strokeLength, strokeLength]),
          dashOffset: DashOffset.absolute(-dashOffset),
        );
        
        final gradient = LinearGradient(colors: gradientColors);
        
        final strokePaint = Paint()
          ..shader = gradient.createShader(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        
        canvas.drawPath(dashedPath, strokePaint);
      }
    }

    if (fillProgress > 0) {
      final fillPaint = Paint()
        ..color = fillColor.withOpacity(fillProgress)
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(path, fillPaint);
    }
  }

  void _drawPathWithStrokeAndFillGradient({
    required Canvas canvas,
    required Path path,
    required List<Color> gradientColors,
    required double strokeProgress,
    required double fillProgress,
  }) {
    final bounds = path.getBounds();
    
    if (strokeProgress < 1.0) {
      final strokeLength = _getPathLength(path);
      final dashOffset = strokeLength * strokeProgress;
      
      final dashedPath = dashPath(
        path,
        dashArray: CircularIntervalList<double>([strokeLength, strokeLength]),
        dashOffset: DashOffset.absolute(-dashOffset),
      );
      
      final gradient = LinearGradient(colors: gradientColors);
      
      final strokePaint = Paint()
        ..shader = gradient.createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      
      canvas.drawPath(dashedPath, strokePaint);
    }

    if (fillProgress > 0) {
      final gradient = LinearGradient(
        colors: gradientColors.map((color) => color.withOpacity(fillProgress)).toList(),
      );
      
      final fillPaint = Paint()
        ..shader = gradient.createShader(bounds)
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_ChuChuTextPainter oldDelegate) {
    return oldDelegate.firstChuStroke != firstChuStroke ||
        oldDelegate.firstChuFill != firstChuFill ||
        oldDelegate.secondChuStroke != secondChuStroke ||
        oldDelegate.secondChuFill != secondChuFill;
  }
}