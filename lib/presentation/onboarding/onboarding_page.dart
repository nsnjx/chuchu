import 'package:chuchu/core/widgets/common_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../login/pages/new_login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _pages = [
    OnboardingItem(
      title: 'Reshaping Creator Economy',
      description: 'Open protocol. Own your content. Control your income. Payments instant.',
      illustration: 'introduction_01.png',
    ),
    OnboardingItem(
      title: 'Custody wallet',
      description: 'Integrated custody wallet for easy sats collection. Instant payments via Lightning Network',
      illustration: 'introduction_02.png',
    ),
    OnboardingItem(
      title: 'Privacy protection',
      description: 'No ad tracking, no big data collection. Browse content freely without algorithm manipulation.',
      illustration: 'introduction_03.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  void _skip() {
    _goToLogin();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => NewLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
     
      color: kBgLight,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Skip button
          
            Container(
              color: kBgLight,
              child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _skip,
                  child: ShaderMask(
                    shaderCallback: (bounds) => getBrandGradientHorizontal().createShader(bounds),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            // Bottom section with content card
            _buildBottomSection(),
            // Bottom safe area padding with white background
            Container(
              height: MediaQuery.of(context).padding.bottom,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );

    // On web, center the content with max width constraint
    if (kIsWeb) {
      return Container(
        color: Colors.white,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: content,
          ),
        ),
      );
    }

    return content;
  }

  Widget _buildPage(OnboardingItem item) {
    return Container(
      color: kBgLight,
      width: double.infinity,
      child: Stack(
        children: [
          // Illustration background with gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                 color: kBgLight,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/${item.illustration}',
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width * 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    final currentItem = _pages[_currentPage];
    final isLastPage = _currentPage == _pages.length - 1;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            currentItem.title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: kTitleColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          // Description
          Text(
            currentItem.description,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          // Pagination indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => _buildIndicator(index == _currentPage),
            ),
          ),
          SizedBox(height: 24),
          // Next/Get Started button
          GradientButton(
            text: isLastPage ? 'Get Started' : 'Next',
            onTap: _nextPage,
            trailingIcon: CommonImage(iconName: 'arrow_right_icon.png', size: 20, color: Colors.white),
            width: double.infinity,
            height: 50,
            borderRadius: 25,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        gradient: isActive ? getBrandGradientHorizontal() : null,
        color: isActive ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String illustration;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.illustration,
  });
}

