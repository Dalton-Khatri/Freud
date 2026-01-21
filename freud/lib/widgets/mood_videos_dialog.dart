// lib/widgets/mood_videos_dialog.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/youtube_config.dart';
import '../utils/theme.dart';

class MoodVideosDialog extends StatelessWidget {
  final String mood;
  final String emoji;

  const MoodVideosDialog({
    super.key,
    required this.mood,
    required this.emoji,
  });

  Future<void> _launchYouTube(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in YouTube app
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open YouTube link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getMoodColor() {
    switch (mood.toLowerCase()) {
      case 'happy':
        return AppTheme.moodColors['happy']!;
      case 'calm':
        return AppTheme.moodColors['calm']!;
      case 'sad':
        return AppTheme.moodColors['sad']!;
      case 'anxious':
        return AppTheme.moodColors['anxious']!;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _getMoodMessage() {
    switch (mood.toLowerCase()) {
      case 'happy':
        return 'Let\'s celebrate your joy! 🎉';
      case 'calm':
        return 'Here are some peaceful vibes for you 🧘';
      case 'sad':
        return 'You\'re not alone. These might help 💙';
      case 'anxious':
        return 'Let\'s ease that anxiety together 🌿';
      default:
        return 'Recommended for you';
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = YouTubeConfig.getVideosForMood(mood);
    final moodColor = _getMoodColor();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Emoji
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: moodColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mood Title
                  Text(
                    'Feeling ${mood.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Message
                  Text(
                    _getMoodMessage(),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Video List
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended Videos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Video Cards
                  ...videos.asMap().entries.map((entry) {
                    final index = entry.key;
                    final video = entry.value;
                    
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < videos.length - 1 ? 12 : 0,
                      ),
                      child: _buildVideoCard(context, video, moodColor),
                    );
                  }).toList(),
                ],
              ),
            ),

            // Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, VideoLink video, Color moodColor) {
    return InkWell(
      onTap: () => _launchYouTube(context, video.url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            // YouTube Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.play_circle_fill,
                color: moodColor,
                size: 28,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Video Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.ondemand_video,
                        size: 14,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'YouTube Video',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textLight,
            ),
          ],
        ),
      ),
    );
  }
}