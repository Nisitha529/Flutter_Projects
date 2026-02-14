import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Detection',
      theme: ThemeData(primarySwatch: Colors.yellow),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pose Detection')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LivePoseScreen()),
                );
              },
              child: const Text('Real‑time Pose Detection'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaticPoseScreen()),
                );
              },
              child: const Text('Single Image Pose Detection'),
            ),
          ],
        ),
      ),
    );
  }
}

class LivePoseScreen extends StatefulWidget {
  const LivePoseScreen({Key? key}) : super(key: key);

  @override
  State<LivePoseScreen> createState() => _LivePoseScreenState();
}

class _LivePoseScreenState extends State<LivePoseScreen> {
  CameraController? _controller;
  bool _isBusy = false;
  PoseDetector? _poseDetector;
  List<Pose> _poses = [];
  CameraImage? _latestImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    _controller = CameraController(_cameras[0], ResolutionPreset.medium);

    await _controller!.initialize();
    if (!mounted) return;

    _controller!.startImageStream((image) {
      if (!_isBusy) {
        _isBusy = true;
        _latestImage = image;
        _detectPose();
      }
    });

    setState(() {});
  }

  Future<void> _detectPose() async {
    final inputImage = _inputImageFromCamera();
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    final poses = await _poseDetector!.processImage(inputImage);
    setState(() {
      _poses = poses;
    });
    _isBusy = false;
  }

  InputImage? _inputImageFromCamera() {
    if (_latestImage == null) return null;

    final camera = _cameras[0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
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

    final format = InputImageFormatValue.fromRawValue(_latestImage!.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (_latestImage!.planes.length != 1) return null;
    final plane = _latestImage!.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(
          _latestImage!.width.toDouble(),
          _latestImage!.height.toDouble(),
        ),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Widget _buildResults() {
    if (_poses.isEmpty ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final Size imageSize = Size(
      _controller!.value.previewSize!.height,
      _controller!.value.previewSize!.width,
    );

    return CustomPaint(painter: LivePosePainter(imageSize, _poses));
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real‑time Pose'),
        backgroundColor: Colors.yellow,
      ),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),
                Positioned.fill(child: _buildResults()),
              ],
            ),
    );
  }
}

/// Custom painter for live pose (overlay on camera preview)
class LivePosePainter extends CustomPainter {
  final Size imageSize;
  final List<Pose> poses;

  LivePosePainter(this.imageSize, this.poses);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final leftPaint = paint..color = Colors.yellow;
    final rightPaint = paint..color = Colors.blueAccent;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(landmark.x * scaleX, landmark.y * scaleY),
          3,
          paint..color = Colors.green,
        );
      });

      void paintLine(PoseLandmarkType t1, PoseLandmarkType t2, Paint p) {
        final l1 = pose.landmarks[t1];
        final l2 = pose.landmarks[t2];
        if (l1 != null && l2 != null) {
          canvas.drawLine(
            Offset(l1.x * scaleX, l1.y * scaleY),
            Offset(l2.x * scaleX, l2.y * scaleY),
            p,
          );
        }
      }

      // Arms
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

      // Body
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

      // Legs
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
  bool shouldRepaint(LivePosePainter oldDelegate) => oldDelegate.poses != poses;
}

class StaticPoseScreen extends StatefulWidget {
  const StaticPoseScreen({Key? key}) : super(key: key);

  @override
  State<StaticPoseScreen> createState() => _StaticPoseScreenState();
}

