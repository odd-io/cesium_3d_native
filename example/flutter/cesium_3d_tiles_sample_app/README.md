This demo app uses your access token to connect to Cesium Ion, retrieves the Google Photorealistic 3D Tiles tileset, and renders the output to your device. To get started:

- create an account at https://ion.cesium.com and login
- click on Access Tokens->Create Token and create a token with assets:read permission, and copy the generated token
- click on Asset Depot and search for "Google Photorealistic 3D Tiles", then click "Add to my assets" (if this has already been added, you ignore this step)

From the command line:
```
flutter channel master
flutter upgrade
flutter config --enable-native-assets
cd example/flutter
flutter pub get
flutter run -d macos --dart-define accessToken=YOUR_CESIUM_ION_ACCESS_TOKEN
```

where YOUR_CESIUM_ION_ACCESS_TOKEN is the token you created above.

