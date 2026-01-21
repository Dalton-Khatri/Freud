class YouTubeConfig {

  static const Map<String, List<VideoLink>> moodVideos = {
    'happy': [
      VideoLink(
        title: 'Uplifting Music for Happy Moments',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Feel-Good Vibes Playlist',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Positive Energy Boost',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Joyful Moments Collection',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
    ],
    
    'calm': [
      VideoLink(
        title: 'Relaxing Meditation Music',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Peaceful Nature Sounds',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Deep Breathing Exercises',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Calming Piano Music',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
    ],
    
    'sad': [
      VideoLink(
        title: 'Comforting Music for Tough Times',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Healing & Recovery Playlist',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Emotional Support & Encouragement',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Hope & Strength Collection',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
    ],
    
    'anxious': [
      VideoLink(
        title: 'Anxiety Relief Meditation',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Stress Reduction Techniques',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Grounding Exercises',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
      VideoLink(
        title: 'Calming Your Mind',
        url: 'https://www.youtube.com/watch?v=aqCxlxclyzo',
      ),
    ],
  };

  // Get videos for a specific mood
  static List<VideoLink> getVideosForMood(String mood) {
    return moodVideos[mood.toLowerCase()] ?? [];
  }
}

class VideoLink {
  final String title;
  final String url;

  const VideoLink({
    required this.title,
    required this.url,
  });
}