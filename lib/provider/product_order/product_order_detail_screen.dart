import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handyman_provider_flutter/components/app_widgets.dart';
import 'package:handyman_provider_flutter/components/back_widget.dart';
import 'package:handyman_provider_flutter/components/cached_image_widget.dart';
import 'package:handyman_provider_flutter/components/custom_image_picker.dart';
import 'package:handyman_provider_flutter/components/empty_error_state_widget.dart';
import 'package:handyman_provider_flutter/components/handyman_name_widget.dart';
import 'package:handyman_provider_flutter/components/image_border_component.dart';
import 'package:handyman_provider_flutter/main.dart';
import 'package:handyman_provider_flutter/models/product_order_model.dart';
import 'package:handyman_provider_flutter/models/user_data.dart';
import 'package:handyman_provider_flutter/networks/rest_apis.dart';
import 'package:handyman_provider_flutter/provider/product_order/assign_delivery_boy_screen.dart';
import 'package:handyman_provider_flutter/screens/chat/user_chat_screen.dart';
import 'package:handyman_provider_flutter/utils/colors.dart';
import 'package:handyman_provider_flutter/utils/common.dart';
import 'package:handyman_provider_flutter/utils/configs.dart';
import 'package:handyman_provider_flutter/utils/constant.dart';
import 'package:handyman_provider_flutter/utils/dashed_rect.dart';
import 'package:handyman_provider_flutter/utils/getImage.dart';
import 'package:handyman_provider_flutter/utils/images.dart';
import 'package:handyman_provider_flutter/utils/model_keys.dart';
import 'package:handyman_provider_flutter/utils/permissions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductOrderDetailScreen extends StatefulWidget {
  final int orderId;

  const ProductOrderDetailScreen({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<ProductOrderDetailScreen> createState() =>
      _ProductOrderDetailScreenState();
}

class _ProductOrderDetailScreenState extends State<ProductOrderDetailScreen>
    with WidgetsBindingObserver {
  late Future<ProductOrderDetailResponse> future;
  bool showBottomActionBar = false;
  String orderStatus = '';
  int assignedUserId = -1;
  Timer? productOrderLocationTimer;
  bool isUpdatingProductOrderLocation = false;
  int productOrderLocationRefreshPeriodInSeconds = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    init();
  }

  void init() {
    future = getProductOrderDetail({
      CommonKeys.id: widget.orderId,
      'order_id': widget.orderId,
    }).then((value) {
      if (!mounted) return value;
      orderStatus = value.data?.effectiveDeliveryStatus ?? '';
      assignedUserId = productOrderAssignedUserId(value.data);
      startProductOrderLocationUpdates(value.data);
      return value;
    });
  }

  Future<void> updateStatus(ProductOrderData order, String status) async {
    if (status != ProductOrderStatusKeys.onGoing) {
      stopProductOrderLocationUpdates();
    }

    appStore.setLoading(true);
    await productOrderUpdate({
      CommonKeys.id: order.id.validate(),
      'delivery_status': status,
      'payment_status': order.paymentStatus.validate(),
    }).then((value) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(value.message.validate());
      init();
      setState(() {});
    }).catchError((e) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(e.toString());
    });
  }

  Future<void> assignToMyself(ProductOrderData order) async {
    appStore.setLoading(true);
    await assignProductOrder({
      CommonKeys.id: order.id.validate(),
      CommonKeys.handymanId: [appStore.userId.validate()],
    }).then((value) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(value.message.validate());
      init();
      setState(() {});
      LiveStream().emit(LIVESTREAM_UPDATE_PRODUCT_ORDERS);
    }).catchError((e) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(e.toString());
    });
  }

  bool canCollectProductOrderPayment(ProductOrderData order) {
    return order.effectiveDeliveryStatus == ProductOrderStatusKeys.delivered &&
        order.paymentStatus.validate().toLowerCase() == PENDING;
  }

  Future<void> collectProductOrderPayment(
      ProductOrderData order, String remarks) async {
    appStore.setLoading(true);
    await productOrderCashPaymentPaid({
      CommonKeys.id: order.id.validate(),
      'remarks': remarks.validate(value: 'Cash collected'),
    }).then((value) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(value.message.validate());
      init();
      setState(() {});
    }).catchError((e) {
      appStore.setLoading(false);
      if (!mounted) return;
      toast(e.toString());
    });
  }

  void showCollectProductOrderPaymentDialog(ProductOrderData order) {
    showInDialog(
      context,
      contentPadding: EdgeInsets.zero,
      builder: (_) {
        return ProductOrderCashPaymentDialog(
          order: order,
          onAccept: (remarks) {
            finish(context);
            collectProductOrderPayment(order, remarks);
          },
        );
      },
    );
  }

  int productOrderAssignedUserId(ProductOrderData? order) {
    if (order == null) return -1;
    if (order.deliveryBoy?.id.validate() == appStore.userId) {
      return order.deliveryBoy!.id.validate();
    }
    if (order.handymanId.validate() == appStore.userId) {
      return order.handymanId.validate();
    }

    return order.deliveryBoy?.id.validate() ?? order.handymanId.validate();
  }

  bool isProductOrderAssignedToCurrentUser(ProductOrderData order) {
    return order.deliveryBoy?.id.validate() == appStore.userId ||
        order.handymanId.validate() == appStore.userId;
  }

  bool canUpdateProductOrderLocation(ProductOrderData? order) {
    if (order == null) return false;
    if (order.effectiveDeliveryStatus != ProductOrderStatusKeys.onGoing) {
      return false;
    }

    if (isUserTypeHandyman) return true;

    return isUserTypeProvider && isProductOrderAssignedToCurrentUser(order);
  }

  Future<void> startProductOrderLocationUpdates(ProductOrderData? order) async {
    if (!canUpdateProductOrderLocation(order)) {
      stopProductOrderLocationUpdates();
      return;
    }

    if (!await Permissions.locationPermissionsGranted()) {
      stopProductOrderLocationUpdates();
      return;
    }

    await updateCurrentProductOrderLocation(order!);

    if (productOrderLocationTimer == null ||
        !productOrderLocationTimer!.isActive) {
      productOrderLocationTimer = Timer.periodic(
        Duration(seconds: productOrderLocationRefreshPeriodInSeconds),
        (timer) => updateCurrentProductOrderLocation(order),
      );
    }
  }

  Future<void> updateCurrentProductOrderLocation(ProductOrderData order) async {
    if (isUpdatingProductOrderLocation ||
        !canUpdateProductOrderLocation(order)) {
      return;
    }

    isUpdatingProductOrderLocation = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      await updateProductOrderLocation(
        order.id.validate(),
        position.latitude.toString(),
        position.longitude.toString(),
      );
    } catch (e) {
      log(e.toString());
    } finally {
      isUpdatingProductOrderLocation = false;
    }
  }

  void stopProductOrderLocationUpdates() {
    productOrderLocationTimer?.cancel();
    productOrderLocationTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      init();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      stopProductOrderLocationUpdates();
    }
  }

  @override
  void dispose() {
    stopProductOrderLocationUpdates();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Widget header(ProductOrderData order) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: boxDecorationDefault(
          color: context.cardColor, borderRadius: radius()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: boxDecorationDefault(
                color: primaryColor,
                borderRadius: radiusOnly(
                    topLeft: defaultRadius, topRight: defaultRadius)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order ID',
                    style: boldTextStyle(size: LABEL_TEXT_SIZE, color: white)),
                Text(order.displayCode,
                    style: boldTextStyle(color: white, size: 16)),
              ],
            ).paddingSymmetric(horizontal: 16, vertical: 8),
          ),
          16.height,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedImageWidget(
                  url: order.displayImage,
                  height: 70,
                  width: 70,
                  fit: BoxFit.cover,
                  radius: 8),
              16.width,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      order.items.validate().isNotEmpty
                          ? order.items!.first.name.validate()
                          : 'Product order',
                      style: boldTextStyle(size: LABEL_TEXT_SIZE),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  8.height,
                  Text(order.displayTotal,
                      style: boldTextStyle(color: primaryColor)),
                  8.height,
                  Text(
                      order.effectiveDeliveryStatusLabel.validate(
                          value: order.effectiveDeliveryStatus
                              .replaceAll('_', ' ')
                              .capitalizeFirstLetter()),
                      style: boldTextStyle(size: 12, color: primaryColor)),
                ],
              ).expand(),
            ],
          ).paddingSymmetric(horizontal: 16),
          if (order.description.validate().isNotEmpty) ...[
            16.height,
            ReadMoreText(order.description.validate(),
                    trimLength: 80,
                    style: secondaryTextStyle(),
                    colorClickableText: context.primaryColor)
                .paddingSymmetric(horizontal: 16),
          ],
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () {
                showProductOrderStatusBottomSheet(order);
              },
              child: Text(
                languages.viewStatus,
                style: boldTextStyle(color: primaryColor, size: 14),
              ),
            ),
          ),
          16.height,
        ],
      ),
    );
  }

  void showProductOrderStatusBottomSheet(ProductOrderData order) {
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: RoundedRectangleBorder(
        borderRadius: radiusOnly(
          topLeft: defaultRadius,
          topRight: defaultRadius,
        ),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.50,
          minChildSize: 0.2,
          maxChildSize: 1,
          builder: (context, scrollController) {
            return ProductOrderStatusBottomSheet(
              order: order,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  Widget productsWidget(ProductOrderData order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Products', style: boldTextStyle(size: LABEL_TEXT_SIZE))
            .paddingSymmetric(horizontal: 16),
        8.height,
        AnimatedListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: order.items.validate().length,
          itemBuilder: (_, index) {
            final item = order.items![index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: boxDecorationDefault(
                  color: context.cardColor, borderRadius: radius()),
              child: Row(
                children: [
                  CachedImageWidget(
                      url: item.image.validate(),
                      height: 58,
                      width: 58,
                      fit: BoxFit.cover,
                      radius: 8),
                  12.width,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name.validate(),
                          style: boldTextStyle(size: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (item.variantLabel.validate().isNotEmpty)
                        Text(item.variantLabel.validate(),
                            style: secondaryTextStyle(size: 12)),
                      4.height,
                      Text(
                          '${item.priceFormat.validate(value: item.price.validate().toString())} x ${item.quantity.validate()}',
                          style: secondaryTextStyle(size: 12)),
                    ],
                  ).expand(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget infoCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: boldTextStyle(size: LABEL_TEXT_SIZE))
            .paddingSymmetric(horizontal: 16),
        8.height,
        Container(
          width: context.width(),
          padding: const EdgeInsets.all(16),
          decoration: boxDecorationDefault(
              color: context.cardColor, borderRadius: radius()),
          child: Column(children: children),
        ).paddingSymmetric(horizontal: 16),
        16.height,
      ],
    );
  }

  Widget infoRow(String title, String value) {
    if (value.validate().isEmpty) return const Offstage();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: secondaryTextStyle()).expand(),
        12.width,
        Text(value, style: boldTextStyle(size: 13), textAlign: TextAlign.right)
            .expand(),
      ],
    ).paddingOnly(bottom: 12);
  }

  Widget priceDetailWidget(ProductOrderData order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Price Detail', style: boldTextStyle(size: LABEL_TEXT_SIZE))
            .paddingSymmetric(horizontal: 16),
        8.height,
        Container(
          width: context.width(),
          padding: const EdgeInsets.all(16),
          decoration: boxDecorationDefault(
              color: context.cardColor, borderRadius: radius()),
          child: Column(
            children: [
              priceDetailRow('Subtotal', order.subtotalFormat.validate()),
              priceDetailRow('Tax', order.taxTotalFormat.validate()),
              Divider(height: 28, thickness: 1, color: context.dividerColor),
              priceDetailRow(
                'Total',
                order.totalFormat.validate(),
                titleStyle: boldTextStyle(size: 16),
                valueStyle: boldTextStyle(size: 18, color: primaryColor),
                bottomPadding: 0,
              ),
            ],
          ),
        ).paddingSymmetric(horizontal: 16),
        16.height,
      ],
    );
  }

  Widget priceDetailRow(
    String title,
    String value, {
    TextStyle? titleStyle,
    TextStyle? valueStyle,
    double bottomPadding = 14,
  }) {
    if (value.validate().isEmpty) return const Offstage();

    return Row(
      children: [
        Text(title, style: titleStyle ?? secondaryTextStyle(size: 15)).expand(),
        12.width,
        Text(
          value,
          style: valueStyle ?? boldTextStyle(size: 15),
          textAlign: TextAlign.right,
        ).expand(),
      ],
    ).paddingOnly(bottom: bottomPadding);
  }

  bool canCustomerContact(ProductOrderData order) {
    return order.effectiveDeliveryStatus != ProductOrderStatusKeys.completed &&
        order.effectiveDeliveryStatus != ProductOrderStatusKeys.cancelled &&
        order.effectiveDeliveryStatus != ProductOrderStatusKeys.rejected;
  }

  String customerPhone(ProductOrderData order) {
    return order.customer?.phone.validate().isNotEmpty == true
        ? order.customer!.phone.validate()
        : order.customerPhone.validate();
  }

  Widget productOrderCustomerWidget(ProductOrderData order) {
    final phone = customerPhone(order);
    final email = order.customer?.email.validate() ?? '';
    final canContact = canCustomerContact(order);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(languages.lblAboutCustomer,
                    style: boldTextStyle(size: LABEL_TEXT_SIZE))
                .expand(),
            if (canContact && order.displayAddress.validate().isNotEmpty)
              TextButton(
                child: Text(languages.lblGetDirection,
                    style: boldTextStyle(color: primaryColor, size: 12)),
                onPressed: () {
                  launchMap(order.displayAddress);
                },
              ),
          ],
        ).paddingSymmetric(horizontal: 16),
        Container(
          decoration: boxDecorationDefault(
              color: context.cardColor, borderRadius: radius()),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (order.displayCustomerImage.validate().isNotEmpty)
                    ImageBorder(src: order.displayCustomerImage, height: 45),
                  16.width,
                  HandymanNameWidget(
                    name: order.displayCustomerName,
                    size: 14,
                    showVerifiedBadge: false,
                  ).expand(),
                  if (canContact && phone.validate().isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        String phoneNumber = phone.validate().contains('+')
                            ? phone.validate().replaceAll('-', '')
                            : '+${phone.validate().replaceAll('-', '')}';
                        launchUrl(
                          Uri.parse(
                              '${getSocialMediaLink(LinkProvider.WHATSAPP)}$phoneNumber'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Image.asset(ic_whatsapp, height: 22),
                    ).paddingRight(8),
                ],
              ),
              if (canContact && email.validate().isNotEmpty) ...[
                16.height,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languages.email,
                      style: boldTextStyle(
                          size: 12,
                          color: appStore.isDarkMode
                              ? textSecondaryColor
                              : textPrimaryColor),
                    ).expand(),
                    8.width,
                    Text(
                      email.validate(),
                      style: boldTextStyle(
                          size: 12,
                          color:
                              appStore.isDarkMode ? white : textSecondaryColor,
                          weight: FontWeight.w400),
                    ).expand(flex: 4),
                  ],
                ).onTap(() => launchMail(email.validate())),
              ],
              if (canContact && order.displayAddress.validate().isNotEmpty) ...[
                8.height,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${languages.lblAddress}:',
                      style: boldTextStyle(
                          size: 12,
                          color: appStore.isDarkMode
                              ? textSecondaryColor
                              : textPrimaryColor),
                    ).expand(),
                    8.width,
                    Text(
                      order.displayAddress,
                      style: boldTextStyle(
                          size: 12,
                          color:
                              appStore.isDarkMode ? white : textSecondaryColor,
                          weight: FontWeight.w400),
                    ).expand(flex: 4),
                  ],
                ).onTap(() => launchMap(order.displayAddress)),
              ],
              if (phone.validate().isNotEmpty) ...[
                16.height,
                Row(
                  children: [
                    if (canContact) ...[
                      AppButton(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(calling, height: 18, width: 18),
                            16.width,
                            Text(languages.lblCall, style: boldTextStyle()),
                          ],
                        ),
                        width: context.width(),
                        color: context.scaffoldBackgroundColor,
                        elevation: 0,
                        onTap: () => launchCall(phone.validate()),
                      ).expand(),
                      24.width,
                    ],
                    if (appConfigurationStore.isEnableChat)
                      AppButton(
                        width:
                            canContact ? context.width() : context.width() / 2,
                        elevation: 0,
                        color: primaryColor,
                        onTap: () async {
                          toast(languages.pleaseWaitWhileWeLoadChatDetails);
                          UserData? user = await userService.getUserNull(
                              email: email.validate());
                          Fluttertoast.cancel();
                          if (user != null) {
                            UserChatScreen(
                              receiverUser: user,
                              isChattingAllow: !canContact,
                            ).launch(context);
                          } else {
                            toast(
                                '${order.displayCustomerName} ${languages.isNotAvailableForChat}');
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(chat,
                                color: Colors.white, height: 18, width: 18),
                            16.width,
                            Text(languages.lblChat,
                                style: boldTextStyle(color: Colors.white)),
                          ],
                        ),
                      ).expand(),
                  ],
                ),
              ],
            ],
          ),
        ).paddingSymmetric(horizontal: 16),
        16.height,
      ],
    );
  }

  Widget productOrderDeliveryBoyWidget(ProductOrderData order) {
    if (appStore.userType != USER_TYPE_PROVIDER) return const Offstage();

    final deliveryBoy = order.deliveryBoy;
    if (deliveryBoy == null) return const Offstage();

    final phone = deliveryBoy.phone.validate();
    final email = deliveryBoy.email.validate();
    final canContact = canCustomerContact(order) &&
        deliveryBoy.id.validate() != appStore.userId;
    final canChat = appConfigurationStore.isEnableChat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Delivery Boy', style: boldTextStyle(size: LABEL_TEXT_SIZE))
            .paddingSymmetric(horizontal: 16),
        8.height,
        Container(
          decoration: boxDecorationDefault(
              color: context.cardColor, borderRadius: radius()),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (deliveryBoy.profileImage.validate().isNotEmpty)
                    ImageBorder(
                        src: deliveryBoy.profileImage.validate(), height: 45),
                  16.width,
                  HandymanNameWidget(
                    name: deliveryBoy.displayName.validate(),
                    size: 14,
                    showVerifiedBadge: false,
                  ).expand(),
                  if (canContact && phone.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        String phoneNumber = phone.contains('+')
                            ? phone.replaceAll('-', '')
                            : '+${phone.replaceAll('-', '')}';
                        launchUrl(
                          Uri.parse(
                              '${getSocialMediaLink(LinkProvider.WHATSAPP)}$phoneNumber'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Image.asset(ic_whatsapp, height: 22),
                    ).paddingRight(8),
                ],
              ),
              if (canContact && email.isNotEmpty) ...[
                16.height,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languages.email,
                      style: boldTextStyle(
                          size: 12,
                          color: appStore.isDarkMode
                              ? textSecondaryColor
                              : textPrimaryColor),
                    ).expand(),
                    8.width,
                    Text(
                      email,
                      style: boldTextStyle(
                          size: 12,
                          color:
                              appStore.isDarkMode ? white : textSecondaryColor,
                          weight: FontWeight.w400),
                    ).expand(flex: 4),
                  ],
                ).onTap(() => launchMail(email)),
              ],
              if (phone.isNotEmpty || canChat) ...[
                16.height,
                Row(
                  children: [
                    if (canContact) ...[
                      AppButton(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(calling, height: 18, width: 18),
                            16.width,
                            Text(languages.lblCall, style: boldTextStyle()),
                          ],
                        ),
                        width: context.width(),
                        color: context.scaffoldBackgroundColor,
                        elevation: 0,
                        onTap: () => launchCall(phone),
                      ).expand(),
                      24.width,
                    ],
                    if (canChat)
                      AppButton(
                        width:
                            canContact ? context.width() : context.width() / 2,
                        elevation: 0,
                        color: primaryColor,
                        onTap: () async {
                          toast(languages.pleaseWaitWhileWeLoadChatDetails);
                          UserData? user =
                              await userService.getUserNull(email: email);
                          Fluttertoast.cancel();
                          if (user != null) {
                            UserChatScreen(
                              receiverUser: user,
                              isChattingAllow: !canContact,
                            ).launch(context);
                          } else {
                            toast(
                                '${deliveryBoy.displayName.validate()} ${languages.isNotAvailableForChat}');
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(chat,
                                color: Colors.white, height: 18, width: 18),
                            16.width,
                            Text(languages.lblChat,
                                style: boldTextStyle(color: Colors.white)),
                          ],
                        ),
                      ).expand(),
                  ],
                ),
              ],
            ],
          ),
        ).paddingSymmetric(horizontal: 16),
        16.height,
      ],
    );
  }

  Widget locationWidget(ProductOrderData order) {
    if (order.displayAddress.validate().isEmpty) return const Offstage();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Delivery Location', style: boldTextStyle()).expand(),
            if (order.displayAddress.validate().isNotEmpty)
              TextButton(
                child: Text(languages.lblGetDirection,
                    style: boldTextStyle(color: primaryColor, size: 12)),
                onPressed: () {
                  launchMap(order.displayAddress);
                },
              ),
          ],
        ).paddingSymmetric(horizontal: 16),
        if (order.displayAddress.validate().isNotEmpty)
          Container(
            width: context.width(),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: boxDecorationDefault(
                color: context.cardColor, borderRadius: radius()),
            child: Text(
              order.displayAddress,
              style: secondaryTextStyle(),
            ),
          ).onTap(() => launchMap(order.displayAddress)),
        16.height,
      ],
    );
  }

  Widget action(ProductOrderData order) {
    showBottomActionBar = false;
    if (isUserTypeProvider) {
      if (order.effectiveDeliveryStatus == ProductOrderStatusKeys.pending) {
        showBottomActionBar = true;
        return Row(
          children: [
            AppButton(
                text: languages.accept,
                color: primaryColor,
                onTap: () {
                  updateStatus(order, ProductOrderStatusKeys.accepted);
                }).expand(),
            16.width,
            AppButton(
                text: languages.decline,
                textColor: textPrimaryColorGlobal,
                onTap: () {
                  updateStatus(order, ProductOrderStatusKeys.rejected);
                }).expand(),
          ],
        );
      }
      if (order.isDeliveryAccepted) {
        showBottomActionBar = true;
        return Row(
          children: [
            AppButton(
                text: 'Assign to Myself',
                color: context.scaffoldBackgroundColor,
                textColor: primaryColor,
                shapeBorder: RoundedRectangleBorder(
                    borderRadius: radius(),
                    side: BorderSide(color: primaryColor)),
                onTap: () {
                  assignToMyself(order);
                }).expand(),
            16.width,
            AppButton(
              text: order.hasDeliveryBoy ? 'Reassign' : 'Assign Delivery Boy',
              color: primaryColor,
              onTap: () {
                AssignDeliveryBoyScreen(
                  orderId: order.id.validate(),
                  onUpdate: () {
                    if (!mounted) return;
                    init();
                    setState(() {});
                  },
                ).launch(context);
              },
            ).expand(),
          ],
        );
      }
      if (order.effectiveDeliveryStatus == ProductOrderStatusKeys.delivered) {
        showBottomActionBar = true;
        return Row(
          children: [
            AppButton(
              text: 'Upload Proof',
              color: context.scaffoldBackgroundColor,
              textColor: primaryColor,
              shapeBorder: RoundedRectangleBorder(
                  borderRadius: radius(),
                  side: BorderSide(color: primaryColor)),
              onTap: () => openProductProofScreen(order),
            ).expand(),
            16.width,
            AppButton(
                text: canCollectProductOrderPayment(order)
                    ? 'Collect Payment'
                    : 'Complete Order',
                color: primaryColor,
                onTap: () {
                  if (canCollectProductOrderPayment(order)) {
                    showCollectProductOrderPaymentDialog(order);
                  } else {
                    updateStatus(order, ProductOrderStatusKeys.completed);
                  }
                }).expand(),
          ],
        );
      }
      if (order.effectiveDeliveryStatus == ProductOrderStatusKeys.completed) {
        showBottomActionBar = true;
        return AppButton(
          text: 'Upload Proof',
          color: primaryColor,
          onTap: () => openProductProofScreen(order),
        );
      }
    }

    final assignedToMe = isProductOrderAssignedToCurrentUser(order);
    if ((isUserTypeHandyman || assignedToMe) &&
        (order.isDeliveryAccepted ||
            order.effectiveDeliveryStatus == ProductOrderStatusKeys.assigned)) {
      showBottomActionBar = true;
      return AppButton(
          text: 'Start Delivery',
          color: startDriveButtonColor,
          onTap: () {
            updateStatus(order, ProductOrderStatusKeys.onGoing);
          });
    }
    if ((isUserTypeHandyman || assignedToMe) &&
        order.effectiveDeliveryStatus == ProductOrderStatusKeys.onGoing) {
      showBottomActionBar = true;
      return AppButton(
          text: 'Mark Delivered',
          color: primaryColor,
          onTap: () {
            updateStatus(order, ProductOrderStatusKeys.delivered);
          });
    }
    if ((isUserTypeHandyman || assignedToMe) &&
        (order.effectiveDeliveryStatus == ProductOrderStatusKeys.delivered ||
            order.effectiveDeliveryStatus ==
                ProductOrderStatusKeys.completed)) {
      showBottomActionBar = true;
      if (canCollectProductOrderPayment(order)) {
        return Row(
          children: [
            AppButton(
              text: 'Upload Proof',
              color: context.scaffoldBackgroundColor,
              textColor: primaryColor,
              shapeBorder: RoundedRectangleBorder(
                  borderRadius: radius(),
                  side: BorderSide(color: primaryColor)),
              onTap: () => openProductProofScreen(order),
            ).expand(),
            16.width,
            AppButton(
              text: 'Collect Payment',
              color: primaryColor,
              onTap: () => showCollectProductOrderPaymentDialog(order),
            ).expand(),
          ],
        );
      }
      return AppButton(
        text: 'Upload Proof',
        color: primaryColor,
        onTap: () => openProductProofScreen(order),
      );
    }
    return const Offstage();
  }

  void openProductProofScreen(ProductOrderData order) {
    ProductOrderProofScreen(order: order).launch(context).then((value) {
      if (!mounted) return;
      if (value == true) {
        init();
        setState(() {});
      }
    });
  }

  Widget body(AsyncSnapshot<ProductOrderDetailResponse> snap) {
    if (snap.hasError) {
      return NoDataWidget(
        title: snap.error.toString(),
        imageWidget: const ErrorStateWidget(),
        retryText: languages.reload,
        onRetry: () {
          appStore.setLoading(true);
          init();
          if (!mounted) return;
          setState(() {});
        },
      );
    }
    if (!snap.hasData) return LoaderWidget().center();

    final order = snap.data!.data!;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            header(order),
            locationWidget(order),
            productsWidget(order),
            16.height,
            priceDetailWidget(order),
            productOrderCustomerWidget(order),
            if (appStore.userType == USER_TYPE_PROVIDER)
              productOrderDeliveryBoyWidget(order),
            infoCard('Payment', [
              infoRow('Method',
                  order.paymentMethod.validate().capitalizeFirstLetter()),
              infoRow('Status',
                  order.paymentStatus.validate().capitalizeFirstLetter()),
              infoRow('Transaction', order.txnId.validate()),
              infoRow('Total', order.displayTotal),
            ]),
            if (order.proof.validate().isNotEmpty)
              infoCard(
                'Delivery Proof',
                order.proof!
                    .map(
                      (e) => Row(
                        children: [
                          CachedImageWidget(
                              url: e.url.validate(),
                              height: 56,
                              width: 56,
                              fit: BoxFit.cover,
                              radius: 8),
                          12.width,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (e.description.validate().isNotEmpty)
                                Text(e.description.validate(),
                                    style: boldTextStyle(size: 13)),
                              if (e.createdAt.validate().isNotEmpty)
                                Text(e.createdAt.validate(),
                                    style: secondaryTextStyle()),
                            ],
                          ).expand(),
                        ],
                      ).paddingBottom(8),
                    )
                    .toList(),
              ),
          ],
        ),
        Positioned(
          bottom: 0,
          child: Container(
            width: context.width(),
            decoration: BoxDecoration(color: context.cardColor),
            padding: showBottomActionBar
                ? const EdgeInsets.all(16)
                : EdgeInsets.zero,
            child: action(order),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget('Product Order',
          textColor: white,
          color: context.primaryColor,
          backWidget: BackWidget(),
          textSize: APP_BAR_TEXT_SIZE),
      body: Stack(
        children: [
          SnapHelperWidget<ProductOrderDetailResponse>(
            future: future,
            loadingWidget: LoaderWidget().center(),
            onSuccess: (_) =>
                body(AsyncSnapshot.withData(ConnectionState.done, _)),
            errorBuilder: (error) => NoDataWidget(
              title: error,
              retryText: languages.reload,
              imageWidget: const ErrorStateWidget(),
              onRetry: () {
                init();
                if (!mounted) return;
                setState(() {});
              },
            ),
          ),
          Observer(builder: (_) => LoaderWidget().visible(appStore.isLoading)),
        ],
      ),
    );
  }
}

