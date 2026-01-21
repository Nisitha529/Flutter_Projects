import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  File? image;
  late ImagePicker imagePicker;
  late ImageLabeler labeler;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();

    ImageLabelerOptions options = ImageLabelerOptions(confidenceThreshold: 0.6);
    labeler = ImageLabeler(options: options);
  }

  chooseImage() async {
    XFile? selectedImage = await imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (selectedImage != null) {
      image = File(selectedImage.path);

      performImageLabeling();

      setState(() {
        image;
      });
    }
  }

  captureImage() async {
    XFile? selectedImage = await imagePicker.pickImage(
      source: ImageSource.camera,
    );

    if (selectedImage != null) {
      image = File(selectedImage.path);

      performImageLabeling();

      setState(() {
        image;
      });
    }
  }

  String results = "";

  performImageLabeling() async {
    results = "";
    InputImage inputImage = InputImage.fromFile(image!);

    final List<ImageLabel> labels = await labeler.processImage(inputImage);

    for (ImageLabel label in labels) {
      final String text = label.label;
      final int index = label.index;
      final double confidence = label.confidence;
      print(text + "  " + confidence.toString());
      results += text + "   " + confidence.toStringAsFixed(2) + "\n";
    }

    setState(() {
      results;
    });
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text("Image Recognizer"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Card(
                color: Colors.blueGrey,
                margin: EdgeInsets.all(10),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height / 2,
                  child: image == null
                      ? Icon(Icons.image_outlined, size: 150)
                      : Image.file(image!),
                ),
              ),
              Card(
                margin: EdgeInsets.all(10),
                color: Colors.tealAccent.shade700,
                child: Container(
                  height: 100,
                  child: Row(
                    children: [
                      InkWell(
                        child: Icon(Icons.image, size: 50),
                        onTap: () {
                          chooseImage();
                        },
                      ),
                      InkWell(
                        child: Icon(Icons.camera, size: 50),
                        onTap: () {
                          captureImage();
                        },
                      ),
                    ],
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  ),
                ),
              ),
              Card(
                child: Container(
                  color: Colors.black,
                  child: Text(results, style: TextStyle(fontSize : 24, color: Colors.white),),
                  width: MediaQuery.of(context).size.width,
                  padding: EdgeInsets.all(10),
                ),
                margin: EdgeInsets.all(10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
