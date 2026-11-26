import 'package:flutter/material.dart';

/// Icon keys used in the Figma file mapped to Material icons.
abstract final class DndIcons {
  static const moon = Icons.nightlight_round;
  static const briefcase = Icons.work_outline;
  static const users = Icons.groups_outlined;
  static const car = Icons.directions_car_outlined;
  static const book = Icons.menu_book_outlined;
  static const shield = Icons.shield_outlined;
  static const user = Icons.person_outline;
  static const bell = Icons.notifications_none;
  static const phone = Icons.phone_outlined;
  static const apps = Icons.apps;
  static const pin = Icons.location_on_outlined;
  static const wifi = Icons.wifi;
  static const calendar = Icons.calendar_today_outlined;
  static const clock = Icons.schedule;
  static const power = Icons.power_settings_new;
  static const warning = Icons.warning_amber_rounded;

  static IconData fromKey(String key) => switch (key.toLowerCase()) {
        'moon' => moon,
        'briefcase' => briefcase,
        'users' => users,
        'car' => car,
        'book' => book,
        'shield' => shield,
        'user' => user,
        'bell' => bell,
        'phone' => phone,
        'pin' => pin,
        'wifi' => wifi,
        'calendar' => calendar,
        'clock' => clock,
        _ => moon,
      };

  static String toKey(IconData icon) {
    if (icon == moon) return 'moon';
    if (icon == briefcase) return 'briefcase';
    if (icon == users) return 'users';
    if (icon == car) return 'car';
    if (icon == book) return 'book';
    if (icon == shield) return 'shield';
    if (icon == user) return 'user';
    if (icon == bell) return 'bell';
    if (icon == phone) return 'phone';
    if (icon == calendar) return 'calendar';
    return 'moon';
  }
}

enum DndMode { totalSilence, priorityOnly, alarmsOnly, custom }

class UserModel {
  const UserModel({
    required this.id,
    required this.phone,
    this.name = '',
    this.email = '',
    this.avatar = 'A',
    this.bio = '',
    this.isProfileComplete = false,
    this.dndEnabled = false,
    this.activeSessionStart,
    this.activeSessionPlannedMinutes = 60,
    this.activeSessionEndTime,
    this.activeProfileName = '',
    this.customDurations = const [30, 60],
    this.customContactCategories = const [
      'VIP Contact',
      'Family',
      'Doctor / Emergency',
      'Repeat Caller',
      'Work Priority',
    ],
    this.customWhitelistOptions = const [
      'Starred',
      'Contacts only',
      'VIP only',
      'Everyone',
      'No one',
    ],
    this.totalAppUsageMinutes = 0,
    this.emergencyContacts = const [],
    this.notificationPreferences = const {
      'allowDndAccess': true,
      'allowContacts': true,
      'allowNotifications': true,
    },
  });

  final String id;
  final String phone;
  final String name;
  final String email;
  final String avatar;
  final String bio;
  final bool isProfileComplete;
  final bool dndEnabled;
  final DateTime? activeSessionStart;
  final int activeSessionPlannedMinutes;
  final DateTime? activeSessionEndTime;
  final String activeProfileName;
  final List<int> customDurations;
  final List<String> customContactCategories;
  final List<String> customWhitelistOptions;
  final int totalAppUsageMinutes;
  final List<LetThroughContact> emergencyContacts;
  final Map<String, bool> notificationPreferences;

