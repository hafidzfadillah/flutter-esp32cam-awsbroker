import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:http/http.dart' as http;

import '../MqttHandler.dart';

class MqttSubscriber extends StatefulWidget {
  @override
  _MqttSubscriberState createState() => _MqttSubscriberState();
}

class _MqttSubscriberState extends State<MqttSubscriber> {
  MqttHandler mqttHandler = MqttHandler();
  var clientID = 'Android';
  var statusText = 'Waiting for MQTT messages...';
  var sliderbawah = 0.0;
  var slideratas = 10.0;
  var isLock = false;

  final MqttServerClient client = MqttServerClient('broker.hivemq.com', '');

  void createID() async {
    if (Platform.isAndroid) {
      const _androidIdPlugin = AndroidId();
      final String? androidId = await _androidIdPlugin.getId();

      if (Platform.isAndroid) {
        setState(() {
          clientID = androidId!;
          // idTextController.text = clientID;
        });
      } else if (Platform.isIOS) {
        setState(() {
          clientID = "iOS";
          // idTextController.text = clientID;
        });
      }
    }
  }

  void publishServo() async {
    await Future.delayed(Duration(milliseconds: 300));
    var mapData = {
      'servo_bawah': (sliderbawah).round(),
      'servo_atas': (slideratas).round()
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(mapData.toString());

    client.publishMessage(
        'SERVO_SUBSCRIBE_TOPIC', MqttQos.atLeastOnce, builder.payload!);
    Fluttertoast.showToast(msg: 'Panning camera..');
    // setState(() {});
  }

  void publishLock() async {
    await Future.delayed(Duration(milliseconds: 300));
    var mapData = {
      'lock_status': isLock ? 1 : 0,
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(mapData.toString());

    client.publishMessage(
        'LOCK_SUBSCRIBE_TOPIC', MqttQos.atLeastOnce, builder.payload!);
    Fluttertoast.showToast(
        msg: 'Bypassing selenoid lock [${isLock ? 'Locking' : 'Opening'}]');

    pushDataLock();
    // setState(() {});
  }

  Future<void> getLockStatus() async {
    final Uri apiUrl = Uri.parse(
        'https://iot-smart-coor-c7780434f6de.herokuapp.com/api/log-lock');

    // Replace this with your actual data to be sent in the request body
    // Map<String, dynamic> requestData = {
    //   'lock_status': isLock ? '1' : '0',
    //   'rfid_number': rfid ?? "-",
    // };

    try {
      final response = await http.get(
        apiUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        // body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        // Successful response
        print('Response: ${response.body}');
        var parse = json.decode(response.body);
        var lastLock = parse['data'][parse.length - 1]['lock_status'];

        setState(() {
          isLock = lastLock == '0';
        });
      } else {
        // Error in the response
        print('Error: ${response.statusCode}, ${response.reasonPhrase}');
        print('Response: ${response.body}');
      }
    } catch (error) {
      // Exception during the HTTP request
      print('Error: $error');
    }
  }

  Future<void> pushDataLock({String? status, String? rfid}) async {
    final Uri apiUrl = Uri.parse(
        'https://iot-smart-coor-c7780434f6de.herokuapp.com/api/log-lock');

    var stat = isLock ? '1' : '0';
    // if (status != null) {
    //   stat = status.contains('Granted') ? '0' : '1';
    //   // setState(() {
    //   isLock = stat == '1';
    //   // });
    // }
    // print('STATUS: $status');
    // print('LOCK:$isLock');

    // Replace this with your actual data to be sent in the request body
    Map<String, dynamic> requestData = {
      'lock_status': stat,
      'rfid_number': rfid ?? "-",
    };

    try {
      final response = await http.post(
        apiUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestData),
      );

      if (response.statusCode == 201) {
        // Successful response
        print('Response: ${response.body}');
      } else {
        // Error in the response
        print('Error: ${response.statusCode}, ${response.reasonPhrase}');
        print('Response: ${response.body}');
      }
    } catch (error) {
      // Exception during the HTTP request
      print('Error: $error');
    }
  }

  Future<void> pushDataRfid({String? rfid}) async {
    final Uri apiUrl =
        Uri.parse('https://4b44-110-136-128-210.ngrok-free.app/api/log-rfid');

    // Replace this with your actual data to be sent in the request body
    Map<String, dynamic> requestData = {
      'lock_status': isLock ? '1' : '0',
      'rfid_number': rfid ?? "-",
    };

    try {
      final response = await http.post(
        apiUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        // Successful response
        print('Response: ${response.body}');
      } else {
        // Error in the response
        print('Error: ${response.statusCode}, ${response.reasonPhrase}');
        print('Response: ${response.body}');
      }
    } catch (error) {
      // Exception during the HTTP request
      print('Error: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    createID();
    mqttHandler.connect();
    _connect();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MQTT Subscriber'),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Lock Door')),
              Switch(
                value: isLock,
                onChanged: (value) {
                  setState(() {
                    isLock = value;
                  });
                  publishLock();
                },
              ),
            ],
          ),
          Text('Servo Bawah'),
          Slider(
            value: sliderbawah,
            min: 0,
            max: 179,
            onChanged: (value) {
              setState(() {
                sliderbawah = value;
              });
              publishServo();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Kanan'), Text('Kiri')],
          ),
          SizedBox(
            height: 16,
          ),
          Text('Servo Atas'),
          Slider(
            value: slideratas,
            min: 10,
            max: 149,
            onChanged: (value) {
              setState(() {
                slideratas = value;
              });
              publishServo();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Atas'), Text('Bawah')],
          ),
          SizedBox(
            height: 16,
          ),
          Center(
            child: ValueListenableBuilder<String>(
              builder: (BuildContext context, String value, Widget? child) {
                if (value.isEmpty) {
                  return CircularProgressIndicator();
                }
                var parse = json.decode(value);

                pushDataLock(rfid: parse['uid'], status: parse['status']);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Text(
                        'Attempt From: ${parse['uid']}\nStatus: ${parse['status']}',
                        maxLines: 10,
                        style: TextStyle(color: Colors.white, fontSize: 20))
                  ],
                );
              },
              valueListenable: mqttHandler.data,
            ),
          ),
        ],
      ),
    );
  }

  _connect() async {
    // if (idTextController.text.trim().isNotEmpty) {
    // ProgressDialog progressDialog = ProgressDialog(context,
    //     blur: 0,
    //     dialogTransitionType: DialogTransitionType.Shrink,
    //     dismissable: false);
    // progressDialog.setLoadingWidget(CircularProgressIndicator(
    //   valueColor: AlwaysStoppedAnimation(Colors.red),
    // ));
    // progressDialog
    //     .setMessage(Text("Please Wait, Connecting to IoT MQTT Broker"));
    // progressDialog.setTitle(Text("Connecting"));
    // progressDialog.show();

    await mqttConnect(clientID.trim());
    // progressDialog.dismiss();
    // }
  }

  //AYUDA A LA CONEXION ASINCRONA Y EL BOOL PARA SABER SI LA CONEXION FUE EXITOSA
  Future<bool> mqttConnect(String uniqueId) async {
    setStatus("Connecting MQTT Browser");
    // ByteData rootCA = await rootBundle.load('assets/certs/RootCA.pem');
    // ByteData deviceCert =
    //     await rootBundle.load('assets/certs/DeviceCertificate.crt');
    // ByteData privateKey = await rootBundle.load('assets/certs/Private.key');

    // SecurityContext context = SecurityContext.defaultContext;
    // context.setClientAuthoritiesBytes(rootCA.buffer.asUint8List());
    // context.useCertificateChainBytes(deviceCert.buffer.asUint8List());
    // context.usePrivateKeyBytes(privateKey.buffer.asUint8List());

    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.port = 1883;
    client.secure = false;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.pongCallback = pong;

    final MqttConnectMessage connMess =
        MqttConnectMessage().withClientIdentifier(uniqueId).startClean();
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print('Exception: ' + e.toString());
      client.disconnect();
    }
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print("Connected to MQTT Successfully!");
    } else {
      print("Connected to MQTT Failed!");
      return false;
    }

    return true;
  }

  _disconnect() {
    client.disconnect();
  }

  void setStatus(String content) {
    setState(() {
      statusText = content;
    });
  }

  void onConnected() {
    setStatus("Client connection was successful");
  }

  void onDisconnected() {
    setStatus("Client Disconnected");
    // isConnected = false;
  }

  void pong() {
    print('Ping response client callback invoked');
  }
}
