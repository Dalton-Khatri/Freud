import 'dart:convert';

class AIService {
 
  static const String _crisisMessage = """
I'm concerned about what you're sharing. Please know that you're not alone, and there are people who can help immediately.

🆘 Nepal Crisis Helplines:
• National Mental Health Helpline: 1660 0102005
• Transcultural Psychosocial Organization (TPO): 9840021600
• Centre for Mental Health and Counselling (CMC): 01-4102037

If you're in immediate danger, please:
• Call Police: 100
• Call Ambulance: 102
• Reach out to a trusted friend or family member

I'm here to support you, but professional help is crucial right now. Please consider calling one of these numbers.""";

  static final List<String> _crisisKeywords = [
    // English
    'suicide', 'kill myself', 'end it all', 'want to die', 
    'self harm', 'hurt myself', 'no reason to live',
    'better off dead', 'end my life', 'take my life',
    
    // Nepali (romanized)
    'aatmahatya', 'marnu', 'jeevan sakaunu',
  ];

  String _detectEmotion(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Sadness indicators
    if (lowerMessage.contains(RegExp(r'\b(sad|lonely|empty|depressed|down|hopeless|cry|tears|crying)\b'))) {
      return 'sad';
    }
    
    // Anxiety indicators
    if (lowerMessage.contains(RegExp(r'\b(anxious|anxiety|worry|worried|nervous|panic|scared|afraid|fear)\b'))) {
      return 'anxious';
    }
    
    // Stress indicators
    if (lowerMessage.contains(RegExp(r'\b(stress|stressed|overwhelm|overwhelmed|pressure|exhausted|tired|exam|exams|test|deadline)\b'))) {
      return 'stressed';
    }
    
    // Anger indicators
    if (lowerMessage.contains(RegExp(r'\b(angry|mad|furious|frustrated|irritated|annoyed)\b'))) {
      return 'angry';
    }
    
    // Happiness indicators
    if (lowerMessage.contains(RegExp(r'\b(happy|joy|joyful|excited|great|good|wonderful|amazing)\b'))) {
      return 'happy';
    }
    
    // Default
    return 'neutral';
  }
  bool detectCrisis(String message) {
    final lowerMessage = message.toLowerCase();
    return _crisisKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  Future<String> generateResponse(List<Map<String, dynamic>> context) async {
    try {
      // Get the last user message
      final lastUserMessage = context.lastWhere(
        (msg) => msg['role'] == 'user',
        orElse: () => {'content': ''},
      )['content'] as String;

      // CRISIS DETECTION
      if (detectCrisis(lastUserMessage)) {
        return _crisisMessage;
      }

      // Detect emotion
      final emotion = _detectEmotion(lastUserMessage);
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('💭 User Message: $lastUserMessage');
      print('🎭 Detected Emotion: $emotion');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Generate context-aware response
      return _generateContextualResponse(lastUserMessage, emotion, context);
      
    } catch (e) {
      print('💥 AI Service Error: $e');
      return "I'm here to listen. Can you tell me more about how you're feeling?";
    }
  }

  String _generateContextualResponse(
    String message,
    String emotion,
    List<Map<String, dynamic>> context,
  ) {
    final lowerMessage = message.toLowerCase();
    final conversationLength = context.length;
    
    // First message
    if (conversationLength <= 2) {
      return _getGreetingResponse(emotion);
    }
    
    // Emotion-specific responses
    switch (emotion) {
      case 'stressed':
        return _getStressResponse(lowerMessage);
      
      case 'anxious':
        return _getAnxietyResponse(lowerMessage);
      
      case 'sad':
        return _getSadnessResponse(lowerMessage);
      
      case 'angry':
        return _getAngerResponse(lowerMessage);
      
      case 'happy':
        return _getHappinessResponse(lowerMessage);
      
      default:
        return _getNeutralResponse(lowerMessage);
    }
  }

  String _getGreetingResponse(String emotion) {
    final greetings = [
      "Hello! I'm Freud, your AI companion for mental wellness. I'm here to listen and support you. How are you feeling today?",
      "Hi there! I'm glad you reached out. I'm here to listen without judgment. What's on your mind?",
      "Welcome! This is a safe space for you to share your thoughts and feelings. How can I support you today?",
    ];
    return greetings[DateTime.now().millisecond % greetings.length];
  }

  String _getStressResponse(String message) {
    if (message.contains('exam') || message.contains('test') || message.contains('study')) {
      final responses = [
        "Exam stress is really common, and it's understandable you're feeling this way. Have you tried breaking your study time into smaller, manageable chunks? Sometimes taking short breaks can help you feel more in control.",
        "I hear you - exam pressure can feel overwhelming. Remember, your worth isn't determined by exam results. Would you like to talk about specific subjects that are worrying you?",
        "Feeling stressed about exams shows you care about doing well, which is natural. What's the biggest challenge you're facing with your preparation right now?",
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
    
    if (message.contains('work') || message.contains('job')) {
      return "Work stress can be really draining. It's important to set boundaries and take time for yourself. What aspect of work is causing you the most stress right now?";
    }
    
    final generalStress = [
      "Stress can feel overwhelming, but talking about it is a great first step. Let's work through this together. What's weighing on you most heavily?",
      "I understand you're going through a stressful time. Would it help to talk about what's causing this stress? Sometimes just expressing it can provide some relief.",
      "Feeling stressed is your mind and body's way of responding to pressure. Let's explore what's triggering these feelings and find ways to manage them.",
    ];
    return generalStress[DateTime.now().millisecond % generalStress.length];
  }

  String _getAnxietyResponse(String message) {
    final responses = [
      "Anxiety can be really difficult to manage. Have you tried grounding exercises? One simple technique is the 5-4-3-2-1 method: notice 5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell, and 1 you can taste.",
      "I hear that you're feeling anxious. Remember, anxiety is often our mind trying to protect us, but sometimes it can be overwhelming. Would you like to talk about what's triggering these feelings?",
      "Dealing with anxiety isn't easy, and I'm glad you're reaching out. Deep breathing can help - try breathing in for 4 counts, holding for 4, and exhaling for 4. What specific situations make you feel most anxious?",
      "Your feelings of anxiety are valid. Sometimes writing down your worries can help. What's been making you feel most worried lately?",
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

  String _getSadnessResponse(String message) {
    if (message.contains('lonely') || message.contains('alone')) {
      return "Feeling lonely is really hard, and I'm sorry you're experiencing this. Please know that reaching out like this takes courage. You're not truly alone - I'm here to listen, and there are people who care about you. Would you like to talk about what's been making you feel this way?";
    }
    
    final responses = [
      "I hear that you're feeling sad. It's okay to feel this way - sadness is a natural emotion. Would you like to share what's been bringing you down?",
      "Sadness can feel heavy, but remember it's temporary. I'm here to listen. What's been on your mind lately?",
      "I'm sorry you're going through this difficult time. Your feelings are valid. Sometimes it helps to express them. What's been making you feel sad?",
      "Thank you for sharing how you feel. Sadness is part of being human. Would it help to talk about what triggered these feelings?",
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

  String _getAngerResponse(String message) {
    final responses = [
      "It sounds like you're dealing with some frustrating situations. Anger is a valid emotion, and it's important to acknowledge it. What's been making you feel this way?",
      "I can sense your frustration. Sometimes anger is masking other emotions like hurt or disappointment. Would you like to explore what's really bothering you?",
      "Feeling angry is okay - it's a natural response to certain situations. What would help you feel better right now?",
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

  String _getHappinessResponse(String message) {
    final responses = [
      "That's wonderful to hear! I'm so glad you're feeling positive. What's been bringing you joy?",
      "It's great that you're feeling good! Positive emotions are important to celebrate. What happened that made you feel this way?",
      "I love hearing that you're in good spirits! Would you like to share what's making you happy?",
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

  String _getNeutralResponse(String message) {
    // Check for questions
    if (message.contains('?')) {
      return "That's an important question. Let me understand better - can you tell me more about what's on your mind?";
    }
    
    // Check for short responses
    if (message.split(' ').length <= 3) {
      return "I'm listening. Would you like to tell me more about that?";
    }
    
    final responses = [
      "Thank you for sharing that with me. I'm here to listen. Can you tell me more about how this makes you feel?",
      "I appreciate you opening up. How does this situation affect you emotionally?",
      "I'm here with you. What else would you like to talk about?",
      "That sounds like something important to you. Would you like to explore this further?",
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }
}