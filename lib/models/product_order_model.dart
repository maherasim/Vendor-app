import 'package:handyman_provider_flutter/models/pagination_model.dart';
import 'package:nb_utils/nb_utils.dart';

class ProductOrderStatusKeys {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const accept = 'accept';
  static const assigned = 'assigned';
  static const onGoing = 'on_going';
  static const delivered = 'delivered';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const rejected = 'rejected';
  static const all = 'all';
}

class ProductOrderListResponse {
  bool? status;
  List<ProductOrderData>? data;
  String? totalEarning;
  ProductOrderPaymentBreakdown? paymentBreakdown;
  Pagination? pagination;

  ProductOrderListResponse(
      {this.status,
      this.data,
      this.totalEarning,
      this.paymentBreakdown,
      this.pagination});

  factory ProductOrderListResponse.fromJson(Map<String, dynamic> json) {
    return ProductOrderListResponse(
      status: json['status'],
      data: json['data'] is List
          ? List<ProductOrderData>.from(
              json['data'].map((e) => ProductOrderData.fromJson(e)))
          : [],
      totalEarning: json['total_earning']?.toString(),
      paymentBreakdown: json['payment_breakdown'] is Map
          ? ProductOrderPaymentBreakdown.fromJson(
              Map<String, dynamic>.from(json['payment_breakdown']))
          : null,
      pagination: json['pagination'] is Map
          ? Pagination.fromJson(Map<String, dynamic>.from(json['pagination']))
          : null,
    );
  }
}

class ProductOrderDetailResponse {
  bool? status;
  ProductOrderData? data;

  ProductOrderDetailResponse({this.status, this.data});

  factory ProductOrderDetailResponse.fromJson(Map<String, dynamic> json) {
    return ProductOrderDetailResponse(
      status: json['status'],
      data: json['data'] is Map
          ? ProductOrderData.fromJson(Map<String, dynamic>.from(json['data']))
          : null,
    );
  }
}

class ProductOrderPaymentBreakdown {
  num cash;
  num online;
  num wallet;

  ProductOrderPaymentBreakdown(
      {this.cash = 0, this.online = 0, this.wallet = 0});

  factory ProductOrderPaymentBreakdown.fromJson(Map<String, dynamic> json) {
    return ProductOrderPaymentBreakdown(
      cash: _parseNum(json['cash']),
      online: _parseNum(json['online']),
      wallet: _parseNum(json['wallet']),
    );
  }
}

class ProductOrderData {
  int? id;
  String? orderCode;
  String? status;
  String? statusLabel;
  String? deliveryStatus;
  String? deliveryStatusLabel;
  String? paymentStatus;
  String? paymentMethod;
  int? paymentId;
  String? txnId;
  num? subtotal;
  String? subtotalFormat;
  num? discount;
  num? taxTotal;
  String? taxTotalFormat;
  num? deliveryCharge;
  num? total;
  String? totalFormat;
  String? date;
  String? description;
  int? customerId;
  String? customerName;
  String? customerImage;
  String? customerPhone;
  String? deliveryAddressText;
  String? deliveryLatitude;
  String? deliveryLongitude;
  int? shopId;
  String? shopName;
  int? handymanId;
  String? productImage;
  int? productCount;
  ProductOrderUser? provider;
  ProductOrderUser? customer;
  ProductOrderAddress? deliveryAddress;
  ProductOrderShipping? shipping;
  ProductOrderShop? shop;
  ProductOrderUser? deliveryBoy;
  List<ProductOrderItem>? items;
  List<ProductOrderActivity>? activity;
  List<ProductOrderProof>? proof;
  ProductOrderLocation? latestLocation;

