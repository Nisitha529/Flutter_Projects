import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Global list of available cameras (initialized in main)
late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Get available cameras
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Classifier',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

// ------------------ HOME PAGE (CHOOSE MODE) ------------------
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Classifier')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryPage()),
                );
              },
              child: const Text('Pick from Gallery'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CameraPage(cameras: _cameras),
                  ),
                );
              },
              child: const Text('Real-time Camera'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------ GALLERY PAGE (SINGLE IMAGE CLASSIFICATION) ------------------
class GalleryPage extends StatefulWidget {
  const GalleryPage({Key? key}) : super(key: key);

  @override
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late ImagePicker imagePicker;
  File? _image;
  String result = '';

  ImageLabeler? _imageLabeler;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    _createLabeler();
  }

  @override
  void dispose() {
    _imageLabeler?.close();
    super.dispose();
  }

  Future<void> _createLabeler() async {
    try {
      final modelPath = await _getModel('assets/ml/mobilenet.tflite');
      final options = LocalLabelerOptions(modelPath: modelPath);
      _imageLabeler = ImageLabeler(options: options);
    } catch (e) {
      print('Error creating labeler: $e');
    }
  }

  Future<String> _getModel(String assetPath) async {
    final appDir = await getApplicationSupportDirectory();
    final localPath = path.join(appDir.path, assetPath);
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    if (!await localFile.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await localFile.writeAsBytes(byteData.buffer.asUint8List());
    }
    return localPath;
  }

  Future<void> _imgFromGallery() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final XFile? pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        await _doImageLabeling();
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
    } finally {
      setState(() => _isPicking = false);
    }
  }

  Future<void> _imgFromCamera() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final XFile? pickedFile = await imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        await _doImageLabeling();
      }
    } catch (e) {
      print('Error picking image from camera: $e');
    } finally {
      setState(() => _isPicking = false);
    }
  }

  Future<void> _doImageLabeling() async {
    if (_imageLabeler == null) {
      setState(() => result = 'Labeler not initialized yet. Please try again.');
      return;
    }
    if (_image == null) {
      setState(() => result = 'No image selected.');
      return;
    }

    try {
      final inputImage = InputImage.fromFile(_image!);
      final List<ImageLabel> labels = await _imageLabeler!.processImage(
        inputImage,
      );
      final buffer = StringBuffer();
      for (final label in labels) {
        buffer.writeln('${label.label} ${label.confidence.toStringAsFixed(2)}');
      }
      setState(() => result = buffer.toString());
    } catch (e) {
      setState(() => result = 'Error during labeling: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery Classifier')),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 100),
              Stack(
                children: [
                  Center(
                    child: Image.asset(
                      'images/frame.png',
                      height: 510,
                      width: 500,
                    ),
                  ),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _imgFromGallery,
                      onLongPress: _imgFromCamera,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: _image != null
                            ? Image.file(
                                _image!,
                                width: 335,
                                height: 495,
                                fit: BoxFit.fill,
                              )
                            : Container(
                                width: 340,
                                height: 330,
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.black,
                                  size: 100,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 20),
                child: Text(
                  result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------ REAL-TIME CAMERA PAGE WITH SWAP CAMERA ------------------
class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraPage({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  CameraImage? _img;
  bool _isBusy = false;
  String _result = "";

  ImageLabeler? _imageLabeler;
  int _currentCameraIndex = 0; // 0 = back, 1 = front (if available)

  // Rotation mapping for Android
  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _createLabeler();
    _initCamera(_currentCameraIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    _imageLabeler?.close();
    super.dispose();
  }

  // Initialize the camera controller for the given index
  Future<void> _initCamera(int index) async {
    final camera = widget.cameras[index];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller.initialize();
      if (!mounted) return;
      _controller.startImageStream((image) {
        if (!_isBusy) {
          _isBusy = true;
          _img = image;
          _doImageLabeling();
        }
      });
      setState(() {}); // refresh UI
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  // Swap between front and back cameras
  Future<void> _swapCamera() async {
    if (widget.cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only one camera available')),
      );
      return;
    }
    final newIndex = _currentCameraIndex == 0 ? 1 : 0;
    setState(() => _currentCameraIndex = newIndex);

    // Dispose old controller and initialize new one
    await _controller.dispose();
    await _initCamera(newIndex);
  }

  // Load the image labeler (same as in gallery)
  Future<void> _createLabeler() async {
    try {
      final modelPath = await _getModel('assets/ml/mobilenet.tflite');
      final options = LocalLabelerOptions(
        modelPath: modelPath,
        confidenceThreshold: 0.2,
      );
      _imageLabeler = ImageLabeler(options: options);
    } catch (e) {
      print('Error creating labeler: $e');
    }
  }

  Future<String> _getModel(String assetPath) async {
    final appDir = await getApplicationSupportDirectory();
    final localPath = path.join(appDir.path, assetPath);
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    if (!await localFile.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await localFile.writeAsBytes(byteData.buffer.asUint8List());
    }
    return localPath;
  }

  // Process image from camera stream
  Future<void> _doImageLabeling() async {
    if (_imageLabeler == null) return;

    final inputImage = _getInputImage();
    if (inputImage == null) {
      setState(() => _isBusy = false);
      return;
    }

    try {
      final List<ImageLabel> labels = await _imageLabeler!.processImage(
        inputImage,
      );
      final buffer = StringBuffer();
      for (final label in labels) {
        buffer.writeln('${label.label} ${label.confidence.toStringAsFixed(2)}');
      }
      setState(() {
        _result = buffer.toString();
        _isBusy = false;
      });
    } catch (e) {
      setState(() => _isBusy = false);
      print('Labeling error: $e');
    }
  }

  // Construct InputImage from camera image with correct rotation
  InputImage? _getInputImage() {
    if (_img == null) return null;

    final camera = widget.cameras[_currentCameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller.value.deviceOrientation];
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

    final format = InputImageFormatValue.fromRawValue(_img!.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888))
      return null;

    if (_img!.planes.length != 1) return null;
    final plane = _img!.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(_img!.width.toDouble(), _img!.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller),
          // Display results
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 10),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                _result,
                style: const TextStyle(color: Colors.white, fontSize: 25),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _swapCamera,
        child: const Icon(Icons.flip_camera_ios),
      ),
    );
  }
}
