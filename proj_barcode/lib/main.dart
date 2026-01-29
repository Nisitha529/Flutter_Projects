import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';

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

  // dynamic barcodeScanner;
  late BarcodeScanner barcodeScanner;

  late ImagePicker _imagePicker;
  File? pickedImage;
  bool useLiveCamera = true;

  @override
  void initState() {
    super.initState();

    // Init Scanner
    final List<BarcodeFormat> formats = [BarcodeFormat.all];
    barcodeScanner = BarcodeScanner(formats: formats);

    // Init Image Picker
    _imagePicker = ImagePicker();

    // Init Camera
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
            if (useLiveCamera && !isBusy) {
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

  // doBarCodeScanning() async {
  //   result = "";
  //   InputImage? inputImg = getInputImage();
  //   final List<Barcode> barcodes = await barcodeScanner.processImage(inputImg);
  //
  //   for (Barcode barcode in barcodes) {
  //     final BarcodeType type = barcode.type;
  //     final Rect? boundingbox = barcode.boundingBox;
  //     final String? displayValue = barcode.displayValue;
  //     final String? rawValue = barcode.rawValue;
  //
  //     switch (type) {
  //       case BarcodeType.wifi:
  //         BarcodeWifi? barcodeWifi = barcode.value as BarcodeWifi?;
  //         if (barcodeWifi != null) {
  //           result = "WiFi : ${barcodeWifi.password!}";
  //         }
  //         break;
  //
  //       case BarcodeType.url:
  //         BarcodeUrl? barcodeUrl = barcode.value as BarcodeUrl;
  //
  //         result = "URL : ${barcodeUrl.url!}";
  //         break;
  //
  //       case BarcodeType.unknown:
  //       // TODO: Handle this case.
  //       case BarcodeType.contactInfo:
  //       // TODO: Handle this case.
  //       case BarcodeType.email:
  //       // TODO: Handle this case.
  //       case BarcodeType.isbn:
  //       // TODO: Handle this case.
  //       case BarcodeType.phone:
  //       // TODO: Handle this case.
  //       case BarcodeType.product:
  //       // TODO: Handle this case.
  //       case BarcodeType.sms:
  //       // TODO: Handle this case.
  //       case BarcodeType.text:
  //       // TODO: Handle this case.
  //       case BarcodeType.geoCoordinates:
  //       // TODO: Handle this case.
  //       case BarcodeType.calendarEvent:
  //       // TODO: Handle this case.
  //       case BarcodeType.driverLicense:
  //       // TODO: Handle this case.
  //     }
  //   }
  //   setState(() {
  //     result;
  //     isBusy = false;
  //   });
  // }

  Future<void> doBarCodeScanning() async {
    if (!useLiveCamera || img == null) {
      isBusy = false;
      return;
    }

    final inputImg = getInputImage();
    if (inputImg == null) {
      isBusy = false;
      return;
    }

    final List<Barcode> barcodes = await barcodeScanner.processImage(inputImg);

    for (final barcode in barcodes) {
      final displayValue = barcode.displayValue ?? "Unknown";

      result = displayValue;
    }

    setState(() {
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
    if (img == null) return null;

    final camera = _cameras[0];
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
    } else {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
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

  Future <void> pickFromCamera() async {
    final XFile? file = await _imagePicker.pickImage(source: ImageSource.camera);

    if (file ==null) return;

    pickedImage = File(file.path);
    useLiveCamera = false;
    await scanImageFile(pickedImage!);
  }

  Future <void> pickFromGallery() async {
    final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    pickedImage = File(file.path);
    useLiveCamera = false;
    await scanImageFile(pickedImage!);
  }

  Future <void> scanImageFile (File image) async {
    result = "";

    final inputImage = InputImage.fromFile(image);
    final List<Barcode> barcodes = await barcodeScanner.processImage(inputImage);

    for (final barcode in barcodes) {
      result = barcode.displayValue ?? "No Value found";
    }

    setState(() {   });
  }

  @override
  void dispose() {
    controller.dispose();
    barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) return const SizedBox();

    return MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Preview
            useLiveCamera
                ? CameraPreview(controller)
                : pickedImage != null
                ? Image.file(pickedImage!, fit: BoxFit.cover)
                : Container(),

            // Result
            Positioned(
              bottom: 120,
              left: 10,
              right: 10,
              child: Text(
                result,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  backgroundColor: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Buttons
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: "gallery",
                    onPressed: pickFromGallery,
                    child: const Icon(Icons.photo),
                  ),
                  FloatingActionButton(
                    heroTag: "camera",
                    onPressed: pickFromCamera,
                    child: const Icon(Icons.camera_alt),
                  ),
                  FloatingActionButton(
                    heroTag: "live",
                    onPressed: () {
                      setState(() {
                        useLiveCamera = true;
                        result = "";
                      });
                    },
                    child: const Icon(Icons.videocam),
                  ),
                ],
              ),
            ),
          ],
        ),
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
