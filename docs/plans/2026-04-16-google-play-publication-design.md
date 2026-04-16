# 2026-04-16 Google Play Store Publication Design

## Goal
Prepare the Flutter application for production release on the Google Play Store by setting up secure app signing and building a signed Android App Bundle (AAB).

## Architecture: Signing Infrastructure
- **Security-First**: Sensitive credentials (keystore, passwords) will be stored in a local `key.properties` file.
- **Git Safety**: Both the `.jks` file and `key.properties` will be explicitly added to `.gitignore`.
- **Gradle Integration**: The `android/app/build.gradle` will be configured to load properties dynamically during the build process, ensuring transparency for production builds.

## Components
1. **Keystore (`android/app/upload-keystore.jks`)**: The digital signature used by Google Play to identify the developer.
2. **Properties File (`android/key.properties`)**: Maps keystore file paths and passwords for the build system.
3. **Gradle Configuration (`android/app/build.gradle`)**: Scripting to apply the signing configuration to the `release` build type.
4. **App Bundle (`build/app/outputs/bundle/release/app-release.aab`)**: The final production artifact.

## Success Criteria
- Successful generation of a 2048-bit RSA keystore.
- Successful execution of `flutter build appbundle` without errors.
- Generation of a valid `.aab` file ready for manual upload to the Google Play Console.
