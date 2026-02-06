import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../services/firebase_service.dart';

class MessageBubble extends StatefulWidget {
  final String message;
  final bool isUser;
  final Timestamp? timestamp;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.timestamp,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  String _userInitial = 'U';

  @override
  void initState() {
    super.initState();
    if (widget.isUser) {
      _loadUserInitial();
    }
  }

  Future<void> _loadUserInitial() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    
    firebaseService.getUserProfile().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final userData = snapshot.data() as Map<String, dynamic>;
        final displayName = userData['displayName'] ?? 'User';
        setState(() {
          _userInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
        });
      }
    });
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar (Freud - "F")
          if (!widget.isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.psychology_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Message Content
          Flexible(
            child: Column(
              crossAxisAlignment:
                  widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: widget.isUser ? AppTheme.primaryGradient : null,
                    color: widget.isUser
                        ? null
                        : const Color(0xFF111111),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(widget.isUser ? 16 : 4),
                      bottomRight: Radius.circular(widget.isUser ? 4 : 16),
                    ),
                    border: widget.isUser
                        ? null
                        : Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                  ),
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.isUser ? Colors.white : Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                if (widget.timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(widget.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // User Avatar (User's Initial)
          if (widget.isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _userInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}