import 'package:flutter/material.dart';
import 'package:smart_door/main.dart';
import 'package:smart_door/screens/camera.dart';

import 'dashboard.dart';

// class PagePesanan extends StatefulWidget {
//   const PagePesanan({super.key});

//   @override
//   State<PagePesanan> createState() => _PagePesananState();
// }

// class _PagePesananState extends State<PagePesanan> {
//   var mytabIndex = 0;

//   List<Widget> tabList = [
//     TabPesanan(),
//     TabSelesai(),
//     TabPengantaran()
//   ]

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 3,
//       initialIndex: mytabIndex,
//       child: Scaffold(
//         appBar: AppBar(
//           bottom: TabBar(tabs: [
//             ...TIDAK BERUBAH...
//           ], onTap: (value){
//             setState(() {
//               mytabIndex = value;
//             });
//           },),
//         ),
//         body: TabBarView(
//           children: tabList,
//         ),
//       ),
//     );
//   }
// }

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  var myIndex = 0;

  List<Widget> pageList = [MqttSubscriber(), MQTTClient()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: pageList[myIndex],
        bottomNavigationBar: BottomNavigationBar(
          onTap: (value) {
            setState(() {
              myIndex = value;
            });
          },
          currentIndex: myIndex,
          items: [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt), label: 'ESP CAM'),
          ],
        ));
  }
}