class ProductOrderCashPaymentDialog extends StatefulWidget {
  final ProductOrderData order;
  final Function(String remarks) onAccept;

  const ProductOrderCashPaymentDialog({
    Key? key,
    required this.order,
    required this.onAccept,
  }) : super(key: key);

  @override
  State<ProductOrderCashPaymentDialog> createState() =>
      _ProductOrderCashPaymentDialogState();
}

class _ProductOrderCashPaymentDialogState
    extends State<ProductOrderCashPaymentDialog> {
  final TextEditingController remarkCont =
      TextEditingController(text: 'Cash collected');

  @override
  void dispose() {
    remarkCont.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width(),
      padding: const EdgeInsets.all(16),
      color: context.cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichTextWidget(
            textAlign: TextAlign.center,
            list: [
              TextSpan(
                  text: 'Cash payment for order ', style: primaryTextStyle()),
              TextSpan(text: widget.order.displayCode, style: boldTextStyle()),
              TextSpan(text: ' is collected.', style: primaryTextStyle()),
            ],
          ),
          26.height,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Amount received: ', style: secondaryTextStyle()),
              Text(widget.order.displayTotal, style: boldTextStyle(size: 16)),
            ],
          ).center(),
          26.height,
          AppTextField(
            textFieldType: TextFieldType.MULTILINE,
            controller: remarkCont,
            decoration: inputDecoration(
              context,
              hint: languages.remark,
              fillColor: context.scaffoldBackgroundColor,
            ),
            minLines: 4,
          ),
          32.height,
          Row(
            children: [
              AppButton(
                text: languages.lblCancel,
                onTap: () {
                  finish(context);
                },
                color: context.scaffoldBackgroundColor,
                shapeBorder: RoundedRectangleBorder(
                    side: BorderSide(color: context.primaryColor),
                    borderRadius: radius()),
                textColor: context.primaryColor,
              ).expand(),
              16.width,
              AppButton(
                text: languages.confirm,
                color: context.primaryColor,
                onTap: () {
                  widget.onAccept.call(
                    remarkCont.text.validate(value: 'Cash collected'),
                  );
                },
              ).expand(),
            ],
          ),
        ],
      ),
    );
  }
}

