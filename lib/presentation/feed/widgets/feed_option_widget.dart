import 'package:flutter/material.dart';

import '../../../core/widgets/common_image.dart';
import '../../../data/enum/feed_enum.dart';

class FeedOptionWidget extends StatefulWidget {
  const FeedOptionWidget({super.key});
  @override
  State createState() => _FeedOptionWidgetState();
}

class _FeedOptionWidgetState extends State<FeedOptionWidget> {
  final List<EFeedOptionType> feedOptionTypeList = [
    EFeedOptionType.reply,
    EFeedOptionType.repost,
    EFeedOptionType.like,
    EFeedOptionType.zaps,
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {},
      child: Container(
        height: 41,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children:
              feedOptionTypeList.map((EFeedOptionType type) {
                return _showItemWidget(type);
              }).toList(),
        ),
      ),
    );
  }

  Widget _showItemWidget(EFeedOptionType type) {
    Widget iconTextWidget = _iconTextWidget(
      type: type,
      isSelect: _isClickByMe(type),
      onTap: () => _onTapCallback(type)(),
      onLongPress: () => _onLongPress(type)(),
      clickNum: _getClickNum(type),
    );

    return Expanded(child: iconTextWidget);
  }

  GestureTapCallback _onTapCallback(EFeedOptionType type) {
    return () => {};
  }

  GestureLongPressCallback _onLongPress(EFeedOptionType type) {
    return () => {};
  }

  Widget _iconTextWidget({
    required EFeedOptionType type,
    required bool isSelect,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
    int? clickNum,
  }) {
    final content =
        clickNum == null || clickNum == 0 ? '' : clickNum.toString();
    Color textColors = isSelect ? Colors.black : Colors.black26;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.translucent,
      onTap: () => onTap?.call(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.only(right: 4),
            child: CommonImage(
              iconName: type.getIconName,
              size: 16,
              color: textColors,
            ),
          ),
          Text(
            content,
            style: TextStyle(
              color: textColors,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  int _getClickNum(EFeedOptionType type) {
    return 2;
  }

  bool _isClickByMe(EFeedOptionType type) {
    return true;
  }
}
