import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Detection Demo',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Object Detection')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveDetectionScreen()),
                );
              },
              child: const Text('Real‑time Detection'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaticDetectionScreen()),
                );
              },
              child: const Text('Single Image Detection'),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({Key? key}) : super(key: key);

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  CameraController? _controller;
  bool _isBusy = false;
  ObjectDetector? _objectDetector;
  List<DetectedObject> _scanResults = [];
  CameraImage? _latestImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      imageFormatGroup:
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    _controller!.startImageStream((image) {
      if (!_isBusy) {
        _isBusy = true;
        _latestImage = image;
        _detectObjectsOnFrame();
      }
    });

    setState(() {});
  }

  Future<void> _detectObjectsOnFrame() async {
    final inputImage = _inputImageFromCamera();
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    final objects = await _objectDetector!.processImage(inputImage);
    setState(() {
      _scanResults = objects;
    });
    _isBusy = false;
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCamera() {
    if (_latestImage == null) return null;

    final camera = cameras[0];
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
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (_latestImage!.planes.length != 1) return null;
    final plane = _latestImage!.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(_latestImage!.width.toDouble(), _latestImage!.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Widget _buildResults() {
    if (_scanResults.isEmpty || _controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final Size imageSize = Size(
      _controller!.value.previewSize!.height,
      _controller!.value.previewSize!.width,
    );
    return CustomPaint(
      painter: LiveObjectPainter(imageSize, _scanResults),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _objectDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text('Real‑time Detection')),
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

class LiveObjectPainter extends CustomPainter {
  final Size absoluteImageSize;
  final List<DetectedObject> objects;

  LiveObjectPainter(this.absoluteImageSize, this.objects);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / absoluteImageSize.width;
    final scaleY = size.height / absoluteImageSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.pinkAccent;

    for (final obj in objects) {
      final rect = Rect.fromLTRB(
        obj.boundingBox.left * scaleX,
        obj.boundingBox.top * scaleY,
        obj.boundingBox.right * scaleX,
        obj.boundingBox.bottom * scaleY,
      );
      canvas.drawRect(rect, paint);

      if (obj.labels.isNotEmpty) {
        final label = obj.labels.first;
        final span = TextSpan(
          text: '${label.text} (${label.confidence.toStringAsFixed(2)})',
          style: const TextStyle(fontSize: 14, color: Colors.blue),
        );
        final tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(rect.left, rect.top - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(LiveObjectPainter oldDelegate) =>
      oldDelegate.absoluteImageSize != absoluteImageSize ||
          oldDelegate.objects != objects;
}

class StaticDetectionScreen extends StatefulWidget {
  const StaticDetectionScreen({Key? key}) : super(key: key);

  @override
  State<StaticDetectionScreen> createState() => _StaticDetectionScreenState();
}

class _StaticDetectionScreenState extends State<StaticDetectionScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  ui.Image? _decodedImage;
  List<DetectedObject> _objects = [];
  ObjectDetector? _objectDetector;

  @override
  void initState() {
    super.initState();
    _initDetector();
  }

  Future<void> _initDetector() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single, // optimized for single image
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _objects = [];
        _decodedImage = null;
      });
      _detectObjects();
    }
  }

  Future<void> _detectObjects() async {
    if (_imageFile == null || _objectDetector == null) return;

    final inputImage = InputImage.fromFile(_imageFile!);
    final objects = await _objectDetector!.processImage(inputImage);
    final bytes = await _imageFile!.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    setState(() {
      _objects = objects;
      _decodedImage = image;
    });
  }

  @override
  void dispose() {
    _objectDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Single Image Detection')),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/bg.jpg'), // optional background
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 50),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  onLongPress: () => _pickImage(ImageSource.camera),
                  child: Container(
                    width: 350,
                    height: 350,
                    color: _decodedImage == null ? Colors.pinkAccent : null,
                    child: _decodedImage != null
                        ? FittedBox(
                      child: SizedBox(
                        width: _decodedImage!.width.toDouble(),
                        height: _decodedImage!.height.toDouble(),
                        child: CustomPaint(
                          painter: StaticObjectPainter(
                            image: _decodedImage!,
                            objects: _objects,
                          ),
                        ),
                      ),
                    )
                        : const Icon(Icons.camera_alt, size: 53, color: Colors.black),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // You can show detection results summary here
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                _objects.isEmpty
                    ? 'Tap to select an image'
                    : '${_objects.length} object(s) detected',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaticObjectPainter extends CustomPainter {
  final ui.Image image;
  final List<DetectedObject> objects;

  StaticObjectPainter({required this.image, required this.objects});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.red;

    for (final obj in objects) {
      canvas.drawRect(obj.boundingBox, paint);

      if (obj.labels.isNotEmpty) {
        final label = obj.labels.first;
        final span = TextSpan(
          text: '${label.text} (${label.confidence.toStringAsFixed(2)})',
          style: const TextStyle(fontSize: 18, color: Colors.blue),
        );
        final tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(obj.boundingBox.left, obj.boundingBox.top - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(StaticObjectPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.objects != objects;
}