import 'package:flutter/material.dart';
import 'package:whisp/screens/signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dark blue background
          Container(
            color: const Color.fromARGB(255, 1, 77, 164),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/ic_whispicon.png',
                          height: 26,
                          width: 26,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Whisp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/welcome_screen.png',
                  height: 310,
                  width: 300,
                  fit: BoxFit.cover,
                ),
              ],
            ),
          ),
          // White container with rounded top corners
          Positioned(
            top: MediaQuery.of(context).size.height * 0.6,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text(
                        'Your voice, amplified in every word.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Transform your messages into moments—join the Whisp conversation',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignUpScreen()),
          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 1, 77, 164),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Let's Go!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