  String get displayName => name.isNotEmpty ? name : 'User';
  String get displayInitial =>
      name.isNotEmpty ? name[0].toUpperCase() : (avatar.isNotEmpty ? avatar[0].toUpperCase() : 'U');

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawDurations = (json['customDurations'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .where((e) => e > 0)
            .toList() ??
        const [30, 60];
    final rawCategories = (json['customContactCategories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [
          'VIP Contact',
          'Family',
          'Doctor / Emergency',
          'Repeat Caller',
          'Work Priority',
        ];
    final rawWhitelists = (json['customWhitelistOptions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const ['Starred', 'Contacts only', 'VIP only', 'Everyone', 'No one'];
    final rawContacts = (json['emergencyContacts'] as List<dynamic>?)
            ?.map((c) => LetThroughContact.fromJson(c as Map<String, dynamic>))
            .toList() ??
        const [];
    final rawPrefs = json['notificationPreferences'] as Map<String, dynamic>?;

    return UserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? 'A',
      bio: json['bio']?.toString() ?? '',
      isProfileComplete: json['isProfileComplete'] == true,
      dndEnabled: json['dndEnabled'] == true,
      activeSessionStart: json['activeSessionStart'] != null
          ? DateTime.tryParse(json['activeSessionStart'].toString())
          : null,
      activeSessionPlannedMinutes:
          (json['activeSessionPlannedMinutes'] as num?)?.toInt() ?? 60,
      activeSessionEndTime: json['activeSessionEndTime'] != null
          ? DateTime.tryParse(json['activeSessionEndTime'].toString())
          : null,
      activeProfileName: json['activeProfileName']?.toString() ?? '',
      customDurations: rawDurations.isNotEmpty ? rawDurations : const [30, 60],
      customContactCategories: rawCategories,
      customWhitelistOptions: rawWhitelists,
      totalAppUsageMinutes: (json['totalAppUsageMinutes'] as num?)?.toInt() ?? 0,
      emergencyContacts: rawContacts,
      notificationPreferences: rawPrefs != null
          ? rawPrefs.map((k, v) => MapEntry(k, v == true))
          : const {
              'allowDndAccess': true,
              'allowContacts': true,
              'allowNotifications': true,
            },
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'email': email,
        'avatar': avatar,
        'bio': bio,
        'isProfileComplete': isProfileComplete,
        'dndEnabled': dndEnabled,
        'activeSessionStart': activeSessionStart?.toIso8601String(),
        'activeSessionPlannedMinutes': activeSessionPlannedMinutes,
        'activeSessionEndTime': activeSessionEndTime?.toIso8601String(),
        'activeProfileName': activeProfileName,
        'customDurations': customDurations,
        'customContactCategories': customContactCategories,
        'customWhitelistOptions': customWhitelistOptions,
        'totalAppUsageMinutes': totalAppUsageMinutes,
        'emergencyContacts': emergencyContacts.map((c) => c.toJson()).toList(),
        'notificationPreferences': notificationPreferences,
      };

  UserModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    String? avatar,
    String? bio,
    bool? isProfileComplete,
    bool? dndEnabled,
    DateTime? activeSessionStart,
    bool clearActiveSessionStart = false,
    int? activeSessionPlannedMinutes,
    DateTime? activeSessionEndTime,
    bool clearActiveSessionEndTime = false,
    String? activeProfileName,
    List<int>? customDurations,
    List<String>? customContactCategories,
    List<String>? customWhitelistOptions,
    int? totalAppUsageMinutes,
    List<LetThroughContact>? emergencyContacts,
    Map<String, bool>? notificationPreferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      activeSessionStart:
          clearActiveSessionStart ? null : (activeSessionStart ?? this.activeSessionStart),
      activeSessionPlannedMinutes:
          activeSessionPlannedMinutes ?? this.activeSessionPlannedMinutes,
      activeSessionEndTime:
          clearActiveSessionEndTime ? null : (activeSessionEndTime ?? this.activeSessionEndTime),
      activeProfileName: activeProfileName ?? this.activeProfileName,
      customDurations: customDurations ?? this.customDurations,
      customContactCategories: customContactCategories ?? this.customContactCategories,
      customWhitelistOptions: customWhitelistOptions ?? this.customWhitelistOptions,
      totalAppUsageMinutes: totalAppUsageMinutes ?? this.totalAppUsageMinutes,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
    );
  }
}

class DndProfile {
  const DndProfile({
    this.id = '',
    required this.name,
    required this.icon,
    required this.meta,
    this.active = false,
    this.mode = DndMode.priorityOnly,
    this.autoReply = true,
    this.hideNotifications = false,
    this.callWhitelist = 'Starred',
    this.messageWhitelist = 'VIP only',
    this.repeatCallersWindowMin = 15,
    this.autoReplyMessage = 'I am currently in Do Not Disturb mode and will respond shortly.',
    this.customTag = '',
  });

  final String id;
  final String name;
  final IconData icon;
  final String meta;
  final bool active;
  final DndMode mode;
  final bool autoReply;
  final bool hideNotifications;
  final String callWhitelist;
  final String messageWhitelist;
  final int repeatCallersWindowMin;
  final String autoReplyMessage;
  final String customTag;

  factory DndProfile.fromJson(Map<String, dynamic> json) {
    final modeStr = json['mode']?.toString() ?? 'priorityOnly';
    final modeEnum = switch (modeStr) {
      'totalSilence' => DndMode.totalSilence,
      'alarmsOnly' => DndMode.alarmsOnly,
      'custom' => DndMode.custom,
      _ => DndMode.priorityOnly,
    };

    return DndProfile(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Profile',
      icon: DndIcons.fromKey(json['icon']?.toString() ?? 'moon'),
      meta: json['meta']?.toString() ?? '',
      active: json['active'] == true,
      mode: modeEnum,
      autoReply: json['autoReply'] != false,
      hideNotifications: json['hideNotifications'] == true,
      callWhitelist: json['callWhitelist']?.toString() ?? 'Starred',
      messageWhitelist: json['messageWhitelist']?.toString() ?? 'VIP only',
      repeatCallersWindowMin: json['repeatCallersWindowMin'] is num
          ? (json['repeatCallersWindowMin'] as num).toInt()
          : 15,
      autoReplyMessage: json['autoReplyMessage']?.toString() ??
          'I am currently in Do Not Disturb mode and will respond shortly.',
      customTag: json['customTag']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': DndIcons.toKey(icon),
        'meta': meta,
        'active': active,
        'mode': mode.name,
        'autoReply': autoReply,
        'hideNotifications': hideNotifications,
        'callWhitelist': callWhitelist,
        'messageWhitelist': messageWhitelist,
        'repeatCallersWindowMin': repeatCallersWindowMin,
        'autoReplyMessage': autoReplyMessage,
        'customTag': customTag,
      };

  DndProfile copyWith({
    String? id,
    String? name,
    IconData? icon,
    String? meta,
    bool? active,
    DndMode? mode,
    bool? autoReply,
    bool? hideNotifications,
    String? callWhitelist,
    String? messageWhitelist,
    int? repeatCallersWindowMin,
    String? autoReplyMessage,
    String? customTag,
  }) =>
      DndProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        meta: meta ?? this.meta,
        active: active ?? this.active,
        mode: mode ?? this.mode,
        autoReply: autoReply ?? this.autoReply,
        hideNotifications: hideNotifications ?? this.hideNotifications,
        callWhitelist: callWhitelist ?? this.callWhitelist,
        messageWhitelist: messageWhitelist ?? this.messageWhitelist,
        repeatCallersWindowMin: repeatCallersWindowMin ?? this.repeatCallersWindowMin,
        autoReplyMessage: autoReplyMessage ?? this.autoReplyMessage,
        customTag: customTag ?? this.customTag,
      );
}

class DndRule {
  const DndRule({
    this.id = '',
    required this.title,
    required this.subtitle,
    this.triggerType = 'schedule',
    this.days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    this.targetProfileName = '',
    this.customCondition = '',
    this.active = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String triggerType;
  final List<String> days;
  final String targetProfileName;
  final String customCondition;
  final bool active;

  IconData get icon => switch (triggerType.toLowerCase()) {
        'schedule' || 'time' => DndIcons.clock,
        'location' || 'place' || 'places' => DndIcons.pin,
        'wifi' || 'wi-fi' => DndIcons.wifi,
        'calendar' => DndIcons.calendar,
        'driving' => DndIcons.car,
        'app' => DndIcons.apps,
        _ => DndIcons.shield,
      };

  factory DndRule.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['days'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return DndRule(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      triggerType: json['triggerType']?.toString() ?? 'schedule',
      days: rawDays,
      targetProfileName: json['targetProfileName']?.toString() ?? '',
      customCondition: json['customCondition']?.toString() ?? '',
      active: json['active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'triggerType': triggerType,
        'days': days,
        'targetProfileName': targetProfileName,
        'customCondition': customCondition,
        'active': active,
      };

  DndRule copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? triggerType,
    List<String>? days,
    String? targetProfileName,
    String? customCondition,
    bool? active,
  }) =>
      DndRule(
        id: id ?? this.id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        triggerType: triggerType ?? this.triggerType,
        days: days ?? this.days,
        targetProfileName: targetProfileName ?? this.targetProfileName,
        customCondition: customCondition ?? this.customCondition,
        active: active ?? this.active,
      );
}

class InsightsStats {
  const InsightsStats({
    this.silencedTonight = 12,
    this.letThroughTonight = 2,
    this.weeklyTotalSilenced = 84,
    this.avgQuietHours = '7h 14m',
    this.focusHours = 31,
    this.blockedTotal = 84,
  });

  final int silencedTonight;
  final int letThroughTonight;
  final int weeklyTotalSilenced;
  final String avgQuietHours;
  final int focusHours;
  final int blockedTotal;

  factory InsightsStats.fromJson(Map<String, dynamic> json) {
    return InsightsStats(
      silencedTonight: (json['silencedTonight'] as num?)?.toInt() ?? 0,
      letThroughTonight: (json['letThroughTonight'] as num?)?.toInt() ?? 0,
      weeklyTotalSilenced: (json['weeklyTotalSilenced'] as num?)?.toInt() ?? 0,
      avgQuietHours: json['avgQuietHours']?.toString() ?? '0h 0m',
      focusHours: (json['focusHours'] as num?)?.toInt() ?? 0,
      blockedTotal: (json['blockedTotal'] as num?)?.toInt() ?? 0,
    );
  }
}

class LetThroughContact {
  const LetThroughContact({
    this.id = '',
    required this.initial,
    required this.name,
    required this.detail,
    this.phone = '',
    this.relationship = 'VIP Contact',
    this.isVip = true,
  });

  final String id;
  final String initial;
  final String name;
  final String detail;
  final String phone;
  final String relationship;
  final bool isVip;

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'initial': initial,
        'name': name,
        'detail': detail,
        'phone': phone,
        'relationship': relationship,
        'isVip': isVip,
      };

  factory LetThroughContact.fromJson(Map<String, dynamic> json) {
    final n = json['name']?.toString() ?? 'Contact';
    final rel = json['relationship']?.toString() ?? 'VIP Contact';
    final ph = json['phone']?.toString() ?? '';
    final init = json['initial']?.toString() ?? (n.isNotEmpty ? n[0].toUpperCase() : 'U');
    final computedDetail = json['detail']?.toString() ?? (ph.isNotEmpty ? '$rel • $ph' : rel);
    return LetThroughContact(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      initial: init,
      name: n,
      detail: computedDetail,
      phone: ph,
      relationship: rel,
      isVip: json['isVip'] != false,
    );
  }
}

class DailyBreakdown {
  const DailyBreakdown({
    required this.day,
    required this.silenced,
    required this.allowed,
    this.hours = 0.0,
  });

  final String day;
  final int silenced;
  final int allowed;
  final double hours;

  factory DailyBreakdown.fromJson(Map<String, dynamic> json) {
    return DailyBreakdown(
      day: json['day']?.toString() ?? '',
      silenced: (json['silenced'] as num?)?.toInt() ?? 0,
      allowed: (json['allowed'] as num?)?.toInt() ?? 0,
      hours: (json['hours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProfileStat {
  const ProfileStat({
    required this.name,
    required this.hours,
    required this.fraction,
  });

  final String name;
  final int hours;
  final double fraction;

  factory ProfileStat.fromJson(Map<String, dynamic> json) {
    return ProfileStat(
      name: json['name']?.toString() ?? 'Profile',
      hours: (json['hours'] as num?)?.toInt() ?? 0,
      fraction: (json['fraction'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class InsightsData {
  const InsightsData({
    required this.range,
    required this.stats,
    required this.letThroughContacts,
    required this.breakdown,
    required this.profiles,
    this.hasData = true,
  });

  final String range;
  final InsightsStats stats;
  final List<LetThroughContact> letThroughContacts;
  final List<DailyBreakdown> breakdown;
  final List<ProfileStat> profiles;
  final bool hasData;

  factory InsightsData.fromJson(Map<String, dynamic> json) {
    final statsJson = json['stats'] as Map<String, dynamic>? ?? {};
    final contactsList = (json['letThroughContacts'] as List<dynamic>?) ?? [];
    final breakdownList = (json['breakdown'] as List<dynamic>?) ?? [];
    final profilesList = (json['profiles'] as List<dynamic>?) ?? [];

    return InsightsData(
      range: json['range']?.toString() ?? 'this_week',
      hasData: json['hasData'] != false,
      stats: InsightsStats.fromJson(statsJson),
      letThroughContacts: contactsList
          .map((c) => LetThroughContact.fromJson(c as Map<String, dynamic>))
          .toList(),
      breakdown: breakdownList
          .map((b) => DailyBreakdown.fromJson(b as Map<String, dynamic>))
          .toList(),
      profiles: profilesList
          .map((p) => ProfileStat.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  static InsightsData empty() => const InsightsData(
        range: 'this_week',
        hasData: false,
        stats: InsightsStats(
          silencedTonight: 0,
          letThroughTonight: 0,
          weeklyTotalSilenced: 0,
          avgQuietHours: '0h 0m',
          focusHours: 0,
          blockedTotal: 0,
        ),
        letThroughContacts: [],
        breakdown: [
          DailyBreakdown(day: 'Mon', silenced: 0, allowed: 0, hours: 0),
          DailyBreakdown(day: 'Tue', silenced: 0, allowed: 0, hours: 0),
          DailyBreakdown(day: 'Wed', silenced: 0, allowed: 0, hours: 0),
          DailyBreakdown(day: 'Thu', silenced: 0, allowed: 0, hours: 0),
          DailyBreakdown(day: 'Fri', silenced: 0, allowed: 0, hours: 0),
          DailyBreakdown(day: 'Sat', silenced: 0, allowed: 0, hours: 0),
          DailyBreakdown(day: 'Sun', silenced: 0, allowed: 0, hours: 0),
        ],
        profiles: [],
      );

  static InsightsData defaults() => const InsightsData(
        range: 'this_week',
        stats: InsightsStats(),
        letThroughContacts: [],
        breakdown: [
          DailyBreakdown(day: 'Mon', silenced: 14, allowed: 1, hours: 4.5),
          DailyBreakdown(day: 'Tue', silenced: 11, allowed: 3, hours: 5.0),
          DailyBreakdown(day: 'Wed', silenced: 15, allowed: 0, hours: 3.8),
          DailyBreakdown(day: 'Thu', silenced: 12, allowed: 2, hours: 5.6),
          DailyBreakdown(day: 'Fri', silenced: 9, allowed: 4, hours: 4.4),
          DailyBreakdown(day: 'Sat', silenced: 16, allowed: 1, hours: 4.2),
          DailyBreakdown(day: 'Sun', silenced: 12, allowed: 2, hours: 3.5),
        ],
        profiles: [
          ProfileStat(name: 'Sleep', hours: 18, fraction: 1.0),
          ProfileStat(name: 'Work', hours: 9, fraction: 0.5),
          ProfileStat(name: 'Meeting', hours: 3, fraction: 3 / 18),
          ProfileStat(name: 'Driving', hours: 1, fraction: 1 / 18),
        ],
      );
}

class DndActivityLog {
  const DndActivityLog({
    this.id = '',
    required this.date,
    required this.profileName,
    required this.durationMinutes,
    this.plannedMinutes = 60,
    this.appUsageMinutes = 0,
    this.completedWithoutEarlyExit = true,
    this.silencedCount = 0,
    this.letThroughCount = 0,
    this.focusStabilityRating = 4,
    this.source = 'manual_log',
    this.notes = '',
  });

  final String id;
  final DateTime date;
  final String profileName;
  final int durationMinutes;
  final int plannedMinutes;
  final int appUsageMinutes;
  final bool completedWithoutEarlyExit;
  final int silencedCount;
  final int letThroughCount;
  final int focusStabilityRating;
  final String source;
  final String notes;

  factory DndActivityLog.fromJson(Map<String, dynamic> json) {
    return DndActivityLog(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      profileName: json['profileName']?.toString() ?? 'Do Not Disturb',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      plannedMinutes: (json['plannedMinutes'] as num?)?.toInt() ?? 60,
      appUsageMinutes: (json['appUsageMinutes'] as num?)?.toInt() ?? 0,
      completedWithoutEarlyExit: json['completedWithoutEarlyExit'] != false,
      silencedCount: (json['silencedCount'] as num?)?.toInt() ?? 0,
      letThroughCount: (json['letThroughCount'] as num?)?.toInt() ?? 0,
      focusStabilityRating: (json['focusStabilityRating'] as num?)?.toInt() ?? 4,
      source: json['source']?.toString() ?? 'manual_log',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class StabilityPillars {
  const StabilityPillars({
    this.adherenceScore = 0,
    this.consistencyScore = 0,
    this.shieldScore = 0,
    this.focusRatingScore = 0,
  });

  final int adherenceScore;
  final int consistencyScore;
  final int shieldScore;
  final int focusRatingScore;

  factory StabilityPillars.fromJson(Map<String, dynamic> json) {
    return StabilityPillars(
      adherenceScore: (json['adherenceScore'] as num?)?.toInt() ?? 0,
      consistencyScore: (json['consistencyScore'] as num?)?.toInt() ?? 0,
      shieldScore: (json['shieldScore'] as num?)?.toInt() ?? 0,
      focusRatingScore: (json['focusRatingScore'] as num?)?.toInt() ?? 0,
    );
  }
}

class StabilitySummary {
  const StabilitySummary({
    this.totalSessions = 0,
    this.completedSessions = 0,
    this.earlyExitSessions = 0,
    this.totalQuietMinutes = 0,
    this.totalAppUsageMinutes = 0,
    this.avgSessionMinutes = 0,
    this.currentStreakDays = 0,
    this.longestStreakDays = 0,
    this.activeDaysCount = 0,
    this.periodDays = 7,
    this.totalSilenced = 0,
    this.totalLetThrough = 0,
    this.activeRulesCount = 0,
    this.activeProfilesCount = 0,
    this.vipContactsCount = 0,
  });

  final int totalSessions;
  final int completedSessions;
  final int earlyExitSessions;
  final int totalQuietMinutes;
  final int totalAppUsageMinutes;
  final int avgSessionMinutes;
  final int currentStreakDays;
  final int longestStreakDays;
  final int activeDaysCount;
  final int periodDays;
  final int totalSilenced;
  final int totalLetThrough;
  final int activeRulesCount;
  final int activeProfilesCount;
  final int vipContactsCount;

  factory StabilitySummary.fromJson(Map<String, dynamic> json) {
    return StabilitySummary(
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      earlyExitSessions: (json['earlyExitSessions'] as num?)?.toInt() ?? 0,
      totalQuietMinutes: (json['totalQuietMinutes'] as num?)?.toInt() ?? 0,
      totalAppUsageMinutes: (json['totalAppUsageMinutes'] as num?)?.toInt() ?? 0,
      avgSessionMinutes: (json['avgSessionMinutes'] as num?)?.toInt() ?? 0,
      currentStreakDays: (json['currentStreakDays'] as num?)?.toInt() ?? 0,
      longestStreakDays: (json['longestStreakDays'] as num?)?.toInt() ?? 0,
      activeDaysCount: (json['activeDaysCount'] as num?)?.toInt() ?? 0,
      periodDays: (json['periodDays'] as num?)?.toInt() ?? 7,
      totalSilenced: (json['totalSilenced'] as num?)?.toInt() ?? 0,
      totalLetThrough: (json['totalLetThrough'] as num?)?.toInt() ?? 0,
      activeRulesCount: (json['activeRulesCount'] as num?)?.toInt() ?? 0,
      activeProfilesCount: (json['activeProfilesCount'] as num?)?.toInt() ?? 0,
      vipContactsCount: (json['vipContactsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StabilityTrendPoint {
  const StabilityTrendPoint({
    required this.label,
    required this.stabilityScore,
    required this.quietHours,
    required this.appUsageMinutes,
    required this.silenced,
    required this.allowed,
    required this.adherenceRate,
    required this.sessions,
  });

  final String label;
  final int stabilityScore;
  final double quietHours;
  final int appUsageMinutes;
  final int silenced;
  final int allowed;
  final int adherenceRate;
  final int sessions;

  factory StabilityTrendPoint.fromJson(Map<String, dynamic> json) {
    return StabilityTrendPoint(
      label: json['label']?.toString() ?? '',
      stabilityScore: (json['stabilityScore'] as num?)?.toInt() ?? 0,
      quietHours: (json['quietHours'] as num?)?.toDouble() ?? 0.0,
      appUsageMinutes: (json['appUsageMinutes'] as num?)?.toInt() ?? 0,
      silenced: (json['silenced'] as num?)?.toInt() ?? 0,
      allowed: (json['allowed'] as num?)?.toInt() ?? 0,
      adherenceRate: (json['adherenceRate'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileStabilityStat {
  const ProfileStabilityStat({
    required this.name,
    required this.sessions,
    required this.totalHours,
    required this.avgStabilityScore,
    required this.adherenceRate,
  });

  final String name;
  final int sessions;
  final double totalHours;
  final int avgStabilityScore;
  final int adherenceRate;

  factory ProfileStabilityStat.fromJson(Map<String, dynamic> json) {
    return ProfileStabilityStat(
      name: json['name']?.toString() ?? 'Profile',
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0.0,
      avgStabilityScore: (json['avgStabilityScore'] as num?)?.toInt() ?? 0,
      adherenceRate: (json['adherenceRate'] as num?)?.toInt() ?? 0,
    );
  }
}

class StabilityRecommendation {
  const StabilityRecommendation({
    required this.title,
    required this.detail,
    this.tone = 'info',
  });

  final String title;
  final String detail;
  final String tone;

  factory StabilityRecommendation.fromJson(Map<String, dynamic> json) {
    return StabilityRecommendation(
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      tone: json['tone']?.toString() ?? 'info',
    );
  }
}

class StabilityReportData {
  const StabilityReportData({
    this.range = '7d',
    this.hasData = false,
    this.overallStabilityScore = 0,
    this.stabilityGrade = 'No Data',
    this.stabilityDelta = 0,
    this.pillars = const StabilityPillars(),
    this.summary = const StabilitySummary(),
    this.trend = const [],
    this.profileStability = const [],
    this.recentLogs = const [],
    this.recommendations = const [],
  });

  final String range;
  final bool hasData;
  final int overallStabilityScore;
  final String stabilityGrade;
  final int stabilityDelta;
  final StabilityPillars pillars;
  final StabilitySummary summary;
  final List<StabilityTrendPoint> trend;
  final List<ProfileStabilityStat> profileStability;
  final List<DndActivityLog> recentLogs;
  final List<StabilityRecommendation> recommendations;

  factory StabilityReportData.fromJson(Map<String, dynamic> json) {
    return StabilityReportData(
      range: json['range']?.toString() ?? '7d',
      hasData: json['hasData'] == true,
      overallStabilityScore: (json['overallStabilityScore'] as num?)?.toInt() ?? 0,
      stabilityGrade: json['stabilityGrade']?.toString() ?? 'No Data',
      stabilityDelta: (json['stabilityDelta'] as num?)?.toInt() ?? 0,
      pillars: StabilityPillars.fromJson(json['pillars'] as Map<String, dynamic>? ?? {}),
      summary: StabilitySummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      trend: ((json['trend'] as List<dynamic>?) ?? [])
          .map((e) => StabilityTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      profileStability: ((json['profileStability'] as List<dynamic>?) ?? [])
          .map((e) => ProfileStabilityStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentLogs: ((json['recentLogs'] as List<dynamic>?) ?? [])
          .map((e) => DndActivityLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: ((json['recommendations'] as List<dynamic>?) ?? [])
          .map((e) => StabilityRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static StabilityReportData empty() => const StabilityReportData();
}

const sampleProfiles = <DndProfile>[
  DndProfile(id: '1', name: 'Sleep', icon: DndIcons.moon, meta: 'Priority only, 10 PM to 6:30 AM', active: true),
  DndProfile(id: '2', name: 'Work', icon: DndIcons.briefcase, meta: 'Starred calls, Mon to Fri 9 to 6'),
  DndProfile(id: '3', name: 'Meeting', icon: DndIcons.users, meta: 'Total silence during calendar events'),
  DndProfile(id: '4', name: 'Driving', icon: DndIcons.car, meta: 'Alarms only, Bluetooth: Car'),
  DndProfile(id: '5', name: 'Study', icon: DndIcons.book, meta: 'Total silence, Tue and Thu 4 to 7 PM'),
];
