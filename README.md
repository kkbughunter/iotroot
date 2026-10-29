# IoTRoot mobile app

Flutter Android/iOS client for the existing `../IotRootBackend` API. Login replaces the previous simulator; all telemetry and message activity come from MQTT or the stored-message API.

## Run

```sh
flutter pub get
flutter run
```

The default API is `https://iotroot.astraval.com`. Change **Server settings** on the login screen or set a build default:

```sh
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

For a local backend, use your computer's LAN address on a physical phone, or `10.0.2.2:8080` on the Android emulator. Android debug builds permit HTTP for development; use HTTPS for release builds. iOS permits local networking and requests local-network access for local brokers.

1. Sign in with an existing, verified IoTRoot account.
2. Select one of that account's devices and its topic rules.
3. Open **Broker connection**. Client ID, username and mountpoint come from the devices API; host and port come from connection-status. Host, port and TLS can be overridden for the actual broker listener.
4. Enter the device MQTT password and connect. The app can remember it in platform secure storage. The backend stores only a password hash and does **not** expose or recover the original password. Use the password set when creating that device, not necessarily the account login password.
5. Select a template for each topic. Templates, broker preferences and metric mappings are saved locally per API/account/device/topic. For custom JSON, map metric fields using paths such as `data.temperature`; leave a mapping blank for scalar numeric payloads. The raw payload view and Activity retain all fields, plain text, arrays and nulls.
6. Publish template commands or custom JSON/plain text on an allowed topic. Wildcard rules require an exact matching publish topic. No `/set` or `/data` suffix is added. Publish uses QoS 1 without retain; success means the broker acknowledged the packet, not that hardware executed the command.

The app connects using the exact backend-issued client ID. MQTT permits one active connection per client ID: connecting this app can replace hardware already using that ID. Use a separate dashboard device with the appropriate topic permissions when hardware must stay online. Mountpoints are applied by broker authentication and are not prepended to MQTT topics in the app.

The selected device subscribes to all of its subscribe/readwrite rules. Device changes and logout disconnect the broker. Unexpected disconnects trigger MQTT reconnection and resubscription. The UI shows no fabricated readings; missing or unmapped values remain “Waiting for data”. Live buffers keep the latest 200 messages per rule and Activity the latest 300 messages per session. STORE topics additionally offer paginated saved messages for the last 30 days. Exact STORE topics are required for history.

## API contracts used

- `POST /api/auth/login`, `/refresh-token`, `/logout`
- `GET /api/devices`
- `GET /api/devices/connection-status`
- `GET /api/devices/{deviceId}/rules`
- `GET /api/store/messages` with device, exact topic, date range and pagination

Responses use the backend's `{status, code, message, data}` envelope. Access/refresh tokens use secure storage; requests refresh expired tokens, retry once on 401 and return to login when refresh is rejected. Account passwords are not retained. Logout removes the local session and attempts server-side refresh-token revocation; it still signs out locally while offline. Saved device passwords and template preferences remain scoped to their account for later sign-in.

The backend and React frontend are unchanged. Device/topic creation remains in the existing dashboard. This project currently targets Android and iOS and uses native MQTT TCP/TLS; Flutter Web would require a WebSocket broker transport and a web target.

## Checks

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The MQTT integration test starts an isolated local Mosquitto broker with password authentication, then checks connect, subscribe, UTF-8 receive, QoS 1 acknowledgement and invalid-password rejection. It does not contact the production broker:

```sh
MQTT_TEST_BROKER="$(command -v mosquitto)" flutter test
```

`mosquitto_passwd` must be on PATH, or set `MQTT_TEST_PASSWORD_TOOL` to its executable path. Without `MQTT_TEST_BROKER`, only that integration test is skipped.

Libraries: [mqtt_client](https://pub.dev/packages/mqtt_client), [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage), and [http](https://pub.dev/packages/http).
