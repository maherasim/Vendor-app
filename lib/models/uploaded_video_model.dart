class UploadedVideoResponse {
  bool? status;
  UploadedVideoData? data;

  UploadedVideoResponse({this.status, this.data});

  factory UploadedVideoResponse.fromJson(Map<String, dynamic> json) {
    return UploadedVideoResponse(
      status: json['status'],
      data: json['data'] != null
          ? UploadedVideoData.fromJson(json['data'])
          : null,
    );
  }
}

class UploadedVideoData {
  int? id;
  String? title;
  int? status;
  String? videoType;
  String? videoUrl;
  String? youtubeUrl;
  String? youtubeVideoId;
  String? youtubeEmbedUrl;
  String? fileName;
  String? mimeType;
  num? size;
  String? updatedAt;

  UploadedVideoData({
    this.id,
    this.title,
    this.status,
    this.videoType,
    this.videoUrl,
    this.youtubeUrl,
    this.youtubeVideoId,
    this.youtubeEmbedUrl,
    this.fileName,
    this.mimeType,
    this.size,
    this.updatedAt,
  });

  factory UploadedVideoData.fromJson(Map<String, dynamic> json) {
    return UploadedVideoData(
      id: parseInt(json['id']),
      title: json['title']?.toString(),
      status: parseInt(json['status']),
      videoType: json['video_type']?.toString(),
      videoUrl: json['video_url']?.toString(),
      youtubeUrl: json['youtube_url']?.toString(),
      youtubeVideoId: json['youtube_video_id']?.toString(),
      youtubeEmbedUrl: json['youtube_embed_url']?.toString(),
      fileName: json['file_name']?.toString(),
      mimeType: json['mime_type']?.toString(),
      size: json['size'],
      updatedAt: json['updated_at']?.toString(),
    );
  }

  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
