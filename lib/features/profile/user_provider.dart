import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserProfile {
  final String userId; // Unique user ID (from Supabase auth)
  final String name;
  final String phoneNumber;
  final String email;
  final String? profileImageUrl;

  UserProfile({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.email,
    this.profileImageUrl,
  });

  UserProfile copyWith({
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    String? profileImageUrl,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'phoneNumber': phoneNumber,
    'email': email,
    'profileImageUrl': profileImageUrl,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] ?? 'default_user',
      name: json['name'] ?? 'User',
      phoneNumber: json['phoneNumber'] ?? '',
      email: json['email'] ?? '',
      profileImageUrl: json['profileImageUrl'],
    );
  }

  // Default profile for development/testing
  factory UserProfile.demo() {
    return UserProfile(
      userId: 'user_12345',
      name: 'Rajesh Kumar',
      phoneNumber: '+91 98765 43210',
      email: 'rajesh@aquafarm.com',
      profileImageUrl: 'https://i.pravatar.cc/150?img=3',
    );
  }
}

// Global SharedPreferences instance (set by main.dart)
SharedPreferences? _sharedPreferences;

void initializeUserProvider(SharedPreferences prefs) {
  _sharedPreferences = prefs;
}

class UserNotifier extends StateNotifier<UserProfile> {
  static const String _storageKey = 'user_profile';

  UserNotifier() : super(UserProfile.demo()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_sharedPreferences == null) return;
    try {
      final jsonString = _sharedPreferences!.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        state = UserProfile.fromJson(json);
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (_sharedPreferences == null) return;
    try {
      await _sharedPreferences!.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (e) {
      print('Error saving user profile: $e');
    }
  }

  Future<void> updateProfile({
    String? name,
    String? phoneNumber,
    String? email,
    String? profileImageUrl,
  }) async {
    state = state.copyWith(
      name: name,
      phoneNumber: phoneNumber,
      email: email,
      profileImageUrl: profileImageUrl,
    );
    await _saveProfile();
  }

  void setUserId(String userId) async {
    state = state.copyWith(userId: userId);
    await _saveProfile();
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile>((ref) {
  return UserNotifier();
});
