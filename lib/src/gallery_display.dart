import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker_plus/image_picker_plus.dart';
import 'package:image_picker_plus/src/camera_display.dart';
import 'package:image_picker_plus/src/images_view_page.dart';
import 'package:image_picker_plus/src/utilities/enum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class CustomImagePicker extends StatefulWidget {
  final ImageSource source;
  final bool multiSelection;
  final GalleryDisplaySettings? galleryDisplaySettings;
  final PickerSource pickerSource;
  const CustomImagePicker({
    required this.source,
    required this.multiSelection,
    required this.galleryDisplaySettings,
    required this.pickerSource,
    super.key,
  });

  @override
  CustomImagePickerState createState() => CustomImagePickerState();
}

class CustomImagePickerState extends State<CustomImagePicker>
    with TickerProviderStateMixin {
  final pageController = ValueNotifier(PageController());
  final clearVideoRecord = ValueNotifier(false);
  final redDeleteText = ValueNotifier(false);
  final selectedPage = ValueNotifier(SelectedPage.left);
  ValueNotifier<List<File>> multiSelectedImage = ValueNotifier([]);
  final multiSelectionMode = ValueNotifier(false);
  final showDeleteText = ValueNotifier(false);
  final selectedVideo = ValueNotifier(false);
  bool noGallery = true;
  ValueNotifier<File?> selectedCameraImage = ValueNotifier(null);
  late bool cropImage;
  late AppTheme appTheme;
  late TabsTexts tapsNames;
  late bool showImagePreview;
  late int maximumSelection;
  final isImagesReady = ValueNotifier(false);
  final currentPage = ValueNotifier(0);
  final lastPage = ValueNotifier(0);

  late Color whiteColor;
  late Color blackColor;
  late GalleryDisplaySettings imagePickerDisplay;

  late bool enableCamera;
  late bool enableVideo;
  late String limitingText;

  late bool showInternalVideos;
  late bool showInternalImages;
  late SliverGridDelegateWithFixedCrossAxisCount gridDelegate;
  late bool cameraAndVideoEnabled;
  late bool cameraVideoOnlyEnabled;
  late bool showAllTabs;
  late AsyncValueSetter<SelectedImagesDetails>? callbackFunction;

  @override
  void initState() {
    _initializeVariables();
    super.initState();
  }

  _initializeVariables() {
    imagePickerDisplay =
        widget.galleryDisplaySettings ?? GalleryDisplaySettings();
    appTheme = imagePickerDisplay.appTheme ?? AppTheme();
    tapsNames = imagePickerDisplay.tabsTexts ?? TabsTexts();
    callbackFunction = imagePickerDisplay.callbackFunction;
    cropImage = imagePickerDisplay.cropImage;
    maximumSelection = imagePickerDisplay.maximumSelection;
    limitingText = tapsNames.limitingText ??
        "The limit is $maximumSelection photos or videos.";

    showImagePreview = cropImage || imagePickerDisplay.showImagePreview;
    gridDelegate = imagePickerDisplay.gridDelegate;

    showInternalImages = widget.pickerSource != PickerSource.video;
    showInternalVideos = widget.pickerSource != PickerSource.image;

    noGallery = widget.source != ImageSource.camera;
    bool notGallery = widget.source != ImageSource.gallery;

    enableCamera = showInternalImages && notGallery;
    enableVideo = showInternalVideos && notGallery;
    cameraAndVideoEnabled = enableCamera && enableVideo;
    cameraVideoOnlyEnabled =
        cameraAndVideoEnabled && widget.source == ImageSource.camera;
    showAllTabs = cameraAndVideoEnabled && noGallery;
    whiteColor = appTheme.primaryColor;
    blackColor = appTheme.focusColor;
  }

  @override
  void dispose() {
    showDeleteText.dispose();
    selectedVideo.dispose();
    selectedPage.dispose();
    selectedCameraImage.dispose();
    pageController.dispose();
    clearVideoRecord.dispose();
    redDeleteText.dispose();
    multiSelectionMode.dispose();
    multiSelectedImage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return tabController();
  }

  Widget tapBarMessage(bool isThatDeleteText) {
    Color deleteColor = redDeleteText.value ? Colors.red : appTheme.focusColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GestureDetector(
          onTap: () async {
            if (isThatDeleteText) {
              setState(() {
                selectedCameraImage.value = null;
                clearVideoRecord.value = true;
                showDeleteText.value = false;
                redDeleteText.value = false;
              });
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isThatDeleteText)
                const Icon(Icons.delete_outline,
                    color: Colors.white, size: 15),
              Text(
                isThatDeleteText ? tapsNames.deletingText : limitingText,
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget clearSelectedImages() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: GestureDetector(
          onTap: () async {
            setState(() {
              multiSelectionMode.value = !multiSelectionMode.value;
              multiSelectedImage.value.clear();
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                tapsNames.clearImagesText,
                style: TextStyle(
                    fontSize: 14,
                    color: appTheme.focusColor,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  replacingDeleteWidget(bool showDeleteText) {
    this.showDeleteText.value = showDeleteText;
  }

  moveToVideo() {
    setState(() {
      selectedPage.value = SelectedPage.right;
      selectedVideo.value = true;
    });
  }

  DefaultTabController tabController() {
    return DefaultTabController(
        length: 2, child: Material(color: appTheme.appBarColor, child: safeArea()));
  }

  SafeArea safeArea() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ValueListenableBuilder(
              valueListenable: pageController,
              builder: (context, PageController pageControllerValue, child) =>
                  PageView(
                controller: pageControllerValue,
                dragStartBehavior: DragStartBehavior.start,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (noGallery) imagesViewPage(),
                  if (enableCamera || enableVideo) cameraPage(),
                ],
              ),
            ),
          ),
          if (multiSelectedImage.value.length < maximumSelection) ...[
            ValueListenableBuilder(
              valueListenable: multiSelectionMode,
              builder: (context, bool multiSelectionModeValue, child) {
                if (enableVideo || enableCamera) {
                  if (!showImagePreview) {
                    if (multiSelectionModeValue) {
                      return clearSelectedImages();
                    } else {
                      return buildTabBar();
                    }
                  } else {
                    return Visibility(
                      visible: !multiSelectionModeValue,
                      child: buildTabBar(),
                    );
                  }
                } else {
                  return multiSelectionModeValue
                      ? clearSelectedImages()
                      : const SizedBox();
                }
              },
            )
          ] else ...[
            tapBarMessage(false)
          ],
        ],
      ),
    );
  }

  ValueListenableBuilder<bool> cameraPage() {
    return ValueListenableBuilder(
      valueListenable: selectedVideo,
      builder: (context, bool selectedVideoValue, child) => CustomCameraDisplay(
        appTheme: appTheme,
        selectedCameraImage: selectedCameraImage,
        tapsNames: tapsNames,
        enableCamera: enableCamera,
        enableVideo: enableVideo,
        replacingTabBar: replacingDeleteWidget,
        clearVideoRecord: clearVideoRecord,
        redDeleteText: redDeleteText,
        moveToVideoScreen: moveToVideo,
        selectedVideo: selectedVideoValue,
      ),
    );
  }

  void clearMultiImages() {
    setState(() {
      multiSelectedImage.value.clear();
      multiSelectionMode.value = false;
    });
  }

  ImagesViewPage imagesViewPage() {
    return ImagesViewPage(
      appTheme: appTheme,
      clearMultiImages: clearMultiImages,
      callbackFunction: callbackFunction,
      gridDelegate: gridDelegate,
      multiSelectionMode: multiSelectionMode,
      blackColor: blackColor,
      showImagePreview: showImagePreview,
      tabsTexts: tapsNames,
      multiSelectedImages: multiSelectedImage,
      whiteColor: whiteColor,
      cropImage: cropImage,
      multiSelection: widget.multiSelection,
      showInternalVideos: showInternalVideos,
      showInternalImages: showInternalImages,
      maximumSelection: maximumSelection,
    );
  }

  ValueListenableBuilder<bool> buildTabBar() {
    return ValueListenableBuilder(
      valueListenable: showDeleteText,
      builder: (context, bool showDeleteTextValue, child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeInOutQuart,
        child: widget.source == ImageSource.both ||
                widget.pickerSource == PickerSource.both
            ? (showDeleteTextValue ? tapBarMessage(true) : tabBar())
            : const SizedBox(),
      ),
    );
  }

  Widget tabBar() {
    double widthOfScreen = MediaQuery.of(context).size.width;
    int divideNumber = showAllTabs ? 3 : 2;
    double widthOfTab = widthOfScreen / divideNumber;
    return ValueListenableBuilder(
      valueListenable: selectedPage,
      builder: (context, SelectedPage selectedPageValue, child) {
        Color photoColor =
            selectedPageValue == SelectedPage.center ? blackColor : Colors.grey;
        return Stack(
          alignment: Alignment.bottomLeft,
          children: [
            Row(
              children: [
                if (noGallery) galleryTabBar(widthOfTab, selectedPageValue),
                if (enableCamera) photoTabBar(widthOfTab, photoColor),
                if (enableVideo) videoTabBar(widthOfTab),
              ],
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutQuad,
              right: selectedPageValue == SelectedPage.center
                  ? widthOfTab
                  : (selectedPageValue == SelectedPage.right
                      ? 0
                      : (divideNumber == 2 ? widthOfTab : widthOfScreen / 1.5)),
              child: Container(height: 1, width: widthOfTab, color: blackColor),
            ),
          ],
        );
      },
    );
  }

  GestureDetector galleryTabBar(
      double widthOfTab, SelectedPage selectedPageValue) {
    return GestureDetector(
      onTap: () {
        setState(() {
          centerPage(numPage: 0, selectedPage: SelectedPage.left);
        });
      },
      child: SizedBox(
        width: widthOfTab,
        height: 50,
        child: Center(
          child: Text(
            tapsNames.galleryText,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  GestureDetector photoTabBar(double widthOfTab, Color textColor) {
    return GestureDetector(
      onTap: () => centerPage(
          numPage: cameraVideoOnlyEnabled ? 0 : 1,
          selectedPage:
              cameraVideoOnlyEnabled ? SelectedPage.left : SelectedPage.center),
      child: SizedBox(
        width: widthOfTab,
        height: 50,
        child: Center(
          child: Text(
            tapsNames.photoText,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  centerPage({required int numPage, required SelectedPage selectedPage}) {
    if (!enableVideo && numPage == 1) selectedPage = SelectedPage.right;

    setState(() {
      this.selectedPage.value = selectedPage;
      pageController.value.animateToPage(numPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutQuad);
      selectedVideo.value = false;
    });
  }

  GestureDetector videoTabBar(double widthOfTab) {
    return GestureDetector(
      onTap: () {
        setState(
          () {
            pageController.value.animateToPage(cameraVideoOnlyEnabled ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutQuad);
            selectedPage.value = SelectedPage.right;
            selectedVideo.value = true;
          },
        );
      },
      child: SizedBox(
        width: widthOfTab,
        height: 40,
        child: ValueListenableBuilder(
          valueListenable: selectedVideo,
          builder: (context, bool selectedVideoValue, child) => Center(
            child: Text(
              tapsNames.videoText,
              style: TextStyle(
                  fontSize: 14,
                  color: selectedVideoValue ? blackColor : Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}
