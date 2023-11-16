import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hardware_example/bridge/bean/message.dart';
import 'package:hardware_example/bridge/native_bridge_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DeviceInfo {
  final String deviceId;
  final String name;
  final BluetoothDevice device;

  DeviceInfo(this.device, {required this.deviceId, required this.name});

  Map<String, dynamic> toJson() {
    return {
      'id': deviceId,
      'name': name,
    };
  }
}

List<int> hexStringToIntList(String hexString) {
  // 移除可能存在的前缀（比如0x或#）
  hexString = hexString.replaceAll(RegExp(r'^0x'), '');
  hexString = hexString.replaceAll('#', '');

  // 若字符数为奇数，则在前面补零（因为每两个十六进制字符表示一个字节）
  if (hexString.length % 2 != 0) {
    hexString = '0' + hexString;
  }

  // 每两个字符一组进行转换
  List<int> intList = [];
  for (int i = 0; i < hexString.length; i += 2) {
    String byteString = hexString.substring(i, i + 2);
    int value = int.parse(byteString, radix: 16);
    intList.add(value);
  }

  return intList;
}

String intListToHexString(List<int> intList) {
  // 使用 map 将整数列表转换为十六进制字符串，并用 toRadixString(16) 转换为16进制表示
  // padLeft(2, '0') 确保每个值至少占两个字符（前导零填充）
  // join() 方法将列表中的所有元素连接为一个字符串
  return intList
      .map((int value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}

///  Name: NativeBridge控制器
class AppBridgeController extends NativeBridgeController {
  AppBridgeController(WebViewController controller) : super(controller);
  var devicesList = <DeviceInfo>[];
  BluetoothCharacteristic? writeCharacteristic;
  BluetoothCharacteristic? notifyCharacteristic;

  Future<bool> findServices({required BluetoothDevice device}) async {
    List<BluetoothService>? services = await device.discoverServices();

    print('发现服务: ${services.length}');
    if (services == null) {
      return false;
    }

    // find 00000001-0000-1000-8000-00805f9b34fb
    for (BluetoothService service in services) {
      // 匹配服务UUID
      if (service.uuid == Guid('00000001-0000-1000-8000-00805f9b34fb')) {
        print('找到服务UUID: 00000001-0000-1000-8000-00805f9b34fb');

        // 服务下的所有特征
        List<BluetoothCharacteristic> characteristics = service.characteristics;

        for (BluetoothCharacteristic characteristic in characteristics) {
          // 匹配第一个特征UUID
          if (characteristic.uuid ==
              Guid('00000002-0000-1000-8000-00805f9b34fb')) {
            print('找到特征UUID: 00000002-0000-1000-8000-00805f9b34fb');
            writeCharacteristic = characteristic;
          }
          // 匹配第二个特征UUID
          if (characteristic.uuid ==
              Guid('00000003-0000-1000-8000-00805f9b34fb')) {
            print('找到特征UUID: 00000003-0000-1000-8000-00805f9b34fb');
            notifyCharacteristic = characteristic;
            notifyCharacteristic?.onValueReceived.listen((value) async {
              print(
                  "notifyCharacteristic.read() value: ${intListToHexString(value)}");
              await sendMessage(Message(
                      api: "monitorCharacteristic",
                      data: intListToHexString(value))) ??
                  false;
            });
            await notifyCharacteristic?.setNotifyValue(true);
          }
        }
        break; // 如果服务被找到，终止循环
      }
    }

    if (writeCharacteristic == null || notifyCharacteristic == null) {
      return false;
    }

    return true;
  }

  Future<bool> connectToDevice({required String targetUuid}) async {
    BluetoothDevice? device;

    // 先检查目标设备是否已连接
    List<BluetoothDevice> connectedDevices =
        await FlutterBluePlus.connectedDevices;
    for (BluetoothDevice d in connectedDevices) {
      if (d.remoteId.toString() == targetUuid) {
        print("设备已连接。UUID: $targetUuid");
        device = d;
        break;
      }
    }

    // 如果设备尚未连接，则开始扫描
    if (device == null) {
      var subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          var deviceId = r.device.remoteId.toString();
          if (deviceId != targetUuid) {
            continue;
          }
          device = r.device;
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 3),
      );

      // 等待扫描完成
      await Future.delayed(const Duration(seconds: 3));

      // 停止扫描
      await FlutterBluePlus.stopScan();
      await subscription.cancel();

      if (device != null) {
        print("找到设备，尝试连接。UUID: $targetUuid");
        if (device != null) {
          print('找到设备: ${device?.name}');
          await device?.connect();

          print('连接设备: ${device?.name}');
          return await findServices(device: device!);
        } else {
          return false;
        }
      } else {
        print("未找到设备。UUID: $targetUuid");
        return false;
      }
    } else {
      print("无需扫描，设备已连接。UUID: $targetUuid");
      if (writeCharacteristic == null || notifyCharacteristic == null) {
        return await findServices(device: device);
      }
      return true;
    }
  }

  /// 指定JSChannel名称
  @override
  get name => "nativeBridge";

  @override
  Map<String, Function?> get callMethodMap => <String, Function?>{
        // 版本号
        "enumerate": (data) async {
          devicesList.clear();
          var seenDevices = <String>{};

          var subscription = FlutterBluePlus.scanResults.listen((results) {
            for (ScanResult r in results) {
              var deviceId = r.device.remoteId.toString();
              if (r.device.platformName.trim().isEmpty ||
                  seenDevices.contains(deviceId)) {
                continue;
              }
              print('${r.device.platformName} found! remoteId: ${deviceId}');
              devicesList.add(DeviceInfo(r.device,
                  deviceId: deviceId, name: r.device.platformName));
              seenDevices.add(deviceId); // Mark this device ID as seen
            }
          });

          // Wait for Bluetooth enabled & permission granted
          // In your real app you should use `FlutterBluePlus.adapterState.listen` to handle all states
          await FlutterBluePlus.adapterState
              .where((val) => val == BluetoothAdapterState.on)
              .first;

          // Start scanning
          // Guid onekeyServiceGuid = Guid('00000001-0000-1000-8000-00805f9b34fb');
          await FlutterBluePlus.startScan(
            timeout: const Duration(seconds: 3),
            // withServices: [onekeyServiceGuid],
          );
          // Wait for the scan to complete
          await Future.delayed(const Duration(seconds: 3));

          // Stop scanning
          FlutterBluePlus.stopScan();
          await subscription.cancel();
          print(devicesList);
          String jsonStr =
              jsonEncode(devicesList.map((obj) => obj.toJson()).toList());
          return jsonStr;
        },
        // 版本名称
        "send": (data) async {
          print("<<<< ====== send");
          print(data['data']);

          print(hexStringToIntList(data['data']));
          await writeCharacteristic?.write(hexStringToIntList(data['data']));
          return true;
        },
        //是否是App
        "connect": (data) async {
          print("<<<< ====== connect");
          print(data['uuid']);

          return await connectToDevice(targetUuid: data['uuid']);
        },
        //测试获取Web的值
        "disconnect": (data) async {
          return true;
        }
      };
}
