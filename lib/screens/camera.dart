import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:android_id/android_id.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:ndialog/ndialog.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class MQTTClient extends StatefulWidget {
  const MQTTClient({Key? key}) : super(key: key);

  @override
  _MQTTClientState createState() => _MQTTClientState();
}

class _MQTTClientState extends State<MQTTClient> {
  String statusText = "Status Text";
  bool isConnected = false;
  TextEditingController idTextController = TextEditingController();
  var clientID = 'Android';
  late Uint8List currentFrame;

  final MqttServerClient client = MqttServerClient(
      'a3gp8u25bug8q8-ats.iot.ap-southeast-1.amazonaws.com', '');

  void createID() async {
    if (Platform.isAndroid) {
      const _androidIdPlugin = AndroidId();
      final String? androidId = await _androidIdPlugin.getId();

      if (Platform.isAndroid) {
        setState(() {
          clientID = androidId!;
          idTextController.text = clientID;
        });
      } else if (Platform.isIOS) {
        setState(() {
          clientID = "iOS";
          idTextController.text = clientID;
        });
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    createID();
    _connect();
  }

  @override
  void dispose() {
    idTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    final bool hasShortWidth = width < 600;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header(), body(hasShortWidth), footer()],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.camera_alt_outlined),
          onPressed: () {
            // final builder = MqttClientPayloadBuilder();
            // builder.addString("capture_image");

            // client.publishMessage(
            //     'esp32/cam_command', MqttQos.atLeastOnce, builder.payload!);
            Fluttertoast.showToast(msg: 'Capturing image..');
            postImageToApi(currentFrame);
          }),
    );
  }

  Widget header() {
    return Expanded(
      child: Container(
        child: Text(
          'Door Cam',
          style: TextStyle(
              fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
      flex: 3,
    );
  }

  Widget body(bool hasShortWidth) {
    return Expanded(
      child: Container(
        child: hasShortWidth
            ? Column(
                children: [bodyMenu(), Expanded(child: bodySteam())],
              )
            : Row(
                children: [
                  Expanded(
                    child: bodyMenu(),
                    flex: 2,
                  ),
                  Expanded(
                    child: bodySteam(),
                    flex: 8,
                  )
                ],
              ),
      ),
      flex: 20,
    );
  }

  Widget bodyMenu() {
    return Container(
      color: Colors.black26,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                      enabled: false,
                      controller: idTextController,
                      decoration: InputDecoration(
                        border: UnderlineInputBorder(),
                        labelText: 'MQTT Client Id',
                        labelStyle: TextStyle(fontSize: 10),
                        // suffixIcon: IconButton(
                        //   icon: Icon(Icons.subdirectory_arrow_left),
                        //   onPressed: _connect,
                        // )
                      )),
                ),
                IconButton(
                    onPressed: _connect,
                    icon: Icon(Icons.subdirectory_arrow_left))
              ],
            ),
          ),
          // isConnected
          //     ? TextButton(onPressed: _disconnect, child: Text('Disconnect'))
          //     : Container()
        ],
      ),
    );
  }

  Widget bodySteam() {
    return Container(
      color: Colors.black,
      child: StreamBuilder(
        stream: client.updates,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          else {
            final mqttReceivedMessages =
                snapshot.data as List<MqttReceivedMessage<MqttMessage?>>?;

            final recMess =
                mqttReceivedMessages![0].payload as MqttPublishMessage;

            img.Image jpegImage =
                img.decodeJpg(Uint8List.view(recMess.payload.message.buffer))
                    as img.Image;

            // setState(() {
            currentFrame = img.encodeJpg(jpegImage) as Uint8List;
            // });

            print(
                'img width = ${jpegImage.width}, height = ${jpegImage.height}');
            return Image.memory(
              img.encodeJpg(jpegImage) as Uint8List,
              gaplessPlayback: true,
            );
          }
        },
      ),
    );
  }

  Widget footer() {
    return Expanded(
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          statusText,
          style: TextStyle(
              fontWeight: FontWeight.normal, color: Colors.amberAccent),
        ),
      ),
      flex: 1,
    );
  }

  _connect() async {
    if (idTextController.text.trim().isNotEmpty) {
      ProgressDialog progressDialog = ProgressDialog(context,
          blur: 0,
          dialogTransitionType: DialogTransitionType.Shrink,
          dismissable: false);
      progressDialog.setLoadingWidget(CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(Colors.red),
      ));
      progressDialog
          .setMessage(Text("Please Wait, Connecting to IoT MQTT Broker"));
      progressDialog.setTitle(Text("Connecting"));
      progressDialog.show();

      isConnected = await mqttConnect(idTextController.text.trim());
      progressDialog.dismiss();
    }
  }

  _disconnect() {
    client.disconnect();
  }

  //AYUDA A LA CONEXION ASINCRONA Y EL BOOL PARA SABER SI LA CONEXION FUE EXITOSA
  Future<bool> mqttConnect(String uniqueId) async {
    setStatus("Connecting MQTT Browser");
    ByteData rootCA = await rootBundle.load('assets/certs/RootCA.pem');
    ByteData deviceCert =
        await rootBundle.load('assets/certs/DeviceCertificate.crt');
    ByteData privateKey = await rootBundle.load('assets/certs/Private.key');

    SecurityContext context = SecurityContext.defaultContext;
    context.setClientAuthoritiesBytes(rootCA.buffer.asUint8List());
    context.useCertificateChainBytes(deviceCert.buffer.asUint8List());
    context.usePrivateKeyBytes(privateKey.buffer.asUint8List());

    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.port = 8883;
    client.secure = true;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.pongCallback = pong;

    final MqttConnectMessage connMess =
        MqttConnectMessage().withClientIdentifier(uniqueId).startClean();
    client.connectionMessage = connMess;

    await client.connect();
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print("Connected to AWS Successfully!");
    } else {
      return false;
    }

    const topicSub = 'esp32/cam_0';
    client.subscribe(topicSub, MqttQos.atMostOnce);

    return true;
  }

  Future<void> postImageToApi(Uint8List imageBytes) async {
    try {
      // Convert Uint8List to List<int>
      final List<int> imageList = imageBytes.toList();

      var data = FormData.fromMap({
        'image': [MultipartFile.fromBytes(imageBytes, filename: 'image.jpg')],
        'capture_by': '0987654321'
      });

      var dio = Dio();
      var response = await dio.request(
        'https://iot-smart-coor-c7780434f6de.herokuapp.com/api/log-capture',
        options: Options(method: 'POST', followRedirects: true, headers: {
          'ngrok-skip-browser-warning': 'true',
        }),
        data: data,
      );

      if (response.statusCode == 201) {
        print(json.encode(response.data));
      } else {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text('Oops'),
                  content: Text(
                    response.statusMessage!,
                    maxLines: 5,
                  ),
                ));
        print(response.statusMessage);
      }

      print('Request URL: ${response.realUri}');
      print('Request Headers: ${response.requestOptions.headers}');
      print('Response Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.data}');

      // Handle the response
      print('Response: ${response.statusCode}, ${response.data}');

      // // Create a multipart request
      // var request = http.MultipartRequest('POST', apiUrl);

      // // Add the image as a file to the request
      // request.files.add(http.MultipartFile.fromBytes(
      //   'image',
      //   imageBytes,
      //   filename: 'image.jpg', // You can change the filename as needed
      //   // contentType: http.MediaType('image', 'jpeg'), // Adjust the content type
      // ));

      // // Send the request
      // final response = await request.send();

      // // Check the response
      if (response.statusCode == 201) {
        print('Image uploaded successfully');
        Fluttertoast.showToast(msg: 'Upload success');
      } else {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text('Oops'),
                  content: Text(response.data),
                ));
        print('Image upload failed with status: ${response.statusCode}');
      }
    } catch (error) {
      print('Error uploading image: $error');
    }
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
    isConnected = false;
  }

  void pong() {
    print('Ping response client callback invoked');
  }
}
