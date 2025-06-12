import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisp/screens/block_screen.dart';
import 'package:whisp/screens/friendlist_screen.dart';
import 'package:whisp/screens/login_screen.dart';
import 'package:whisp/screens/signup_screen.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  File? _image;
  String? profileImageUrl;
  String fullName = '';
  String userName = '';
  bool _isUploading = false;
  int friendCount = 0;
  int blockedUserCount = 0;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchFriendCount();
    fetchBlockedUserCount();
  }

  Future<void> fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        profileImageUrl = userDoc['profilePicture'] ?? '';
        fullName = userDoc['fullName'] ?? 'Full Name';
        userName = userDoc['username'] ?? 'username';
      });
    }
  }

  Future<void> fetchFriendCount() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .get();
      setState(() {
        friendCount = friendsSnapshot.docs.length;
      });
    }
  }

  Future<void> fetchBlockedUserCount() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      List<dynamic> blockedUsers = userDoc['blockedUsers'] ?? [];
      setState(() {
        blockedUserCount = blockedUsers.length;
      });
    }
  }

  Future<void> _chooseImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isUploading = true;
      });

      File? compressedImage = await _compressImage(File(pickedFile.path));
      await _uploadImageToFirebase(compressedImage);
    }
  }

  Future<File?> _compressImage(File imageFile) async {
    final image = img.decodeImage(imageFile.readAsBytesSync());
    if (image == null) return null;

    final resizedImage = img.copyResize(image, width: 200);
    final compressedImageFile = File('${imageFile.path}_compressed.jpg')
      ..writeAsBytesSync(img.encodeJpg(resizedImage, quality: 50));

    return compressedImageFile;
  }

  Future<void> _uploadImageToFirebase(File? imageFile) async {
    if (imageFile == null) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String fileName = 'profile_pictures/${user!.uid}';

      UploadTask uploadTask =
          FirebaseStorage.instance.ref(fileName).putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'profilePicture': downloadUrl,
      });

      setState(() {
        profileImageUrl = downloadUrl;
        _isUploading = false;
      });
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user data is loaded
    bool isUserDataLoaded = fullName.isNotEmpty && userName.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 77, 164),
        title: const Text('About You',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: isUserDataLoaded
          ? Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _chooseImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.white,
                          child: _isUploading
                              ? const CircularProgressIndicator()
                              : CircleAvatar(
                                  radius: 75,
                                  backgroundImage: profileImageUrl != null &&
                                          profileImageUrl!.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          profileImageUrl!)
                                      : const AssetImage(
                                              'assets/profile_placeholder.png')
                                          as ImageProvider,
                                ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  blurRadius: 5.0),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 30, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(fullName,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('@$userName',
                      style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 30),
                  Column(
                    children: [
                      const Divider(color: Colors.grey),
                      ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Your Buddies',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w600)),
                            Text(
                              '$friendCount',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 20),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const FriendListScreen()));
                        },
                      ),
                      const Divider(color: Colors.grey),
                    ],
                  ),
                  Column(
                    children: [
                      const Divider(color: Colors.grey),
                      ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Blocked Ones',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w600)),
                            Text(
                              '$blockedUserCount',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 20),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const BlockScreen()));
                        },
                      ),
                      const Divider(color: Colors.grey),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('isLoggedIn', false);
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 1, 77, 164)),
                      child: const Text('Log Out',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .delete();
                          await user.delete();
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('isLoggedIn', false);
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SignUpScreen()));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      child: const Text('Delete Account',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
