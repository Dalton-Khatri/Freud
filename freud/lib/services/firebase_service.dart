
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== AUTHENTICATION ====================

  // Sign up - FIXED VERSION
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Create auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('User created: ${userCredential.user?.uid}');

      // IMPORTANT: Wait for auth to fully complete
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Create Firestore profile
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'displayName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'preferences': {
            'voiceEnabled': false,
            'theme': 'light',
            'notificationsEnabled': true,
          },
          'moodTracking': [],
        });
        
        print('Profile created for: $displayName');
      }
    } catch (e) {
      print('Signup error: $e');
      rethrow;
    }
  }

 // Sign in - FIXED VERSION
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Login successful');
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==================== USER OPERATIONS ====================

  // Create user profile
  Future<void> createUserProfile({
    required String email,
    required String displayName,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(currentUserId).set({
      'email': email,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
      'preferences': {
        'voiceEnabled': false,
        'theme': 'light',
        'notificationsEnabled': true,
      },
      'moodTracking': [],
    });
  }

  // Update last active
  Future<void> updateLastActive() async {
    if (currentUserId == null) return;

    await _firestore.collection('users').doc(currentUserId).set({
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Add mood entry
  Future<void> addMoodEntry({
    required String mood,
    String? note,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(currentUserId).set({
      'moodTracking': FieldValue.arrayUnion([
        {
          'date': Timestamp.now(),
          'mood': mood,
          'note': note ?? '',
        }
      ]),
    }, SetOptions(merge: true));
  }

  // Update preferences
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(currentUserId).set({
      'preferences': preferences,
    }, SetOptions(merge: true));
  }

  // Get user profile
  Stream<DocumentSnapshot> getUserProfile() {
    if (currentUserId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(currentUserId).snapshots();
  }

  // ==================== CONVERSATION OPERATIONS ====================

  // Create conversation
  Future<String> createConversation({required String title}) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final conversationRef = _firestore.collection('conversations').doc();
    
    final ttlExpiry = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 90)),
    );

    await conversationRef.set({
      'userId': currentUserId,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'messageCount': 0,
      'ttlExpiry': ttlExpiry,
    });

    return conversationRef.id;
  }

  // Get conversations
  Stream<QuerySnapshot> getConversations() {
    if (currentUserId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('conversations')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // Update conversation
  Future<void> updateConversation({
    required String conversationId,
    required String lastMessage,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    await _firestore.collection('conversations').doc(conversationId).update({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': lastMessage,
      'messageCount': FieldValue.increment(1),
    });
  }

  // Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final messagesSnapshot = await _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_firestore.collection('conversations').doc(conversationId));
    await batch.commit();
  }

  // ==================== MESSAGE OPERATIONS ====================

  // Add message
  Future<void> addMessage({
    required String conversationId,
    required String content,
    required String role,
    String? sentiment,
    bool crisisDetected = false,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final ttlExpiry = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 90)),
    );

    await _firestore.collection('messages').add({
      'conversationId': conversationId,
      'userId': currentUserId,
      'content': content,
      'role': role,
      'timestamp': FieldValue.serverTimestamp(),
      'sentiment': sentiment,
      'crisisDetected': crisisDetected,
      'ttlExpiry': ttlExpiry,
    });

    if (role == 'user') {
      await updateConversation(
        conversationId: conversationId,
        lastMessage: content,
      );
    }
  }

  // Get messages
  Stream<QuerySnapshot> getMessages(String conversationId) {
    if (currentUserId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('userId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get recent messages for AI context
  Future<List<Map<String, dynamic>>> getRecentMessagesForContext({
    required String conversationId,
    int limit = 20,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final snapshot = await _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('userId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.reversed.map((doc) {
      final data = doc.data();
      return {
        'role': data['role'],
        'content': data['content'],
      };
    }).toList();
  }

  // Cleanup expired data
  Future<void> cleanupExpiredData() async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final now = Timestamp.now();

    final expiredMessages = await _firestore
        .collection('messages')
        .where('userId', isEqualTo: currentUserId)
        .where('ttlExpiry', isLessThan: now)
        .get();

    final batch = _firestore.batch();
    for (var doc in expiredMessages.docs) {
      batch.delete(doc.reference);
    }

    final expiredConversations = await _firestore
        .collection('conversations')
        .where('userId', isEqualTo: currentUserId)
        .where('ttlExpiry', isLessThan: now)
        .get();

    for (var doc in expiredConversations.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}