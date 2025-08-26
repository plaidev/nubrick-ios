import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:nativebrik_bridge/nativebrik_bridge.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    NativebrikBridge("cgv3p3223akg00fod19g");
    NativebrikBridge.instance?.addEventListener((event) {
      print("EVENT: ${event.name}");
    });
    FlutterError.onError = (errorDetails) {
      NativebrikCrashReport.instance.recordFlutterError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      NativebrikCrashReport.instance.recordPlatformError(error, stack);
      return true;
    };
    runApp(const MyApp());
  }, (error, stack) {
    NativebrikCrashReport.instance.recordPlatformError(error, stack);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _message = "Not Found";
  String _userId = "None";
  String _prefecture = "None";

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    final user = NativebrikUser();
    var userId = await user.getId();
    await user.setProperties({
      'prefecture': "Tokyo",
      'age': 11,
      'is_member': true,
      'environment': const bool.fromEnvironment('dart.vm.product')
          ? 'production'
          : 'development',
    });
    var properties = await user.getProperties();

    var config = NativebrikRemoteConfig("cnoku4223akg00e5m630");
    var variant = await config.fetch();
    var message = await variant.get("message");

    setState(() {
      _message = message ?? "Not Found";
      _userId = userId ?? "Not Found";
      _prefecture = properties?['prefecture'] ?? "Not Found";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      builder: (context, child) {
        return NativebrikProvider(child: child!);
      },
      routes: {
        '/': (context) => PageA(
              message: _message,
              userId: _userId,
              prefecture: _prefecture,
            ),
        '/pageB': (context) => const PageB(),
      },
    );
  }
}

class PageA extends StatelessWidget {
  final String message;
  final String userId;
  final String prefecture;

  const PageA({
    super.key,
    required this.message,
    required this.userId,
    required this.prefecture,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page A'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            NativebrikEmbedding("TOP_COMPONENT", height: 270, onEvent: (event) {
              print("Nativebrik Embedding Event: ${event.payload}");
            }),
            const NativebrikAnchor("TOOLTIP_1", child: Text("Tooltip 1")),
            const Text("Message:"),
            Text(message),
            const Text("User ID:"),
            Text(userId),
            const Text("Prefecture:"),
            Text(prefecture),
            ElevatedButton(
              onPressed: () {
                NativebrikDispatcher()
                    .dispatch(NativebrikEvent("DEMO_ON_CLICK"));
              },
              child: const Text('dispatch custom event'),
            ),
            const SizedBox(height: 200),
            NativebrikAnchor(
              "TOOLTIP_2",
              child: ElevatedButton(
                onPressed: () {
                  print("Tooltip 2 anchor button pressed");
                },
                child: Text('Tooltip 2 anchor'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const NativebrikAnchor(
        "NAV_BAR",
        child: CustomBottomNavBar(
          currentIndex: 0,
          onTap: "/pageB",
        ),
      ),
    );
  }
}

class PageB extends StatelessWidget {
  const PageB({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page B'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const NativebrikAnchor("TOOLTIP_4",
                child: Text('Welcome to Page B!')),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const NativebrikAnchor(
        "NAV_BAR",
        child: CustomBottomNavBar(
          currentIndex: 1,
          onTap: "/",
        ),
      ),
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      items: [
        BottomNavigationBarItem(
          icon: const NativebrikAnchor(
            "NAV_ITEM_A",
            child: Icon(Icons.home),
          ),
          label: 'Page A',
        ),
        BottomNavigationBarItem(
          icon: const NativebrikAnchor(
            "NAV_ITEM_B",
            child: Icon(Icons.business),
          ),
          label: 'Page B',
        ),
      ],
      onTap: (index) {
        if ((currentIndex == 0 && index == 1) ||
            (currentIndex == 1 && index == 0)) {
          Navigator.pushReplacementNamed(context, onTap);
        }
      },
    );
  }
}
