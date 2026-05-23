import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:handyman_provider_flutter/components/app_widgets.dart';
import 'package:handyman_provider_flutter/components/back_widget.dart';
import 'package:handyman_provider_flutter/components/cached_image_widget.dart';
import 'package:handyman_provider_flutter/components/empty_error_state_widget.dart';
import 'package:handyman_provider_flutter/main.dart';
import 'package:handyman_provider_flutter/models/product_model.dart';
import 'package:handyman_provider_flutter/networks/rest_apis.dart';
import 'package:handyman_provider_flutter/provider/product/add_edit_product_screen.dart';
import 'package:handyman_provider_flutter/utils/colors.dart';
import 'package:handyman_provider_flutter/utils/configs.dart';
import 'package:handyman_provider_flutter/utils/constant.dart';
import 'package:nb_utils/nb_utils.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController searchCont = TextEditingController();

  List<ProductData> products = [];
  Future<List<ProductData>>? future;

  int page = 1;
  bool isLastPage = false;
  String selectedRequestStatus = '';

  final List<String> requestStatuses = ['', 'pending', 'approve', 'reject'];

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() {
    getProducts();
  }

  Future<void> getProducts({bool showLoader = true}) async {
    appStore.setLoading(showLoader);
    future = getUserProductList(
      page: page,
      perPage: 10,
      products: products,
      search: searchCont.text.validate(),
      serviceRequestStatus: selectedRequestStatus,
      lastPageCallback: (value) {
        isLastPage = value;
      },
    ).then((value) {
      products.sort(
        (a, b) => b.isFeatured.validate().compareTo(a.isFeatured.validate()),
      );
      return value;
    }).whenComplete(() => appStore.setLoading(false));
    setState(() {});
  }

  Future<void> setPageToOne() async {
    page = 1;
    await getProducts();
  }

  Future<void> deleteProductDialog(ProductData product) async {
    showConfirmDialogCustom(
      context,
      dialogType: DialogType.DELETE,
      title: 'Delete product?',
      positiveText: languages.lblDelete,
      negativeText: languages.lblCancel,
      onAccept: (_) async {
        appStore.setLoading(true);
        await deleteProduct(product.id.validate()).then((value) {
          toast(value.message.validate());
          setPageToOne();
        }).catchError((e) {
          toast(e.toString(), print: true);
        });
        appStore.setLoading(false);
      },
    );
  }

  @override
  void dispose() {
    searchCont.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget(
        'Products',
        textColor: white,
        color: context.primaryColor,
        backWidget: BackWidget(),
        textSize: APP_BAR_TEXT_SIZE,
        actions: [
          IconButton(
            onPressed: () async {
              final res = await const AddEditProductScreen()
                  .launch(context, pageRouteAnimation: PageRouteAnimation.Fade);
              if (res == true) setPageToOne();
            },
            icon: const Icon(Icons.add, size: 28, color: white),
            tooltip: 'Create product',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              AppTextField(
                textFieldType: TextFieldType.OTHER,
                controller: searchCont,
                onFieldSubmitted: (_) => setPageToOne(),
                decoration: InputDecoration(
                  hintText: languages.lblSearchHere,
                  prefixIcon:
                      Icon(Icons.search, color: context.iconColor, size: 20),
                  suffixIcon: searchCont.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: context.iconColor, size: 20),
                          onPressed: () {
                            searchCont.clear();
                            setPageToOne();
                          },
                        )
                      : null,
                  hintStyle: secondaryTextStyle(),
                  border: OutlineInputBorder(
                      borderRadius: radius(8),
                      borderSide:
                          const BorderSide(width: 0, style: BorderStyle.none)),
                  filled: true,
                  contentPadding: const EdgeInsets.all(16),
                  fillColor: appStore.isDarkMode ? cardDarkColor : cardColor,
                ),
              ).paddingOnly(left: 16, right: 16, top: 16, bottom: 8),
              HorizontalList(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                spacing: 12,
                itemCount: requestStatuses.length,
                itemBuilder: (context, index) {
                  final status = requestStatuses[index];
                  final selected = selectedRequestStatus == status;
                  return FilterChip(
                    shape: RoundedRectangleBorder(
                      borderRadius: radius(8),
                      side: BorderSide(
                          color: selected ? primaryColor : Colors.transparent),
                    ),
                    label: Text(
                        status.isEmpty ? 'All' : status.capitalizeFirstLetter(),
                        style: boldTextStyle(
                            size: 12, color: selected ? primaryColor : null)),
                    selected: false,
                    backgroundColor:
                        selected ? lightPrimaryColor : context.cardColor,
                    onSelected: (_) {
                      selectedRequestStatus = status;
                      setPageToOne();
                    },
                  );
                },
              ).paddingOnly(bottom: 8),
              SnapHelperWidget<List<ProductData>>(
                future: future,
                errorBuilder: (error) {
                  return NoDataWidget(
                    title: error,
                    imageWidget: const ErrorStateWidget(),
                    retryText: languages.reload,
                    onRetry: setPageToOne,
                  );
                },
                loadingWidget: LoaderWidget().center(),
                onSuccess: (list) {
                  if (list.isEmpty) {
                    return NoDataWidget(
                      title: 'No products found',
                      imageWidget: const EmptyStateWidget(),
                      onRetry: setPageToOne,
                    ).center();
                  }

                  return AnimatedListView(
                    listAnimationType: ListAnimationType.FadeIn,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    onSwipeRefresh: () async {
                      await setPageToOne();
                      return 1.seconds.delay;
                    },
                    onNextPage: () {
                      if (!isLastPage) {
                        page++;
                        getProducts();
                      }
                    },
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductItemWidget(
                        product: product,
                        onEdit: () async {
                          final res = await AddEditProductScreen(
                                  product: product)
                              .launch(context,
                                  pageRouteAnimation: PageRouteAnimation.Fade);
                          if (res == true) setPageToOne();
                        },
                        onDelete: () => deleteProductDialog(product),
                      );
                    },
                  );
                },
              ).expand(),
            ],
          ),
          Observer(builder: (_) => LoaderWidget().visible(appStore.isLoading)),
        ],
      ),
    );
  }
}

