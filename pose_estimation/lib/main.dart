import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHomePage(title: 'screen'));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  dynamic controller;
  bool isBusy = false;
  late Size size;

  late ImagePicker imagePicker;
  File? _image;

  String result = '';
  ui.Image? image; //var image;
  late List<Pose> poses;

  dynamic poseDetector;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    initializeCamera();
  }

  initializeCamera() async {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    poseDetector = PoseDetector(options: options);

    controller = CameraController(cameras[0], ResolutionPreset.high);
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream(
        (image) => {
          if (!isBusy) {isBusy = true, img = image, doPoseEstimationOnFrame()},
        },
      );
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    super.dispose();
  }

  dynamic _scanResults;
  CameraImage? img;

  doPoseEstimationOnFrame() async {
    var inputImage = getInputImage();

    final List<Pose> poses = await poseDetector.processImage(inputImage);

    _scanResults = poses;

    for (Pose pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        final type = landmark.type;
        final x = landmark.x;
        final y = landmark.y;

        print("${type.name} $x  $y");
      });

      final landmark = pose.landmarks[PoseLandmarkType.nose];
    }

    setState(() {
      _scanResults;
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
    final camera = cameras[1];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(img!.format.raw);

    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888))
      return null;

    if (img?.planes.length != 1) return null;

    final plane = img?.planes.first;

    return InputImage.fromBytes(
      bytes: plane!.bytes,
      metadata: InputImageMetadata(
        size: Size(img!.width.toDouble(), img!.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  //Show rectangles around detected objects
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Text('');
    }

    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = PosePainter(imageSize as List<Pose>, _scanResults);
    return CustomPaint(
      painter: painter,
    );
  }

  Future<void> _imgFromCamera() async {
    final XFile? pickedFile = await imagePicker.pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null) {
      _image = File(pickedFile.path);
      await doPoseDetection();
    }
  }

  //TODO choose image using gallery
  Future<void> _imgFromGallery() async {
    final XFile? pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      _image = File(pickedFile.path);
      await doPoseDetection();
    }
  }

  Future<void> doPoseDetection() async {
    InputImage inputImage = InputImage.fromFile(_image!);
    poses = await poseDetector.processImage(inputImage);

    for (Pose pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        final type = landmark.type;
        final x = landmark.x;
        final y = landmark.y;

        print("${type.name}  $x  $y");
      });

      final landmark = pose.landmarks[PoseLandmarkType.nose];
    }
    setState(() {
      _image;
    });

    drawPose();
  }

  // //TODO draw pose
  Future<void> drawPose() async {
    final bytes = await _image!
        .readAsBytes(); //image = await _image?.readAsBytes();
    image = await decodeImageFromList(
      bytes,
    ); // image = await decodeImageFromList(image);
    setState(() {
      image;
      poses;
      result;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if (controller != null) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: Container(
            child: (controller.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  )
                : Container(),
          ),
        ),
      );

      stackChildren.add(
        Positioned(
            top: 0.0,
            left: 0.0,
            width: size.width,
            height: size.height,
            child: buildResult()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pose Estimation",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.yellow,
      ),
      backgroundColor: Colors.black,
      body: Container(
        margin: const EdgeInsets.only(top: 0),
        color: Colors.black,
        child: Stack(children: stackChildren),
      ),
    );
  }
}

//   @override
//   Widget build(BuildContext context) {
//     // TODO: implement build
//     return MaterialApp(
//       home: Scaffold(
//         body: Container(
//           decoration: const BoxDecoration(
//             image: DecorationImage(
//               image: AssetImage('images/bg.jpg'),
//               fit: BoxFit.cover,
//             ),
//           ),
//           child: Column(
//             children: [
//               const SizedBox(width: 100),
//               Container(
//                 margin: const EdgeInsets.only(top: 100),
//                 child: Stack(
//                   children: <Widget>[
//                     Center(
//                       child: ElevatedButton(
//                         onPressed: _imgFromGallery,
//                         onLongPress: _imgFromCamera,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.transparent,
//                           shadowColor: Colors.transparent,
//                         ),
//                         child:
//                             // Container(
//                             //   margin: const EdgeInsets.only(top: 8),
//                             //   child: _image != null
//                             //       ? Image.file(
//                             //           _image!,
//                             //           width: 350,
//                             //           height: 350,
//                             //           fit: BoxFit.fill,
//                             //         )
//                             //       : Container(
//                             //           width: 350,
//                             //           height: 350,
//                             //           color: Colors.indigo,
//                             //           child: const Icon(
//                             //             Icons.camera_alt,
//                             //             color: Colors.white,
//                             //             size: 100,
//                             //           ),
//                             //         ),
//                             // ),
//                             Container(
//                               child: image != null
//                                   ? Center(
//                                       child: FittedBox(
//                                         child: SizedBox(
//                                           width: image!.width.toDouble(),
//                                           height: image!.height.toDouble(),
//                                           child: CustomPaint(
//                                             painter: PosePainter(poses, image),
//                                           ),
//                                         ),
//                                       ),
//                                     )
//                                   : Container(
//                                       color: Colors.indigo,
//                                       width: 350,
//                                       height: 350,
//                                       child: const Icon(
//                                         Icons.camera_alt,
//                                         color: Colors.white,
//                                         size: 53,
//                                       ),
//                                     ),
//                             ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

class PosePainter extends CustomPainter {
  PosePainter(this.poses, this.imageFile);

  final List<Pose> poses;
  var imageFile;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageFile != null) {
      canvas.drawImage(imageFile, Offset.zero, Paint());
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.green;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(Offset(landmark.x, landmark.y), 1, paint);
      });

      void paintLine(
        PoseLandmarkType type1,
        PoseLandmarkType type2,
        Paint paintType,
      ) {
        final PoseLandmark joint1 = pose.landmarks[type1]!;
        final PoseLandmark joint2 = pose.landmarks[type2]!;
        canvas.drawLine(
          Offset(joint1.x, joint1.y),
          Offset(joint2.x, joint2.y),
          paintType,
        );
      }

      //Draw arms
      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        rightPaint,
      );
      paintLine(
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
        rightPaint,
      );

      //Draw Body
      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip,
        rightPaint,
      );

      //Draw legs
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);

      paintLine(
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        rightPaint,
      );
      paintLine(
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
        rightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses;
  }
}
