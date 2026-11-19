class UserSettings {
  UserSettings({
    required this.userId,
    required this.timezone,
    required this.updatedAt,
  });

  final String userId;

  /// 'system' 或 IANA 时区名，例如 Asia/Shanghai。
  final String timezone;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'timezone': timezone,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toUpsertParams() => {
        'p_timezone': timezone,
        'p_updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['user_id'] as String,
      timezone: (json['timezone'] as String?) ?? 'system',
      updatedAt: DateTime.tryParse('${json['updated_at']}')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

class TimezoneOption {
  const TimezoneOption(this.id, this.label);
  final String id;
  final String label;
}

const kSystemTimezoneId = 'system';

const kTimezoneOptions = <TimezoneOption>[
  TimezoneOption(kSystemTimezoneId, '跟随系统'),
  TimezoneOption('Asia/Shanghai', '中国（北京、上海）'),
  TimezoneOption('Asia/Hong_Kong', '香港'),
  TimezoneOption('Asia/Macau', '澳门'),
  TimezoneOption('Asia/Taipei', '台北'),
  TimezoneOption('Asia/Tokyo', '东京'),
  TimezoneOption('Asia/Seoul', '首尔'),
  TimezoneOption('Asia/Singapore', '新加坡'),
  TimezoneOption('Asia/Bangkok', '曼谷'),
  TimezoneOption('Asia/Kolkata', '新德里'),
  TimezoneOption('UTC', 'UTC'),
  TimezoneOption('Europe/London', '伦敦'),
  TimezoneOption('Europe/Paris', '巴黎'),
  TimezoneOption('Europe/Berlin', '柏林'),
  TimezoneOption('America/New_York', '纽约'),
  TimezoneOption('America/Chicago', '芝加哥'),
  TimezoneOption('America/Denver', '丹佛'),
  TimezoneOption('America/Los_Angeles', '洛杉矶'),
  TimezoneOption('Australia/Sydney', '悉尼'),
];
