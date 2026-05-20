import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:handyman_provider_flutter/components/app_widgets.dart';
import 'package:handyman_provider_flutter/components/cached_image_widget.dart';
import 'package:handyman_provider_flutter/components/empty_error_state_widget.dart';
import 'package:handyman_provider_flutter/components/handyman_add_update_screen.dart';
import 'package:handyman_provider_flutter/components/handyman_name_widget.dart';
import 'package:handyman_provider_flutter/main.dart';
import 'package:handyman_provider_flutter/models/user_data.dart';
import 'package:handyman_provider_flutter/networks/rest_apis.dart';
import 'package:handyman_provider_flutter/utils/configs.dart';
import 'package:handyman_provider_flutter/utils/constant.dart';
import 'package:handyman_provider_flutter/utils/model_keys.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../components/base_scaffold_widget.dart';

class AssignDeliveryBoyScreen extends StatefulWidget {
  final int orderId;
  final Function? onUpdate;

  const AssignDeliveryBoyScreen(
      {Key? key, required this.orderId, this.onUpdate})
      : super(key: key);

  @override
  State<AssignDeliveryBoyScreen> createState() =>
      _AssignDeliveryBoyScreenState();
}

class _AssignDeliveryBoyScreenState extends State<AssignDeliveryBoyScreen> {
  final ScrollController scrollController = ScrollController();
  Future<List<UserData>>? future;
  List<UserData> deliveryBoys = [];
  UserData? selectedDeliveryBoy;
  int page = 1;
  bool isLastPage = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() {
    future = getAllHandyman(
      page: page,
      userData: deliveryBoys,
      lastPageCallback: (value) {
        isLastPage = value;
      },
    );
  }

  Future<void> assignTo(int userId, String title) async {
    showConfirmDialogCustom(
      context,
      title: title,
      positiveText: languages.lblYes,
      negativeText: languages.lblNo,
      primaryColor: context.primaryColor,
      onAccept: (_) async {
        appStore.setLoading(true);
        await assignProductOrder({
          CommonKeys.id: widget.orderId,
          CommonKeys.handymanId: [userId],
        }).then((value) {
          appStore.setLoading(false);
          widget.onUpdate?.call();
          finish(context);
          toast(value.message.validate());
        }).catchError((e) {
          appStore.setLoading(false);
          toast(e.toString());
        });
      },
    );
  }

  Widget buildDeliveryBoyItem(UserData userData) {
    return Row(
      children: [
        CachedImageWidget(
          url: userData.profileImage.validate(),
          height: 60,
          fit: BoxFit.cover,
          circle: true,
        ),
        16.width,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Marquee(
              child: HandymanNameWidget(
                size: 14,
                name: userData.displayName.validate(),
                isHandymanAvailable: userData.isHandymanAvailable,
              ),
            ),
            4.height,
            Text(userData.designation.validate(value: 'Delivery Boy'),
                style: secondaryTextStyle()),
          ],
        ).expand(),
      ],
    );
  }

  Widget buildRadioTile(UserData userData) {
    if (!userData.isHandymanAvailable.validate()) {
      return buildDeliveryBoyItem(userData)
          .paddingSymmetric(vertical: 13, horizontal: 16);
    }
    return RadioGroup<UserData>(
      groupValue: selectedDeliveryBoy,
      onChanged: (value) {
        selectedDeliveryBoy = value;
        setState(() {});
      },
      child: RadioListTile<UserData>(
        value: userData,
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        controlAffinity: ListTileControlAffinity.trailing,
        title: buildDeliveryBoyItem(userData),
        activeColor: primaryColor,
      ),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AppScaffold(
        appBarTitle: 'Assign Delivery Boy',
        body: Stack(
          fit: StackFit.expand,
          children: [
            SnapHelperWidget<List<UserData>>(
              future: future,
              loadingWidget: LoaderWidget(),
              onSuccess: (snap) {
                return AnimatedListView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 90),
                  itemCount: snap.length,
                  emptyWidget: NoDataWidget(
                    title: 'No delivery boy available',
                    imageWidget: const EmptyStateWidget(),
                    retryText: languages.lblAddHandyman,
                    onRetry: () {
                      HandymanAddUpdateScreen(
                        userType: USER_TYPE_HANDYMAN,
                        onUpdate: () {
                          page = 1;
                          init();
                          setState(() {});
                        },
                      ).launch(context);
                    },
                  ),
                  onNextPage: () {
                    if (!isLastPage) {
                      page++;
                      appStore.setLoading(true);
                      init();
                      setState(() {});
                    }
                  },
                  onSwipeRefresh: () async {
                    page = 1;
                    init();
                    setState(() {});
                    return 2.seconds.delay;
                  },
                  itemBuilder: (_, index) {
                    return Column(
                      children: [
                        buildRadioTile(snap[index])
                            .paddingOnly(bottom: 2, top: 2),
                        Divider(
                            endIndent: 16,
                            indent: 16,
                            height: 0,
                            color: context.dividerColor),
                      ],
                    );
                  },
                );
              },
              errorBuilder: (error) {
                return NoDataWidget(
                  title: error,
                  imageWidget: const ErrorStateWidget(),
                  retryText: languages.reload,
                  onRetry: () {
                    page = 1;
                    appStore.setLoading(true);
                    init();
                    setState(() {});
                  },
                );
              },
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  AppButton(
                    onTap: () => assignTo(appStore.userId.validate(),
                        'Assign this order to yourself?'),
                    width: context.width(),
                    shapeBorder: RoundedRectangleBorder(
                        borderRadius: radius(),
                        side: BorderSide(color: context.primaryColor)),
                    color: context.scaffoldBackgroundColor,
                    elevation: 0,
                    textColor: context.primaryColor,
                    text: 'Assign to Myself',
                  ).expand(),
                  if (selectedDeliveryBoy != null) 16.width,
                  if (selectedDeliveryBoy != null)
                    AppButton(
                      onTap: () => assignTo(selectedDeliveryBoy!.id.validate(),
                          'Assign this order to ${selectedDeliveryBoy!.displayName.validate()}?'),
                      color: primaryColor,
                      width: context.width(),
                      text: languages.lblAssign,
                    ).expand(),
                ],
              ),
            ),
            Observer(
                builder: (_) => LoaderWidget().visible(appStore.isLoading)),
          ],
        ),
      ),
    );
  }
}
