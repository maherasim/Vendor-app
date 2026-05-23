import 'package:handyman_provider_flutter/models/pagination_model.dart';
import 'package:nb_utils/nb_utils.dart';

class ProductListResponse {
  bool? status;
  List<ProductData>? data;
  Pagination? pagination;

  ProductListResponse({this.status, this.data, this.pagination});

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    return ProductListResponse(
      status: json['status'],
      data: json['data'] is List
          ? List<ProductData>.from(
              json['data'].map((e) => ProductData.fromJson(e)))
          : [],
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class ProductDetailResponse {
  bool? status;
  ProductData? data;
  bool? hasVariants;

  ProductDetailResponse({this.status, this.data, this.hasVariants});

  factory ProductDetailResponse.fromJson(Map<String, dynamic> json) {
    return ProductDetailResponse(
      status: json['status'],
      data: json['data'] != null ? ProductData.fromJson(json['data']) : null,
      hasVariants: json['has_variants'],
    );
  }
}

class ProductFormConfigResponse {
  bool? status;
  ProductFormConfigData? data;

  ProductFormConfigResponse({this.status, this.data});

  factory ProductFormConfigResponse.fromJson(Map<String, dynamic> json) {
    return ProductFormConfigResponse(
      status: json['status'],
      data: json['data'] != null
          ? ProductFormConfigData.fromJson(json['data'])
          : null,
    );
  }
}

class ProductFormConfigData {
  List<ProductAttributeData>? attributes;
  List<ProductUnitData>? units;

  ProductFormConfigData({this.attributes, this.units});

  factory ProductFormConfigData.fromJson(Map<String, dynamic> json) {
    return ProductFormConfigData(
      attributes: json['attributes'] is List
          ? List<ProductAttributeData>.from(
              json['attributes'].map((e) => ProductAttributeData.fromJson(e)))
          : [],
      units: json['units'] is List
          ? List<ProductUnitData>.from(
              json['units'].map((e) => ProductUnitData.fromJson(e)))
          : [],
    );
  }
}

class ProductAttributeData {
  int? id;
  String? name;
  List<ProductAttributeOptionData>? options;

  ProductAttributeData({this.id, this.name, this.options});

  factory ProductAttributeData.fromJson(Map<String, dynamic> json) {
    return ProductAttributeData(
      id: ProductData.parseInt(json['id']),
      name: json['name']?.toString(),
      options: json['options'] is List
          ? List<ProductAttributeOptionData>.from(json['options']
              .map((e) => ProductAttributeOptionData.fromJson(e)))
          : [],
    );
  }
}

class ProductAttributeOptionData {
  int? id;
  String? value;

  ProductAttributeOptionData({this.id, this.value});

  factory ProductAttributeOptionData.fromJson(Map<String, dynamic> json) {
    return ProductAttributeOptionData(
      id: ProductData.parseInt(json['id']),
      value: json['value']?.toString(),
    );
  }
}

class ProductUnitData {
  int? id;
  String? name;

  ProductUnitData({this.id, this.name});

  factory ProductUnitData.fromJson(Map<String, dynamic> json) {
    return ProductUnitData(
      id: ProductData.parseInt(json['id']),
      name: json['name']?.toString(),
    );
  }
}

class ProductData {
  int? id;
  String? name;
  int? categoryId;
  int? subcategoryId;
  int? providerId;
  num? price;
  String? priceFormat;
  num? discount;
  int? status;
  String? description;
  int? isFeatured;
  String? productImage;
  List<ProductAttachment>? attachments;
  int? totalStock;
  int? maxPurchaseQty;
  int? productUnitId;
  String? productUnitName;
  String? serviceRequestStatus;
  bool? requiresVariantSelection;
  String? variantAttributeName;
  List<ProductVariant>? variants;
  List<int>? serviceZoneIds;

  ProductData({
    this.id,
    this.name,
    this.categoryId,
    this.subcategoryId,
    this.providerId,
    this.price,
    this.priceFormat,
    this.discount,
    this.status,
    this.description,
    this.isFeatured,
    this.productImage,
    this.attachments,
    this.totalStock,
    this.maxPurchaseQty,
    this.productUnitId,
    this.productUnitName,
    this.serviceRequestStatus,
    this.requiresVariantSelection,
    this.variantAttributeName,
    this.variants,
    this.serviceZoneIds,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) {
    final rawAttachments =
        json['attchments_array'] ?? json['attachments'] ?? [];
    return ProductData(
      id: parseInt(json['id']),
      name: json['name']?.toString(),
      categoryId: parseInt(json['category_id']),
      subcategoryId: parseInt(json['subcategory_id']),
      providerId: parseInt(json['provider_id']),
      price: json['price'],
      priceFormat: json['price_format']?.toString(),
      discount: json['discount'],
      status: parseInt(json['status']),
      description: json['description']?.toString(),
      isFeatured: parseInt(json['is_featured']),
      productImage: json['product_image']?.toString(),
      attachments: rawAttachments is List
          ? rawAttachments.map((e) => ProductAttachment.fromJson(e)).toList()
          : [],
      totalStock: parseInt(json['total_stock']),
      maxPurchaseQty: parseInt(json['max_purchase_qty']),
      productUnitId: parseInt(json['product_unit_id']),
      productUnitName: json['product_unit_name']?.toString(),
      serviceRequestStatus: json['service_request_status']?.toString(),
      requiresVariantSelection: parseBool(json['requires_variant_selection']),
      variantAttributeName: json['variant_attribute_name']?.toString(),
      variants: json['variants'] is List
          ? List<ProductVariant>.from(
              json['variants'].map((e) => ProductVariant.fromJson(e)))
          : [],
      serviceZoneIds: _parseServiceZoneIds(json),
    );
  }

  List<String> get imageUrls {
    final urls = attachments
        .validate()
        .map((e) => e.url.validate())
        .where((e) => e.isNotEmpty)
        .toList();
    if (urls.isEmpty && productImage.validate().isNotEmpty)
      urls.add(productImage.validate());
    return urls;
  }

  static List<int> _parseServiceZoneIds(Map<String, dynamic> json) {
    final rawZoneIds = json['service_zone_ids'];
    if (rawZoneIds is List) {
      final ids = rawZoneIds
          .map((id) {
            if (id is int) return id;
            if (id is String) return int.tryParse(id);
            return null;
          })
          .whereType<int>()
          .toSet()
          .toList();

      if (ids.isNotEmpty) return ids;
    }

    if (json['service_zone_ids'] != null &&
        json['service_zone_ids'] is String) {
      final String str = json['service_zone_ids'];
      final parts = str.split(',');
      final ids =
          parts.map((e) => int.tryParse(e.trim())).whereType<int>().toList();
      if (ids.isNotEmpty) return ids;
    }

    final rawZones =
        json['service_zones'] ?? json['zones'] ?? json['provider_zones'];
    if (rawZones is! List) {
      final zoneId = json['zone_id'];
      if (zoneId is int) return [zoneId];
      if (zoneId is String) {
        final parsedZoneId = int.tryParse(zoneId);
        if (parsedZoneId != null) return [parsedZoneId];
      }
      return [];
    }

    return rawZones
        .map((zone) {
          if (zone is int) return zone;
          if (zone is String) return int.tryParse(zone);
          if (zone is Map) {
            final id =
                zone['id'] ?? zone['zone_id'] ?? zone['provider_zone_id'];
            if (id is int) return id;
            if (id is String) return int.tryParse(id);
          }
          return null;
        })
        .whereType<int>()
        .toSet()
        .toList();
  }

  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is num) return value.toInt() == 1;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }
}

class ProductAttachment {
  int? id;
  String? url;