class ProductOrderProofScreen extends StatefulWidget {
  final ProductOrderData order;

  const ProductOrderProofScreen({Key? key, required this.order})
      : super(key: key);

  @override
  State<ProductOrderProofScreen> createState() =>
      _ProductOrderProofScreenState();
}

class _ProductOrderProofScreenState extends State<ProductOrderProofScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController descriptionCont = TextEditingController();
  final FocusNode descriptionFocus = FocusNode();
  List<XFile> imageFiles = [];

  Future<void> submit() async {
    hideKeyboard(context);

    if (imageFiles.isEmpty) {
      toast(languages.lblChooseOneImage);
      return;
    }

    appStore.setLoading(true);
    await saveProductOrderProof(
      orderId: widget.order.id.validate(),
      description: descriptionCont.text.validate(),
      images: imageFiles.map((e) => File(e.path)).toList(),
    ).then((value) {
      appStore.setLoading(false);
      finish(context, true);
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
    });
  }

  void showImagePickDialog() {
    showInDialog(
      context,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      title: Text(languages.chooseAction, style: boldTextStyle()),
      builder: (context) {
        return FilePickerDialog(isSelected: false);
      },
    ).then((file) async {
      if (file == GalleryFileTypes.CAMERA) {
        GetImage(ImageSource.camera, path: (path, name, xFile) async {
          imageFiles.add(xFile);
          setState(() {});
        });
      } else if (file == GalleryFileTypes.GALLERY) {
        GetMultipleImage(path: (xFiles) async {
          final existingNames =
              imageFiles.map((file) => file.name.trim().toLowerCase()).toSet();
          imageFiles.addAll(xFiles.where((file) =>
              !existingNames.contains(file.name.trim().toLowerCase())));
          setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    descriptionCont.dispose();
    descriptionFocus.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget(
        'Delivery Proof',
        color: context.primaryColor,
        textColor: white,
        backWidget: BackWidget(),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order', style: boldTextStyle()),
                  12.height,
                  AppTextField(
                    textFieldType: TextFieldType.NAME,
                    initialValue: widget.order.displayCode,
                    enabled: false,
                    decoration: inputDecoration(context, showLabel: false),
                  ),
                  16.height,
                  Text(languages.hintDescription, style: boldTextStyle()),
                  12.height,
                  AppTextField(
                    textFieldType: TextFieldType.MULTILINE,
                    controller: descriptionCont,
                    focus: descriptionFocus,
                    minLines: 4,
                    decoration: inputDecoration(context,
                        hint: languages.hintDescription, showLabel: false),
                  ),
                  16.height,
                  DottedBorderWidget(
                    color: primaryColor.withValues(alpha: 0.6),
                    strokeWidth: 1,
                    padding: const EdgeInsets.all(16),
                    radius: defaultRadius,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_upload_outlined,
                            size: 30, color: context.iconColor),
                        8.height,
                        Text(languages.uploadMedia, style: boldTextStyle()),
                      ],
                    ).center().onTap(
                          showImagePickDialog,
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                        ),
                  ),
                  16.height,
                  Text(languages.serviceProofMediaUploadNote,
                      style: secondaryTextStyle()),
                  16.height,
                  HorizontalList(
                    padding: EdgeInsets.zero,
                    itemCount: imageFiles.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.file(
                            File(imageFiles[index].path),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ).cornerRadiusWithClipRRect(defaultRadius),
                          Container(
                            decoration: boxDecorationWithRoundedCorners(
                                boxShape: BoxShape.circle,
                                backgroundColor: primaryColor),
                            margin: const EdgeInsets.only(right: 8, top: 8),
                            padding: const EdgeInsets.all(4),
                            child:
                                const Icon(Icons.close, size: 16, color: white),
                          ).onTap(() {
                            imageFiles.removeAt(index);
                            setState(() {});
                          }),
                        ],
                      );
                    },
                  ).visible(imageFiles.isNotEmpty),
                ],
              ),
            ),
          ),
          Observer(builder: (_) => LoaderWidget().visible(appStore.isLoading)),
        ],
      ),
      bottomNavigationBar: AppButton(
        text: languages.lblSubmit,
        color: primaryColor,
        textColor: white,
        onTap: () {
          if (formKey.currentState!.validate()) {
            submit();
          }
        },
      ).paddingAll(16),
    );
  }
}

