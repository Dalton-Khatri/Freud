

class AIService {
  // TODO: Replace with your actual AI API endpoint
  // This is a placeholder - you'll integrate your trained model here
  final String apiUrl = 'YOUR_AI_API_ENDPOINT';
  final String apiKey = 'YOUR_API_KEY';

  Future<String> generateResponse(List<Map<String, dynamic>> context) async {
    try {
      // OPTION 1: Use your custom trained model API
      // Uncomment and modify when your AI model is deployed
      /*
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'messages': context,
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        throw Exception('Failed to get AI response');
      }
      */

      // OPTION 2: Temporary fallback responses for testing
      // Remove this when you have your AI model ready
      return _getFallbackResponse(context);
      
    } catch (e) {
      print('AI Service Error: $e');
      return "I'm here to listen. Could you tell me more about how you're feeling?";
    }
  }

  // Temporary fallback for testing without AI model
  String _getFallbackResponse(List<Map<String, dynamic>> context) {
    if (context.isEmpty) {
      return "Hello! I'm Freud, your AI mental health companion. I'm here to listen and support you. How are you feeling today?";
    }

    final lastMessage = context.last['content'].toString().toLowerCase();

    // Simple keyword-based responses for testing
    if (lastMessage.contains('anxious') || lastMessage.contains('anxiety')) {
      return "I understand you're feeling anxious. Anxiety can be overwhelming. Would you like to try a breathing exercise? Take a deep breath in for 4 counts, hold for 4, and exhale for 4.";
    } else if (lastMessage.contains('sad') || lastMessage.contains('depressed')) {
      return "I hear that you're going through a difficult time. It's okay to feel sad. Would you like to talk about what's making you feel this way?";
    } else if (lastMessage.contains('stressed') || lastMessage.contains('stress')) {
      return "Stress can be really challenging to deal with. Let's work through this together. What's the main source of your stress right now?";
    } else if (lastMessage.contains('happy') || lastMessage.contains('good') || lastMessage.contains('great')) {
      return "That's wonderful to hear! I'm glad you're feeling positive. Would you like to share what's bringing you joy?";
    } else if (lastMessage.contains('help') || lastMessage.contains('crisis')) {
      return "I'm concerned about you. If you're in crisis, please reach out to a professional immediately. You can call the National Suicide Prevention Lifeline at 988. I'm here to support you, but I'm not a replacement for professional help.";
    } else {
      return "Thank you for sharing that with me. I'm listening. Can you tell me more about how this makes you feel?";
    }
  }

  // Crisis detection (simple keyword-based for now)
  bool detectCrisis(String message) {
    final crisisKeywords = [
      'suicide',
      'kill myself',
      'end it all',
      'want to die',
      'self harm',
      'hurt myself',
    ];

    final lowerMessage = message.toLowerCase();
    return crisisKeywords.any((keyword) => lowerMessage.contains(keyword));
  }
}