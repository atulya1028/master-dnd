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
  });

  final String id;
  final String phone;
  final String name;
  final String email;
  final String avatar;
  final String bio;
  final bool isProfileComplete;
  final bool dndEnabled;

  String get displayName => name.isNotEmpty ? name : 'User';
  String get displayInitial =>
      name.isNotEmpty ? name[0].toUpperCase() : (avatar.isNotEmpty ? avatar[0].toUpperCase() : 'U');

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? 'A',
      bio: json['bio']?.toString() ?? '',
      isProfileComplete: json['isProfileComplete'] == true,
      dndEnabled: json['dndEnabled'] == true,
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
      );
}

class DndRule {
  const DndRule({
    this.id = '',
    required this.title,
    required this.subtitle,
    this.triggerType = 'schedule',
    this.active = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String triggerType;
  final bool active;

  IconData get icon => switch (triggerType.toLowerCase()) {
        'schedule' || 'time' => DndIcons.clock,
        'location' || 'place' || 'places' => DndIcons.pin,
        'wifi' || 'wi-fi' => DndIcons.wifi,
        'calendar' => DndIcons.calendar,
        'driving' => DndIcons.car,
        'app' => DndIcons.apps,
        _ => DndIcons.clock,
      };

  factory DndRule.fromJson(Map<String, dynamic> json) {
    return DndRule(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      triggerType: json['triggerType']?.toString() ?? 'schedule',
      active: json['active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'triggerType': triggerType,
        'active': active,
      };

  DndRule copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? triggerType,
    bool? active,
  }) =>
      DndRule(
        id: id ?? this.id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        triggerType: triggerType ?? this.triggerType,
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
      silencedTonight: (json['silencedTonight'] as num?)?.toInt() ?? 12,
      letThroughTonight: (json['letThroughTonight'] as num?)?.toInt() ?? 2,
      weeklyTotalSilenced: (json['weeklyTotalSilenced'] as num?)?.toInt() ?? 84,
      avgQuietHours: json['avgQuietHours']?.toString() ?? '7h 14m',
      focusHours: (json['focusHours'] as num?)?.toInt() ?? 31,
      blockedTotal: (json['blockedTotal'] as num?)?.toInt() ?? 84,
    );
  }
}

class LetThroughContact {
  const LetThroughContact({
    required this.initial,
    required this.name,
    required this.detail,
  });

  final String initial;
  final String name;
  final String detail;

  factory LetThroughContact.fromJson(Map<String, dynamic> json) {
    return LetThroughContact(
      initial: json['initial']?.toString() ?? 'U',
      name: json['name']?.toString() ?? 'Contact',
      detail: json['detail']?.toString() ?? '',
    );
  }
}

class DailyBreakdown {
  const DailyBreakdown({
    required this.day,
    required this.silenced,
    required this.allowed,
    this.hours = 4.0,
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
      hours: (json['hours'] as num?)?.toDouble() ?? 4.0,
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
      fraction: (json['fraction'] as num?)?.toDouble() ?? 0.5,
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
  });

  final String range;
  final InsightsStats stats;
  final List<LetThroughContact> letThroughContacts;
  final List<DailyBreakdown> breakdown;
  final List<ProfileStat> profiles;

  factory InsightsData.fromJson(Map<String, dynamic> json) {
    final statsJson = json['stats'] as Map<String, dynamic>? ?? {};
    final contactsList = (json['letThroughContacts'] as List<dynamic>?) ?? [];
    final breakdownList = (json['breakdown'] as List<dynamic>?) ?? [];
    final profilesList = (json['profiles'] as List<dynamic>?) ?? [];

    return InsightsData(
      range: json['range']?.toString() ?? 'this_week',
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

  static InsightsData defaults() => const InsightsData(
        range: 'this_week',
        stats: InsightsStats(),
        letThroughContacts: [
          LetThroughContact(initial: 'M', name: 'Mom', detail: 'Call at 11:12 PM, VIP contact'),
          LetThroughContact(initial: 'D', name: 'Dr. Rao', detail: 'Call at 11:19 PM, repeat caller'),
        ],
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

const sampleProfiles = <DndProfile>[
  DndProfile(id: '1', name: 'Sleep', icon: DndIcons.moon, meta: 'Priority only, 10 PM to 6:30 AM', active: true),
  DndProfile(id: '2', name: 'Work', icon: DndIcons.briefcase, meta: 'Starred calls, Mon to Fri 9 to 6'),
  DndProfile(id: '3', name: 'Meeting', icon: DndIcons.users, meta: 'Total silence during calendar events'),
  DndProfile(id: '4', name: 'Driving', icon: DndIcons.car, meta: 'Alarms only, Bluetooth: Car'),
  DndProfile(id: '5', name: 'Study', icon: DndIcons.book, meta: 'Total silence, Tue and Thu 4 to 7 PM'),
];
