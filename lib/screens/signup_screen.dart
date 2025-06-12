import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // Import the image package for compression
import 'package:whisp/screens/login_screen.dart';
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  XFile? _image;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _dismissLoadingDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _signUp() async {
    if (passwordController.text != confirmPasswordController.text) {
      _showError("Passwords do not match");
      return;
    }

    _showLoadingDialog("Creating your account...");

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: usernameController.text.trim())
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _dismissLoadingDialog();
        _showError("Username is already taken");
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String? imageUrl;
      if (_image != null) {
        // Compress the image
        final compressedImage = await _compressImage(File(_image!.path));
        // Upload the compressed image to Firebase Storage
        final ref = _storage.ref().child('profile_pictures/${userCredential.user!.uid}');
        await ref.putFile(compressedImage);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'fullName': fullNameController.text.trim(),
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'uid': userCredential.user!.uid,
        'profilePicture': imageUrl,
      });

      _dismissLoadingDialog();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _dismissLoadingDialog();
      _showError(e.message ?? "An error occurred");
    }
  }

  Future<File> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes)!;

    // Resize the image to a width of 300 pixels (maintains aspect ratio)
    final resizedImage = img.copyResize(image, width: 200);
    final compressedBytes = img.encodeJpg(resizedImage, quality: 50);

    // Save the compressed image as a temporary file
    final compressedImage = File('${file.path}_compressed.jpg');
    await compressedImage.writeAsBytes(compressedBytes);

    return compressedImage;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      _image = pickedFile;
    });
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
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
              const SizedBox(height: 20),
              const Text(
                'Create your Account',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _image != null ? FileImage(File(_image!.path)) : null,
                  child: _image == null
                      ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildFullNameField(),
              const SizedBox(height: 20),
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildUsernameField(),
              const SizedBox(height: 20),
              _buildPasswordField(passwordController, 'Password'),
              const SizedBox(height: 20),
              _buildPasswordField(confirmPasswordController, 'Confirm Password'),
              const SizedBox(height: 20),
              _buildSignUpButton(),
              const SizedBox(height: 20),
              _buildLoginRedirect(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullNameField() {
    return TextField(
      controller: fullNameController,
      textCapitalization: TextCapitalization.words,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (newValue.text.isEmpty) return newValue;
          final text = newValue.text.split(' ');
          for (int i = 0; i < text.length; i++) {
            if (text[i].isNotEmpty) {
              text[i] = text[i][0].toUpperCase() + text[i].substring(1).toLowerCase();
            }
          }
          return TextEditingValue(text: text.join(' '), selection: newValue.selection);
        }),
      ],
      decoration: InputDecoration(
        labelText: 'Full Name',
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

  Widget _buildEmailField() {
    return TextField(
      controller: emailController,
      decoration: InputDecoration(
        labelText: 'Email',
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

  Widget _buildUsernameField() {
    return TextField(
      controller: usernameController,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.-]')),
        FilteringTextInputFormatter.deny(RegExp(r'[A-Z]')),
      ],
      decoration: InputDecoration(
        labelText: 'Username',
        prefixText: '@',
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
      obscureText: label == 'Password' ? !_isPasswordVisible : !_isConfirmPasswordVisible,
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
            label == 'Password' ? (_isPasswordVisible ? Icons.visibility : Icons.visibility_off) : (_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
          ),
          onPressed: () {
            setState(() {
              if (label == 'Password') {
                _isPasswordVisible = !_isPasswordVisible;
              } else {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 1, 77, 164),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: _signUp,
      child: const SizedBox(
        width: double.infinity,
        child: Text(
          'Sign Up',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?"),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: const Text(
            'Log In',
            style: TextStyle(
              color: Color.fromARGB(255, 1, 77, 164),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
