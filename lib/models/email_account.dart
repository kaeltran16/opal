import 'enums.dart';

/// Internal value-equality helper for lists of sender filter strings.
bool _strListEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A connected IMAP email account used for receipt import.
///
/// Mirrors the handoff's `@Model class EmailAccount`. The actual app password
/// is NEVER stored on the model — only [appPasswordRef], a keychain/secure-
/// storage reference. `Date?` → nullable [lastSyncedAt].
class EmailAccount {
  const EmailAccount({
    required this.address,
    required this.provider,
    required this.appPasswordRef,
    this.imapHost = 'imap.gmail.com',
    this.imapPort = 993,
    this.lastSyncedAt,
    this.autoSyncInterval = 15,
    this.senderFilters = const [],
  });

  final String address;
  final Provider provider;

  /// Keychain/secure-storage reference; the password itself is never modelled.
  final String appPasswordRef;
  final String imapHost;
  final int imapPort;

  /// Last successful sync time. Nullable (never synced yet).
  final DateTime? lastSyncedAt;

  /// Auto-sync cadence in minutes (15 default).
  final int autoSyncInterval;

  /// Allowlist of sender domains/addresses.
  final List<String> senderFilters;

  EmailAccount copyWith({
    String? address,
    Provider? provider,
    String? appPasswordRef,
    String? imapHost,
    int? imapPort,
    DateTime? lastSyncedAt,
    int? autoSyncInterval,
    List<String>? senderFilters,
  }) {
    return EmailAccount(
      address: address ?? this.address,
      provider: provider ?? this.provider,
      appPasswordRef: appPasswordRef ?? this.appPasswordRef,
      imapHost: imapHost ?? this.imapHost,
      imapPort: imapPort ?? this.imapPort,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      senderFilters: senderFilters ?? this.senderFilters,
    );
  }

  /// Serialise for local persistence (the password is never included — only
  /// [appPasswordRef], the secure-storage key). Used by `RealEmailSyncService`
  /// to survive app restarts.
  Map<String, Object?> toJson() => {
        'address': address,
        'provider': provider.wire,
        'appPasswordRef': appPasswordRef,
        'imapHost': imapHost,
        'imapPort': imapPort,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'autoSyncInterval': autoSyncInterval,
        'senderFilters': senderFilters,
      };

  factory EmailAccount.fromJson(Map<String, Object?> json) => EmailAccount(
        address: json['address']! as String,
        provider: Provider.fromWire(json['provider']! as String),
        appPasswordRef: json['appPasswordRef']! as String,
        imapHost: json['imapHost'] as String? ?? 'imap.gmail.com',
        imapPort: (json['imapPort'] as num?)?.toInt() ?? 993,
        lastSyncedAt: json['lastSyncedAt'] == null
            ? null
            : DateTime.parse(json['lastSyncedAt']! as String),
        autoSyncInterval: (json['autoSyncInterval'] as num?)?.toInt() ?? 15,
        senderFilters:
            (json['senderFilters'] as List?)?.cast<String>() ?? const [],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailAccount &&
          other.address == address &&
          other.provider == provider &&
          other.appPasswordRef == appPasswordRef &&
          other.imapHost == imapHost &&
          other.imapPort == imapPort &&
          other.lastSyncedAt == lastSyncedAt &&
          other.autoSyncInterval == autoSyncInterval &&
          _strListEquals(other.senderFilters, senderFilters);

  @override
  int get hashCode => Object.hash(
        address,
        provider,
        appPasswordRef,
        imapHost,
        imapPort,
        lastSyncedAt,
        autoSyncInterval,
        Object.hashAll(senderFilters),
      );

  @override
  String toString() =>
      'EmailAccount(address: $address, provider: ${provider.wire})';
}
