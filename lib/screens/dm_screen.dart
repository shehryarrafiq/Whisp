import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum MessageStatus { sent, delivered, seen }

class ChatMessage {
  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;
  bool isRead;
  MessageStatus status;

  ChatMessage(this.id, this.content, this.isFromUser, this.timestamp,
      {this.isRead = false, this.status = MessageStatus.sent});
}

class DMPage extends StatefulWidget {
  final String contactName;
  final String profileImageUrl;
  final String chatId;
  final String currentUserId;
  final String contactUserId;

  const DMPage({
    Key? key,
    required this.contactName,
    required this.profileImageUrl,
    required this.chatId,
    required this.currentUserId,
    required this.contactUserId,
  }) : super(key: key);

  @override
  _DMPageState createState() => _DMPageState();
}

class _DMPageState extends State<DMPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  String _availabilityStatus = 'Available';
  bool _isPreviewingImage = false;
  bool _isUploadingImage = false; // New variable to track uploading state
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _listenForMessages();
    _listenToUserStatus();
    _markMessagesAsRead();
  }

  void _listenForMessages() {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _messages.clear();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          bool isFromUser = data['senderId'] == widget.currentUserId;
          DateTime messageTimestamp = (data['timestamp'] as Timestamp).toDate();
          bool isRead = data['isRead'] ?? false;

          _messages.add(ChatMessage(
            doc.id,
            data['content'],
            isFromUser,
            messageTimestamp,
            isRead: isRead,
            status: MessageStatus.seen,
          ));

          if (!isFromUser && !isRead) {
            FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .collection('messages')
                .doc(doc.id)
                .update({'isRead': true});
          }
        }
      });
    });
  }

  void _markMessagesAsRead() async {
    final messagesCollection = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');

    final unreadMessages = await messagesCollection
        .where('senderId', isNotEqualTo: widget.currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadMessages.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  void _listenToUserStatus() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.contactUserId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        setState(() {
          _availabilityStatus = doc.data()?['userStatus'] ?? 'Available';
        });
      }
    });
  }

  void _sendMessage() async {
    final messageContent = _messageController.text.trim();
    if (messageContent.isNotEmpty) {
      _messageController.clear();
      final messageData = {
        'content': messageContent,
        'senderId': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);
    }
  }

  Future<void> _sendMediaMessage(String mediaUrl) async {
    final messageData = {
      'content': mediaUrl,
      'senderId': widget.currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'media', // Indicate that this is a media message
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);
  }

  Future<void> _pickAndSendMedia() async {
    final picker = ImagePicker();
    // Allow user to choose between image or video
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage =
            File(pickedFile.path); // Set the selected image for preview
        _isPreviewingImage = true; // Show the preview overlay
      });
    }
  }

  Future<void> _sendImageMessage() async {
    if (_selectedImage != null) {
      setState(() {
        _isUploadingImage = true; // Show loader when uploading starts
        _uploadProgress = 0.0; // Reset progress
      });

      String? downloadUrl = await _uploadMediaToStorage(_selectedImage!);
      if (downloadUrl != null) {
        await _sendMediaMessage(downloadUrl);
        setState(() {
          _selectedImage = null;
          _isPreviewingImage = false; // Hide the preview after sending
        });
      }

      setState(() {
        _isUploadingImage = false; // Hide loader after upload completes
        _uploadProgress = 0.0; // Reset progress
      });
    }
  }


  double _uploadProgress = 0.0; // New variable to track progress

  Future<String?> _uploadMediaToStorage(File mediaFile) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child('chat_media/$fileName');

      final uploadTask = ref.putFile(mediaFile);

      // Monitor the upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e) {
      print("Failed to upload media: $e");
      return null;
    }
  }

  void _clearChat() async {
    final messagesCollection = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');

    final messagesSnapshot = await messagesCollection.get();
    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat cleared successfully.')),
    );
  }

  Future<void> _blockContact() async {
    final invitationsCollection =
        FirebaseFirestore.instance.collection('invitations');

    final querySnapshot = await invitationsCollection
        .where('fromUserId', isEqualTo: widget.currentUserId)
        .where('toUserId', isEqualTo: widget.contactUserId)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }

    final reverseQuerySnapshot = await invitationsCollection
        .where('fromUserId', isEqualTo: widget.contactUserId)
        .where('toUserId', isEqualTo: widget.currentUserId)
        .get();

    for (var doc in reverseQuerySnapshot.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('contacts')
        .doc(widget.contactUserId)
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.contactUserId)
        .collection('contacts')
        .doc(widget.currentUserId)
        .delete();

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId);
    await userRef.set(
      {
        'blockedUsers': FieldValue.arrayUnion([widget.contactUserId]),
      },
      SetOptions(merge: true),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact blocked and invitation removed.')),
    );
  }

  void _deleteMessage(String messageId) {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> _showDeleteConfirmation(String messageId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      _deleteMessage(messageId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    DateTime messageDate = _messages[index].timestamp;
                    bool showDateSeparator = index == _messages.length - 1 ||
                        messageDate.day != _messages[index + 1].timestamp.day ||
                        messageDate.month !=
                            _messages[index + 1].timestamp.month ||
                        messageDate.year != _messages[index + 1].timestamp.year;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDateSeparator) _buildDateSeparator(messageDate),
                        GestureDetector(
                          onLongPress: () =>
                              _showDeleteConfirmation(_messages[index].id),
                          child: _buildChatBubble(_messages[index]),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildMessageInput(),
            ],
          ),
          if (_isPreviewingImage) _buildImagePreviewOverlay(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    Color dotColor;
    if (_availabilityStatus == 'available') {
      dotColor = Colors.green;
    } else if (_availabilityStatus == 'away') {
      dotColor = Colors.yellow;
    } else {
      dotColor = Colors.grey;
    }

    return AppBar(
      toolbarHeight: 65,
      backgroundColor: const Color.fromARGB(255, 1, 77, 164),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(widget.profileImageUrl),
            radius: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis, // Add this line
                  maxLines: 1, // Add this line
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _availabilityStatus,
                      style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () => _showOptions(context),
        ),
      ],
    );
  }

  Widget _buildImagePreviewOverlay() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // Semi-transparent background overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.8),
          ),
        ),
        // Centered image preview
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.contain,
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.6,
            ),
          ),
        ),
        // Progress bar or action buttons at the bottom
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: _isUploadingImage
              ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Sending...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 10),
              // LinearProgressIndicator with rounded corners
              ClipRRect(
                borderRadius: BorderRadius.circular(8), // Rounded corners
                child: LinearProgressIndicator(
                  value: _uploadProgress, // Displays upload progress
                  minHeight: 6, // Slightly thicker progress bar
                  backgroundColor: Colors.grey[700],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _uploadProgress == 1.0
                        ? const Color.fromARGB(255, 1, 77, 164) // Color when completed
                        : const Color.fromARGB(255, 1, 77, 164), // Default progress color
                  ),
                ),
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel Button
              FloatingActionButton(
                heroTag: 'cancel',
                backgroundColor: Colors.redAccent,
                onPressed: () {
                  setState(() {
                    _isPreviewingImage = false;
                    _selectedImage = null;
                  });
                },
                child: const Icon(Icons.cancel, color: Colors.white),
              ),
              // Send Button
              FloatingActionButton(
                heroTag: 'send',
                backgroundColor: Colors.green,
                onPressed: _sendImageMessage,
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }




  Widget _buildDateSeparator(DateTime date) {
    String formattedDate = DateFormat.yMMMMd().format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[400]!.withOpacity(0.3),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            formattedDate,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    String formattedTime = DateFormat.jm().format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Align(
        alignment: message.isFromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: message.isFromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.content.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.network(
                    message.content,
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.6, // 60% of screen width for image
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Icon(Icons.error, color: Colors.redAccent),
                    ),
                  ),
                ),
              )
            else
            // Regular message bubble for text messages
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8, // 80% of screen width for text
                ),
                decoration: BoxDecoration(
                  color: message.isFromUser
                      ? const Color.fromARGB(255, 1, 77, 164)
                      : Colors.grey[300],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 1),
                      blurRadius: 5,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: message.isFromUser ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
            const SizedBox(height: 5),

            // Read/Delivered indicators for both image and text messages
            if (message.isFromUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: message.isRead ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: message.isRead ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 5),

            // Timestamp for both text and image messages
            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Color.fromARGB(255, 1, 77, 164)),
            onPressed: _pickAndSendMedia,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1, // Start with a single line
              maxLines: 4, // Allow it to grow up to 4 lines
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(fontSize: 16, color: Colors.black54),
                filled: true,
                fillColor: const Color.fromARGB(255, 1, 77, 164).withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              textInputAction: TextInputAction.newline, // Allows Enter to add a new line
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 1, 77, 164),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.arrow_upward, color: Colors.white),
          ),
        ],
      ),
    );
  }



  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text(
                'Block Contact',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _blockContact();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.grey[700]),
              title: const Text(
                'Delete Chat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _clearChat();
              },
            ),
          ],
        );
      },
    );
  }
}
