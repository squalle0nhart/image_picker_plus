import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker_plus/image_picker_plus.dart';
import 'package:image_picker_plus/src/crop_image_view.dart';
import 'package:image_picker_plus/src/custom_packages/crop_image/crop_image.dart';
import 'package:image_picker_plus/src/image.dart';
import 'package:image_picker_plus/src/multi_selection_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shimmer/shimmer.dart';

class ImagesViewPage extends StatefulWidget {
  final ValueNotifier<List<File>> multiSelectedImages;
  final ValueNotifier<bool> multiSelectionMode;
  final TabsTexts tabsTexts;
  final bool cropImage;
  final bool multiSelection;
  final bool showInternalVideos;
  final bool showInternalImages;
  final int maximumSelection;
  final AsyncValueSetter<SelectedImagesDetails>? callbackFunction;

  /// To avoid lag when you interacting with image when it expanded
  final AppTheme appTheme;
  final VoidCallback clearMultiImages;
  final Color whiteColor;
  final Color blackColor;
  final bool showImagePreview;
  final SliverGridDelegateWithFixedCrossAxisCount gridDelegate;
  const ImagesViewPage({
    Key? key,
    required this.multiSelectedImages,
    required this.multiSelectionMode,
    required this.clearMultiImages,
    required this.appTheme,
    required this.tabsTexts,
    required this.whiteColor,
    required this.cropImage,
    required this.multiSelection,
    required this.showInternalVideos,
    required this.showInternalImages,
    required this.blackColor,
    required this.showImagePreview,
    required this.gridDelegate,
    required this.maximumSelection,
    this.callbackFunction,
  }) : super(key: key);

  @override
  State<ImagesViewPage> createState() => _ImagesViewPageState();
}

class _ImagesViewPageState extends State<ImagesViewPage> with AutomaticKeepAliveClientMixin<ImagesViewPage> {
  final ValueNotifier<List<FutureBuilder<Uint8List?>>> _mediaList = ValueNotifier([]);

  ValueNotifier<List<File?>> allImages = ValueNotifier([]);
  final ValueNotifier<List<double?>> scaleOfCropsKeys = ValueNotifier([]);
  final ValueNotifier<List<Rect?>> areaOfCropsKeys = ValueNotifier([]);

  ValueNotifier<File?> selectedImage = ValueNotifier(null);
  ValueNotifier<List<int>> indexOfSelectedImages = ValueNotifier([]);

  ScrollController scrollController = ScrollController();

  final expandImage = ValueNotifier(false);
  final expandHeight = ValueNotifier(0.0);
  final moveAwayHeight = ValueNotifier(0.0);
  final expandImageView = ValueNotifier(false);

  final isImagesReady = ValueNotifier(false);
  final currentPage = ValueNotifier(0);
  final lastPage = ValueNotifier(0);

  /// To avoid lag when you interacting with image when it expanded
  final enableVerticalTapping = ValueNotifier(false);
  final cropKey = ValueNotifier(GlobalKey<CustomCropState>());
  bool noPaddingForGridView = false;

  double scrollPixels = 0.0;
  bool isScrolling = false;
  bool noImages = false;
  final noDuration = ValueNotifier(false);
  int indexOfLatestImage = -1;

  @override
  void dispose() {
    _mediaList.dispose();
    allImages.dispose();
    scrollController.dispose();
    isImagesReady.dispose();
    lastPage.dispose();
    expandImage.dispose();
    expandHeight.dispose();
    moveAwayHeight.dispose();
    expandImageView.dispose();
    enableVerticalTapping.dispose();
    cropKey.dispose();
    noDuration.dispose();
    scaleOfCropsKeys.dispose();
    areaOfCropsKeys.dispose();
    indexOfSelectedImages.dispose();
    super.dispose();
  }

  late Widget forBack;
  @override
  void initState() {
    _fetchNewMedia(currentPageValue: 0);
    super.initState();
  }

  bool _handleScrollEvent(ScrollNotification scroll, {required int currentPageValue, required int lastPageValue}) {
    if (scroll.metrics.pixels / scroll.metrics.maxScrollExtent > 0.33 && currentPageValue != lastPageValue) {
      _fetchNewMedia(currentPageValue: currentPageValue);
      return true;
    }
    return false;
  }