class ProductOrderStatusBottomSheet extends StatelessWidget {
  final ProductOrderData order;
  final ScrollController? scrollController;

  const ProductOrderStatusBottomSheet({
    Key? key,
    required this.order,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activity = order.activity.validate().reversed.toList();

    return Container(
      decoration: boxDecorationDefault(
        color: context.scaffoldBackgroundColor,
        borderRadius: radiusOnly(
          topLeft: defaultRadius,
          topRight: defaultRadius,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: AnimatedScrollView(
        controller: scrollController,
        listAnimationType: ListAnimationType.FadeIn,
        fadeInConfiguration: FadeInConfiguration(duration: 2.seconds),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              Text('Order Status', style: boldTextStyle(size: LABEL_TEXT_SIZE))
                  .expand(),
              GestureDetector(
                onTap: () {
                  finish(context);
                },
                child: Container(
                  decoration: boxDecorationDefault(
                    color: context.cardColor,
                    borderRadius: radius(4),
                    border: Border.all(color: context.iconColor),
                  ),
                  child: const Icon(Icons.close_rounded, size: 16),
                ),
              ),
            ],
          ),
          Divider(height: 32, thickness: 1, color: context.dividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order ID:', style: secondaryTextStyle(size: 14)),
              Text(
                order.displayCode,
                style: boldTextStyle(color: primaryColor),
              ),
            ],
          ),
          16.height,
          if (activity.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              decoration: boxDecorationDefault(color: context.cardColor),
              child: AnimatedWrap(
                listAnimationType: ListAnimationType.FadeIn,
                itemCount: activity.length,
                itemBuilder: (context, index) {
                  return ProductOrderStatusListWidget(
                    data: activity[index],
                    index: index,
                    length: activity.length,
                  );
                },
              ),
            ),
          if (activity.isEmpty) Text(languages.noDataFound),
        ],
      ),
    );
  }
}

