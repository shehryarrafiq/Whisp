import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dm_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateUserStatus("available");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateUserStatus("away");
    super.dispose();
  }

  void _updateUserStatus(String status) {
    if (currentUserId != null) {
      FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'userStatus': status,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((error) {
        print("Failed to update user status: $error");
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _updateUserStatus("away");
    } else if (state == AppLifecycleState.resumed) {
      _updateUserStatus("available");
    }
  }

  Stream<List<Map<String, dynamic>>> _getAcceptedInvitations() async* {
    final invitationsCollection = FirebaseFirestore.instance.collection('invitations');

    final Stream<List<Map<String, dynamic>>> query1Stream = invitationsCollection
        .where('status', isEqualTo: 'accepted')
        .where('toUserId', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((querySnapshot) => _processContacts(querySnapshot, true));

    final Stream<List<Map<String, dynamic>>> query2Stream = invitationsCollection
        .where('status', isEqualTo: 'accepted')
        .where('fromUserId', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((querySnapshot) => _processContacts(querySnapshot, false));

    yield* query1Stream.asyncExpand((query1Contacts) {
      return query2Stream.map((query2Contacts) {
        return [...query1Contacts, ...query2Contacts];
      });
    });
  }

  Future<List<Map<String, dynamic>>> _processContacts(
      QuerySnapshot<Map<String, dynamic>> querySnapshot, bool isToUserId) async {
    List<Map<String, dynamic>> contactsList = [];
    for (var doc in querySnapshot.docs) {
      final invitationData = doc.data();
      final otherUserId = isToUserId ? invitationData['fromUserId'] : invitationData['toUserId'];
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        contactsList.add({
          'userId': otherUserId,
          'fullName': userData['fullName'],
          'profilePicture': userData['profilePicture'],
          'username': userData['username'],
          'invitationId': doc.id,
        });
      }
    }
    return contactsList;
  }
  String _formatMessagePreview(String message) {
    final isImageMessage = Uri.tryParse(message)?.isAbsolute ?? false;
    return isImageMessage ? 'sent an Image' : message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search chats',
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 20.0),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAcceptedInvitations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "There is no one to Whisper, Send invitations!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                } else {
                  final contacts = snapshot.data!;
                  return ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .doc(contact['invitationId'])
                            .collection('messages')
                            .orderBy('timestamp', descending: true)
                            .limit(1)
                            .snapshots(),
                        builder: (context, messageSnapshot) {
                          if (messageSnapshot.hasData &&
                              messageSnapshot.data!.docs.isNotEmpty) {
                            final lastMessageDoc = messageSnapshot.data!.docs.first;
                            contact['lastMessage'] = lastMessageDoc['content'];
                            contact['lastMessageTime'] = lastMessageDoc['timestamp'];
                            contact['lastMessageSenderId'] = lastMessageDoc['senderId'];
                            contact['isRead'] = lastMessageDoc['isRead'];
                          } else {
                            contact['lastMessage'] = 'No messages yet';
                            contact['lastMessageTime'] = null;
                            contact['lastMessageSenderId'] = null;
                            contact['isRead'] = true;
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(contact['profilePicture']),
                            ),
                            title: Text(
                              contact['fullName'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              contact['lastMessage'] != null
                                  ? (contact['lastMessageSenderId'] == currentUserId
                                  ? 'You: ${_formatMessagePreview(contact['lastMessage'])}'
                                  : '@${contact['username']}: ${_formatMessagePreview(contact['lastMessage'])}')
                                  : 'No messages yet',
                              maxLines: 1, // Limits the message to one line
                              overflow: TextOverflow.ellipsis, // Shows "..." if text overflows
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                contact['isRead'] == false &&
                                        contact['lastMessageSenderId'] != currentUserId
                                    ? const Icon(
                                        Icons.circle,
                                        color: Colors.blue,
                                        size: 15,
                                      )
                                    : const SizedBox.shrink(),
                                const SizedBox(width: 8),
                                Text(
                                  contact['lastMessageTime'] != null
                                      ? _formatTimestamp(contact['lastMessageTime'].toDate())
                                      : '',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DMPage(
                                    contactName: contact['fullName'],
                                    profileImageUrl: contact['profilePicture'],
                                    chatId: contact['invitationId'],
                                    currentUserId: currentUserId!,
                                    contactUserId: contact['userId'],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    int hour = timestamp.hour;
    final minutes = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour:$minutes $period';
  }
}
