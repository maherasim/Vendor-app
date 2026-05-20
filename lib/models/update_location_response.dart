class UpdateLocationResponse {
  Data data;
  String message;

  UpdateLocationResponse({
    required this.data,
    this.message = "",
  });

  factory UpdateLocationResponse.fromJson(Map<String, dynamic> json) {
    return UpdateLocationResponse(
      data: json['data'] is Map ? Data.fromJson(json['data']) : Data(),
      message: json['message'] is String ? json['message'] : "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.toJson(),
      'message': message,
    };
  }
}

class Data {
  String bookingId;
  num latitude;
  num longitude;

  String datetime;

  Data({
    this.bookingId = "",
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.datetime = "",
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      bookingId: (json['booking_id'] ?? json['order_id'] ?? '').toString(),
      latitude: json['latitude'] is num
          ? json['latitude']
          : num.tryParse(json['latitude']?.toString() ?? '') ?? 0.0,
      longitude: json['longitude'] is num
          ? json['longitude']
          : num.tryParse(json['longitude']?.toString() ?? '') ?? 0.0,
      datetime: json['datetime'] is String ? json['datetime'] : "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'latitude': latitude,
      'longitude': longitude,
      'datetime': datetime,
    };
  }
}