class ProductOrderStatusListWidget extends StatelessWidget {
  final ProductOrderActivity data;
  final int index;
  final int length;

  const ProductOrderStatusListWidget({
    Key? key,
    required this.data,
    required this.index,
    required this.length,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 12,
              width: 12,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: radius(16),
              ),
            ),
            SizedBox(
              height: 70,
              child: DashedRect(
                gap: 3,
                color: primaryColor,
                strokeWidth: 1.5,
              ),
            ).visible(index != length - 1),
          ],
        ).paddingOnly(top: 4),
        16.width,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextIcon(
              expandedText: true,
              edgeInsets: const EdgeInsets.only(right: 4, left: 4, bottom: 4),
              text: data.activityType
                  .validate()
                  .replaceAll('_', ' ')
                  .capitalizeFirstLetter(),
            ),
            Text(
              data.activityMessage.validate().replaceAll('_', ' '),
              style: secondaryTextStyle(),
            ).paddingOnly(left: 4),
          ],
        ).paddingOnly(bottom: 18).expand(flex: 3),
        if (data.datetime.validate().isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDate(data.datetime.validate()).suffixText(value: ','),
                style: primaryTextStyle(size: 12),
              ),
              Text(
                formatDate(data.datetime.validate(), isTime: true),
                style: primaryTextStyle(size: 12),
              ),
            ],
          ),
      ],
    );
  }
}
