import 'package:flutter/material.dart';
import 'package:handyman_provider_flutter/components/app_widgets.dart';
import 'package:handyman_provider_flutter/models/uploaded_video_model.dart';
import 'package:handyman_provider_flutter/networks/rest_apis.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VendorGuideVideoDialog extends StatefulWidget {
  const VendorGuideVideoDialog({Key? key}) : super(key: key);

  @override
  State<VendorGuideVideoDialog> createState() => _VendorGuideVideoDialogState();
}

class _VendorGuideVideoDialogState extends State<VendorGuideVideoDialog> {
  WebViewController? controller;
  UploadedVideoData? videoData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await getUploadedVideo().then((value) {
      videoData = value.data;
      final videoUrl = getPlayableVideoUrl();

      if (videoUrl.isEmpty) {
        isLoading = false;
        setState(() {});
        return;
      }

      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              isLoading = false;
              setState(() {});
            },
          ),
        )
        ..loadHtmlString(videoHtml(videoUrl));

      setState(() {});
    }).catchError((e) {
      error = e.toString();
      isLoading = false;
      setState(() {});
    });
  }

  bool get isYoutubeVideo {
    final type = videoData?.videoType.validate().toLowerCase();
    return type == 'youtube' ||
        videoData?.youtubeEmbedUrl.validate().isNotEmpty == true ||
        videoData?.youtubeVideoId.validate().isNotEmpty == true ||
        videoData?.youtubeUrl.validate().isNotEmpty == true;
  }

  String getPlayableVideoUrl() {
    if (!isYoutubeVideo) return videoData?.videoUrl.validate() ?? '';

    if (videoData?.youtubeEmbedUrl.validate().isNotEmpty == true) {
      return videoData!.youtubeEmbedUrl.validate();
    }

    final videoId = videoData?.youtubeVideoId.validate();
    if (videoId != null && videoId.isNotEmpty) {
      return 'https://www.youtube.com/embed/$videoId';
    }

    return getYoutubeEmbedUrl(
      videoData?.youtubeUrl.validate().isNotEmpty == true
          ? videoData!.youtubeUrl.validate()
          : videoData?.videoUrl.validate() ?? '',
    );
  }

  String getYoutubeEmbedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    String videoId = uri.queryParameters['v'] ?? '';
    if (videoId.isEmpty && uri.host.contains('youtu.be')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    }
    if (videoId.isEmpty && uri.pathSegments.contains('shorts')) {
      final index = uri.pathSegments.indexOf('shorts');
      videoId = uri.pathSegments.length > index + 1
          ? uri.pathSegments[index + 1]
          : '';
    }
    if (videoId.isEmpty && uri.pathSegments.contains('embed')) {
      final index = uri.pathSegments.indexOf('embed');
      videoId = uri.pathSegments.length > index + 1
          ? uri.pathSegments[index + 1]
          : '';
    }

    return videoId.isNotEmpty ? 'https://www.youtube.com/embed/$videoId' : url;
  }

  String videoHtml(String videoUrl) {
    final safeVideoUrl = videoUrl.replaceAll('"', '&quot;');

    if (isYoutubeVideo) {
      return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background: #000;
        overflow: hidden;
      }
      iframe {
        width: 100%;
        height: 100%;
        border: 0;
        background: #000;
      }
    </style>
  </head>
  <body>
    <iframe
      src="$safeVideoUrl"
      title="Vendor Guide Video"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen>
    </iframe>
  </body>
</html>
''';
    }

    final mimeType =
        videoData?.mimeType.validate(value: 'video/mp4') ?? 'video/mp4';

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background: #000;
        overflow: hidden;
      }
      video {
        width: 100%;
        height: 100%;
        object-fit: contain;
        background: #000;
      }
    </style>
  </head>
  <body>
    <video controls autoplay playsinline>
      <source src="$safeVideoUrl" type="$mimeType">
    </video>
  </body>
</html>
''';
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: 560, maxHeight: context.height() * 0.78),
        decoration: boxDecorationDefault(
          color: context.cardColor,
          borderRadius: radius(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  videoData?.title.validate(value: 'Vendor Guide') ??
                      'Vendor Guide',
                  style: boldTextStyle(size: 16),
                ).expand(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => finish(context),
                ),
              ],
            ).paddingOnly(left: 16, right: 8, top: 8, bottom: 6),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  if (controller != null)
                    WebViewWidget(controller: controller!)
                  else
                    Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Text(
                        error.validate().isNotEmpty
                            ? error.validate()
                            : 'No video found',
                        style: primaryTextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ).paddingAll(16),
                    ),
                  if (isLoading) LoaderWidget().center(),
                ],
              ),
            ).paddingSymmetric(horizontal: 12),
            12.height,
          ],
        ),
      ),
    );
  }
}
