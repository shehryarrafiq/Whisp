import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  _InvitationScreenState createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  List<Map<String, dynamic>> _invitations = []; // Store invitations data
  bool _isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _fetchInvitations(); // Fetch invitations when the screen initializes
  }

  Future<void> _fetchInvitations() async {
    final currentUserId =
        FirebaseAuth.instance.currentUser?.uid; // Get current user ID
    if (currentUserId != null) {
      try {
        final invitationsCollection =
            FirebaseFirestore.instance.collection('invitations');
        final querySnapshot = await invitationsCollection
            .where('toUserId',
                isEqualTo:
                    currentUserId) // Get invitations sent to current user
            .where('status',
                isEqualTo: 'pending') // Only get pending invitations
            .get();

        List<Map<String, dynamic>> invitationsList = [];

        // Fetch user details for each invitation
        for (var doc in querySnapshot.docs) {
          final invitationData = doc.data();
          final fromUserId = invitationData['fromUserId'];

          // Fetch user details from the users collection
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(fromUserId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() ?? {};
            invitationsList.add({
              'fromUserId': fromUserId,
              'fullName': userData['fullName'], // User's full name
              'profilePicture':
                  userData['profilePicture'], // User's profile picture
              'username': userData['username'], // User's username
              'invitationId':
                  doc.id // Store invitation document ID for updates/deletion
            });
          }
        }

        setState(() {
          _invitations = invitationsList;
          _isLoading = false; // Set loading state to false after fetching
        });
      } catch (e) {
        print("Error fetching invitations: $e"); // Handle any errors
        setState(() {
          _isLoading = false; // Reset loading state on error
        });
      }
    }
  }

  Future<void> _acceptInvitation(String invitationId) async {
    try {
      // Fetch the invitation data to get the fromUserId
      final invitationDoc = await FirebaseFirestore.instance
          .collection('invitations')
          .doc(invitationId)
          .get();
      if (!invitationDoc.exists) return; // Check if the invitation exists

      final invitationData = invitationDoc.data()!;
      final fromUserId = invitationData['fromUserId'];

      // Update the status to 'accepted'
      await FirebaseFirestore.instance
          .collection('invitations')
          .doc(invitationId)
          .update({
        'status': 'accepted',
      });

      // Get the current user's ID (toUserId)
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      final chatId = currentUserId.hashCode <= fromUserId.hashCode
          ? "$currentUserId-$fromUserId"
          : "$fromUserId-$currentUserId";

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'users': [currentUserId, fromUserId],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Fetch full name, username, and profile picture of the fromUser
      final fromUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUserId)
          .get();
      if (!fromUserDoc.exists) return; // Check if the fromUser exists

      final fromUserData = fromUserDoc.data()!;
      final fromFullName = fromUserData['fullName'];
      final fromUsername = fromUserData['username'];
      final fromProfilePicture = fromUserData['profilePicture'];

      // Fetch full name, username, and profile picture of the current user
      final toUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (!toUserDoc.exists) return; // Check if the current user exists

      final toUserData = toUserDoc.data()!;
      final toFullName = toUserData['fullName'];
      final toUsername = toUserData['username'];
      final toProfilePicture = toUserData['profilePicture'];

      // Create contact for the current user (toUserId)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('contacts')
          .doc(fromUserId)
          .set({
        'userId': fromUserId,
        'fullName': fromFullName, // Full name of the fromUser
        'username': fromUsername,
        'profilePicture': fromProfilePicture, // Optional
        'addedAt': FieldValue
            .serverTimestamp(), // Timestamp of when the contact was added
        'invitationId':
            invitationId, // Store invitationId here for later reference
            'chatId': chatId,  // Store chatId here for direct access
      });

      // Create contact for the fromUserId (fromUser)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUserId)
          .collection('contacts')
          .doc(currentUserId)
          .set({
        'userId': currentUserId,
        'fullName': toFullName, // Full name of the current user
        'username': toUsername,
        'profilePicture': toProfilePicture, // Optional
        'addedAt': FieldValue
            .serverTimestamp(), // Timestamp of when the contact was added
        'invitationId':
            invitationId, // Store invitationId here for later reference
            'chatId': chatId,  // Store chatId here for direct access
      }); 

      // Optionally, navigate to chat screen or update the UI as needed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation accepted!')),
      );
      _fetchInvitations(); // Refresh invitations
    } catch (e) {
      print("Error accepting invitation: $e"); // Handle any errors
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept invitation')),
      );
    }
  }

  Future<void> _rejectInvitation(String invitationId) async {
    try {
      // Delete the invitation from Firestore
      await FirebaseFirestore.instance
          .collection('invitations')
          .doc(invitationId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation rejected!')),
      );
      _fetchInvitations(); // Refresh invitations
    } catch (e) {
      print("Error rejecting invitation: $e"); // Handle any errors
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject invitation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Your Invitations to Whisper',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator()) // Show loading indicator while fetching
                : _invitations.isEmpty // Check if there are no invitations
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(
                              16.0), // Add padding around the text
                          child: Text(
                            "There are no invitations for you currently!",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors
                                  .black54, // You can adjust the color as needed
                            ),
                            textAlign: TextAlign.center, // Center the text
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _invitations.length,
                        itemBuilder: (context, index) {
                          final invitation = _invitations[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0)),
                              elevation: 5,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                      invitation['profilePicture']),
                                ),
                                title: Text(
                                  "@${invitation['username']}", // Display username with "@" symbol
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle:
                                    const Text('wants to Whisper with you'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check,
                                          color: Colors.green),
                                      onPressed: () => _acceptInvitation(invitation[
                                          'invitationId']), // Accept invitation
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.red),
                                      onPressed: () => _rejectInvitation(invitation[
                                          'invitationId']), // Reject invitation
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
