import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  List<Map<String, dynamic>> _filteredUsers = [];
  String? currentUsername;
  List<String> blockedUsers = []; // List to store blocked user IDs
  bool _noUserFound = false;
  final Map<String, String> _sentInvitations = {};
  final Map<String, bool> _loadingStatus = {}; // Loading state per user
  Timer? _debounce; // Debounce timer for search

  @override
  void initState() {
    super.initState();
    _getCurrentUsername();
    _fetchBlockedUsers(); // Fetch blocked users
    _fetchUserSpecificInvitations();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Debounce search to prevent flickering and multiple calls
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchText = _searchController.text;
        });
        if (_searchText.isNotEmpty) {
          _searchUsers(_searchText);
        } else {
          setState(() {
            _filteredUsers.clear();
            _noUserFound = false;
          });
        }
      }
    });
  }

  Future<void> _getCurrentUsername() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          currentUsername = userDoc['username'];
        });
      }
    }
  }

  Future<void> _fetchBlockedUsers() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          blockedUsers = List<String>.from(userDoc['blockedUsers'] ?? []);
        });
      }
    }
  }

void _fetchUserSpecificInvitations() {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  if (currentUserId != null) {
    // Listen for real-time updates on sent and received invitations
    FirebaseFirestore.instance
        .collection('invitations')
        .where('fromUserId', isEqualTo: currentUserId)
        .snapshots()
        .listen((sentInvitationsSnapshot) {
      setState(() {
        // Update sent invitations
        for (var doc in sentInvitationsSnapshot.docs) {
          _sentInvitations[doc['toUserId']] = doc['status'];
        }
      });
    });

    FirebaseFirestore.instance
        .collection('invitations')
        .where('toUserId', isEqualTo: currentUserId)
        .snapshots()
        .listen((receivedInvitationsSnapshot) {
      setState(() {
        // Update received invitations for accepted invitations
        for (var doc in receivedInvitationsSnapshot.docs) {
          if (doc['status'] == 'accepted') {
            _sentInvitations[doc['fromUserId']] = 'accepted';
          }
        }
      });
    });
  }
}


  Future<void> _searchUsers(String query) async {
    final usersCollection = FirebaseFirestore.instance.collection('users');

    try {
      final querySnapshot = await usersCollection
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      if (mounted) {
        setState(() {
          _filteredUsers = querySnapshot.docs
              .map((doc) => {
                    'fullName': doc['fullName'] ?? '',
                    'profilePicture': doc['profilePicture'] ?? '',
                    'username': doc['username'] ?? '',
                    'userId': doc.id
                  })
              .where((user) => user['username'] != currentUsername && !blockedUsers.contains(user['userId']))
              .toList()
              .cast<Map<String, dynamic>>();

          _noUserFound = _filteredUsers.isEmpty && query.isNotEmpty;
        });
      }
    } catch (e) {
      print("Error fetching users: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch users. Check your connection.')),
      );
    }
  }

  Future<void> _sendChatRequest(String toUserId, String username) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId != null) {
      try {
        setState(() {
          _loadingStatus[toUserId] = true;
        });

        // Check for existing invitations
        final existingInvitationQuery1 = await FirebaseFirestore.instance
            .collection('invitations')
            .where('fromUserId', isEqualTo: currentUserId)
            .where('toUserId', isEqualTo: toUserId)
            .get();

        final existingInvitationQuery2 = await FirebaseFirestore.instance
            .collection('invitations')
            .where('fromUserId', isEqualTo: toUserId)
            .where('toUserId', isEqualTo: currentUserId)
            .get();

        // Handle existing invitations
        if (existingInvitationQuery1.docs.isNotEmpty || existingInvitationQuery2.docs.isNotEmpty) {
          final status = (existingInvitationQuery1.docs.isNotEmpty)
              ? existingInvitationQuery1.docs.first['status']
              : existingInvitationQuery2.docs.first['status'];

          String message = status == 'pending'
              ? 'Invitation already pending with @$username'
              : 'You are already connected with @$username';

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        } else {
          // Send new invitation
          await FirebaseFirestore.instance.collection('invitations').add({
            'fromUserId': currentUserId,
            'toUserId': toUserId,
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });

          setState(() {
            _sentInvitations[toUserId] = 'pending';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invitation sent to @$username')),
          );
        }
      } catch (e) {
        print("Error sending invitation: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send invitation')),
        );
      } finally {
        setState(() {
          _loadingStatus[toUserId] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search users',
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _filteredUsers.isEmpty && _searchText.isEmpty
              ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0), // Add padding around the text
                        child: Text(
                          "Search the one to whisper by their username!",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54, // You can adjust the color as needed
                          ),
                          textAlign: TextAlign.center, // Center the text
                        ),
                      ),
                    )
              : _filteredUsers.isEmpty && _noUserFound
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0), // Add padding around the text
                        child: Text(
                          "No whisperer found by that username!",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54, // You can adjust the color as needed
                          ),
                          textAlign: TextAlign.center, // Center the text
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final userId = user['userId'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(user['profilePicture']),
                          ),
                          title: Text(user['fullName']),
                          subtitle: Text('@${user['username']}'),
                          trailing: _sentInvitations[userId] == 'pending'
                              ? const Icon(Icons.hourglass_empty, color: Colors.orange) // Pending icon
                              : _sentInvitations[userId] == 'accepted'
                                  ? const Icon(Icons.check_circle, color: Colors.green) // Connected icon
                                  : IconButton(
                                      icon: const Icon(Icons.person_add, color: Colors.blue), // Add person icon
                                      onPressed: _loadingStatus[userId] == true
                                          ? null
                                          : () {
                                              _sendChatRequest(userId, user['username']);
                                            },
                                  ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
