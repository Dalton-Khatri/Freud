import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_service.dart';
import '../../utils/theme.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/chat_input.dart';
import '../../widgets/conversation_feedback_dialog.dart';
import '../../widgets/crisis_alert_dialog.dart';

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
    final details =
        await firebaseService.getConversationDetails(widget.conversationId);

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
    if (_conversationTitle == 'New Conversation' && !_hasFeedback) {
      final result = await showDialog<Map<String, dynamic>?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ConversationFeedbackDialog(),
      );

      if (result != null) {
        final firebaseService =
            Provider.of<FirebaseService>(context, listen: false);
        await firebaseService.updateConversationDetails(
          conversationId: widget.conversationId,
          name: result['name'],
          feedback:
              result['feedback'].isNotEmpty ? result['feedback'] : null,
          rating: result['rating'],
        );
      }
    }
    return true;
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final firebaseService =
        Provider.of<FirebaseService>(context, listen: false);

    try {
      final isCrisis = _aiService.detectCrisis(text);

      // Show crisis alert
      if (isCrisis && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const CrisisAlertDialog(),
        );
      }

      // Add user message
      await firebaseService.addMessage(
        conversationId: widget.conversationId,
        content: text.trim(),
        role: 'user',
        crisisDetected: isCrisis,
      );

      setState(() => _isAITyping = true);

      final chatContext =
          await firebaseService.getRecentMessagesForContext(
        conversationId: widget.conversationId,
        limit: 10,
      );

      // Call AI service to generate response
      final aiResponse =
          await _aiService.generateResponse(chatContext);

      // Add AI message
      await firebaseService.addMessage(
        conversationId: widget.conversationId,
        content: aiResponse,
        role: 'assistant',
      );

      setState(() => _isAITyping = false);

      Future.delayed(
        const Duration(milliseconds: 100),
        _scrollToBottom,
      );
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
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          title: const Text('Chat', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF0A0A0A),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.8)),
              color: const Color(0xFF1A1A1A),
              onSelected: (value) {
                if (value == 'rename') {
                  _showRenameDialog();
                } else if (value == 'delete') {
                  _showDeleteDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.8)),
                      const SizedBox(width: 8),
                      const Text('Edit name & feedback', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('Delete conversation', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    firebaseService.getMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.waving_hand,
                            size: 60,
                            color: const Color(0xFF6C63FF),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Hi! I\'m Freud',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'How can I support you today?',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance
                      .addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final data =
                          messages[index].data()
                              as Map<String, dynamic>;

                      return MessageBubble(
                        message: data['content'] ?? '',
                        isUser: data['role'] == 'user',
                        timestamp:
                            data['timestamp'] as Timestamp?,
                      );
                    },
                  );
                },
              ),
            ),
            if (_isAITyping)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Freud is typing...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ChatInput(
              onSend: _handleSendMessage,
              enabled: !_isAITyping,
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() async {
    final firebaseService =
        Provider.of<FirebaseService>(context, listen: false);
    final details =
        await firebaseService.getConversationDetails(
            widget.conversationId);

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
        feedback:
            result['feedback'].isNotEmpty ? result['feedback'] : null,
        rating: result['rating'],
      );

      setState(() {
        _conversationTitle = result['name'];
        _hasFeedback = true;
      });
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Conversation',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final firebaseService =
                  Provider.of<FirebaseService>(context,
                      listen: false);
              await firebaseService
                  .deleteConversation(widget.conversationId);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
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