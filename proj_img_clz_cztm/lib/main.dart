import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyHomePage());
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late ImagePicker imagePicker;
  File? _image;
  String result = '';

  // Make it nullable and initialize after async creation
  ImageLabeler? _imageLabeler;

  // Flag to prevent multiple simultaneous pick operations
  bool _isPicking = false;

  @override
  void initState() {
    super.initState(); // only one call needed
    imagePicker = ImagePicker();
    _createLabeler(); // start async initialization
  }

  @override
  void dispose() {
    // Close the labeler only if it was initialized
    _imageLabeler?.close();
    super.dispose();
  }

  // Asynchronously create the labeler and update state when ready
  Future<void> _createLabeler() async {
    try {
      final modelPath = await _getModel('assets/ml/mobilenet.tflite');
      final options = LocalLabelerOptions(modelPath: modelPath);
      _imageLabeler = ImageLabeler(options: options);
    } catch (e) {
      print('Error creating labeler: $e');
      // Optionally show a snackbar or handle error gracefully
    }
    // No need to call setState here because the labeler is not used in UI directly
  }

  // Copies the model from assets to a local file and returns its path
  Future<String> _getModel(String assetPath) async {
    final appDir = await getApplicationSupportDirectory();
    final localPath = path.join(appDir.path, assetPath);
    final localFile = File(localPath);

    // Ensure the directory exists
    await localFile.parent.create(recursive: true);

    // Copy from assets if not already present
    if (!await localFile.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await localFile.writeAsBytes(byteData.buffer.asUint8List());
    }
    return localPath;
  }

  // Image picker from gallery
  Future<void> _imgFromGallery() async {
    if (_isPicking) return; // prevent concurrent picks
    setState(() => _isPicking = true);

    try {
      final XFile? pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        // Perform labeling after the image is set
        await _doImageLabeling();
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
    } finally {
      setState(() => _isPicking = false);
    }
  }

  // Image picker from camera
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

  // Perform image labeling (must be called after _image is set)
  Future<void> _doImageLabeling() async {
    // Ensure the labeler is ready
    if (_imageLabeler == null) {
      setState(() {
        result = 'Labeler not initialized yet. Please try again.';
      });
      return;
    }

    if (_image == null) {
      setState(() {
        result = 'No image selected.';
      });
      return;
    }

    try {
      final inputImage = InputImage.fromFile(_image!);
      final List<ImageLabel> labels = await _imageLabeler!.processImage(
        inputImage,
      );

      // Build result string
      final buffer = StringBuffer();
      for (final label in labels) {
        buffer.writeln('${label.label} ${label.confidence.toStringAsFixed(2)}');
      }

      setState(() {
        result = buffer.toString();
      });
    } catch (e) {
      setState(() {
        result = 'Error during labeling: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 100), // replaced width with height
                Stack(
                  children: <Widget>[
                    // Frame image
                    Center(
                      child: Image.asset(
                        'images/frame.png',
                        height: 510,
                        width: 500,
                      ),
                    ),
                    // Button that shows the picked image or camera icon
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
      ),
    );
  }
}
