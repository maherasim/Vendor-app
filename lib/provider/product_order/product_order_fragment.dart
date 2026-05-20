import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:handyman_provider_flutter/components/app_widgets.dart';
import 'package:handyman_provider_flutter/components/empty_error_state_widget.dart';
import 'package:handyman_provider_flutter/main.dart';
import 'package:handyman_provider_flutter/models/product_order_model.dart';
import 'package:handyman_provider_flutter/networks/rest_apis.dart';
import 'package:handyman_provider_flutter/provider/product_order/product_order_item_component.dart';
import 'package:handyman_provider_flutter/utils/colors.dart';
import 'package:handyman_provider_flutter/utils/common.dart';
import 'package:handyman_provider_flutter/utils/configs.dart';
import 'package:handyman_provider_flutter/utils/constant.dart';
import 'package:nb_utils/nb_utils.dart';

class ProductOrderFragment extends StatefulWidget {
  const ProductOrderFragment({Key? key}) : super(key: key);

  @override
  State<ProductOrderFragment> createState() => _ProductOrderFragmentState();
}

class _ProductOrderFragmentState extends State<ProductOrderFragment> {
  final ScrollController scrollController = ScrollController();
  final TextEditingController searchCont = TextEditingController();

  Future<List<ProductOrderData>>? future;
  List<ProductOrderData> orders = [];

  int page = 1;
  bool isLastPage = false;
  String selectedStatus = ProductOrderStatusKeys.all;
  String totalEarning = '';
  ProductOrderPaymentBreakdown paymentBreakdown =
      ProductOrderPaymentBreakdown();

  final List<String> statuses = [
    ProductOrderStatusKeys.all,
    ProductOrderStatusKeys.pending,
    ProductOrderStatusKeys.accepted,
    ProductOrderStatusKeys.assigned,
    ProductOrderStatusKeys.onGoing,
    ProductOrderStatusKeys.delivered,
    ProductOrderStatusKeys.completed,
  ];

  @override
  void initState() {
    super.initState();
    init();
    LiveStream().on(LIVESTREAM_UPDATE_PRODUCT_ORDERS, (_) {
      page = 1;
      appStore.setLoading(true);
      init();
      setState(() {});
    });
  }

  void init() {
    future = getProviderProductOrderList(
      page: page,
      perPage: 10,
      orders: orders,
      deliveryStatus: selectedStatus,
      search: searchCont.text.validate(),
      handymanId: isUserTypeHandyman ? appStore.userId.toString() : '',
      lastPageCallback: (value) {
        isLastPage = value;
      },
      paymentBreakdownCallBack: (total, breakdown) {
        totalEarning = total;
        paymentBreakdown = breakdown;
      },
    );
  }

  Future<void> setPageToOne() async {
    page = 1;
    appStore.setLoading(true);
    init();
    setState(() {});
  }

  @override
  void dispose() {
    scrollController.dispose();
    searchCont.dispose();
    LiveStream().dispose(LIVESTREAM_UPDATE_PRODUCT_ORDERS);
    super.dispose();
  }

  String statusLabel(String value) => value == ProductOrderStatusKeys.all
      ? 'All'
      : value.replaceAll('_', ' ').capitalizeFirstLetter();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  final status = statuses[index];
                  final selected = selectedStatus == status;
                  return FilterChip(
                    shape: RoundedRectangleBorder(
                      borderRadius: radius(8),
                      side: BorderSide(
                          color: selected ? primaryColor : Colors.transparent),
                    ),
                    label: Text(statusLabel(status),
                        style: boldTextStyle(
                            size: 12, color: selected ? primaryColor : null)),
                    selected: false,
                    backgroundColor:
                        selected ? lightPrimaryColor : context.cardColor,
                    onSelected: (_) {
                      selectedStatus = status;
                      setPageToOne();
                    },
                  );
                },
              ).paddingOnly(bottom: 8),
              SnapHelperWidget<List<ProductOrderData>>(
                future: future,
                loadingWidget: LoaderWidget().center(),
                errorBuilder: (error) {
                  return NoDataWidget(
                    title: error,
                    retryText: languages.reload,
                    imageWidget: const ErrorStateWidget(),
                    onRetry: setPageToOne,
                  );
                },
                onSuccess: (list) {
                  return AnimatedScrollView(
                    controller: scrollController,
                    listAnimationType: ListAnimationType.FadeIn,
                    physics: const AlwaysScrollableScrollPhysics(),
                    onSwipeRefresh: () async {
                      await setPageToOne();
                      return 1.seconds.delay;
                    },
                    onNextPage: () {
                      if (!isLastPage) {
                        page++;
                        appStore.setLoading(true);
                        init();
                        setState(() {});
                      }
                    },
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: boxDecorationWithRoundedCorners(
                          borderRadius: radius(),
                          backgroundColor: appStore.isDarkMode
                              ? context.cardColor
                              : cardLightColor,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Product order sales', style: boldTextStyle()),
                            8.height,
                            Text(totalEarning.validate(value: '0'),
                                style: boldTextStyle(
                                    color: primaryColor, size: 18)),
                          ],
                        ),
                      ),
                      AnimatedListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: list.length,
                        shrinkWrap: true,
                        disposeScrollController: true,
                        physics: const NeverScrollableScrollPhysics(),
                        emptyWidget: SizedBox(
                          width: context.width(),
                          height: context.height() * 0.5,
                          child: NoDataWidget(
                            title: 'No product orders found',
                            imageWidget: const EmptyStateWidget(),
                          ),
                        ),
                        itemBuilder: (_, index) =>
                            ProductOrderItemComponent(order: list[index]),
                      ),
                    ],
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
