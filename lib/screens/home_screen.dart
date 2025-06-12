import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth for current user
import 'package:whisp/screens/userprofile_screen.dart';
import 'chat_screen.dart';
import 'search_screen.dart';
import 'invitation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  String? _profilePictureUrl;

  final List<Widget> _pages = [
    const ChatScreen(),
    const InvitationScreen(),
    const SearchScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfilePicture();
  }

  Future<void> _loadUserProfilePicture() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data()!['profilePicture'] != null) {
          setState(() {
            _profilePictureUrl = userDoc.data()!['profilePicture'];
          });
        }
      }
    } catch (e) {
      print('Error loading profile picture: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 77, 164),
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
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
        actions: [
          IconButton(
            icon: _profilePictureUrl != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(_profilePictureUrl!),
                    radius: 16,
                  )
                : const Icon(Icons.account_circle, color: Colors.white),
            iconSize: 32,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UserProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        color: const Color.fromARGB(255, 1, 77, 164),
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.chat, 'Chats', 0),
            _buildNavItem(Icons.mail_outline, 'Invitations', 1),
            _buildNavItem(Icons.search, 'Search', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => _onItemTapped(index),
      splashColor: Colors.white.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: _selectedIndex == index ? Colors.white : Colors.white70,
            ),
            Text(
              label,
              style: TextStyle(
                color: _selectedIndex == index ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}