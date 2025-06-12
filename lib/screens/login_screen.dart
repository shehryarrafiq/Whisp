import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whisp/screens/home_screen.dart';
import 'package:whisp/screens/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance; // Initialize Firebase Auth

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Show loading dialog
    void showLoadingDialog(String message) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 1, 77, 164),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      // Show the loading dialog
      showLoadingDialog("Logging you in buddy...");

      // Sign in with email and password
      await _auth.signInWithEmailAndPassword(
        email: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Save login state
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // If successful, navigate to HomeScreen
      Navigator.of(context).pop(); // Close the loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop(); // Close the loading dialog if there's an error

      // Handle errors here
      String message = 'An error occurred, please try again.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      }
      _showMessageDialog(message, title: 'Error');
    }
  }

  void _forgotPassword() {
    // Show a dialog to enter email
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController emailController = TextEditingController(
          text: usernameController.text.trim(),
        );
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Send password reset email
                Navigator.of(context).pop(); // Close the dialog
                try {
                  await _auth.sendPasswordResetEmail(
                    email: emailController.text.trim(),
                  );
                  _showMessageDialog(
                    'Password reset email sent. Please check your email.',
                    title: 'Success',
                  );
                } on FirebaseAuthException catch (e) {
                  String message = 'An error occurred, please try again.';
                  if (e.code == 'user-not-found') {
                    message = 'No user found for that email.';
                  }
                  _showMessageDialog(message, title: 'Error');
                }
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showMessageDialog(String message, {String title = 'Info'}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _forgotPassword,
        child: const Text(
          'Forgot Password?',
          style: TextStyle(
            color: Color.fromARGB(255, 1, 77, 164),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 1, 77, 164),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 1, 77, 164),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _login, // Call the _login function
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 1, 77, 164),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Log In',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpRedirect() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignUpScreen()),
        );
      },
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            color: Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.w300,
          ),
          children: <TextSpan>[
            TextSpan(text: 'Don\'t have an account? '),
            TextSpan(
              text: 'Sign Up',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 1, 77, 164),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color.fromARGB(255, 1, 77, 164),
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/ic_whispicon.png',
                  height: 50,
                  width: 50,
                ),
              ),
              Image.asset(
                'assets/login_screen.png',
                height: 250,
                width: 300,
                fit: BoxFit.cover,
              ),
              const Center(
                child: Text(
                  'Welcome Back Buddy!',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildTextField(usernameController, 'Email'), // Update label to Email
              const SizedBox(height: 20),
              _buildPasswordField(passwordController, 'Password'),
              const SizedBox(height: 10),
              _buildForgotPasswordButton(), // Added Forgot Password button here
              const SizedBox(height: 30),
              _buildLoginButton(),
              const SizedBox(height: 20),
              _buildSignUpRedirect(),
            ],
          ),
        ),
      ),
    );
  }
}
