import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_service.dart';
import '../../utils/theme.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/chat_input.dart';
import '../../widgets/conversation_feedback_dialog.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;

  const ChatScreen({
    super.key,
    required this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  bool _isAITyping = false;
  bool _hasFeedback = false;
  String? _conversationTitle;

  @override
  void initState() {
    super.initState();
    _loadConversationDetails();
  }

  Future<void> _loadConversationDetails() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final details = await firebaseService.getConversationDetails(widget.conversationId);
    
    if (details != null && mounted) {
      setState(() {
        _conversationTitle = details['title'];
        _hasFeedback = details['feedback'] != null || details['rating'] != null;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppTheme.mediumAnimation,
        curve: Curves.easeOut,
      );
    }
  }

  Future<bool> _onWillPop() async {
    // Only show feedback dialog if:
    // 1. Title is "New Conversation" (hasn't been named yet)
    // 2. No feedback has been given yet
    if (_conversationTitle == 'New Conversation' && !_hasFeedback) {
      final result = await showDialog<Map<String, dynamic>?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ConversationFeedbackDialog(),
      );

      if (result != null) {
        // Save the feedback
        final firebaseService = Provider.of<FirebaseService>(context, listen: false);
        await firebaseService.updateConversationDetails(
          conversationId: widget.conversationId,
          name: result['name'],
          feedback: result['feedback'].isNotEmpty ? result['feedback'] : null,
          rating: result['rating'],
        );
      }
    }
    
    return true; // Allow back navigation
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    try {
      // Add user message
      await firebaseService.addMessage(
        conversationId: widget.conversationId,
        content: text.trim(),
        role: 'user',
      );

      setState(() => _isAITyping = true);

      // Get conversation context
      final context = await firebaseService.getRecentMessagesForContext(
        conversationId: widget.conversationId,
        limit: 10,
      );

      // Get AI response
      final aiResponse = await _aiService.generateResponse(context);

      // Add AI message
      await firebaseService.addMessage(
        conversationId: widget.conversationId,
        content: aiResponse,
        role: 'assistant',
      );

      setState(() => _isAITyping = false);
      
      // Scroll to bottom after messages are added
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      setState(() => _isAITyping = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') {
                  _showRenameDialog();
                } else if (value == 'delete') {
                  _showDeleteDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('Edit name & feedback'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete conversation'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Messages List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firebaseService.getMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.waving_hand,
                            size: 60,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Hi! I\'m Freud',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'How can I support you today?',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  // Auto-scroll when new messages arrive
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final doc = messages[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      return MessageBubble(
                        message: data['content'] ?? '',
                        isUser: data['role'] == 'user',
                        timestamp: data['timestamp'] as Timestamp?,
                      );
                    },
                  );
                },
              ),
            ),

            // AI Typing Indicator
            if (_isAITyping)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.aiMessageColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTypingDot(0),
                          const SizedBox(width: 4),
                          _buildTypingDot(1),
                          const SizedBox(width: 4),
                          _buildTypingDot(2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Chat Input
            ChatInput(
              onSend: _handleSendMessage,
              enabled: !_isAITyping,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final offset = (index * 0.2);
        final animation = (value + offset) % 1.0;
        final opacity = (animation < 0.5) 
            ? animation * 2 
            : 2 - (animation * 2);
        
        return Opacity(
          opacity: opacity.clamp(0.3, 1.0),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final details = await firebaseService.getConversationDetails(widget.conversationId);
    
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => ConversationFeedbackDialog(
        initialName: details?['title'],
        initialFeedback: details?['feedback'],
        initialRating: details?['rating'],
      ),
    );

    if (result != null && mounted) {
      await firebaseService.updateConversationDetails(
        conversationId: widget.conversationId,
        name: result['name'],
        feedback: result['feedback'].isNotEmpty ? result['feedback'] : null,
        rating: result['rating'],
      );

      setState(() {
        _conversationTitle = result['name'];
        _hasFeedback = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final firebaseService = Provider.of<FirebaseService>(
                context,
                listen: false,
              );
              
              await firebaseService.deleteConversation(widget.conversationId);
              
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to home
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}