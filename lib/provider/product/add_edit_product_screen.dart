import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:handyman_provider_flutter/components/app_widgets.dart';
import 'package:handyman_provider_flutter/components/back_widget.dart';
import 'package:handyman_provider_flutter/components/custom_image_picker.dart';
import 'package:handyman_provider_flutter/main.dart';
import 'package:handyman_provider_flutter/models/product_model.dart';
import 'package:handyman_provider_flutter/models/shop_model.dart';
import 'package:handyman_provider_flutter/networks/rest_apis.dart';
import 'package:handyman_provider_flutter/provider/services/components/category_sub_cat_drop_down.dart';
import 'package:handyman_provider_flutter/provider/services/components/service_address_component.dart';
import 'package:handyman_provider_flutter/provider/shop/shop_list_screen.dart';
import 'package:handyman_provider_flutter/utils/common.dart';
import 'package:handyman_provider_flutter/utils/configs.dart';
import 'package:handyman_provider_flutter/utils/constant.dart';
import 'package:nb_utils/nb_utils.dart';

class AddEditProductScreen extends StatefulWidget {
  final ProductData? product;

  const AddEditProductScreen({Key? key, this.product}) : super(key: key);

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameCont = TextEditingController();
  final TextEditingController priceCont = TextEditingController();
  final TextEditingController discountCont = TextEditingController();
  final TextEditingController stockCont = TextEditingController();
  final TextEditingController maxPurchaseQtyCont = TextEditingController();
  final TextEditingController descriptionCont = TextEditingController();

  final FocusNode nameFocus = FocusNode();
  final FocusNode priceFocus = FocusNode();
  final FocusNode discountFocus = FocusNode();
  final FocusNode stockFocus = FocusNode();
  final FocusNode maxPurchaseQtyFocus = FocusNode();
  final FocusNode descriptionFocus = FocusNode();

  ProductData? productDetail;
  List<File> imageFiles = [];
  List<int> serviceZoneList = [];
  List<ShopModel> selectedShops = [];
  List<int> selectedShopIds = [];
  List<ProductAttributeData> productAttributes = [];
  List<ProductUnitData> productUnits = [];
  List<ProductVariantInputData> variantRows = [];

  int? categoryId = -1;
  int? subCategoryId = -1;
  int? productUnitId = -1;
  int? productAttributeId;
  ProductAttributeData? selectedAttribute;
  ProductUnitData? selectedUnit;
  bool isActive = true;
  bool isFeatured = false;
  bool get isUpdate => widget.product?.id.validate() != 0;