class _StaticPoseScreenState extends State<StaticPoseScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  ui.Image? _decodedImage;
  List<Pose> _poses = [];
  PoseDetector? _poseDetector;

  @override
  void initState() {
    super.initState();
    _initDetector();
  }

  Future<void> _initDetector() async {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _poses = [];
        _decodedImage = null;
      });
      _detectPose();
    }
  }

  Future<void> _detectPose() async {
    if (_imageFile == null || _poseDetector == null) return;

    final inputImage = InputImage.fromFile(_imageFile!);
    final poses = await _poseDetector!.processImage(inputImage);

    final bytes = await _imageFile!.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    setState(() {
      _poses = poses;
      _decodedImage = image;
    });
  }

  @override
  void dispose() {
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Single Image Pose'),
        backgroundColor: Colors.yellow,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  onLongPress: () => _pickImage(ImageSource.camera),
                  child: Container(
                    width: 350,
                    height: 350,
                    color: _decodedImage == null ? Colors.indigo : null,
                    child: _decodedImage != null
                        ? FittedBox(
                      child: SizedBox(
                        width: _decodedImage!.width.toDouble(),
                        height: _decodedImage!.height.toDouble(),
                        child: CustomPaint(
                          painter: StaticPosePainter(
                            image: _decodedImage!,
                            poses: _poses,
                          ),
                        ),
                      ),
                    )
                        : const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 53,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _poses.isEmpty
                  ? 'Tap to select an image'
                  : '${_poses.length} pose(s) detected',
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class StaticPosePainter extends CustomPainter {
  final ui.Image image;
  final List<Pose> poses;

  StaticPosePainter({required this.image, required this.poses});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final leftPaint = paint..color = Colors.yellow;
    final rightPaint = paint..color = Colors.blueAccent;

    for (final pose in poses) {
      // Landmarks as circles
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(landmark.x, landmark.y),
          3,
          paint..color = Colors.green,
        );
      });

      void paintLine(PoseLandmarkType t1, PoseLandmarkType t2, Paint p) {
        final l1 = pose.landmarks[t1];
        final l2 = pose.landmarks[t2];
        if (l1 != null && l2 != null) {
          canvas.drawLine(
            Offset(l1.x, l1.y),
            Offset(l2.x, l2.y),
            p,
          );
        }
      }

      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);

      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
    }
  }

  @override
  bool shouldRepaint(StaticPosePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.poses != poses;
}

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({Key? key, required this.title}) : super(key: key);
//   final String title;
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   dynamic controller;
//   bool isBusy = false;
//   late Size size;
//
//   late ImagePicker imagePicker;
//   File? _image;
//
//   String result = '';
//   ui.Image? image; //var image;
//   late List<Pose> poses;
//
//   dynamic poseDetector;
//
//   @override
//   void initState() {
//     super.initState();
//     imagePicker = ImagePicker();
//     initializeCamera();
//   }
//
//   initializeCamera() async {
//     final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
//     poseDetector = PoseDetector(options: options);
//
//     controller = CameraController(cameras[0], ResolutionPreset.high);
//     await controller.initialize().then((_) {
//       if (!mounted) {
//         return;
//       }
//       controller.startImageStream(
//         (image) => {
//           if (!isBusy) {isBusy = true, img = image, doPoseEstimationOnFrame()},
//         },
//       );
//     });
//   }
//
//   @override
//   void dispose() {
//     controller?.dispose();
//     poseDetector.close();
//     super.dispose();
//   }
//
//   dynamic _scanResults;
//   CameraImage? img;
//
//   doPoseEstimationOnFrame() async {
//     var inputImage = getInputImage();
//
//     final List<Pose> poses = await poseDetector.processImage(inputImage);
//
//     _scanResults = poses;
//
//     for (Pose pose in poses) {
//       pose.landmarks.forEach((_, landmark) {
//         final type = landmark.type;
//         final x = landmark.x;
//         final y = landmark.y;
//
//         print("${type.name} $x  $y");
//       });
//
//       final landmark = pose.landmarks[PoseLandmarkType.nose];
//     }
//
//     setState(() {
//       _scanResults;
//       isBusy = false;
//     });
//   }
//
//   final _orientations = {
//     DeviceOrientation.portraitUp: 0,
//     DeviceOrientation.landscapeLeft: 90,
//     DeviceOrientation.portraitDown: 180,
//     DeviceOrientation.landscapeRight: 270,
//   };
//
//   InputImage? getInputImage() {
//     final camera = cameras[1];
//     final sensorOrientation = camera.sensorOrientation;
//     InputImageRotation? rotation;
//
//     if (Platform.isIOS) {
//       rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
//     } else if (Platform.isAndroid) {
//       var rotationCompensation =
//           _orientations[controller!.value.deviceOrientation];
//       if (rotationCompensation == null) return null;
//       if (camera.lensDirection == CameraLensDirection.front) {
//         // front-facing
//         rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
//       } else {
//         // back-facing
//         rotationCompensation =
//             (sensorOrientation - rotationCompensation + 360) % 360;
//       }
//       rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
//     }
//
//     if (rotation == null) return null;
//
//     final format = InputImageFormatValue.fromRawValue(img!.format.raw);
//
//     if (format == null ||
//         (Platform.isAndroid && format != InputImageFormat.nv21) ||
//         (Platform.isIOS && format != InputImageFormat.bgra8888))
//       return null;
//
//     if (img?.planes.length != 1) return null;
//
//     final plane = img?.planes.first;
//
//     return InputImage.fromBytes(
//       bytes: plane!.bytes,
//       metadata: InputImageMetadata(
//         size: Size(img!.width.toDouble(), img!.height.toDouble()),
//         rotation: rotation, // used only in Android
//         format: format, // used only in iOS
//         bytesPerRow: plane.bytesPerRow, // used only in iOS
//       ),
//     );
//   }
//
//   //Show rectangles around detected objects
//   Widget buildResult() {
//     if (_scanResults == null ||
//         controller == null ||
//         !controller.value.isInitialized) {
//       return Text('');
//     }
//
//     final Size imageSize = Size(
//       controller.value.previewSize!.height,
//       controller.value.previewSize!.width,
//     );
//     CustomPainter painter = PosePainter(imageSize as List<Pose>, _scanResults);
//     return CustomPaint(
//       painter: painter,
//     );
//   }
//
//   Future<void> _imgFromCamera() async {
//     final XFile? pickedFile = await imagePicker.pickImage(
//       source: ImageSource.camera,
//     );
//     if (pickedFile != null) {
//       _image = File(pickedFile.path);
//       await doPoseDetection();
//     }
//   }
//
//   //TODO choose image using gallery
//   Future<void> _imgFromGallery() async {
//     final XFile? pickedFile = await imagePicker.pickImage(
//       source: ImageSource.gallery,
//     );
//     if (pickedFile != null) {
//       _image = File(pickedFile.path);
//       await doPoseDetection();
//     }
//   }
//
//   Future<void> doPoseDetection() async {
//     InputImage inputImage = InputImage.fromFile(_image!);
//     poses = await poseDetector.processImage(inputImage);
//
//     for (Pose pose in poses) {
//       pose.landmarks.forEach((_, landmark) {
//         final type = landmark.type;
//         final x = landmark.x;
//         final y = landmark.y;
//
//         print("${type.name}  $x  $y");
//       });
//
//       final landmark = pose.landmarks[PoseLandmarkType.nose];
//     }
//     setState(() {
//       _image;
//     });
//
//     drawPose();
//   }
//
//   // //TODO draw pose
//   Future<void> drawPose() async {
//     final bytes = await _image!
//         .readAsBytes(); //image = await _image?.readAsBytes();
//     image = await decodeImageFromList(
//       bytes,
//     ); // image = await decodeImageFromList(image);
//     setState(() {
//       image;
//       poses;
//       result;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     List<Widget> stackChildren = [];
//     size = MediaQuery.of(context).size;
//     if (controller != null) {
//       stackChildren.add(
//         Positioned(
//           top: 0.0,
//           left: 0.0,
//           width: size.width,
//           height: size.height,
//           child: Container(
//             child: (controller.value.isInitialized)
//                 ? AspectRatio(
//                     aspectRatio: controller.value.aspectRatio,
//                     child: CameraPreview(controller),
//                   )
//                 : Container(),
//           ),
//         ),
//       );
//
//       stackChildren.add(
//         Positioned(
//             top: 0.0,
//             left: 0.0,
//             width: size.width,
//             height: size.height,
//             child: buildResult()),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           "Pose Estimation",
//           style: TextStyle(color: Colors.black),
//         ),
//         backgroundColor: Colors.yellow,
//       ),
//       backgroundColor: Colors.black,
//       body: Container(
//         margin: const EdgeInsets.only(top: 0),
//         color: Colors.black,
//         child: Stack(children: stackChildren),
//       ),
//     );
//   }
// }

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

