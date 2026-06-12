import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handyman_provider_flutter/provider/jobRequest/bid_list_screen.dart';
import 'package:handyman_provider_flutter/utils/common.dart';
import 'package:http/http.dart' as http;
import 'package:nb_utils/nb_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../provider/services/service_detail_screen.dart';
import '../screens/booking_detail_screen.dart';
import '../screens/chat/user_chat_list_screen.dart';
import 'constant.dart';

const String defaultNotificationChannelId = 'notification';
const String bookingNotificationChannelId = 'booking_notification';
const String bookingNotificationSoundName = 'leon';

AudioPlayer? _bookingAlertPlayer;

Future<void> initFirebaseMessaging() async {
  await FirebaseMessaging.instance
      .requestPermission(
    alert: true,
    badge: true,
    sound: true,
  )
      .then((value) async {
    if (value.authorizationStatus == AuthorizationStatus.authorized) {
      await createNotificationChannels();

      await registerNotificationListeners().catchError((e) {
        log('------Notification Listener REGISTRATION ERROR-----------');
      });

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      )
          .catchError((e) {
        log('------setForegroundNotificationPresentationOptions ERROR-----------');
      });
    }
  });
}

Future<void> registerNotificationListeners() async {
  FirebaseMessaging.instance.setAutoInitEnabled(true).then((value) {
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        if (message.notification != null &&
            message.notification!.title.validate().isNotEmpty &&
            message.notification!.body.validate().isNotEmpty) {
          if (Platform.isAndroid)
            showNotification(
              currentTimeStamp(),
              message.notification!.title.validate(),
              parseHtmlString(message.notification!.body.validate()),
              message,
            );
        }
      },
      onError: (e) {
        log("setAutoInitEnabled error $e");
      },
    );

    // replacement for onResume: When the app is in the background and opened directly from the push notification.
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        handleNotificationClick(message);
      },
      onError: (e) {
        log("onMessageOpenedApp Error $e");
      },
    );

    // workaround for onLaunch: When the app is completely closed (not in the background) and opened directly from the push notification
    FirebaseMessaging.instance.getInitialMessage().then(
      (RemoteMessage? message) {
        if (message != null) {
          handleNotificationClick(message);
        }
      },
      onError: (e) {
        log("getInitialMessage error : $e");
      },
    );
  }).onError((error, stackTrace) {
    log("onGetInitialMessage error: $error");
  });
}

Future<void> createNotificationChannels() async {
  if (!Platform.isAndroid) return;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
    defaultNotificationChannelId,
    'Notification',
    importance: Importance.high,
    enableLights: true,
  );

  const AndroidNotificationChannel bookingChannel = AndroidNotificationChannel(
    bookingNotificationChannelId,
    'Booking Notifications',
    description: 'Notifications for newly received bookings',
    importance: Importance.high,
    enableLights: true,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(bookingNotificationSoundName),
  );

  final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(defaultChannel);
  await androidPlugin?.createNotificationChannel(bookingChannel);
}

bool isIncomingBookingNotification(RemoteMessage message) {
  try {
    final notificationInfo = getNotificationAlertInfo(message);

    return notificationInfo.notificationType == ADD_BOOKING ||
        notificationInfo.bookingType == BOOKING ||
        notificationInfo.title.contains('new booking') ||
        notificationInfo.body.contains('new booking') ||
        notificationInfo.title.contains('booking received') ||
        notificationInfo.body.contains('booking received');
  } catch (e) {
    log('Incoming booking notification parse error: $e');
    return false;
  }
}

bool isIncomingProductOrderNotification(RemoteMessage message) {
  try {
    final notificationInfo = getNotificationAlertInfo(message);

    return notificationInfo.notificationType.contains('product_order') ||
        notificationInfo.notificationType.contains('product order') ||
        notificationInfo.notificationType.contains('product') ||
        notificationInfo.orderType.contains('product') ||
        notificationInfo.additionalData.containsKey('product_order_id') ||
        notificationInfo.additionalData.containsKey('order_id') ||
        message.data.containsKey('product_order_id') ||
        message.data.containsKey('order_id') ||
        notificationInfo.title.contains('new product order') ||
        notificationInfo.body.contains('new product order') ||
        notificationInfo.title.contains('product order received') ||
        notificationInfo.body.contains('product order received') ||
        notificationInfo.title.contains('new order') ||
        notificationInfo.body.contains('new order') ||
        notificationInfo.title.contains('order received') ||
        notificationInfo.body.contains('order received');
  } catch (e) {
    log('Incoming product order notification parse error: $e');
    return false;
  }
}

