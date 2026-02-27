import 'dart:io' if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';

import 'package:chuchu/core/utils/adapt.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_image_gallery.dart';

class NinePalaceGridPictureWidget extends StatefulWidget {
  final int crossAxisCount;
  final double? width;
  final bool isEdit;
  final List<String> imageList;
  final int axisSpacing;
  final Function(List<String> imageList)? addImageCallback;
  final Function(int index)? delImageCallback;

  const NinePalaceGridPictureWidget(
      {
        super.key,
        required this.imageList,
        this.addImageCallback,
        this.width,
        this.axisSpacing = 10,
        this.isEdit = false,
        this.crossAxisCount = 3,
        this.delImageCallback,
      });

  @override
  State createState() =>
      _NinePalaceGridPictureWidgetState();
}

class _NinePalaceGridPictureWidgetState extends State<NinePalaceGridPictureWidget> {
  String tag = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
  }


  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageList != oldWidget.imageList) {
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    List<String> _imageList = _getShowImageList();
    return SizedBox(
      width: widget.width ?? double.infinity,
      child: AspectRatio(
        aspectRatio: _getAspectRatio(_imageList.length),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _imageList.length,
          itemBuilder: (context, index) {
            return widget.isEdit
                ? _showEditImageWidget(context, index, _imageList)
                : _showImageWidget(context, index, _imageList);
          },
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            crossAxisSpacing: widget.axisSpacing.px,
            mainAxisSpacing: widget.axisSpacing.px,
            childAspectRatio: 1,
          ),
        ),
      ),
    );
  }

  Widget _showImageWidget(
      BuildContext context, int index, List<String> imageList) {
    String imgPath = imageList[index];
    final widgetWidth = MediaQuery.of(context).size.width / widget.crossAxisCount;
    return GestureDetector(
      onTap: () {
        CommonImageGallery.show(
          context: context,
          imageList: imageList.map((url) => ImageEntry(id: url + tag, url: url)).toList(),
          initialPage:index,
        );
        _photoOption(false);
      },
      child: Hero(
        tag: imgPath + tag,
        child: FeedWidgetsUtils.clipImage(
          borderRadius: 8.px,
          child: ExtendedImage(
            image:ChuChuCachedImageProviderEx.create(
              imgPath,
              width: widgetWidth,
            ),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _showEditImageWidget(
      BuildContext context, int index, List<String> imageList) {
    bool isShowAddIcon = imageList[index] == 'add_moment.png';
    String imgPath =
    isShowAddIcon ? 'add_moment.png' : imageList[index];

    Widget imageWidget = Image.file(
      File(imgPath),
      fit: BoxFit.cover,
      // package: isShowAddIcon ? 'ox_discovery' : null,
    );

    if(isShowAddIcon){
      imageWidget = CommonImage(
        iconName: imgPath,
        fit: BoxFit.cover,
      );
    }

    return GestureDetector(
      onTap: () => _photoOption(isShowAddIcon),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FeedWidgetsUtils.clipImage(
              borderRadius: 8.px,
              child: imageWidget,
            ),
          ),
          isShowAddIcon ? const SizedBox() : Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: () {
                widget.delImageCallback?.call(index);
              },
              child: Container(
                width: 30.px,
                height: 30.px,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(
                    Radius.circular(30.px),
                  ),
                ),
                child: Center(
                  child: CommonImage(
                    iconName: 'close_icon.png',
                    size: 20.px,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _photoOption(bool isShowAddIcon) {

  }

  double _getAspectRatio(int length) {
    if (widget.crossAxisCount == 1) return 1.0;
    if (widget.crossAxisCount == 2) {
      return length > 2 ? 1 : 2;
    }
    if (widget.crossAxisCount == 3) {
      if (length >= 1 && length <= 3) {
        return 3.0;
      } else if (length >= 4 && length <= 6) {
        return 1.5;
      } else if (length >= 7 && length <= 9) {
        return 1.0;
      }
    }
    return 1.0;
  }

  List<String> _getShowImageList() {
    if (!widget.isEdit) return widget.imageList;
    List<String> showImageList = widget.imageList;
    if (widget.isEdit && widget.imageList.length < 9) {
      showImageList.add('add_moment.png');
    }
    return showImageList;
  }

}
