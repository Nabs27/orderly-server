import 'package:dio/dio.dart';
import '../../../core/api_client.dart';

class ServerProfile {
  final String id;
  final String name;
  final String role;
  final String pin;
  final Map<String, bool> permissions;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.pin,
    required this.permissions,
  });

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    final permsRaw = (json['permissions'] as Map<String, dynamic>? ?? {});
    final permissions = permsRaw.map((key, value) => MapEntry(key, value == true));
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String? ?? 'Serveur',
      pin: json['pin'] as String? ?? '',
      permissions: permissions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'pin': pin,
        'permissions': permissions,
      };

  ServerProfile copyWith({
    String? name,
    String? role,
    String? pin,
    Map<String, bool>? permissions,
  }) {
    return ServerProfile(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      pin: pin ?? this.pin,
      permissions: permissions ?? this.permissions,
    );
  }
}

class ServersService {
  static const _basePath = '/api/admin/servers-profiles';

  static Future<List<ServerProfile>> loadProfiles() async {
    final response = await ApiClient.dio.get(_basePath);
    final list = (response.data as List).cast<Map<String, dynamic>>();
    return list.map(ServerProfile.fromJson).toList();
  }

  static Future<ServerProfile> createProfile({
    required String name,
    required String pin,
    String role = 'Serveur',
    Map<String, bool>? permissions,
  }) async {
    final response = await ApiClient.dio.post(
      _basePath,
      data: {
        'name': name,
        'pin': pin,
        'role': role,
        'permissions': permissions,
      },
    );
    return ServerProfile.fromJson((response.data as Map<String, dynamic>));
  }

  static Future<ServerProfile> updateProfile(ServerProfile profile) async {
    final response = await ApiClient.dio.patch(
      '$_basePath/${profile.id}',
      data: {
        'name': profile.name,
        'pin': profile.pin,
        'role': profile.role,
        'permissions': profile.permissions,
      },
    );
    return ServerProfile.fromJson((response.data as Map<String, dynamic>));
  }

  static Future<void> deleteProfile(String id) async {
    await ApiClient.dio.delete('$_basePath/$id');
  }

  static Future<ServerProfile> togglePermission({
    required ServerProfile profile,
    required String permissionKey,
    required bool value,
  }) async {
    final updated = profile.permissions.map((key, val) => MapEntry(key, key == permissionKey ? value : val));
    return updateProfile(profile.copyWith(permissions: updated));
  }
}

