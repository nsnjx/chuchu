import 'package:chuchu/core/widgets/common_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chuchu/core/utils/ui_refresh_mixin.dart';
import 'mode_selector.dart';
import 'login_form.dart';
import 'register_form.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with ChuChuUIRefreshMixin {
  bool _isLoginMode = true;

  void _toggleMode(bool isLoginMode) {
    setState(() {
      _isLoginMode = isLoginMode;
    });
  }

  @override
  Widget buildBody(BuildContext context) {
    Widget content = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Logo at the top
                  Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CommonImage(width: 325, iconName: 'logo_text_primary.png'),
                  ),
                  SizedBox(height: 50),

                  // Login/Register toggle and form
                  Column(
                    children: [
                      // Mode selector
                      Text(
                        'Sign up to support your favorite creators',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 24),
                      ModeSelector(
                        isLoginMode: _isLoginMode,
                        onModeChanged: _toggleMode,
                      ),

                      SizedBox(height: 51),

                      // Conditional content based on mode with animation
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0.3, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            )),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _isLoginMode 
                          ? LoginForm(key: ValueKey('login'))
                          : RegisterForm(key: ValueKey('register')),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 40),
                  
                  // Bottom section
                // Column(
                //   children: [
                //     Row(
                //       mainAxisAlignment: MainAxisAlignment.center,
                //       children: [
                //         Text(
                //           '©2023 chuchu',
                //           style: TextStyle(
                //             color: Theme.of(context).colorScheme.onSurfaceVariant,
                //             fontSize: 12,
                //           ),
                //         ),
                //         SizedBox(width: 16),
                //         Text(
                //           'Help',
                //           style: TextStyle(
                //             color: Theme.of(context).colorScheme.onSurfaceVariant,
                //             fontSize: 12,
                //           ),
                //         ),
                //         SizedBox(width: 8),
                //         Text('•', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                //         SizedBox(width: 8),
                //         Row(
                //           children: [
                //             Icon(Icons.language, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                //             SizedBox(width: 4),
                //             Text(
                //               'Language',
                //               style: TextStyle(
                //                 color: Theme.of(context).colorScheme.onSurfaceVariant,
                //                 fontSize: 12,
                //               ),
                //             ),
                //           ],
                //         ),
                //       ],
                //     ),
                //     SizedBox(height: 20),
                //   ],
                // ),
                ],
              ),
            ),
          ),
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
}