  ProductOrderData({
    this.id,
    this.orderCode,
    this.status,
    this.statusLabel,
    this.deliveryStatus,
    this.deliveryStatusLabel,
    this.paymentStatus,
    this.paymentMethod,
    this.paymentId,
    this.txnId,
    this.subtotal,
    this.subtotalFormat,
    this.discount,
    this.taxTotal,
    this.taxTotalFormat,
    this.deliveryCharge,
    this.total,
    this.totalFormat,
    this.date,
    this.description,
    this.customerId,
    this.customerName,
    this.customerImage,
    this.customerPhone,
    this.deliveryAddressText,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.shopId,
    this.shopName,
    this.handymanId,
    this.productImage,
    this.productCount,
    this.provider,
    this.customer,
    this.deliveryAddress,
    this.shipping,
    this.shop,
    this.deliveryBoy,
    this.items,
    this.activity,
    this.proof,
    this.latestLocation,
  });

  factory ProductOrderData.fromJson(Map<String, dynamic> json) {
    final shippingJson = _shippingJson(json);

    return ProductOrderData(
      id: _parseInt(json['id']),
      orderCode:
          json['order_code']?.toString() ?? json['order_number']?.toString(),
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
      deliveryStatus:
          json['delivery_status']?.toString() ?? json['status']?.toString(),
      deliveryStatusLabel: json['delivery_status_label']?.toString() ??
          json['status_label']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString() ??
          json['payment_type']?.toString(),
      paymentId: _parseInt(json['payment_id']),
      txnId: json['txn_id']?.toString(),
      subtotal: _parseNum(json['subtotal']),
      subtotalFormat: (json['subtotal_format'] ?? '').toString(),
      discount: _parseNum(json['discount']),
      taxTotal: _parseNum(json['tax_total'] ?? json['tax']),
      taxTotalFormat:
          (json['tax_total_format'] ?? json['tax_format'] ?? '').toString(),
      deliveryCharge: _parseNum(json['delivery_charge']),
      total: _parseNum(json['total'] ?? json['total_amount']),
      totalFormat: (json['total_format'] ?? json['total_amount_format'] ?? '')
          .toString(),
      date: json['date']?.toString() ??
          json['order_date']?.toString() ??
          json['created_at']?.toString(),
      description: json['description']?.toString(),
      customerId: _parseInt(json['customer_id']),
      customerName: json['customer_name']?.toString(),
      customerImage: json['customer_image']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      deliveryAddressText: json['delivery_address']?.toString(),
      deliveryLatitude: json['delivery_latitude']?.toString(),
      deliveryLongitude: json['delivery_longitude']?.toString(),
      shopId: _parseInt(json['shop_id']),
      shopName: json['shop_name']?.toString(),
      handymanId: _parseInt(json['handyman_id']),
      productImage: json['product_image']?.toString(),
      productCount: _parseInt(json['product_count']),
      provider: json['provider'] is Map
          ? ProductOrderUser.fromJson(
              Map<String, dynamic>.from(json['provider']))
          : null,
      customer: json['customer'] is Map
          ? ProductOrderUser.fromJson(
              Map<String, dynamic>.from(json['customer']))
          : null,
      deliveryAddress: json['delivery_address'] is Map
          ? ProductOrderAddress.fromJson(
              Map<String, dynamic>.from(json['delivery_address']))
          : null,
      shipping: shippingJson != null
          ? ProductOrderShipping.fromJson(shippingJson)
          : null,
      shop: json['shop'] is Map
          ? ProductOrderShop.fromJson(Map<String, dynamic>.from(json['shop']))
          : null,
      deliveryBoy: json['delivery_boy'] is Map
          ? ProductOrderUser.fromJson(
              Map<String, dynamic>.from(json['delivery_boy']))
          : null,
      items: json['items'] is List
          ? List<ProductOrderItem>.from(
              json['items'].map((e) => ProductOrderItem.fromJson(e)))
          : [],
      activity: json['activity'] is List
          ? List<ProductOrderActivity>.from(
              json['activity'].map((e) => ProductOrderActivity.fromJson(e)))
          : [],
      proof: json['proof'] is List
          ? List<ProductOrderProof>.from(
              json['proof'].map((e) => ProductOrderProof.fromJson(e)))
          : [],
      latestLocation: json['latest_location'] is Map
          ? ProductOrderLocation.fromJson(
              Map<String, dynamic>.from(json['latest_location']))
          : null,
    );
  }

