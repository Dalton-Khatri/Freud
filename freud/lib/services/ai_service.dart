import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String backendUrl = 'https://dalton-khatri-freud-ai.hf.space';
  static const int timeout = 60;
  static const bool debugMode = true;

  static const String _crisisMessage = """
I'm concerned about what you're sharing. Please know that you're not alone, and there are people who can help immediately.

Nepal Crisis Helplines:
• National Mental Health Helpline: 1660 0102005
• Transcultural Psychosocial Organization (TPO): 9840021600
• Centre for Mental Health and Counselling (CMC): 01-4102037

If you're in immediate danger, please:
• Call Police: 100
• Call Ambulance: 102
• Reach out to a trusted friend or family member

I'm here to support you, but professional help is crucial right now. Please consider calling one of these numbers.""";

  static final List<String> _crisisKeywords = [
    'suicide', 'kill myself', 'end it all', 'want to die',
    'self harm', 'hurt myself', 'no reason to live',
    'better off dead', 'end my life', 'take my life',
    'aatmahatya', 'marnu', 'jeevan sakaunu',
  ];

  bool detectCrisis(String message) {
    final lowerMessage = message.toLowerCase();
    return _crisisKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  String _detectEmotion(String message) {
    final lowerMessage = message.toLowerCase();

    // Emotion detection (same as before - works well!)
    if (lowerMessage.contains(RegExp(r'\b(sad|lonely|empty|depressed|down|hopeless|cry|tears)\b'))) {
      return 'sad';
    }
    if (lowerMessage.contains(RegExp(r'\b(anxious|anxiety|worry|worried|nervous|panic|scared|afraid|fear)\b'))) {
      return 'anxious';
    }
    if (lowerMessage.contains(RegExp(r'\b(stress|stressed|overwhelm|overwhelmed|pressure|exhausted|tired)\b'))) {
      return 'stressed';
    }
    if (lowerMessage.contains(RegExp(r'\b(angry|mad|furious|frustrated|irritated|annoyed)\b'))) {
      return 'angry';
    }
    if (lowerMessage.contains(RegExp(r'\b(happy|joy|joyful|excited|great|good|wonderful|amazing)\b'))) {
      return 'happy';
    }
    return 'neutral';
  }

  String _buildPrompt(List<Map<String, dynamic>> context) {
    final StringBuffer prompt = StringBuffer();

    // Enhanced system prompt with clear boundaries
    prompt.writeln('<|system|>: You are Freud, a calm, empathetic therapeutic AI assistant. '
        'You respond thoughtfully, kindly, and supportively. '
        'You ask gentle follow-up questions and never judge the user. '
        'Respond in 1-3 sentences only. Do not continue the conversation or add user responses.');

    // Build conversation history (last 10 messages)
    for (var message in context.take(10)) {
      final role = message['role'];
      final content = message['content'];

      if (role == 'user') {
        final emotion = _detectEmotion(content);
        prompt.writeln('<|user|>:');
        prompt.writeln('[emotion: $emotion]');
        prompt.writeln(content);
      } else if (role == 'assistant') {
        prompt.writeln('<|assistant|>:');
        prompt.writeln(content);
      }
    }

    // Add final assistant tag
    prompt.write('<|assistant|>:\n');
    return prompt.toString();
  }

  bool _isValidResponse(String response) {
    // Enhanced validation to catch tag leakage
    
    // Check for empty or too short
    if (response.isEmpty || response.trim().length < 10) {
      return false;
    }

    // Check for tag leakage (critical issue from testing)
    if (response.contains('<|user|>') || 
        response.contains('<^user|>') ||
        response.contains('<|assistant|>') ||
        response.contains('<|system|>')) {
      if (debugMode) print(' Validation failed: Tag leakage detected');
      return false;
    }

    // Check for emotion tag leakage
    if (response.contains('[emotion:')) {
      if (debugMode) print(' Validation failed: Emotion tag detected');
      return false;
    }

    // Check for special markers
    if (RegExp(r'\*\|[a-z]+\d*\|').hasMatch(response)) {
      if (debugMode) print(' Validation failed: Special markers detected');
      return false;
    }

    // Check for excessive punctuation (gibberish)
    if (response.replaceAll(RegExp(r'[^!]'), '').length > 10) {
      if (debugMode) print(' Validation failed: Excessive exclamation marks');
      return false;
    }

    // Check for error messages
    if (response.toLowerCase().startsWith('error')) {
      return false;
    }

    // All checks passed
    return true;
  }

  String _cleanResponse(String response) {
    // Additional client-side cleaning as safety net
    String cleaned = response;

    // Remove any remaining tags (just in case backend missed them)
    cleaned = cleaned.replaceAll(RegExp(r'<\|.*?\|>:?'), '');
    cleaned = cleaned.replaceAll(RegExp(r'<\^.*?\|>:?'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[emotion:\s*\w+\]', caseSensitive: false), '');
    
    // Remove role labels
    cleaned = cleaned.replaceAll(RegExp(r'^(User:|Assistant:|Freud:|System:)\s*', multiLine: true), '');
    
    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  Future<String> generateResponse(List<Map<String, dynamic>> context) async {
    try {
      final lastUserMessage = context.lastWhere(
        (msg) => msg['role'] == 'user',
        orElse: () => {'content': ''},
      )['content'] as String;

      // Crisis check (keep this - works well!)
      if (detectCrisis(lastUserMessage)) {
        return _crisisMessage;
      }

      final prompt = _buildPrompt(context);

      if (debugMode) {
        print(' Sending to: $backendUrl/generate');
        print(' Prompt length: ${prompt.length} chars');
      }

      // Call FastAPI endpoint
      final response = await http.post(
        Uri.parse('$backendUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'max_tokens': 150,
          'temperature': 0.7,
        }),
      ).timeout(Duration(seconds: timeout));

      if (debugMode) {
        print(' Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String generatedText = data['response'] ?? '';

        if (debugMode) {
          print(' Raw response: ${generatedText.substring(0, generatedText.length < 100 ? generatedText.length : 100)}...');
        }

        // Additional client-side cleaning
        generatedText = _cleanResponse(generatedText);

        // Validate response quality
        if (!_isValidResponse(generatedText)) {
          if (debugMode) {
            print('Response failed validation, using fallback');
          }
          return _getFallbackResponse(context);
        }

        // Check for empty response
        if (generatedText.isEmpty || generatedText.startsWith('Error:')) {
          if (debugMode) {
            print(' Empty or error response, using fallback');
          }
          return _getFallbackResponse(context);
        }

        if (debugMode) {
          print(' Response validated successfully');
        }

        return generatedText;

      } else if (response.statusCode == 503) {
        return "I'm waking up! Please try again in a moment.";
      } else {
        if (debugMode) {
          print(' HTTP Error ${response.statusCode}');
        }
        return _getFallbackResponse(context);
      }

    } on TimeoutException {
      if (debugMode) {
        print(' Request timed out');
      }
      return "I'm taking longer than usual. Please try again.";
    } catch (e) {
      if (debugMode) {
        print('Error: $e');
      }
      return _getFallbackResponse(context);
    }
  }

  String _getFallbackResponse(List<Map<String, dynamic>> context) {
    
    if (context.isEmpty) {
      return "Hello! I'm Freud, your AI companion for mental wellness. I'm here to listen and support you. How are you feeling today?";
    }

    final lastMessage = context.last['content'].toString().toLowerCase();

    if (lastMessage.contains(RegExp(r'\b(anxious|anxiety|worry)\b'))) {
      return "I understand you're feeling anxious. That can be really overwhelming. Would you like to try a simple breathing exercise? Take a deep breath in for 4 counts, hold for 4, and exhale for 4.";
    } else if (lastMessage.contains(RegExp(r'\b(sad|depressed|down|lonely)\b'))) {
      return "I hear that you're going through a difficult time. It's okay to feel this way. Would you like to talk about what's making you feel sad?";
    } else if (lastMessage.contains(RegExp(r'\b(stressed|overwhelm)\b'))) {
      return "Stress can be really challenging. Let's work through this together. What's the main source of your stress right now?";
    } else if (lastMessage.contains(RegExp(r'\b(happy|good|great|wonderful)\b'))) {
      return "That's wonderful to hear! I'm glad you're feeling positive. Would you like to share what's bringing you joy?";
    } else {
      return "Thank you for sharing that with me. I'm listening. Can you tell me more about how you're feeling?";
    }
  }
}