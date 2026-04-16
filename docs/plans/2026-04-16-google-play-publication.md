# Google Play Store Publication Implementation Plan

> **For Antigravity:** REQUIRED SUB-SKILL: Load executing-plans to implement this plan task-by-task.

**Goal:** Configure Android app signing and build a production-ready App Bundle (.aab).

**Architecture:** Use a local `key.properties` file for secure credential management, excluded from Git, and integrated into the Gradle build process.

**Tech Stack:** Flutter, Gradle, Keytool.

---

### Task 1: Environment Security

**Files:**
- Modify: `.gitignore`

**Step 1: Add signing files to .gitignore**

Add the following lines to the end of `.gitignore`:
```text
android/key.properties
android/app/*.jks
android/app/*.keystore
```

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: exclude signing files from version control"
```

---

### Task 2: Keystore Generation

**Files:**
- Create: `android/app/upload-keystore.jks`

**Step 1: Generate the keystore**

Run the following command:
```powershell
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
*Wait for interactive prompts. Note: You will need to provide these passwords in the next task.*

**Step 2: Verify file existence**

Check if `android/app/upload-keystore.jks` exists.

---

### Task 3: Signing Configuration

**Files:**
- Create: `android/key.properties`
- Modify: `android/app/build.gradle`

**Step 1: Create android/key.properties**

Create the file with the following content (replacing placeholders with passwords from Task 2):
```properties
storePassword=STRE_PASSWORD_HERE
keyPassword=KEY_PASSWORD_HERE
keyAlias=upload
storeFile=upload-keystore.jks
```

**Step 2: Load properties in android/app/build.gradle**

Add this at the top of the file (after imports):
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

**Step 3: Update signingConfigs in android/app/build.gradle**

Update the `signingConfigs` block:
```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

**Step 4: Use signingConfig in buildType**

Update the `buildTypes` block:
```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

**Step 5: Commit changes**

```bash
git add android/app/build.gradle
git commit -m "feat: configure android app signing"
```

---

### Task 4: Production Build

**Files:**
- Output: `build/app/outputs/bundle/release/app-release.aab`

**Step 1: Build the app bundle**

Run:
```bash
flutter build appbundle --release
```

**Step 2: Verify the output**

Confirm the existence of `build/app/outputs/bundle/release/app-release.aab`.