// class PosePainter extends CustomPainter {
//   PosePainter(this.poses, this.imageFile);
//
//   final List<Pose> poses;
//   var imageFile;
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (imageFile != null) {
//       canvas.drawImage(imageFile, Offset.zero, Paint());
//     }
//     final paint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4.0
//       ..color = Colors.green;
//
//     final leftPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3.0
//       ..color = Colors.yellow;
//
//     final rightPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3.0
//       ..color = Colors.blueAccent;
//
//     for (final pose in poses) {
//       pose.landmarks.forEach((_, landmark) {
//         canvas.drawCircle(Offset(landmark.x, landmark.y), 1, paint);
//       });
//
//       void paintLine(
//         PoseLandmarkType type1,
//         PoseLandmarkType type2,
//         Paint paintType,
//       ) {
//         final PoseLandmark joint1 = pose.landmarks[type1]!;
//         final PoseLandmark joint2 = pose.landmarks[type2]!;
//         canvas.drawLine(
//           Offset(joint1.x, joint1.y),
//           Offset(joint2.x, joint2.y),
//           paintType,
//         );
//       }
//
//       //Draw arms
//       paintLine(
//         PoseLandmarkType.leftShoulder,
//         PoseLandmarkType.leftElbow,
//         leftPaint,
//       );
//       paintLine(
//         PoseLandmarkType.leftElbow,
//         PoseLandmarkType.leftWrist,
//         leftPaint,
//       );
//       paintLine(
//         PoseLandmarkType.rightShoulder,
//         PoseLandmarkType.rightElbow,
//         rightPaint,
//       );
//       paintLine(
//         PoseLandmarkType.rightElbow,
//         PoseLandmarkType.rightWrist,
//         rightPaint,
//       );
//
//       //Draw Body
//       paintLine(
//         PoseLandmarkType.leftShoulder,
//         PoseLandmarkType.leftHip,
//         leftPaint,
//       );
//       paintLine(
//         PoseLandmarkType.rightShoulder,
//         PoseLandmarkType.rightHip,
//         rightPaint,
//       );
//
//       //Draw legs
//       paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
//
//       paintLine(
//         PoseLandmarkType.leftKnee,
//         PoseLandmarkType.leftAnkle,
//         leftPaint,
//       );
//       paintLine(
//         PoseLandmarkType.rightHip,
//         PoseLandmarkType.rightKnee,
//         rightPaint,
//       );
//       paintLine(
//         PoseLandmarkType.rightKnee,
//         PoseLandmarkType.rightAnkle,
//         rightPaint,
//       );
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant PosePainter oldDelegate) {
//     return oldDelegate.poses != poses;
//   }
// }
