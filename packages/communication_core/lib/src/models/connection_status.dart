enum ConnectionStatus { disconnected, pairing, upgrading, connected, error }

extension ConnectionStatusLabel on ConnectionStatus {
  String get label => switch (this) {
    ConnectionStatus.disconnected => 'Not connected',
    ConnectionStatus.pairing      => 'Pairing...',
    ConnectionStatus.upgrading    => 'Upgrading connection...',
    ConnectionStatus.connected    => 'Phone connected',
    ConnectionStatus.error        => 'Max reconnects reached. Restart app.',
  };
}