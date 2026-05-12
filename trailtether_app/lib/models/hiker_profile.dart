import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  final String name;
  final String email;
  final String phone;
  final String relation;

  const EmergencyContact({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.relation = '',
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> m) => EmergencyContact(
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        relation: m['relation'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'relation': relation,
      };
}

class HikerProfile {
  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final String bio;
  final String experienceLevel; // beginner | intermediate | advanced | expert
  final List<EmergencyContact> contacts;
  final String bloodType;
  final List<String> allergies;
  final String medications;
  final String medicalConditions;
  final String doctorName;
  final String doctorPhone;
  final String photoUrl;
  final List<String> unlockedAchievementIds;

  const HikerProfile({
    this.uid = '',
    this.displayName = '',
    this.email = '',
    this.phone = '',
    this.bio = '',
    this.experienceLevel = 'beginner',
    this.contacts = const [],
    this.bloodType = '',
    this.allergies = const [],
    this.medications = '',
    this.medicalConditions = '',
    this.doctorName = '',
    this.doctorPhone = '',
    this.photoUrl = '',
    this.unlockedAchievementIds = const [],
  });

  factory HikerProfile.fromMap(Map<String, dynamic> m) => HikerProfile(
        uid: m['uid'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        bio: m['bio'] as String? ?? '',
        experienceLevel: m['experienceLevel'] as String? ?? 'beginner',
        contacts: (m['contacts'] as List<dynamic>?)
                ?.map(
                    (c) => EmergencyContact.fromMap(c as Map<String, dynamic>))
                .toList() ??
            [],
        bloodType: m['bloodType'] as String? ?? '',
        allergies: (m['allergies'] as List<dynamic>?)?.cast<String>() ?? [],
        medications: m['medications'] as String? ?? '',
        medicalConditions: m['medicalConditions'] as String? ?? '',
        doctorName: m['doctorName'] as String? ?? '',
        doctorPhone: m['doctorPhone'] as String? ?? '',
        photoUrl: m['photoUrl'] as String? ?? '',
        unlockedAchievementIds:
            (m['unlockedAchievementIds'] as List<dynamic>?)?.cast<String>() ??
                [],
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'bio': bio,
        'experienceLevel': experienceLevel,
        'contacts': contacts.map((c) => c.toMap()).toList(),
        'bloodType': bloodType,
        'allergies': allergies,
        'medications': medications,
        'medicalConditions': medicalConditions,
        'doctorName': doctorName,
        'doctorPhone': doctorPhone,
        'photoUrl': photoUrl,
        'unlockedAchievementIds': unlockedAchievementIds,
      };

  HikerProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? phone,
    String? bio,
    String? experienceLevel,
    List<EmergencyContact>? contacts,
    String? bloodType,
    List<String>? allergies,
    String? medications,
    String? medicalConditions,
    String? doctorName,
    String? doctorPhone,
    String? photoUrl,
    List<String>? unlockedAchievementIds,
  }) =>
      HikerProfile(
        uid: uid ?? this.uid,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        bio: bio ?? this.bio,
        experienceLevel: experienceLevel ?? this.experienceLevel,
        contacts: contacts ?? this.contacts,
        bloodType: bloodType ?? this.bloodType,
        allergies: allergies ?? this.allergies,
        medications: medications ?? this.medications,
        medicalConditions: medicalConditions ?? this.medicalConditions,
        doctorName: doctorName ?? this.doctorName,
        doctorPhone: doctorPhone ?? this.doctorPhone,
        photoUrl: photoUrl ?? this.photoUrl,
        unlockedAchievementIds:
            unlockedAchievementIds ?? this.unlockedAchievementIds,
      );

  // ── Local persistence ──────────────────────────────────────────────────
  static const _prefsKey = 'hiker_profile';

  static Future<HikerProfile> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const HikerProfile();
    try {
      return HikerProfile.fromMap(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const HikerProfile();
    }
  }

  Future<void> saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(toMap()));
  }
}