  String get displayCode => orderCode.validate().isNotEmpty
      ? orderCode.validate()
      : '#${id.validate()}';
  String get displayCustomerName =>
      customer?.displayName.validate().isNotEmpty == true
          ? customer!.displayName.validate()
          : customerName.validate();
  String get displayCustomerImage =>
      customer?.profileImage.validate().isNotEmpty == true
          ? customer!.profileImage.validate()
          : customerImage.validate();
  String get displayAddress =>
      deliveryAddress?.address.validate().isNotEmpty == true
          ? deliveryAddress!.address.validate()
          : shipping?.fullAddress.validate().isNotEmpty == true
              ? shipping!.fullAddress
              : deliveryAddressText.validate();
  String get mapAddress =>
      deliveryAddress?.address.validate().isNotEmpty == true
          ? deliveryAddress!.address.validate()
          : shipping?.address.validate().isNotEmpty == true
              ? shipping!.address.validate()
              : displayAddress;
  String get displayImage => productImage.validate().isNotEmpty
      ? productImage.validate()
      : items.validate().isNotEmpty
          ? items!.first.image.validate()
          : '';
  String get displayTotal => totalFormat.validate().isNotEmpty
      ? totalFormat.validate()
      : total.validate().toString();
  bool get hasDeliveryBoy => deliveryBoy != null || handymanId.validate() > 0;
  String get effectiveDeliveryStatus => deliveryStatus.validate().isNotEmpty
      ? deliveryStatus.validate()
      : status.validate();
  String get effectiveDeliveryStatusLabel =>
      deliveryStatusLabel.validate().isNotEmpty
          ? deliveryStatusLabel.validate()
          : statusLabel.validate();
  bool get isDeliveryAccepted =>
      effectiveDeliveryStatus == ProductOrderStatusKeys.accepted ||
      effectiveDeliveryStatus == ProductOrderStatusKeys.accept;
}

class ProductOrderShipping {
  String? name;
  String? address;
  String? city;
  String? state;
  String? pincode;
  String? country;

  ProductOrderShipping({
    this.name,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.country,
  });

  factory ProductOrderShipping.fromJson(Map<String, dynamic> json) {
    return ProductOrderShipping(
      name: json['name']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      country: json['country']?.toString(),
    );
  }

  String get fullAddress {
    return [
      address.validate(),
      city.validate(),
      state.validate(),
      pincode.validate(),
      country.validate(),
    ].where((element) => element.isNotEmpty).join(', ');
  }
}

class ProductOrderUser {
  int? id;
  String? displayName;
  String? profileImage;
  String? phone;
  String? email;
  bool? isAvailable;

  ProductOrderUser(
      {this.id,
      this.displayName,
      this.profileImage,
      this.phone,
      this.email,
      this.isAvailable});

  factory ProductOrderUser.fromJson(Map<String, dynamic> json) {
    return ProductOrderUser(
      id: _parseInt(json['id']),
      displayName: json['display_name']?.toString() ?? json['name']?.toString(),
      profileImage: json['profile_image']?.toString(),
      phone: json['phone']?.toString() ?? json['contact_number']?.toString(),
      email: json['email']?.toString(),
      isAvailable: json['is_available'] is bool
          ? json['is_available']
          : json['is_handyman_available'] is bool
              ? json['is_handyman_available']
              : null,
    );
  }
}

class ProductOrderAddress {
  int? id;
  String? address;
  String? latitude;
  String? longitude;

  ProductOrderAddress({this.id, this.address, this.latitude, this.longitude});

  factory ProductOrderAddress.fromJson(Map<String, dynamic> json) {
    return ProductOrderAddress(
      id: _parseInt(json['id']),
      address: json['address']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
    );
  }
}

class ProductOrderShop {
  int? id;
  String? name;
  String? address;
  String? latitude;
  String? longitude;
  String? image;

