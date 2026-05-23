import 'package:flutter/material.dart';
import 'package:handyman_provider_flutter/components/cached_image_widget.dart';
import 'package:handyman_provider_flutter/main.dart';
import 'package:handyman_provider_flutter/models/product_order_model.dart';
import 'package:handyman_provider_flutter/networks/rest_apis.dart';
import 'package:handyman_provider_flutter/provider/product_order/assign_delivery_boy_screen.dart';
import 'package:handyman_provider_flutter/provider/product_order/product_order_detail_screen.dart';
import 'package:handyman_provider_flutter/utils/colors.dart';
import 'package:handyman_provider_flutter/utils/common.dart';
import 'package:handyman_provider_flutter/utils/configs.dart';
import 'package:handyman_provider_flutter/utils/constant.dart';
import 'package:handyman_provider_flutter/utils/model_keys.dart';
import 'package:nb_utils/nb_utils.dart';

class ProductOrderItemComponent extends StatefulWidget {
  final ProductOrderData order;

  const ProductOrderItemComponent({Key? key, required this.order})
      : super(key: key);

  @override
  State<ProductOrderItemComponent> createState() =>
      _ProductOrderItemComponentState();
}

class _ProductOrderItemComponentState extends State<ProductOrderItemComponent> {
  Future<void> updateStatus(String status) async {
    appStore.setLoading(true);
    await productOrderUpdate({
      CommonKeys.id: widget.order.id.validate(),
      'delivery_status': status,
      'payment_status': widget.order.paymentStatus.validate(),
    }).then((value) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(value.message.validate());
    }).catchError((e) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(e.toString());
    });
  }

  Future<void> assignToMyself() async {
    appStore.setLoading(true);
    await assignProductOrder({
      CommonKeys.id: widget.order.id.validate(),
      CommonKeys.handymanId: [appStore.userId.validate()],
    }).then((value) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(value.message.validate());
      LiveStream().emit(LIVESTREAM_UPDATE_PRODUCT_ORDERS);
    }).catchError((e) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(e.toString());
    });
  }

  void updateStatusAfterDialog(String status) {
    Future.microtask(() {
      if (!mounted) return;
      updateStatus(status);
    });
  }

  void assignToMyselfAfterDialog() {
    Future.microtask(() {
      if (!mounted) return;
      assignToMyself();
    });
  }

  Color get statusColor {
    switch (widget.order.effectiveDeliveryStatus) {
      case ProductOrderStatusKeys.pending:
        return pending;
      case ProductOrderStatusKeys.accepted:
      case ProductOrderStatusKeys.accept:
      case ProductOrderStatusKeys.assigned:
        return primaryColor;
      case ProductOrderStatusKeys.onGoing:
        return startDriveButtonColor;
      case ProductOrderStatusKeys.delivered:
      case ProductOrderStatusKeys.completed:
        return Colors.green;
      case ProductOrderStatusKeys.cancelled:
      case ProductOrderStatusKeys.rejected:
        return redColor;
      default:
        return primaryColor;
    }
  }

  String get statusText {
    return widget.order.effectiveDeliveryStatusLabel.isNotEmpty
        ? widget.order.effectiveDeliveryStatusLabel
        : widget.order.effectiveDeliveryStatus
            .replaceAll('_', ' ')
            .capitalizeFirstLetter();
  }

  Widget statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: radius(16),
        border: Border.all(color: statusColor),
      ),
      child:
          Text(statusText, style: boldTextStyle(color: statusColor, size: 12)),
    );
  }

  Widget infoRow(String title, String value) {
    if (value.validate().isEmpty) return const Offstage();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: secondaryTextStyle()).expand(flex: 2),
        8.width,
        Text(value,
                style: boldTextStyle(size: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis)
            .expand(flex: 5),
      ],
    ).paddingOnly(left: 8, right: 8, bottom: 8);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: boxDecorationWithRoundedCorners(
        borderRadius: radius(),
        backgroundColor:
            appStore.isDarkMode ? context.cardColor : cardLightColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedImageWidget(
                url: widget.order.displayImage,
                fit: BoxFit.cover,
                width: 80,
                height: 80,
                radius: defaultRadius,
              ),
              16.width,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withValues(alpha: 0.1),
                          borderRadius: radius(16),
                          border: Border.all(color: context.primaryColor),
                        ),
                        child: Text(widget.order.displayCode,
                            style: boldTextStyle(
                                color: context.primaryColor, size: 12)),
                      ),
                      6.width,
                      statusPill().flexible(),
                    ],
                  ),
                  12.height,
                  Text(
                    widget.order.items.validate().isNotEmpty
                        ? widget.order.items!.first.name.validate()
                        : 'Product order',
                    style: boldTextStyle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  8.height,
                  Text(widget.order.displayTotal,
                      style: boldTextStyle(color: primaryColor, size: 14)),
                  if (widget.order.productCount.validate() > 1) ...[
                    4.height,
                    Text('${widget.order.productCount.validate()} products',
                        style: secondaryTextStyle(size: 12)),
                  ],
                ],
              ).expand(),
            ],
          ).paddingAll(8),
          Container(
            decoration: boxDecorationWithRoundedCorners(
              backgroundColor:
                  appStore.isDarkMode ? context.cardColor : whiteColor,
              border: Border.all(color: context.dividerColor),
              borderRadius: radius(8),
            ),
            margin: const EdgeInsets.all(8),
            child: Column(
              children: [
                infoRow('Customer:', widget.order.displayCustomerName),
                infoRow('Address:', widget.order.displayAddress),
                infoRow('Payment:',
                    '${widget.order.paymentStatus.validate().capitalizeFirstLetter()} ${widget.order.paymentMethod.validate().isNotEmpty ? '(${widget.order.paymentMethod.validate().capitalizeFirstLetter()})' : ''}'),
                if (widget.order.deliveryBoy != null)
                  infoRow('Delivery Boy:',
                      widget.order.deliveryBoy!.displayName.validate()),
              ],
            ).paddingTop(8),
          ),
          if (isUserTypeProvider &&
              widget.order.effectiveDeliveryStatus ==
                  ProductOrderStatusKeys.pending)
            Row(
              children: [
                AppButton(
                  width: context.width(),
                  color: primaryColor,
                  elevation: 0,
                  onTap: () {
                    showConfirmDialogCustom(
                      context,
                      title: 'Accept this product order?',
                      positiveText: languages.lblYes,
                      negativeText: languages.lblNo,
                      primaryColor: context.primaryColor,
                      onAccept: (_) => updateStatusAfterDialog(
                          ProductOrderStatusKeys.accepted),
                    );
                  },
                  child: Text(languages.accept,
                      style: boldTextStyle(color: white)),
                ).expand(),
                12.width,
                AppButton(
                  width: context.width(),
                  elevation: 0,
                  color: appStore.isDarkMode
                      ? context.scaffoldBackgroundColor
                      : white,
                  onTap: () {
                    showConfirmDialogCustom(
                      context,
                      title: 'Reject this product order?',
                      positiveText: languages.lblYes,
                      negativeText: languages.lblNo,
                      primaryColor: redColor,
                      onAccept: (_) => updateStatusAfterDialog(
                          ProductOrderStatusKeys.rejected),
                    );
                  },
                  child: Text(languages.decline, style: boldTextStyle()),
                ).expand(),
              ],
            ).paddingOnly(bottom: 8, left: 8, right: 8, top: 8),
          if (isUserTypeProvider && widget.order.isDeliveryAccepted)
            Row(
              children: [
                AppButton(
                  width: context.width(),
                  color: context.scaffoldBackgroundColor,
                  shapeBorder: RoundedRectangleBorder(
                      borderRadius: radius(),
                      side: BorderSide(color: context.primaryColor)),
                  elevation: 0,
                  textColor: context.primaryColor,
                  text: 'Assign to Myself',
                  onTap: () {
                    showConfirmDialogCustom(
                      context,
                      title: 'Assign this order to yourself?',
                      positiveText: languages.lblYes,
                      negativeText: languages.lblCancel,
                      primaryColor: context.primaryColor,
                      onAccept: (_) => assignToMyselfAfterDialog(),
                    );
                  },
                ).expand(),
                12.width,
                AppButton(
                  width: context.width(),
                  color: primaryColor,
                  elevation: 0,
                  text: widget.order.hasDeliveryBoy ? 'Reassign' : 'Assign',
                  onTap: () {
                    AssignDeliveryBoyScreen(
                      orderId: widget.order.id.validate(),
                      onUpdate: () =>
                          LiveStream().emit(LIVESTREAM_UPDATE_PRODUCT_ORDERS),
                    ).launch(context);
                  },
                ).expand(),
              ],
            ).paddingAll(8),
        ],
      ),
    ).onTap(() {
      ProductOrderDetailScreen(orderId: widget.order.id.validate())
          .launch(context);
    },
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent);
  }
}
