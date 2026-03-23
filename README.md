# Project Name
Flutter Desktop + Android Pairing

## Architecture
Flutter Version Manager [FVM](https://fvm.app/) 
Monorepo managed with [Melos](https://melos.invertase.dev/).

apps/
  desktop/       # Flutter desktop app (WebSocket server)
  android/       # Flutter Android app (WebSocket client)

packages/
  communication_core/   # Pairing and communication logic
  shared_ui/            # Shared widgets
  notification_service/ # Desktop notifications

## Getting Started
# Install melos globally
dart pub global activate melos

# Bootstrap all packages
melos bootstrap

## Running the apps
melos run desktop
melos run android