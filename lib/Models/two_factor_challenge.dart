class TwoFactorChallenge {
  final String challengeId;
  final String websiteName;
  final String? ipAddress;
  final String? deviceInfo;
  final String? location;
  final DateTime createdAt;
  final int expiresInSeconds;
  final String? securityCode;
  final String status; // PENDING, APPROVED, DECLINED, EXPIRED

  TwoFactorChallenge({
    required this.challengeId,
    required this.websiteName,
    this.ipAddress,
    this.deviceInfo,
    this.location,
    required this.createdAt,
    this.expiresInSeconds = 90,
    this.securityCode,
    this.status = 'PENDING',
  });

  /// Seconds left before expiration from now
  int get remainingSeconds {
    final expiryTime = createdAt.add(Duration(seconds: expiresInSeconds));
    final diff = expiryTime.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isExpired => remainingSeconds <= 0;

  factory TwoFactorChallenge.fromFcmPayload(Map<String, dynamic> data) {
    DateTime parsedTime;
    try {
      if (data['timestamp'] != null) {
        parsedTime = DateTime.parse(data['timestamp'].toString());
      } else {
        parsedTime = DateTime.now();
      }
    } catch (_) {
      parsedTime = DateTime.now();
    }

    int expires = 90;
    if (data['expires_in'] != null) {
      expires = int.tryParse(data['expires_in'].toString()) ?? 90;
    } else if (data['expires_at'] != null) {
      expires = int.tryParse(data['expires_at'].toString()) ?? 90;
    }

    return TwoFactorChallenge(
      challengeId: data['challenge_id']?.toString() ??
          data['challengeId']?.toString() ??
          '',
      websiteName: data['website_name']?.toString() ??
          data['service_name']?.toString() ??
          'Corporate Website',
      ipAddress: data['ip_address']?.toString() ?? data['ip']?.toString(),
      deviceInfo: data['device_info']?.toString() ??
          data['device']?.toString() ??
          'Web Browser',
      location: data['location']?.toString(),
      createdAt: parsedTime,
      expiresInSeconds: expires,
      securityCode: data['security_code']?.toString(),
      status: data['status']?.toString().toUpperCase() ?? 'PENDING',
    );
  }

  factory TwoFactorChallenge.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      if (json['created_at'] != null) {
        parsedTime = DateTime.parse(json['created_at'].toString());
      } else {
        parsedTime = DateTime.now();
      }
    } catch (_) {
      parsedTime = DateTime.now();
    }

    return TwoFactorChallenge(
      challengeId: json['challenge_id']?.toString() ?? '',
      websiteName: json['website_name']?.toString() ?? 'Corporate Website',
      ipAddress: json['ip_address']?.toString(),
      deviceInfo: json['device_info']?.toString() ?? 'Web Browser',
      location: json['location']?.toString(),
      createdAt: parsedTime,
      expiresInSeconds: int.tryParse(json['expires_in']?.toString() ?? '90') ?? 90,
      securityCode: json['security_code']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge_id': challengeId,
      'website_name': websiteName,
      'ip_address': ipAddress,
      'device_info': deviceInfo,
      'location': location,
      'created_at': createdAt.toIso8601String(),
      'expires_in': expiresInSeconds,
      'security_code': securityCode,
      'status': status,
    };
  }
}
