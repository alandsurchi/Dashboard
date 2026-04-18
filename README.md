# dashbord

A new Flutter project.

## Run Locally (Web)

1. Install Flutter.
2. From the project root, run:

```bash
flutter pub get
flutter run -d chrome --dart-define=MQTT_USERNAME=Flutter --dart-define=MQTT_PASSWORD=123
```

## Deploy To Vercel

This project is configured to deploy Flutter web output on Vercel using:

- `vercel.json`
- `scripts/vercel-build.sh`

### Steps

1. Push this repository to GitHub.
2. In Vercel, click New Project and import the repository.
3. Keep Framework Preset as `Other`.
4. In Project Settings -> Environment Variables, add:
	 - `MQTT_USERNAME` (example: `Flutter`)
	 - `MQTT_PASSWORD` (example: `123`)
5. Deploy.

### Notes

- Routing rewrite to `index.html` is already configured for Flutter web.
- If environment variables are not provided, build defaults remain:
	- `MQTT_USERNAME=Flutter`
	- `MQTT_PASSWORD=123`
- Voice assistant on web requires HTTPS and microphone permission. Vercel provides HTTPS by default.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
