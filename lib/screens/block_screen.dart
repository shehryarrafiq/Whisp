import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockScreen extends StatefulWidget {
  const BlockScreen({super.key});

  @override
  _BlockScreenState createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen> {
  List<Map<String, String>> blockedUsers = [];
  List<String> blockedUserIds = [];

  @override
  void initState() {
    super.initState();
    fetchBlockedUsers();
  }

  Future<void> fetchBlockedUsers() async {
    try {
      // Get current user's blocked contacts array
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        blockedUserIds = List<String>.from(userDoc['blockedUsers'] ?? []);

        // Fetch each blocked user's fullName and username
        List<Map<String, String>> fetchedBlockedUsers = [];
        for (String blockedUserId in blockedUserIds) {
          DocumentSnapshot blockedUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(blockedUserId)
              .get();
          if (blockedUserDoc.exists) {
            String fullName = blockedUserDoc['fullName'] ?? 'Unknown';
            String username = blockedUserDoc['username'] ?? 'unknown';
            fetchedBlockedUsers.add({
              'id': blockedUserId,
              'fullName': fullName,
              'username': username,
            });
          }
        }

        setState(() {
          blockedUsers = fetchedBlockedUsers;
        });
      }
    } catch (e) {
      print("Error fetching blocked users: $e");
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Update Firestore by removing the userId from the blockedUsers array
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'blockedUsers': FieldValue.arrayRemove([userId])
        });

        // Update local list and UI
        setState(() {
          blockedUsers.removeWhere((user) => user['id'] == userId);
          blockedUserIds.remove(userId);
        });
      }
    } catch (e) {
      print("Error unblocking user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 77, 164),
        title: const Text(
          'Blocked Contacts',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: blockedUsers.isEmpty
                ? const Center(child: Text('No blocked contacts'))
                : ListView.builder(
                    itemCount: blockedUsers.length,
                    itemBuilder: (context, index) {
                      final user = blockedUsers[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.block, color: Colors.white),
                        ),
                        title: Text(
                          user['fullName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('@${user['username'] ?? 'unknown'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            _showUnblockDialog(context, user['fullName'] ?? 'User', user['id']!);
                          },
                        ),
                        onTap: () {
                          // Optional: Add functionality when a blocked contact is tapped
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Function to show a dialog for unblocking a contact
  void _showUnblockDialog(BuildContext context, String contactName, String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unblock Contact'),
          content: Text('Are you sure you want to unblock $contactName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Call unblockUser method to remove the userId from blockedUsers
                unblockUser(userId);
                Navigator.pop(context);
              },
              child: const Text('Unblock'),
            ),
          ],
        );
      },
    );
  }
}