  _fetchNewMedia({required int currentPageValue}) async {
    lastPage.value = currentPageValue;
    PermissionState result = await PhotoManager.requestPermissionExtend();
    if (result.isAuth) {
      RequestType type = widget.showInternalVideos && widget.showInternalImages ? RequestType.common : (widget.showInternalImages ? RequestType.image : RequestType.video);

      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(onlyAll: true, type: type);
      if (albums.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => noImages = true));
        return;
      } else if (noImages) {
        noImages = false;
      }
      List<AssetEntity> media = await albums[0].getAssetListPaged(page: currentPageValue, size: 60);
      List<FutureBuilder<Uint8List?>> temp = [];
      List<File?> imageTemp = [];

      for (int i = 0; i < media.length; i++) {
        FutureBuilder<Uint8List?> gridViewImage = await getImageGallery(media, i);
        File? image = await highQualityImage(media, i);
        temp.add(gridViewImage);
        imageTemp.add(image);
      }
      _mediaList.value.addAll(temp);
      allImages.value.addAll(imageTemp);
      selectedImage.value = allImages.value[0];
      currentPage.value++;
      isImagesReady.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else {
      await PhotoManager.requestPermissionExtend();
      PhotoManager.openSetting();
    }
  }

  Future<FutureBuilder<Uint8List?>> getImageGallery(List<AssetEntity> media, int i) async {
    bool highResolution = widget.gridDelegate.crossAxisCount <= 3;
    FutureBuilder<Uint8List?> futureBuilder = FutureBuilder(
      future: media[i].thumbnailDataWithSize(highResolution ? const ThumbnailSize(350, 350) : const ThumbnailSize(200, 200)),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          Uint8List? image = snapshot.data;
          if (image != null) {
            return Container(
              color: const Color.fromARGB(255, 189, 189, 189),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: MemoryImageDisplay(imageBytes: image, appTheme: widget.appTheme),
                  ),
                  if (media[i].type == AssetType.video)
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 5, bottom: 5),
                        child: Icon(
                          Icons.slow_motion_video_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
        }
        return const SizedBox();
      },
    );
    return futureBuilder;
  }

  Future<File?> highQualityImage(List<AssetEntity> media, int i) async => media[i].file;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: noImages
          ? Center(
              child: Text(
                widget.tabsTexts.noImagesFounded,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            )
          : buildGridView(),
    );
  }

  ValueListenableBuilder<bool> buildGridView() {
    return ValueListenableBuilder(
      valueListenable: isImagesReady,
      builder: (context, bool isImagesReadyValue, child) {
        if (isImagesReadyValue) {
          return ValueListenableBuilder(
            valueListenable: _mediaList,
            builder: (context, List<FutureBuilder<Uint8List?>> mediaListValue, child) {
              return ValueListenableBuilder(
                valueListenable: lastPage,
                builder: (context, int lastPageValue, child) => ValueListenableBuilder(
                  valueListenable: currentPage,
                  builder: (context, int currentPageValue, child) {
                    if (!widget.showImagePreview) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          normalAppBar(),
                          Flexible(child: normalGridView(mediaListValue, currentPageValue, lastPageValue)),
                        ],
                      );
                    } else {
                      return instagramGridView(mediaListValue, currentPageValue, lastPageValue);
                    }
                  },
                ),
              );
            },
          );
        } else {
          return loadingWidget();
        }
      },
    );
  }

  Widget loadingWidget() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        normalAppBar(),
        const Expanded(
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 40,
                height: 40,
                child: CupertinoActivityIndicator(
                  color: Colors.grey,
                ),
              ),
            )),
      ],
    );
  }

  AppBar appBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 30),
        onPressed: () {
          Navigator.of(context).maybePop(null);
        },
      ),
    );
  }

  Widget normalAppBar() {
    double width = MediaQuery.of(context).size.width;
    return Container(
      color: widget.appTheme.appBarColor,
      height: 56,
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          existButton(),
          const Spacer(),
          doneButton(),
        ],
      ),
    );
  }

  IconButton existButton() {
    return IconButton(
      icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 30),
      onPressed: () {
        Navigator.of(context).maybePop(null);
      },
    );
  }

  Widget doneButton() {
    return ValueListenableBuilder(
      valueListenable: indexOfSelectedImages,
      builder: (context, List<int> indexOfSelectedImagesValue, child) => IconButton(
        icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 32),
        onPressed: () async {
          double aspect = expandImage.value ? 6 / 8 : 1.0;
          if (widget.multiSelectionMode.value && widget.multiSelection) {
            if (areaOfCropsKeys.value.length != widget.multiSelectedImages.value.length) {
              scaleOfCropsKeys.value.add(cropKey.value.currentState?.scale);
              areaOfCropsKeys.value.add(cropKey.value.currentState?.area);
            } else {
              if (indexOfLatestImage != -1) {
                scaleOfCropsKeys.value[indexOfLatestImage] = cropKey.value.currentState?.scale;
                areaOfCropsKeys.value[indexOfLatestImage] = cropKey.value.currentState?.area;
              }
            }

            List<SelectedByte> selectedBytes = [];
            for (int i = 0; i < widget.multiSelectedImages.value.length; i++) {
              File currentImage = widget.multiSelectedImages.value[i];
              String path = currentImage.path;
              bool isThatVideo = path.contains("mp4", path.length - 5);
              File? croppedImage = !isThatVideo && widget.cropImage ? await cropImage(currentImage, indexOfCropImage: i) : null;
              File image = croppedImage ?? currentImage;
              Uint8List byte = await image.readAsBytes();
              SelectedByte img = SelectedByte(
                isThatImage: !isThatVideo,
                selectedFile: image,
                selectedByte: byte,
              );
              selectedBytes.add(img);
            }
            if (selectedBytes.isNotEmpty) {
              SelectedImagesDetails details = SelectedImagesDetails(
                selectedFiles: selectedBytes,
                multiSelectionMode: true,
                aspectRatio: aspect,
              );
              if (!mounted) return;

              if (widget.callbackFunction != null) {
                await widget.callbackFunction!(details);
              } else {
                Navigator.of(context).maybePop(details);
              }
            }
          } else {
            File? image = selectedImage.value;
            if (image == null) return;
            String path = image.path;

            bool isThatVideo = path.contains("mp4", path.length - 5);
            File? croppedImage = !isThatVideo && widget.cropImage ? await cropImage(image) : null;
            File img = croppedImage ?? image;
            Uint8List byte = await img.readAsBytes();

            SelectedByte selectedByte = SelectedByte(
              isThatImage: !isThatVideo,
              selectedFile: img,
              selectedByte: byte,
            );
            SelectedImagesDetails details = SelectedImagesDetails(
              multiSelectionMode: false,
              aspectRatio: aspect,
              selectedFiles: [selectedByte],
            );
            if (!mounted) return;

            if (widget.callbackFunction != null) {
              await widget.callbackFunction!(details);
            } else {
              Navigator.of(context).maybePop(details);
            }
          }
        },
      ),
    );
  }

  Widget normalGridView(List<FutureBuilder<Uint8List?>> mediaListValue, int currentPageValue, int lastPageValue) {
    return NotificationListener(
      onNotification: (ScrollNotification notification) {
        _handleScrollEvent(notification, currentPageValue: currentPageValue, lastPageValue: lastPageValue);
        return true;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.gridDelegate.crossAxisSpacing),
        child: GridView.builder(
          gridDelegate: widget.gridDelegate,
          itemBuilder: (context, index) {
            return buildImage(mediaListValue, index);
          },
          itemCount: mediaListValue.length,
        ),
      ),
    );
  }

  ValueListenableBuilder<File?> buildImage(List<FutureBuilder<Uint8List?>> mediaListValue, int index) {
    return ValueListenableBuilder(
      valueListenable: selectedImage,
      builder: (context, File? selectedImageValue, child) {
        return ValueListenableBuilder(
          valueListenable: allImages,
          builder: (context, List<File?> allImagesValue, child) {
            return ValueListenableBuilder(
              valueListenable: widget.multiSelectedImages,
              builder: (context, List<File> selectedImagesValue, child) {
                FutureBuilder<Uint8List?> mediaList = mediaListValue[index];
                File? image = allImagesValue[index];
                if (image != null) {
                  bool imageSelected = selectedImagesValue.contains(image);
                  List<File> multiImages = selectedImagesValue;
                  return Stack(
                    children: [
                      gestureDetector(image, index, mediaList),
                      if (selectedImageValue == image) gestureDetector(image, index, blurContainer()),
                      MultiSelectionMode(
                        image: image,
                        multiSelectionMode: widget.multiSelectionMode,
                        imageSelected: imageSelected,
                        multiSelectedImage: multiImages,
                      ),
                    ],
                  );
                } else {
                  return Container();
                }
              },
            );
          },
        );
      },
    );
  }

  Stack blurContainer() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          color: Colors.black.withOpacity(0.75),
          height: double.maxFinite,
        ),
        const Center(
          child: Icon(
            Icons.check,
            color: Colors.white,
          ),
        )
      ],
    );
  }

  Widget gestureDetector(File image, int index, Widget childWidget) {
    return ValueListenableBuilder(
      valueListenable: widget.multiSelectionMode,
      builder: (context, bool multipleValue, child) => ValueListenableBuilder(
        valueListenable: widget.multiSelectedImages,
        builder: (context, List<File> selectedImagesValue, child) => GestureDetector(
            onTap: () => onTapImage(image, selectedImagesValue, index),
            onLongPress: () {
              if (widget.multiSelection) {
                widget.multiSelectionMode.value = true;
              }
            },
            onLongPressUp: () {
              if (multipleValue) {
                selectionImageCheck(image, selectedImagesValue, index, enableCopy: true);
                expandImageView.value = false;
                moveAwayHeight.value = 0;

                enableVerticalTapping.value = false;
                setState(() => noPaddingForGridView = true);
              } else {
                onTapImage(image, selectedImagesValue, index);
              }
            },
            child: childWidget),
      ),
    );
  }

  onTapImage(File image, List<File> selectedImagesValue, int index) {
    setState(() {
      if (widget.multiSelectionMode.value) {
        bool close = selectionImageCheck(image, selectedImagesValue, index);
        if (close) return;
      }
      selectedImage.value = image;
      expandImageView.value = false;
      moveAwayHeight.value = 0;
      enableVerticalTapping.value = false;
      noPaddingForGridView = true;
    });
  }

  bool selectionImageCheck(File image, List<File> multiSelectionValue, int index, {bool enableCopy = false}) {
    if (multiSelectionValue.contains(image) && selectedImage.value == image) {
      setState(() {
        int indexOfImage = multiSelectionValue.indexWhere((element) => element == image);
        multiSelectionValue.removeAt(indexOfImage);
        if (multiSelectionValue.isNotEmpty && indexOfImage < scaleOfCropsKeys.value.length) {
          indexOfSelectedImages.value.remove(index);

          scaleOfCropsKeys.value.removeAt(indexOfImage);
          areaOfCropsKeys.value.removeAt(indexOfImage);
          indexOfLatestImage = -1;
        }
      });

      return true;
    } else {
      if (multiSelectionValue.length < widget.maximumSelection) {
        setState(() {
          if (!multiSelectionValue.contains(image)) {
            multiSelectionValue.add(image);
            if (multiSelectionValue.length > 1) {
              scaleOfCropsKeys.value.add(cropKey.value.currentState?.scale);
              areaOfCropsKeys.value.add(cropKey.value.currentState?.area);
              indexOfSelectedImages.value.add(index);
            }
          } else if (areaOfCropsKeys.value.length != multiSelectionValue.length) {
            scaleOfCropsKeys.value.add(cropKey.value.currentState?.scale);
            areaOfCropsKeys.value.add(cropKey.value.currentState?.area);
          }
          if (widget.showImagePreview && multiSelectionValue.contains(image)) {
            int index = multiSelectionValue.indexWhere((element) => element == image);
            if (indexOfLatestImage != -1) {
              scaleOfCropsKeys.value[indexOfLatestImage] = cropKey.value.currentState?.scale;
              areaOfCropsKeys.value[indexOfLatestImage] = cropKey.value.currentState?.area;
            }
            indexOfLatestImage = index;
          }

          if (enableCopy) selectedImage.value = image;
        });
      }
      return false;
    }
  }

  Future<File?> cropImage(File imageFile, {int? indexOfCropImage}) async {
    final double? scale;
    final Rect? area;
    if (indexOfCropImage == null) {
      scale = cropKey.value.currentState?.scale;
      area = cropKey.value.currentState?.area;
    } else {
      scale = scaleOfCropsKeys.value[indexOfCropImage];
      area = areaOfCropsKeys.value[indexOfCropImage];
    }

    if (area == null || scale == null) return null;

    final crop = await ImageCropper.platform.cropImage(
      sourcePath: imageFile.path,
      aspectRatioPresets: [CropAspectRatioPreset.square, CropAspectRatioPreset.ratio3x2, CropAspectRatioPreset.original, CropAspectRatioPreset.ratio4x3, CropAspectRatioPreset.ratio16x9],
    );
    if (crop == null) {
      return null;
    }

    final File file = File(crop.path);
    return file;
  }

  void clearMultiImages() {
    setState(() {
      widget.multiSelectedImages.value = [];
      widget.clearMultiImages();
      indexOfSelectedImages.value.clear();
      scaleOfCropsKeys.value.clear();
      areaOfCropsKeys.value.clear();
    });
  }

  Widget instagramGridView(List<FutureBuilder<Uint8List?>> mediaListValue, int currentPageValue, int lastPageValue) {
    return ValueListenableBuilder(
      valueListenable: expandHeight,
      builder: (context, double expandedHeightValue, child) {
        return ValueListenableBuilder(
          valueListenable: moveAwayHeight,
          builder: (context, double moveAwayHeightValue, child) => ValueListenableBuilder(
            valueListenable: expandImageView,
            builder: (context, bool expandImageValue, child) {
              double a = expandedHeightValue - 360;
              double expandHeightV = a < 0 ? a : 0;
              double moveAwayHeightV = moveAwayHeightValue < 360 ? moveAwayHeightValue * -1 : -360;
              double topPosition = expandImageValue ? expandHeightV : moveAwayHeightV;
              enableVerticalTapping.value = !(topPosition == 0);
              double padding = 2;
              if (scrollPixels < 416) {
                double pixels = 416 - scrollPixels;
                padding = pixels >= 58 ? pixels + 2 : 58;
              } else if (expandImageValue) {
                padding = 58;
              } else if (noPaddingForGridView) {
                padding = 58;
              } else {
                padding = topPosition + 418;
              }
              int duration = noDuration.value ? 0 : 250;

              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: padding),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        expandImageView.value = false;
                        moveAwayHeight.value = scrollController.position.pixels;
                        scrollPixels = scrollController.position.pixels;
                        setState(() {
                          isScrolling = true;
                          noPaddingForGridView = false;
                          noDuration.value = false;
                          if (notification is ScrollEndNotification) {
                            expandHeight.value = expandedHeightValue > 240 ? 360 : 0;
                            isScrolling = false;
                          }
                        });

                        _handleScrollEvent(notification, currentPageValue: currentPageValue, lastPageValue: lastPageValue);
                        return true;
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: widget.gridDelegate.crossAxisSpacing),
                        child: GridView.builder(
                          gridDelegate: widget.gridDelegate,
                          controller: scrollController,
                          itemBuilder: (context, index) {
                            return buildImage(mediaListValue, index);
                          },
                          itemCount: mediaListValue.length,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    top: topPosition,
                    duration: Duration(milliseconds: duration),
                    child: Column(
                      children: [
                        normalAppBar(),
                        CropImageView(
                          cropKey: cropKey,
                          indexOfSelectedImages: indexOfSelectedImages,
                          selectedImage: selectedImage,
                          appTheme: widget.appTheme,
                          multiSelectionMode: widget.multiSelectionMode,
                          enableVerticalTapping: enableVerticalTapping,
                          expandHeight: expandHeight,
                          expandImage: expandImage,
                          expandImageView: expandImageView,
                          noDuration: noDuration,
                          clearMultiImages: clearMultiImages,
                          topPosition: topPosition,
                          whiteColor: widget.whiteColor,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
