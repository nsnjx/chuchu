import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/account/account.dart';
import '../../../core/account/model/userDB_isar.dart';
import '../../../core/utils/feed_content_analyze_utils.dart';
import '../../../core/utils/feed_utils.dart';


class FeedRichTextWidget extends StatefulWidget {
  final String text;
  final int? maxLines;
  final double? textSize;
  final Color? defaultTextColor;
  final Function? clickBlankCallback;
  final Function? showMoreCallback;
  final bool isShowAllContent;

  const FeedRichTextWidget({
    super.key,
    required this.text,
    this.textSize,
    this.defaultTextColor,
    this.maxLines,
    this.clickBlankCallback,
    this.showMoreCallback,
    this.isShowAllContent = false,
  });

  @override
  _FeedRichTextWidgetState createState() => _FeedRichTextWidgetState();
}

class _FeedRichTextWidgetState extends State<FeedRichTextWidget>
    with WidgetsBindingObserver {
  final GlobalKey _containerKey = GlobalKey();

  Map<String, UserDBISAR?> userDBList = {};

  bool isOnSelectText = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getUserInfo();
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _getUserInfo();
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _getUserInfo() async {
    userDBList = await FeedContentAnalyzeUtils(widget.text).getUserInfoMap;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    String getShowText =
        FeedContentAnalyzeUtils(widget.text).getMomentShowContent;
    final textSpans = _buildTextSpans(getShowText, context);
    if(getShowText.isEmpty) return const SizedBox();
    return Container(
      key: _containerKey,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText.rich(
            onSelectionChanged:(TextSelection selection, SelectionChangedCause? cause){
              if(cause == SelectionChangedCause.longPress){
                isOnSelectText = true;
              }
            },
            onTap: _clearSelectTextToCallback,
            maxLines: widget.maxLines,
            TextSpan(
              style: GoogleFonts.inter(
                color: widget.defaultTextColor ?? Color(0xFF1D293D),
                fontSize: widget.textSize ?? 15,
              ),
              children: textSpans,
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String text, BuildContext context) {
    FeedContentAnalyzeUtils analyze = FeedContentAnalyzeUtils(text);
    String showContent = analyze.getMomentPlainText;

    if (!widget.isShowAllContent && showContent.length > 300) {
      text = '${FeedUtils.truncateTextAndProcessUsers(text)} show more';
    }

    final List<TextSpan> spans = [];
    Map<String, RegExp> regexMap = FeedContentAnalyzeUtils.regexMap;
    final RegExp contentExp = RegExp(
        [
          (regexMap['hashRegex'] as RegExp).pattern,
          (regexMap['urlExp'] as RegExp).pattern,
          (regexMap['nostrExp'] as RegExp).pattern,
          (regexMap['lineFeedExp'] as RegExp).pattern,
          (regexMap['showMoreExp'] as RegExp).pattern,
        ].join('|'),
        caseSensitive: false
    );
    int lastMatchEnd = 0;
    contentExp.allMatches(text).forEach((match) {
      final beforeMatch = text.substring(lastMatchEnd, match.start);
      if (beforeMatch.isNotEmpty) {
        spans.add(TextSpan(
          text: beforeMatch,
          recognizer: TapGestureRecognizer()
            ..onTap = _clearSelectTextToCallback,
        ));
      }

      final matchText = match.group(0);
      if (matchText == '\n') {
        spans.add(const TextSpan(text: '\n'));
      } else if (matchText == 'show more') {
        spans.add(TextSpan(
          text: '... show more',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              widget.showMoreCallback?.call();
            },
        ));
      } else {
        spans.add(_buildLinkSpan(matchText!, context));
      }

      lastMatchEnd = match.end;
    });

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return spans;
  }

  TextSpan _buildLinkSpan(String text, BuildContext context) {
    List<String> list = _dealWithText(text);
    bool hasClickInfo = list[1].isNotEmpty;
    return TextSpan(
      text: list[0],
      style: TextStyle(color: hasClickInfo ? Theme.of(context).colorScheme.primary : Colors.white),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          _onTextTap(list[1], context);
        },
    );
  }

  List<String> _dealWithText(String text) {
    if (text.startsWith('nostr:npub') ||
        text.startsWith('npub') ||
        text.startsWith('nostr:nprofile')) {
      if (userDBList[text] != null) {
        UserDBISAR userDB = userDBList[text]!;
        return ['@${userDB.name}', '@${userDB.pubKey}'];
      }

      Map<String, dynamic>? userMap = Account.decodeProfile(text);
      String showContent = '';
      if(userMap == null || userMap['pubkey'].isEmpty){
        showContent = text;
      }
      return [showContent, ''];
    }

    if (text.startsWith('http')) {
      int subLength = text.length > 20 ? 20 : text.length;
      return [text.substring(0, subLength) + '...', text];
    }
    return [text, text];
  }

  void _onTextTap(String text, BuildContext context) async {
    if (text.startsWith('#')) {
      // OXNavigator.pushPage(context, (context) => TopicMomentPage(title: text));
      return;
    }
    if (text.startsWith('@')) {
      // OXModuleService.pushPage(context, 'ox_chat', 'ContactUserInfoPage', {
      //   'pubkey': text.substring(1),
      // });
      return;
    }
    if (text.startsWith('http')) {
      // MomentContentAnalyzeUtils analyzeUtils = MomentContentAnalyzeUtils(text);
      // if(analyzeUtils.getMediaList(2).isNotEmpty){
      //   CommonVideoPage.show(text);
      //   return;
      // }
      // OXModuleService.invoke('ox_common', 'gotoWebView', [context, text, null, null, null, null]);
      // return;
    }
    widget.clickBlankCallback?.call();
  }

  void _clearSelectTextToCallback(){
    if (FocusScope.of(context).hasFocus && isOnSelectText) {
      FocusScope.of(context).unfocus();
      isOnSelectText = false;
    } else {
      widget.clickBlankCallback?.call();
    }
  }
}