  ProductAttachment({this.id, this.url});

  factory ProductAttachment.fromJson(dynamic json) {
    if (json is String) return ProductAttachment(url: json);
    return ProductAttachment(
      id: ProductData.parseInt(json['id']),
      url: json['url'] ??
          json['full_url'] ??
          json['product_image'] ??
          json['file_url'],
    );
  }
}

class ProductVariant {
  int? id;
  int? productVariantId;
  int? productAttributeOptionId;
  String? optionValue;
  String? attributeName;
  String? label;
  num? price;
  int? stock;
  int? maxAllowedQuantity;
  bool? isAvailable;
  int? status;

  ProductVariant({
    this.id,
    this.productVariantId,
    this.productAttributeOptionId,
    this.optionValue,
    this.attributeName,
    this.label,
    this.price,
    this.stock,
    this.maxAllowedQuantity,
    this.isAvailable,
    this.status,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: ProductData.parseInt(json['id']),
      productVariantId: ProductData.parseInt(json['product_variant_id']),
      productAttributeOptionId:
          ProductData.parseInt(json['product_attribute_option_id']),
      optionValue: json['option_value']?.toString(),
      attributeName: json['attribute_name']?.toString(),
      label: json['label']?.toString(),
      price: json['price'],
      stock: ProductData.parseInt(json['stock']),
      maxAllowedQuantity: ProductData.parseInt(json['max_allowed_quantity']),
      isAvailable: ProductData.parseBool(json['is_available']),
      status: ProductData.parseInt(json['status']),
    );
  }
}