  ProductOrderShop(
      {this.id,
      this.name,
      this.address,
      this.latitude,
      this.longitude,
      this.image});

  factory ProductOrderShop.fromJson(Map<String, dynamic> json) {
    return ProductOrderShop(
      id: _parseInt(json['id']),
      name: json['name']?.toString(),
      address: json['address']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      image: json['image']?.toString(),
    );
  }
}

class ProductOrderItem {
  int? id;
  int? productId;
  String? name;
  String? description;
  String? image;
  List<String>? attachments;
  int? quantity;
  num? price;
  String? priceFormat;
  num? total;
  int? variantId;
  String? variantLabel;

  ProductOrderItem(
      {this.id,
      this.productId,
      this.name,
      this.description,
      this.image,
      this.attachments,
      this.quantity,
      this.price,
      this.priceFormat,
      this.total,
      this.variantId,
      this.variantLabel});

  factory ProductOrderItem.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'])
        : <String, dynamic>{};

    return ProductOrderItem(
      id: _parseInt(json['id']),
      productId: _parseInt(json['product_id']),
      name: json['name']?.toString() ??
          json['product_name']?.toString() ??
          productJson['name']?.toString(),
      description: json['description']?.toString(),
      image: json['image']?.toString() ?? productJson['image']?.toString(),
      attachments: json['attachments'] is List
          ? List<String>.from(json['attachments'].map((e) => e.toString()))
          : [],
      quantity: _parseInt(json['quantity']),
      price: _parseNum(json['price'] ?? json['unit_price']),
      priceFormat: json['price_format']?.toString() ??
          json['unit_price_format']?.toString(),
      total: _parseNum(json['total'] ?? json['line_total']),
      variantId: _parseInt(json['variant_id'] ?? json['product_variant_id']),
      variantLabel: json['variant_label']?.toString(),
    );
  }
}

class ProductOrderActivity {
  int? id;
  int? orderId;
  String? activityType;
  String? activityMessage;
  String? datetime;
  int? createdBy;

  ProductOrderActivity(
      {this.id,
      this.orderId,
      this.activityType,
      this.activityMessage,
      this.datetime,
      this.createdBy});

  factory ProductOrderActivity.fromJson(Map<String, dynamic> json) {
    return ProductOrderActivity(
      id: _parseInt(json['id']),
      orderId: _parseInt(json['order_id']),
      activityType: json['activity_type']?.toString(),
      activityMessage: json['activity_message']?.toString(),
      datetime: json['datetime']?.toString(),
      createdBy: _parseInt(json['created_by']),
    );
  }
}

class ProductOrderProof {
  int? id;
  String? url;
  String? description;
  String? createdAt;

  ProductOrderProof({this.id, this.url, this.description, this.createdAt});

  factory ProductOrderProof.fromJson(Map<String, dynamic> json) {
    return ProductOrderProof(
      id: _parseInt(json['id']),
      url: json['url']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ProductOrderLocation {
  int? orderId;
  num? latitude;
  num? longitude;
  String? datetime;

  ProductOrderLocation(
      {this.orderId, this.latitude, this.longitude, this.datetime});

  factory ProductOrderLocation.fromJson(Map<String, dynamic> json) {
    return ProductOrderLocation(
      orderId: _parseInt(json['order_id'] ?? json['id']),
      latitude: _parseNum(json['latitude']),
      longitude: _parseNum(json['longitude']),
      datetime: json['datetime']?.toString(),
    );
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return value.toString().toInt();
}

num _parseNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}

Map<String, dynamic>? _shippingJson(Map<String, dynamic> json) {
  if (json['shipping'] is Map) {
    return Map<String, dynamic>.from(json['shipping']);
  }
  if (json['notes'] is Map) {
    final notes = Map<String, dynamic>.from(json['notes']);
    if (notes['shipping'] is Map) {
      return Map<String, dynamic>.from(notes['shipping']);
    }
  }
  return null;
}
