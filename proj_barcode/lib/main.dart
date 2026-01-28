import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

late List<CameraDescription> _cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const CameraScreen());
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  CameraImage? img;
  bool isBusy = false;
  String result = "Results will be shown.";

  dynamic barcodeScanner;

  @override
  void initState() {
    super.initState();

    final List<BarcodeFormat> formats = [BarcodeFormat.all];
    barcodeScanner = BarcodeScanner(formats: formats);

    controller = CameraController(
      _cameras[0],
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup
                .nv21 // for Android
          : ImageFormatGroup.bgra8888,
    );
    controller
        .initialize()
        .then((_) {
          if (!mounted) {
            return;
          }
          controller.startImageStream((image) {
            if (!isBusy) {
              isBusy = true;
              img = image;
              doBarCodeScanning();
            }
          });
          setState(() {});
        })
        .catchError((Object e) {
          if (e is CameraException) {
            switch (e.code) {
              case 'CameraAccessDenied':
                print('User denied camera access.');
                break;
              default:
                print('Handle other errors.');
                break;
            }
          }
        });
  }

  doBarCodeScanning() async {
    result = "";
    InputImage? inputImg = getInputImage();
    final List<Barcode> barcodes = await barcodeScanner.processImage(inputImg);

    for (Barcode barcode in barcodes) {
      final BarcodeType type = barcode.type;
      final Rect? boundingbox = barcode.boundingBox;
      final String? displayValue = barcode.displayValue;
      final String? rawValue = barcode.rawValue;

      switch (type) {
        case BarcodeType.wifi:
          BarcodeWifi? barcodeWifi = barcode.value as BarcodeWifi?;
          if (barcodeWifi != null) {
            result = "WiFi : ${barcodeWifi.password!}";
          }
          break;

        case BarcodeType.url:
          BarcodeUrl? barcodeUrl = barcode.value as BarcodeUrl;

          result = "URL : ${barcodeUrl.url!}";
          break;

        case BarcodeType.unknown:
        // TODO: Handle this case.
        case BarcodeType.contactInfo:
        // TODO: Handle this case.
        case BarcodeType.email:
        // TODO: Handle this case.
        case BarcodeType.isbn:
        // TODO: Handle this case.
        case BarcodeType.phone:
        // TODO: Handle this case.
        case BarcodeType.product:
        // TODO: Handle this case.
        case BarcodeType.sms:
        // TODO: Handle this case.
        case BarcodeType.text:
        // TODO: Handle this case.
        case BarcodeType.geoCoordinates:
        // TODO: Handle this case.
        case BarcodeType.calendarEvent:
        // TODO: Handle this case.
        case BarcodeType.driverLicense:
        // TODO: Handle this case.
      }
    }
    setState(() {
      result;
      isBusy = false;
    });
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? getInputImage() {
    final camera = _cameras[1];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller.value.deviceOrientation];

      if (rotationCompensation == null) return null;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }

      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(img!.format.raw);

    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (img?.planes.length != 1) return null;

    final plane = img?.planes.first;

    return InputImage.fromBytes(
      bytes: plane!.bytes,
      metadata: InputImageMetadata(
        size: Size(img!.width.toDouble(), img!.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }

    return MaterialApp(
      home: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 10),

            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                result,
                style: const TextStyle(color: Colors.white, fontSize: 25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
//
//
// void main() {
//   runApp(MyHomePage());
// }
//
// class MyHomePage extends StatefulWidget {
//   const MyHomePage({Key? key}) : super(key: key);
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   late ImagePicker imagePicker;
//   File? _image;
//
//   String result = 'Results will be shown here';
//
//   @override
//   void initState() {
//     super.initState();
//     imagePicker = ImagePicker();
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//   }
//
//   _imgFromCamera() async {
//     XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
//     _image = File(pickedFile!.path);
//     setState(() {
//       _image;
//       doBarcodeScanning();
//     });
//   }
//
//   _imgFromGallery() async {
//     XFile? pickedFile = await imagePicker.pickImage(
//       source: ImageSource.gallery,
//     );
//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//         doBarcodeScanning();
//       });
//     }
//   }
//
//   doBarcodeScanning() async {}
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Container(
//         decoration: const BoxDecoration(
//           image: DecorationImage(
//             image: AssetImage('images/bg.jpg'),
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: Scaffold(
//           body: SingleChildScrollView(
//             child: Column(
//               children: [
//                 const SizedBox(width: 100),
//                 Container(
//                   margin: const EdgeInsets.only(top: 100),
//                   child: Stack(
//                     children: <Widget>[
//                       Stack(
//                         children: <Widget>[
//                           Center(
//                             child: Image.asset(
//                               'images/frame.jpg',
//                               height: 350,
//                               width: 350,
//                             ),
//                           ),
//                         ],
//                       ),
//                       Center(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             shadowColor: Colors.transparent,
//                             backgroundColor: Colors.transparent,
//                           ),
//                           onPressed: _imgFromGallery,
//                           onLongPress: _imgFromCamera,
//
//                           child: Container(
//                             margin: const EdgeInsets.only(top: 12),
//                             child: _image != null
//                                 ? Image.file(
//                                     _image!,
//                                     width: 325,
//                                     height: 325,
//                                     fit: BoxFit.fill,
//                                   )
//                                 : Container(
//                                     width: 340,
//                                     height: 330,
//                                     child: const Icon(
//                                       Icons.camera_alt,
//                                       color: Colors.black,
//                                       size: 100,
//                                     ),
//                                   ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Container(
//                   margin: const EdgeInsets.only(top: 20),
//                   child: Text(
//                     result,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 30,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           backgroundColor: Colors.transparent,
//         ),
//       ),
//     );
//   }
// }
