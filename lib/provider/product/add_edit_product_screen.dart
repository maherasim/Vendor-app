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

  int? categoryId = -1;
  int? subCategoryId = -1;
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
    imagePickerKey = UniqueKey();
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
      if (productDetail?.productUnitId != null)
        req['product_unit_id'] = productDetail!.productUnitId.validate();

      await addEditProductMultiPart(
        productId: widget.product?.id.validate() ?? 0,
        data: req,
        serviceZones: serviceZoneList,
        shopIds: selectedShopIds,
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
    nameFocus.dispose();
    priceFocus.dispose();
    discountFocus.dispose();
    stockFocus.dispose();
    maxPurchaseQtyFocus.dispose();
    descriptionFocus.dispose();
    super.dispose();
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
