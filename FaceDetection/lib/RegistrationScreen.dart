import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _HomePageState();
}

class _HomePageState extends State<RegistrationScreen> {
  //TODO declare variables
  late ImagePicker imagePicker;
  File? _image;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    imagePicker = ImagePicker();

    //TODO initialize face detector

    //TODO initialize face recognizer
  }

  //TODO capture image using camera
  _imgFromCamera() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        doFaceDetection();
      });
    }
  }

  //TODO choose image using gallery
  _imgFromGallery() async {
    XFile? pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        doFaceDetection();
      });
    }
  }

  //TODO face detection code here
  doFaceDetection() async {
    //TODO remove rotation of camera images
    _image = await removeRotation(_image!);
  }

  //TODO remove rotation of camera images
  removeRotation(File inputImage) async {
    final img.Image? capturedImage = img.decodeImage(
      await File(inputImage!.path).readAsBytes(),
    );
    final img.Image orientedImage = img.bakeOrientation(capturedImage!);
    return await File(_image!.path).writeAsBytes(img.encodeJpg(orientedImage));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1f4037), Color(0xFF99f2c8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                "Face Registration",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 30),

              // Face Preview
              Container(
                width: MediaQuery.of(context).size.width / 1.15,
                height: MediaQuery.of(context).size.width / 1.15,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24), // Rounded corners
                  gradient: const LinearGradient(
                    colors: [Color(0xFFffffff), Color(0xFFd4f7e6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(75),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    18,
                  ), // Match inner clip radius
                  child: // image != null
                  //     ? FittedBox(
                  //   child: SizedBox(
                  //     width: image.width.toDouble(),
                  //     height: image.height.toDouble(),
                  //     child: CustomPaint(
                  //       painter: FacePainter(
                  //         facesList: faces,
                  //         imageFile: image,
                  //       ),
                  //     ),
                  //   ),
                  // )
                  _image != null
                      ? Image.file(_image!)
                      : Image.asset("images/logo.png", fit: BoxFit.fill),
                ),
              ),

              const SizedBox(height: 40),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _gradientButton(
                    icon: Icons.image,
                    label: "Gallery",
                    onTap: _imgFromGallery,
                    width: screenWidth * 0.4,
                  ),
                  _gradientButton(
                    icon: Icons.camera_alt,
                    label: "Camera",
                    onTap: _imgFromCamera,
                    width: screenWidth * 0.4,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable beautiful button
  Widget _gradientButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double width = 150,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFFffffff), Color(0xFFc4f1e0)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// class FacePainter extends CustomPainter {
//   List<Face> facesList;
//   dynamic imageFile;
//   FacePainter({required this.facesList, @required this.imageFile});
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (imageFile != null) {
//       canvas.drawImage(imageFile, Offset.zero, Paint());
//     }
//
//     Paint p = Paint();
//     p.color = Colors.red;
//     p.style = PaintingStyle.stroke;
//     p.strokeWidth = 3;
//
//     for (Face face in facesList) {
//       canvas.drawRect(face.boundingBox, p);
//     }
//   }
//
//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) {
//     return true;
//   }
// }