class ProductItemWidget extends StatelessWidget {
  final ProductData product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductItemWidget({
    Key? key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isFeatured = product.isFeatured.validate() == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: boxDecorationWithRoundedCorners(
          backgroundColor: context.cardColor, borderRadius: radius(8)),
      child: Stack(
        children: [
          Column(
            children: [
              if (isFeatured) 16.height,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CachedImageWidget(
                    url: product.productImage.validate(),
                    height: 74,
                    width: 74,
                    fit: BoxFit.cover,
                    radius: 8,
                  ),
                  12.width,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name.validate(),
                          style: boldTextStyle(size: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      6.height,
                      Text(
                          product.priceFormat.validate(
                              value: product.price.validate().toString()),
                          style: boldTextStyle(color: primaryColor, size: 13)),
                      6.height,
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                              product.status == 1
                                  ? languages.active
                                  : languages.inactive,
                              style: secondaryTextStyle(size: 12)),
                          if (product.serviceRequestStatus
                              .validate()
                              .isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: boxDecorationWithRoundedCorners(
                                  backgroundColor:
                                      primaryColor.withValues(alpha: 0.1),
                                  borderRadius: radius(6)),
                              child: Text(
                                  product.serviceRequestStatus
                                      .validate()
                                      .capitalizeFirstLetter(),
                                  style: boldTextStyle(
                                      size: 10, color: primaryColor)),
                            ),
                        ],
                      ),
                      if (product.totalStock != null) ...[
                        6.height,
                        Text('Stock: ${product.totalStock.validate()}',
                            style: secondaryTextStyle(size: 12)),
                      ],
                    ],
                  ).expand(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: context.iconColor),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: Text(languages.lblEdit,
                              style: primaryTextStyle())),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text(languages.lblDelete,
                              style: primaryTextStyle(color: redColor))),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (isFeatured) featuredBanner(),
        ],
      ),
    );
  }

  Widget featuredBanner() {
    return Positioned(
      top: 0,
      left: 0,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFFF9F0A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: Text(
          'FEATURED',
          style: boldTextStyle(color: white, size: 10),
        ),
      ),
    );
  }
}
