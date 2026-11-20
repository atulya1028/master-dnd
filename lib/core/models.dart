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
  });

  final String id;
  final String name;
  final IconData icon;
  final String meta;
  final bool active;
  final DndMode mode;
  final bool autoReply;
  final bool hideNotifications;

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

  factory DndRule.fromJson(Map<String, dynamic> json) {
    return DndRule(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      triggerType: json['triggerType']?.toString() ?? 'schedule',
      active: json['active'] != false,
    );
  }

  DndRule copyWith({bool? active}) => DndRule(
        id: id,
        title: title,
        subtitle: subtitle,
        triggerType: triggerType,
        active: active ?? this.active,
      );
}

const sampleProfiles = <DndProfile>[
  DndProfile(id: '1', name: 'Sleep', icon: DndIcons.moon, meta: 'Priority only, 10 PM to 6:30 AM', active: true),
  DndProfile(id: '2', name: 'Work', icon: DndIcons.briefcase, meta: 'Starred calls, Mon to Fri 9 to 6'),
  DndProfile(id: '3', name: 'Meeting', icon: DndIcons.users, meta: 'Total silence during calendar events'),
  DndProfile(id: '4', name: 'Driving', icon: DndIcons.car, meta: 'Alarms only, Bluetooth: Car'),
  DndProfile(id: '5', name: 'Study', icon: DndIcons.book, meta: 'Total silence, Tue and Thu 4 to 7 PM'),
];
