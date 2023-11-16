import 'package:flutter/material.dart';
import 'package:hardware_example/bridge/bean/message.dart';
import 'package:hardware_example/native_bridge_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Communication Bridge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({Key? key}) : super(key: key);

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

_print(message) {
  final d = DateTime.now();
  final ts = '${d.hour}:${d.minute}:${d.second}:${d.millisecond}';
  print('[$ts] $message');
}

class _WebViewPageState<WebViewPage> extends State {
  late final WebViewController _controller;
  late final AppBridgeController _appBridgeController;

  @override
  void initState() {
    super.initState();
    // 初始化WebViewController
    _controller = WebViewController()
      ..enableZoom(true)
      ..loadFlutterAsset('assets/sdk/index.html');
    // 初始化AppBridgeController
    _appBridgeController = AppBridgeController(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneKey hardware example'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 8,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () async {
                    var searchDeviceResult = await _appBridgeController
                        .sendMessage(Message(api: 'searchDevice'));

                    print("=======> searchDeviceResult");
                    print(searchDeviceResult);
                  },
                  child: Text('searchDevice'),
                ),
                const SizedBox(height: 10), // Spacing between buttons
                ElevatedButton(
                  onPressed: () async {
                    var getFeaturesResult =
                        await _appBridgeController.sendMessage(Message(
                            api: 'getFeatures',
                            data: {'connectId': 'F5:75:D2:0F:FD:B1'}));

                    print("=======> getFeaturesResult");
                    print(getFeaturesResult);
                  },
                  child: Text('getFeatures'),
                ),
                const SizedBox(height: 10), // Spacing between buttons
                ElevatedButton(
                  onPressed: () async {
                    var btcGetAddressResult = await _appBridgeController
                        .sendMessage(Message(api: 'btcGetAddress', data: {
                      'connectId': 'F5:75:D2:0F:FD:B1',
                      'deviceId': 'B6AAC0F6983E5739791DC234',
                      'path': "m/44'/0'/0'/0/0",
                      'coin': "btc",
                      'showOnScreen': false,
                    }));

                    print("=======> btcGetAddressResult");
                    print(btcGetAddressResult);
                  },
                  child: Text('btcGetAddress'),
                ),
                // Add more buttons if needed
              ],
            ),
          ),
          Expanded(flex: 2, child: WebViewWidget(controller: _controller))
        ],
      ),
    );
  }
}