  Key imagePickerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await loadProductFormConfig();
    if (widget.product != null) {
      productDetail = widget.product;
      fillProduct(widget.product!);
      await loadProductDetail();
    }
  }

  void fillProduct(ProductData data) {
    nameCont.text = data.name.validate();
    priceCont.text = data.price.validate().toString();
    discountCont.text = data.discount.validate().toString();
    stockCont.text = data.totalStock.validate().toString();
    maxPurchaseQtyCont.text = data.maxPurchaseQty.validate() > 0
        ? data.maxPurchaseQty.validate().toString()
        : '';
    descriptionCont.text = data.description.validate();
    categoryId = data.categoryId.validate(value: -1);
    subCategoryId = data.subcategoryId.validate(value: -1);
    isActive = data.status.validate(value: 1) == 1;
    isFeatured = data.isFeatured.validate() == 1;
    imageFiles = data.imageUrls.map((e) => File(e)).toList();
    serviceZoneList = data.serviceZoneIds.validate();
    productUnitId = data.productUnitId.validate(value: -1);
    fillVariantRows(data);
    syncSelectedFormConfig(data);
    imagePickerKey = UniqueKey();
    setState(() {});
  }

  Future<void> loadProductFormConfig() async {
    appStore.setLoading(true);
    await getProductFormConfig().then((value) {
      productAttributes = value.data?.attributes.validate() ?? [];
      productUnits = value.data?.units.validate() ?? [];
      syncSelectedFormConfig(productDetail);
    }).catchError((e) {
      toast(e.toString(), print: true);
    });
    appStore.setLoading(false);
  }

  void syncSelectedFormConfig(ProductData? data) {
    selectedUnit = findProductUnit(
      (element) => element.id == productUnitId,
    );

    if (productAttributeId == null && data != null) {
      final attributeName = data.variantAttributeName.validate().isNotEmpty
          ? data.variantAttributeName.validate()
          : data.variants.validate().isNotEmpty
              ? data.variants!.first.attributeName.validate()
              : '';

      if (attributeName.isNotEmpty) {
        selectedAttribute = findProductAttribute(
          (element) =>
              element.name.validate().toLowerCase() ==
              attributeName.toLowerCase(),
        );
        productAttributeId = selectedAttribute?.id;
      }
    } else if (productAttributeId != null) {
      selectedAttribute = findProductAttribute(
        (element) => element.id == productAttributeId,
      );
    }
  }

  ProductUnitData? findProductUnit(bool Function(ProductUnitData) test) {
    for (final unit in productUnits) {
      if (test(unit)) return unit;
    }
    return null;
  }

  ProductAttributeData? findProductAttribute(
      bool Function(ProductAttributeData) test) {
    for (final attribute in productAttributes) {
      if (test(attribute)) return attribute;
    }
    return null;
  }

  void fillVariantRows(ProductData data) {
    clearVariantRows();
    data.variants.validate().forEach((variant) {
      final label = variant.optionValue.validate().isNotEmpty
          ? variant.optionValue.validate()
          : variant.label.validate().split(':').last.trim();
      variantRows.add(ProductVariantInputData(
        label: label,
        price: variant.price?.toString() ?? '',
        stock: variant.stock?.toString() ?? '',
      ));
    });
  }

  void clearVariantRows() {
    for (final row in variantRows) {
      row.dispose();
    }
    variantRows.clear();
  }

  void addVariantRow() {
    variantRows.add(ProductVariantInputData());
    setState(() {});
  }

  void removeVariantRow(ProductVariantInputData row) {
    row.dispose();
    variantRows.remove(row);
    if (variantRows.isEmpty) {
      selectedAttribute = null;
      productAttributeId = null;
    }
    setState(() {});
  }

  Future<void> loadProductDetail() async {
    appStore.setLoading(true);
    await getProductDetail({'product_id': widget.product!.id.validate()})
        .then((value) {
      productDetail = value.data;
      if (value.data != null) fillProduct(value.data!);
    }).catchError((e) {
      toast(e.toString(), print: true);
    });
    appStore.setLoading(false);
  }

  Future<void> saveProduct() async {
    if (!isUpdate && imageFiles.isEmpty) {
      toast(languages.pleaseSelectImages);
      return;
    }

    if (serviceZoneList.isEmpty) {
      toast(languages.plzSelectOneZone);
      return;
    }

    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      hideKeyboard(context);

      final req = <String, dynamic>{
        'name': nameCont.text.validate(),
        'provider_id': appStore.userId.validate(),
        'category_id': categoryId,
        'service_type': 'ecommerce',
        'type': 'fixed',
        'price': priceCont.text.validate(),
        'discount': discountCont.text.validate().isEmpty
            ? '0'
            : discountCont.text.validate(),
        'description': descriptionCont.text.validate(),
        'total_stock': stockCont.text.validate(),
        'status': isActive ? '1' : '0',
        'is_featured': isFeatured ? '1' : '0',
      };

      if (subCategoryId.validate(value: -1) != -1)
        req['subcategory_id'] = subCategoryId;
      if (maxPurchaseQtyCont.text.validate().isNotEmpty)
        req['max_purchase_qty'] = maxPurchaseQtyCont.text.validate();
      if (productUnitId.validate(value: -1) != -1)
        req['product_unit_id'] = productUnitId.validate();

      final variants =
          variantRows.where((element) => element.hasAnyValue).toList();

      if (variants.isNotEmpty) {
        if (productAttributeId.validate(value: -1) == -1) {
          toast('Please select product attribute');
          return;
        }

        for (final variant in variants) {
          if (!variant.isComplete) {
            toast('Please complete all variant labels, prices, and stock');
            return;
          }
        }

        req['product_attribute_id'] = productAttributeId.validate();
      }

      await addEditProductMultiPart(
        productId: widget.product?.id.validate() ?? 0,
        data: req,
        serviceZones: serviceZoneList,
        shopIds: selectedShopIds,
        variantLabels:
            variants.map((e) => e.labelCont.text.validate()).toList(),
        variantPrices:
            variants.map((e) => e.priceCont.text.validate()).toList(),
        variantStocks:
            variants.map((e) => e.stockCont.text.validate()).toList(),
        images: imageFiles
            .where((element) => !element.path.contains('http'))
            .toList(),
      );
    }
  }

  @override
  void dispose() {
    nameCont.dispose();
    priceCont.dispose();
    discountCont.dispose();
    stockCont.dispose();
    maxPurchaseQtyCont.dispose();
    descriptionCont.dispose();
    clearVariantRows();
    nameFocus.dispose();
    priceFocus.dispose();
    discountFocus.dispose();
    stockFocus.dispose();
    maxPurchaseQtyFocus.dispose();
    descriptionFocus.dispose();
    super.dispose();
  }

  Widget productUnitDropdown() {
    if (productUnits.isEmpty) return Offstage();

    return DropdownButtonFormField<ProductUnitData>(
      decoration: inputDecoration(context,
          fillColor: context.scaffoldBackgroundColor, hint: 'Product unit'),
      initialValue: selectedUnit,
      dropdownColor: context.scaffoldBackgroundColor,
      items: productUnits.map((data) {
        return DropdownMenuItem<ProductUnitData>(
          value: data,
          child: Text(data.name.validate(), style: primaryTextStyle()),
        );
      }).toList(),
      onChanged: (ProductUnitData? value) {
        selectedUnit = value;
        productUnitId = value?.id.validate(value: -1);
        setState(() {});
      },
    );
  }

  Widget variantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Variants', style: boldTextStyle(size: 14)).expand(),
            TextButton.icon(
              onPressed: addVariantRow,
              icon: Icon(Icons.add, size: 18, color: primaryColor),
              label: Text('Add', style: boldTextStyle(color: primaryColor)),
            ),
          ],
        ),
        if (variantRows.isNotEmpty) ...[
          8.height,
          DropdownButtonFormField<ProductAttributeData>(
            decoration: inputDecoration(context,
                fillColor: context.scaffoldBackgroundColor,
                hint: 'Product attribute'),
            initialValue: selectedAttribute,
            dropdownColor: context.scaffoldBackgroundColor,
            items: productAttributes.map((data) {
              return DropdownMenuItem<ProductAttributeData>(
                value: data,
                child: Text(data.name.validate(), style: primaryTextStyle()),
              );
            }).toList(),
            validator: (_) {
              if (variantRows.any((element) => element.hasAnyValue) &&
                  productAttributeId.validate(value: -1) == -1) {
                return errorThisFieldRequired;
              }
              return null;
            },
            onChanged: (ProductAttributeData? value) {
              selectedAttribute = value;
              productAttributeId = value?.id;
              setState(() {});
            },
          ),
          12.height,
          ...variantRows.map((row) => variantRowWidget(row)).toList(),
        ],
      ],
    );
  }

  Widget variantRowWidget(ProductVariantInputData row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: context.scaffoldBackgroundColor,
        borderRadius: radius(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppTextField(
                textFieldType: TextFieldType.NAME,
                controller: row.labelCont,
                decoration: inputDecoration(context,
                    hint: 'Variant label',
                    fillColor: appStore.isDarkMode ? context.cardColor : white),
                validator: (value) {
                  if (row.hasAnyValue && value.validate().isEmpty) {
                    return errorThisFieldRequired;
                  }
                  return null;
                },
              ).expand(),
              IconButton(
                onPressed: () => removeVariantRow(row),
                icon: Icon(Icons.delete_outline, color: redColor),
                tooltip: languages.lblDelete,
              ),
            ],
          ),
          12.height,
          Row(
            children: [
              AppTextField(
                textFieldType: TextFieldType.PHONE,
                controller: row.priceCont,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: inputDecoration(context,
                    hint: 'Variant price',
                    fillColor: appStore.isDarkMode ? context.cardColor : white),
                validator: (value) {
                  if (row.hasAnyValue && value.validate().isEmpty) {
                    return errorThisFieldRequired;
                  }
                  return null;
                },
              ).expand(),
              12.width,
              AppTextField(
                textFieldType: TextFieldType.PHONE,
                controller: row.stockCont,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: inputDecoration(context,
                    hint: 'Variant stock',
                    fillColor: appStore.isDarkMode ? context.cardColor : white),
                validator: (value) {
                  if (row.hasAnyValue && value.validate().isEmpty) {
                    return errorThisFieldRequired;
                  }
                  return null;
                },
              ).expand(),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget(
        isUpdate ? 'Edit Product' : 'Create Product',
        textColor: white,
        color: context.primaryColor,
        backWidget: BackWidget(),
        textSize: APP_BAR_TEXT_SIZE,
      ),
      body: Stack(
        children: [
          AnimatedScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              CustomImagePicker(
                key: imagePickerKey,
                selectedImages: imageFiles.map((e) => e.path).toList(),
                height: 140,
                width: double.infinity,
                isMultipleImages: true,
                onFileSelected: (files) {
                  imageFiles = files;
                  setState(() {});
                },
                onRemoveClick: (value) {
                  showConfirmDialogCustom(
                    context,
                    dialogType: DialogType.DELETE,
                    positiveText: languages.lblDelete,
                    negativeText: languages.lblCancel,
                    onAccept: (_) {
                      imageFiles
                          .removeWhere((element) => element.path == value);
                      imagePickerKey = UniqueKey();
                      setState(() {});
                    },
                  );
                },
              ),
              16.height,
              Container(
                padding: const EdgeInsets.all(16),
                decoration: boxDecorationWithRoundedCorners(
                    backgroundColor: context.cardColor,
                    borderRadius: radius(8)),
                child: Form(
                  key: formKey,
                  child: Wrap(
                    runSpacing: 16,
                    children: [
                      AppTextField(
                        textFieldType: TextFieldType.NAME,
                        controller: nameCont,
                        focus: nameFocus,
                        nextFocus: priceFocus,
                        errorThisFieldRequired: languages.hintRequired,
                        decoration: inputDecoration(context,
                            hint: 'Product name',
                            fillColor: context.scaffoldBackgroundColor),
                      ),
                      CategorySubCatDropDown(
                        categoryId: categoryId == -1 ? null : categoryId,
                        subCategoryId:
                            subCategoryId == -1 ? null : subCategoryId,
                        languageCode: appStore.selectedLanguage.languageCode,
                        serviceType: 'ecommerce',
                        isCategoryValidate: true,
                        fillColor: context.scaffoldBackgroundColor,
                        onCategorySelect: (val) {
                          categoryId = val;
                          setState(() {});
                        },
                        onSubCategorySelect: (val) {
                          subCategoryId = val ?? -1;
                          setState(() {});
                        },
                      ),
                      ServiceAddressComponent(
                        selectedList: serviceZoneList,
                        onSelectedList: (val) {
                          serviceZoneList = val;
                          setState(() {});
                        },
                      ),
                      productUnitDropdown(),
                      Row(
                        children: [
                          AppTextField(
                            textFieldType: TextFieldType.PHONE,
                            controller: priceCont,
                            focus: priceFocus,
                            nextFocus: discountFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            errorThisFieldRequired: languages.hintRequired,
                            decoration: inputDecoration(context,
                                hint: languages.hintPrice,
                                fillColor: context.scaffoldBackgroundColor),
                          ).expand(),
                          16.width,
                          AppTextField(
                            textFieldType: TextFieldType.PHONE,
                            controller: discountCont,
                            focus: discountFocus,
                            nextFocus: stockFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: inputDecoration(context,
                                hint: '${languages.hintDiscount} (%)',
                                fillColor: context.scaffoldBackgroundColor),
                          ).expand(),
                        ],
                      ),
                      Row(
                        children: [
                          AppTextField(
                            textFieldType: TextFieldType.PHONE,
                            controller: stockCont,
                            focus: stockFocus,
                            nextFocus: maxPurchaseQtyFocus,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            errorThisFieldRequired: languages.hintRequired,
                            decoration: inputDecoration(context,
                                hint: 'Total stock',
                                fillColor: context.scaffoldBackgroundColor),
                          ).expand(),
                          16.width,
                          AppTextField(
                            textFieldType: TextFieldType.PHONE,
                            controller: maxPurchaseQtyCont,
                            focus: maxPurchaseQtyFocus,
                            nextFocus: descriptionFocus,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: inputDecoration(context,
                                hint: 'Max purchase qty',
                                fillColor: context.scaffoldBackgroundColor),
                          ).expand(),
                        ],
                      ),
                      variantSection(),
                      AppTextField(
                        textFieldType: TextFieldType.MULTILINE,
                        minLines: 4,
                        controller: descriptionCont,
                        focus: descriptionFocus,
                        decoration: inputDecoration(context,
                            hint: languages.hintDescription,
                            fillColor: context.scaffoldBackgroundColor),
                      ),
                      SettingItemWidget(
                        decoration: boxDecorationWithRoundedCorners(
                            backgroundColor: context.scaffoldBackgroundColor,
                            borderRadius: radius(8)),
                        title: selectedShops.isEmpty
                            ? 'Shops'
                            : '${selectedShops.length} shops selected',
                        titleTextStyle: primaryTextStyle(size: 14),
                        trailing: Icon(Icons.chevron_right,
                            color: context.iconColor, size: 18),
                        onTap: () async {
                          final result = await ShopListScreen(
                                  fromServiceDetail: true,
                                  selectedShops: selectedShops)
                              .launch(context);
                          if (result is List<ShopModel>) {
                            selectedShops = result;
                            selectedShopIds =
                                result.map((e) => e.id.validate()).toList();
                            setState(() {});
                          }
                        },
                      ),
                      SwitchListTile(
                        value: isActive,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: primaryColor,
                        title: Text(languages.lblStatus,
                            style: primaryTextStyle()),
                        subtitle: Text(
                            isActive ? languages.active : languages.inactive,
                            style: secondaryTextStyle(size: 12)),
                        onChanged: (value) {
                          isActive = value;
                          setState(() {});
                        },
                      ),
                      SwitchListTile(
                        value: isFeatured,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: primaryColor,
                        title: Text('Featured', style: primaryTextStyle()),
                        onChanged: (value) {
                          isFeatured = value;
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Observer(
              builder: (_) => AppButton(
                text: languages.btnSave,
                color: appStore.isLoading
                    ? primaryColor.withValues(alpha: 0.5)
                    : primaryColor,
                textStyle: boldTextStyle(color: white),
                onTap: appStore.isLoading ? () {} : saveProduct,
              ),
            ),
          ),
          Observer(
              builder: (_) =>
                  LoaderWidget().center().visible(appStore.isLoading)),
        ],
      ),
    );
  }
}

class ProductVariantInputData {
  final TextEditingController labelCont;
  final TextEditingController priceCont;
  final TextEditingController stockCont;

  ProductVariantInputData(
      {String label = '', String price = '', String stock = ''})
      : labelCont = TextEditingController(text: label),
        priceCont = TextEditingController(text: price),
        stockCont = TextEditingController(text: stock);

  bool get hasAnyValue =>
      labelCont.text.validate().isNotEmpty ||
      priceCont.text.validate().isNotEmpty ||
      stockCont.text.validate().isNotEmpty;

  bool get isComplete =>
      labelCont.text.validate().isNotEmpty &&
      priceCont.text.validate().isNotEmpty &&
      stockCont.text.validate().isNotEmpty;

  void dispose() {
    labelCont.dispose();
    priceCont.dispose();
    stockCont.dispose();
  }
}