({
  Map<String, dynamic> additionalData,
  String bookingType,
  String body,
  String notificationType,
  String orderType,
  String title
}) getNotificationAlertInfo(RemoteMessage message) {
  final Map<String, dynamic> additionalData =
      message.data.containsKey('additional_data')
          ? jsonDecode(message.data['additional_data']) ?? {}
          : {};
  final String notificationType = (additionalData['notification-type'] ??
          additionalData['notification_type'] ??
          message.data['notification-type'] ??
          message.data['notification_type'])
      .toString()
      .validate()
      .toLowerCase();
  final String bookingType = (additionalData['check_booking_type'] ??
          message.data['check_booking_type'])
      .toString()
      .validate()
      .toLowerCase();
  final String orderType =
      (additionalData['order_type'] ?? message.data['order_type'])
          .toString()
          .validate()
          .toLowerCase();
  final String title = (message.notification?.title ??
          message.data['title'] ??
          message.data['subject'] ??
          '')
      .toString()
      .toLowerCase();
  final String body = (message.notification?.body ??
          message.data['body'] ??
          message.data['message'] ??
          '')
      .toString()
      .toLowerCase();

  return (
    additionalData: additionalData,
    bookingType: bookingType,
    body: body,
    notificationType: notificationType,
    orderType: orderType,
    title: title,
  );
}

Future<void> playIncomingBookingAlert(RemoteMessage message) async {
  if (!isIncomingBookingNotification(message)) return;

  await playOrderAlertAudio();
}

Future<void> playIncomingProviderOrderAlert(RemoteMessage message) async {
  if (!isIncomingBookingNotification(message) &&
      !isIncomingProductOrderNotification(message)) {
    return;
  }

  await playOrderAlertAudio();
}

Future<void> playOrderAlertAudio() async {
  try {
    await _bookingAlertPlayer?.stop();
    await _bookingAlertPlayer?.dispose();

    final player = AudioPlayer();
    _bookingAlertPlayer = player;

    await player.play(AssetSource('leon.mp3'));
    15.seconds.delay.then((_) async {
      if (_bookingAlertPlayer == player) {
        await player.stop();
        await player.dispose();
        _bookingAlertPlayer = null;
      }
    });
  } catch (e) {
    log('Booking alert audio error: $e');
  }
}

Future<bool> subscribeToFirebaseTopic() async {
  bool result = appStore.isSubscribedForPushNotification;
  await initFirebaseMessaging();
  if (appStore.isLoggedIn) {
    if (Platform.isIOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        await 3.seconds.delay;
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      }
      log('Apn Token=========$apnsToken');
    }

    await FirebaseMessaging.instance
        .subscribeToTopic('user_${appStore.userId}')
        .then((value) {
      result = true;
      log("topic-----subscribed----> user_${appStore.userId}");
    });
    final topicTag = isUserTypeHandyman ? HANDYMAN_APP_TAG : PROVIDER_APP_TAG;
    await FirebaseMessaging.instance.subscribeToTopic(topicTag).then((value) {
      result = true;
      log("topic-----subscribed----> $topicTag");
    });

    await appStore.setPushNotificationSubscriptionStatus(result);
  }
  return result;
}

Future<bool> unsubscribeFirebaseTopic(int userId) async {
  bool result = appStore.isSubscribedForPushNotification;
  await FirebaseMessaging.instance
      .unsubscribeFromTopic('user_$userId')
      .then((_) {
    result = false;
    log("topic-----unsubscribed----> user_$userId");
  });
  final topicTag = isUserTypeHandyman ? HANDYMAN_APP_TAG : PROVIDER_APP_TAG;
  await FirebaseMessaging.instance.unsubscribeFromTopic(topicTag).then((_) {
    result = false;
    log('topic-----unsubscribed---->------> $topicTag');
  });

  await appStore.setPushNotificationSubscriptionStatus(result);
  return result;
}

