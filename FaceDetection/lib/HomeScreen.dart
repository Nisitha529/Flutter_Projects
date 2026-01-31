import 'package:flutter/material.dart';

import 'RecognitionScreen.dart';
import 'RegistrationScreen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build (BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold (
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration (
          gradient: LinearGradient (
            colors: [Color(0xFF1f4037), Color(0xFF99f2c8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: SafeArea(
          child: Padding (
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column (
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                Text(
                  'Face ID App',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith (
                    color:Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox (height: 16),
                Text (
                  'Secure • Fast • Accurate',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.1
                  ),
                ),

                const SizedBox (height: 24),
                Expanded (
                  flex: 3,
                  child:Center (
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset (
                        'images/logo.png',
                        width: size.width * 0.55,
                        fit: BoxFit.cover
                      ),
                    ),
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _AppButton (
                        label : 'Register Face',
                        icon: Icons.person_add_alt_1,
                        onPressed : () {
                          Navigator.push (
                            context,
                            MaterialPageRoute (
                              builder: (_) => const RegistrationScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox (height: 16),
                      _AppButton (
                        label:'Registered Faces',
                        icon: Icons.list_alt,
                        onPressed : () {

                        },
                      ),
                      const SizedBox (height : 40),
                    ],
                  ),
                )
              ]
            )
          )
        )
      )
    );
  }
}

class _AppButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _AppButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          elevation: 8,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black38,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}