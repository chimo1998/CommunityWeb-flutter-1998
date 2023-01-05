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
// line sdk
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// used to pass messages from event handler to the UI
final _messageStreamController = BehaviorSubject<RemoteMessage>();
final _urlMessageController = BehaviorSubject<RemoteMessage>();
int _id = 0;
const String baseUrl = 'https://chargingpile-develope-ts6mdg2sfq-de.a.run.app';
String webUrl = '';
String uuid = '';
bool waitingForDialog = true;
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
  //if (Platform.isAndroid) _showNotification(message);
}

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

var userProfile;
String userLineSub = "";

Future<void> _lineLogin() async {
  // setup line login

  WidgetsFlutterBinding.ensureInitialized();
  LineSDK.instance.setup("1657447798").then((value) => print("LineSDK prepared"));
  try {
    final result = await LineSDK.instance.login(scopes: ["openid"]); //If the userLineSub ;isn't logged in, it returns a null.
    if (result != null) {
      userProfile = result;
      var idtoken = result.accessToken.idToken;
      print(idtoken);
      print(idtoken?["sub"]);
      userLineSub = idtoken?["sub"];
      //return userLineSub ;data in Map it contains displayName,pictureUrl,userIdprint(result.userProfile.data);print(result.userProfile.pictureUrl);print(result.userProfile.displayName);
    } else {
      print("unable to login");
    }
  } catch (e) {
    // Error handling.print(e.stacktrace);}
    print(e);
  }
}

String fcm_redirect = "";
void _handleMessage(RemoteMessage message) {
  print("in handle message ${message.data}");
  fcm_redirect = message.data["redirect"];
  _urlMessageController.add(message);
  print("redirect is $webUrl$fcm_redirect");
}

Future<void> _showNotification(message) async {
  if (kDebugMode) {
    print("in show notification");
  }

  const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails('communityweb1998_channel', "communityweb1998_channel",
      importance: Importance.max, priority: Priority.max, playSound: true, groupKey: 'com.cloudct.community_web_1998');
  const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(categoryIdentifier: "community_web_1998");
  const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails, iOS: darwinNotificationDetails);
  await flutterLocalNotificationsPlugin.show(_id++, message.notification?.title ?? "", message.notification?.body ?? "", notificationDetails, payload: "testing");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const AndroidInitializationSettings android = AndroidInitializationSettings('app_icon');
  const DarwinInitializationSettings iOS = DarwinInitializationSettings();
  const InitializationSettings initSettings = InitializationSettings(android: android, iOS: iOS);
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
  );

  // Request permission of notifications
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

  // Request permission of camera and photos
  await Permission.camera.request();
  // if (! await Permission.camera.status.isGranted) {
  //   await Permission.camera.request();
  // }
  if (Platform.isAndroid) {
    await Permission.storage.request();
    // if (! await Permission.storage.status.isGranted) {
    //   await Permission.storage.request();
    // }
  } else {
    await Permission.photos.request();
    // if (! await Permission.photos.status.isGranted) {
    //   await Permission.photos.request();
    // }
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

  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    fcm_redirect = initialMessage.data["redirect"];
  }
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
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

  // Line login
  // await _lineLogin();
  final prefs = await SharedPreferences.getInstance();
  String? lineSub = prefs.getString("line_sub"); //storage.getItem('line_sub');

  if (lineSub?.isEmpty ?? true) {
    await _lineLogin();
    prefs.setString("line_sub", userLineSub);
  } else {
    userLineSub = lineSub!;
  }

  webUrl = '$baseUrl?from_app=true&fcm_device_id=$uuid&fcm_token=${token!}&line_sub=$userLineSub&$fcm_redirect';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '社區網1998',
      debugShowCheckedModeBanner: false,
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
  String showUrl = webUrl;

  @override
  void initState() {
    super.initState();
    // Enable virtual display.
    if (Platform.isAndroid) WebView.platform = AndroidWebView();
  }

  _MyHomePageState() {
    _urlMessageController.listen((message) {
      setState(() {
        fcm_redirect = message.data["redirect"];
        showUrl = "$baseUrl?$fcm_redirect";
      });
    });
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
        initialUrl: showUrl,
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