void handleNotificationClick(RemoteMessage message) {
  if (message.data['url'] != null && message.data['url'] is String) {
    commonLaunchUrl(
      message.data['url'],
      launchMode: LaunchMode.externalApplication,
    );
  }
  if (message.data.containsKey('is_chat')) {
    if (message.data.isNotEmpty) {
      navigatorKey.currentState!
          .push(MaterialPageRoute(builder: (context) => ChatListScreen()));
      // navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => UserChatScreen(receiverUser: UserData.fromJson(message.data))));
    }
  } else if (message.data.containsKey('additional_data')) {
    final Map<String, dynamic> additionalData =
        jsonDecode(message.data["additional_data"]) ?? {};
    if (additionalData.containsKey('id') && additionalData['id'] != null) {
      if (additionalData.containsKey('check_booking_type') &&
          additionalData['check_booking_type'] == 'booking') {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) =>
                BookingDetailScreen(bookingId: additionalData['id'].toInt()),
          ),
        );
      }

      if (additionalData.containsKey('notification-type') &&
          additionalData['notification-type'] == 'user_accept_bid') {
        navigatorKey.currentState!
            .push(MaterialPageRoute(builder: (context) => BidListScreen()));
      }
    }

    if (additionalData.containsKey('service_id') &&
        additionalData["service_id"] != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ServiceDetailScreen(
            serviceId: additionalData["service_id"].toInt(),
          ),
        ),
      );
    }
  }
}

void showNotification(
  int id,
  String title,
  String message,
  RemoteMessage remoteMessage,
) async {
  log('Notification : ${remoteMessage.notification!.toMap()}');
  log('Message Data : ${remoteMessage.data}');
  log("Provider Message Image Url : ${remoteMessage.data["image_url"]} ");
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final bool isBookingNotification =
      isIncomingBookingNotification(remoteMessage);

  //code for background notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    defaultNotificationChannelId,
    'Notification',
    importance: Importance.high,
    enableLights: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_stat_ic_notification');
  const iOS = DarwinInitializationSettings(
    requestSoundPermission: false,
    requestBadgePermission: false,
    requestAlertPermission: false,
  );
  const macOS = iOS;
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: iOS,
    macOS: macOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      handleNotificationClick(remoteMessage);
    },
  );

  // region image logic
  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  final BigPictureStyleInformation? bigPictureStyleInformation =
      remoteMessage.data.containsKey("image_url")
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(
                await _downloadAndSaveFile(
                  remoteMessage.data["image_url"],
                  'bigPicture',
                ),
              ),
              largeIcon: FilePathAndroidBitmap(
                await _downloadAndSaveFile(
                  remoteMessage.data["image_url"],
                  'largeIcon',
                ),
              ),
            )
          : null;
  // endregion

  final androidPlatformChannelSpecifics = AndroidNotificationDetails(
    isBookingNotification
        ? bookingNotificationChannelId
        : defaultNotificationChannelId,
    isBookingNotification ? 'Booking Notifications' : 'Notification',
    importance: Importance.high,
    visibility: NotificationVisibility.public,
    priority: Priority.high,
    icon: '@drawable/ic_stat_ic_notification',
    playSound: !isBookingNotification,
    sound: isBookingNotification
        ? const RawResourceAndroidNotificationSound(
            bookingNotificationSoundName)
        : null,
    largeIcon: remoteMessage.data.containsKey("image_url")
        ? FilePathAndroidBitmap(
            await _downloadAndSaveFile(
              remoteMessage.data["image_url"],
              'largeIcon',
            ),
          )
        : null,
    styleInformation: remoteMessage.data.containsKey("image_url")
        ? bigPictureStyleInformation
        : null,
  );

  var darwinPlatformChannelSpecifics = const DarwinNotificationDetails();

  final platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: darwinPlatformChannelSpecifics,
    macOS: darwinPlatformChannelSpecifics,
  );

  flutterLocalNotificationsPlugin.show(
    id,
    remoteMessage.notification!.title.validate(),
    remoteMessage.notification!.body.validate(),
    platformChannelSpecifics,
  );
}
