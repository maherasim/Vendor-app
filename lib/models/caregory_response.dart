import 'package:handyman_provider_flutter/models/pagination_model.dart';

class CategoryResponse {
  Pagination? pagination;
  List<CategoryData>? data;

  CategoryResponse({this.pagination, this.data});

  CategoryResponse.fromJson(Map<String, dynamic> json) {
    pagination = json['pagination'] != null
        ? Pagination.fromJson(json['pagination'])
        : null;
    final categoryData = json['data'] ?? json['results'];
    if (categoryData != null) {
      data = [];
      categoryData.forEach((v) {
        data!.add(CategoryData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    if (pagination != null) {
      data['pagination'] = pagination!.toJson();
    }
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class CategoryData {
  int? id;
  String? name;
  int? status;
  String? description;
  int? isFeatured;
  String? color;
  String? categoryImage;
  int? categoryId;
  String? categoryExtension;
  String? categoryName;
  int? services;

  CategoryData(
      {this.id,
      this.name,
      this.status,
      this.description,
      this.isFeatured,
      this.color,
      this.categoryImage,
      this.categoryId,
      this.categoryExtension,
      this.categoryName,
      this.services});

  //CategoryData({this.id, this.name, this.status, this.description, this.isFeatured, this.color, this.categoryImage});

  CategoryData.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = json['name']?.toString() ?? json['text']?.toString();
    status = parseInt(json['status']);
    description = json['description'];
    isFeatured = parseInt(json['is_featured']);
    color = json['color'];
    categoryImage = json['category_image'];
    categoryId = parseInt(json['category_id']);
    categoryExtension = json['category_extension'];
    categoryName = json['category_name']?.toString();
    services = parseInt(json['services']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['id'] = id;
    data['name'] = name;
    data['status'] = status;
    data['description'] = description;
    data['is_featured'] = isFeatured;
    data['color'] = color;
    data['category_image'] = categoryImage;
    data['category_id'] = categoryId;
    data['category_extension'] = categoryExtension;
    data['category_name'] = categoryName;
    data['services'] = services;
    return data;
  }

  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
