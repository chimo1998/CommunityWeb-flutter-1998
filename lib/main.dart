import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
// core Flutter primitives
import 'package:flutter/foundation.dart';
// core FlutterFire dependency
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// FlutterFire's Firebase Cloud Messaging plugin
import 'package:firebase_messaging/firebase_messaging.dart';
// Wevview library
import 'package:webview_flutter/webview_flutter.dart';
// Message library
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Add stream controller
import 'package:rxdart/rxdart.dart';
// Get device info
import 'package:device_info_plus/device_info_plus.dart';
// Signup channel for android notifications

// used to pass messages from event handler to the UI
final _messageStreamController = BehaviorSubject<RemoteMessage>();
String webUrl = 'https://chargingpile-develope-ts6mdg2sfq-de.a.run.app';
String uuid = '';
// Define the background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');
    print('Message notification: ${message.notification?.body}');
  }

  // if(Platform.isAndroid) _showNotification(message);
  if (Platform.isAndroid) _showNotification(message);
}

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _showNotification(message) async {
  if (kDebugMode) {
    print("in show notification");
  }
  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails('communityweb1998_channel', "communityweb1998_channel",
          importance: Importance.max, priority: Priority.max, playSound: true,
          groupKey: 'com.example.community_web_1998');
  const DarwinNotificationDetails darwinNotificationDetails =
      DarwinNotificationDetails(categoryIdentifier: "community_web_1998");
  const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails , iOS: darwinNotificationDetails);
  await flutterLocalNotificationsPlugin.show(
      message.messageId,
      message.notification?.title ?? "",
      message.notification?.body ?? "",
      notificationDetails,
      payload: "testing");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const AndroidInitializationSettings android =
      AndroidInitializationSettings('app_icon');
  const DarwinInitializationSettings iOS = DarwinInitializationSettings();
  const InitializationSettings initSettings =
      InitializationSettings(android: android, iOS: iOS);
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
  );

  // Request permission
  final messaging = FirebaseMessaging.instance;
  await messaging.setAutoInitEnabled(true);
  final settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (kDebugMode) {
    print('Permission granted: ${settings.authorizationStatus}');
  }

  // Register with FCM
  String? token = await messaging.getToken();

  messaging.onTokenRefresh.listen((newToken) async {
    // Save newToken
    if (kDebugMode) {
      print('Token: $newToken');
    }
  });

  if (kDebugMode) {
    print('Registration Token=$token');
  }

  // Set up foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (kDebugMode) {
      print('Handling a foreground message: ${message.messageId}');
      print('Message data: ${message.data}');
      print('Message notification: ${message.notification?.title}');
      print('Message notification: ${message.notification?.body}');
    }

    _messageStreamController.sink.add(message);
    _showNotification(message);
  });

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Get device uuid
  var deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    // import 'dart:io'
    var iosDeviceInfo = await deviceInfo.iosInfo;
    uuid = iosDeviceInfo.identifierForVendor ?? ''; // unique ID on iOS
  } else if (Platform.isAndroid) {
    var androidDeviceInfo = await deviceInfo.androidInfo;
    uuid = androidDeviceInfo.id; // unique ID on Android
  }

  webUrl += '?fcm_device_id=$uuid&fcm_token=${token!}';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '社區網1998',
      // theme: ThemeData(
      //   // This is the theme of your application.
      //   //
      //   // Try running your application with "flutter run". You'll see the
      //   // application has a blue toolbar. Then, without quitting the app, try
      //   // changing the primarySwatch below to Colors.green and then invoke
      //   // "hot reload" (press "r" in the console where you ran "flutter run",
      //   // or simply save your changes to "hot reload" in a Flutter IDE).
      //   // Notice that the counter didn't reset back to zero; the application
      //   // is not restarted.
      //   primarySwatch: Colors.blue,
      // ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _lastMessage = "";

  _MyHomePageState() {
    _messageStreamController.listen((message) {
      setState(() {
        if (message.notification != null) {
          _lastMessage = 'Received a notification message:'
              '\nTitle=${message.notification?.title},'
              '\nBody=${message.notification?.body},'
              '\nData=${message.data}';
        } else {
          _lastMessage = 'Received a data message: ${message.data}';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: SafeArea(
          child: WebView(
        initialUrl: webUrl,
        javascriptMode: JavascriptMode.unrestricted,
      )),
      // appBar: AppBar(
      //   // Here we take the value from the MyHomePage object that was created by
      //   // the App.build method, and use it to set our appbar title.
      //   title: Text(widget.title),
      // ),
      // body: Center(
      //   // Center is a layout widget. It takes a single child and positions it
      //   // in the middle of the parent.
      //   child: Column(
      //     // Column is also a layout widget. It takes a list of children and
      //     // arranges them vertically. By default, it sizes itself to fit its
      //     // children horizontally, and tries to be as tall as its parent.
      //     //
      //     // Invoke "debug painting" (press "p" in the console, choose the
      //     // "Toggle Debug Paint" action from the Flutter Inspector in Android
      //     // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
      //     // to see the wireframe for each widget.
      //     //
      //     // Column has various properties to control how it sizes itself and
      //     // how it positions its children. Here we use mainAxisAlignment to
      //     // center the children vertically; the main axis here is the vertical
      //     // axis because Columns are vertical (the cross axis would be
      //     // horizontal).
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: <Widget>[
      //       Text('Last message from Firebase Messaging:',
      //           style: Theme.of(context).textTheme.titleLarge),
      //       Text(_lastMessage, style: Theme.of(context).textTheme.bodyLarge),
      //     ],
      //   ),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
