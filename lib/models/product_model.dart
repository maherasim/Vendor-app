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
  });

  factory ProductData.fromJson(Map<String, dynamic> json) {
    final rawAttachments =
        json['attchments_array'] ?? json['attachments'] ?? [];
    return ProductData(
      id: json['id'],
      name: json['name'],
      categoryId: json['category_id'],
      subcategoryId: json['subcategory_id'],
      providerId: json['provider_id'],
      price: json['price'],
      priceFormat: json['price_format'],
      discount: json['discount'],
      status: json['status'],
      description: json['description'],
      isFeatured: json['is_featured'],
      productImage: json['product_image'],
      attachments: rawAttachments is List
          ? rawAttachments.map((e) => ProductAttachment.fromJson(e)).toList()
          : [],
      totalStock: json['total_stock'],
      maxPurchaseQty: json['max_purchase_qty'],
      productUnitId: json['product_unit_id'],
      productUnitName: json['product_unit_name'],
      serviceRequestStatus: json['service_request_status'],
      requiresVariantSelection: json['requires_variant_selection'],
      variantAttributeName: json['variant_attribute_name'],
      variants: json['variants'] is List
          ? List<ProductVariant>.from(
              json['variants'].map((e) => ProductVariant.fromJson(e)))
          : [],
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
}

class ProductAttachment {
  int? id;
  String? url;

  ProductAttachment({this.id, this.url});

  factory ProductAttachment.fromJson(dynamic json) {
    if (json is String) return ProductAttachment(url: json);
    return ProductAttachment(
      id: json['id'],
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
      id: json['id'],
      productVariantId: json['product_variant_id'],
      productAttributeOptionId: json['product_attribute_option_id'],
      optionValue: json['option_value'],
      attributeName: json['attribute_name'],
      label: json['label'],
      price: json['price'],
      stock: json['stock'],
      maxAllowedQuantity: json['max_allowed_quantity'],
      isAvailable: json['is_available'],
      status: json['status'],
    );
  }
}
