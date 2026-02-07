import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up 
  Future<UserCredential> signUp({
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

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);
      
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
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      
      // Provide user-friendly error messages
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        default:
          errorMessage = 'Signup failed: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('Signup error: $e');
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  // Sign in
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Login successful for: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      
      // Provide user-friendly error messages
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('Login error: $e');
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
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

  // Delete mood entry
  Future<void> deleteMoodEntry(int index) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final moodTracking = List.from(data['moodTracking'] ?? []);
      
      if (index >= 0 && index < moodTracking.length) {
        moodTracking.removeAt(index);
        
        await _firestore.collection('users').doc(currentUserId).update({
          'moodTracking': moodTracking,
        });
      }
    }
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
      'isSaved': false, // Add default value for saved status
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

  // Update conversation with name, feedback, and rating
  Future<void> updateConversationDetails({
    required String conversationId,
    String? name,
    String? feedback,
    int? rating,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) {
      updates['title'] = name;
    }
    if (feedback != null) {
      updates['feedback'] = feedback;
    }
    if (rating != null) {
      updates['rating'] = rating;
    }

    await _firestore.collection('conversations').doc(conversationId).update(updates);
  }

  // Get conversation details
  Future<Map<String, dynamic>?> getConversationDetails(String conversationId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final doc = await _firestore.collection('conversations').doc(conversationId).get();
    
    if (doc.exists) {
      return doc.data();
    }
    return null;
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

  // Toggle save/bookmark conversation
  Future<void> toggleSaveConversation(String conversationId, bool isSaved) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    await _firestore.collection('conversations').doc(conversationId).update({
      'isSaved': isSaved,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get saved conversations
  Stream<QuerySnapshot> getSavedConversations() {
    if (currentUserId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('conversations')
        .where('userId', isEqualTo: currentUserId)
        .where('isSaved', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

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