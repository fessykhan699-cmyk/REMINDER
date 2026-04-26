# PayDeck Google Play Store Submission Checklist

This document serves as the guide for all Google Play Store policy requirements for PayDeck (com.apexmobilelabs.reminder). Verify every item before each submission to minimize rejection risk.

---

### SECTION 1 — APP IDENTITY & STORE LISTING

| Item | Requirement | Status |
| :--- | :--- | :---: |
| **App Name** | 30 char max, no prices, no #1 claims, no "best", no "free" in name. | □ |
| **Short Description** | 80 chars max, no keyword stuffing. | □ |
| **Full Description** | 4000 chars max, accurate, no misleading claims. | □ |
| **Screenshots** | Must match actual app UI, no device frames, show PayDeck branding. | □ |
| **Feature Graphic** | 1024x500px required. | □ |
| **App Icon** | 512x512px, no misleading design. | □ |
| **Content Rating** | Complete questionnaire honestly based on financial context. | □ |
| **Category** | Finance or Business (be consistent across listings). | □ |
| **Tags** | No competitor names allowed (e.g., "Invoice2Go"). | □ |
| **Contact Details** | Valid support email and HTTPS support URL. | □ |
| **Privacy Policy** | Live HTTPS link, matching in-app link. | □ |

---

### SECTION 2 — DATA SAFETY FORM
*Google Play's most common rejection reason. PayDeck must document as follows.*

**Data Collected and Purpose:**
- **Email Address**: Collected via Google Sign-in for account identification.
- **User ID**: Firebase UID used to link data to the account.
- **Invoice Data**: Amounts, client names, due dates. Stored in Firestore, linked to user identity.
- **Expense Data**: Amounts, categories. Stored in Firestore.
- **Client Data**: Names, emails, phone numbers. Stored in Firestore.
- **Device Identifiers**: Used by Firebase Analytics (if enabled).
- **Crash Logs**: Collected by Firebase Crashlytics.

**Data Sharing & Security:**
- **Sharing**: Google/Firebase (auth, storage, analytics). No ad networks. No sale of data.
- **Security**: All data encrypted in transit (Firebase default).
- **Deletion**: Users can request deletion in-app and via external URL.

**Form Answers:**
- Does app collect data? **YES**
- Is data encrypted in transit? **YES**
- Can users request deletion? **YES**
- Deletion method: In-app Settings → Delete Account.

---

### SECTION 3 — ACCOUNT DELETION REQUIREMENT
*Mandatory per May 2024 policy.*

- [ ] **In-app deletion**: Settings → Delete Account (Must delete Auth + Firestore + Local).
- [ ] **Web deletion URL**: REQUIRED for Play Console. (Options: Google Form or `mailto:support@paydeck.app`).
- [ ] **Transparency**: Privacy Policy must explicitly mention the deletion option and the "within 30 days" timeframe.

---

### SECTION 4 — PERMISSIONS POLICY
*Every permission in AndroidManifest.xml must be justified.*

- **INTERNET**: Required for Firebase/Cloud sync.
- **RECEIVE_BOOT_COMPLETED**: Required for notification rescheduling.
- **POST_NOTIFICATIONS**: Required for invoice reminders (Runtime permission required).
- **USE_BIOMETRIC / USE_FINGERPRINT**: Required for app lock feature.
- **VIBRATE / WAKE_LOCK**: Required for background notification delivery.
- **BILLING**: Required for Google Play in-app purchases.

---

### SECTION 5 — FINANCIAL APP REQUIREMENTS
*PayDeck is an INVOICING TOOL, not a financial service.*

- No investment advice.
- No real money transfers.
- No bank account connections.
- No promised financial returns.
- No regulatory license required for invoicing tools.

---

### SECTION 6 — IN-APP PURCHASES POLICY

- [ ] **Billing System**: All Pro subscriptions must use Google Play Billing.
- [ ] **Price Parity**: Do not offer cheaper subscriptions outside the app.
- [ ] **UI Disclosure**: Subscription screen must show price, period, features, and "Manage in Google Play Settings" instruction.
- [ ] **Functionality**: Free tier must be genuinely usable (e.g., 5 free invoices/month).
- [ ] **Restore**: "Restore Purchases" button must exist in Settings/Paywall.
- [ ] **IDs**: `invoiceflow_pro_monthly` and `invoiceflow_pro_yearly`.

---

### SECTION 7 — CONTENT POLICY

- [ ] No hate speech, violence, or adult content.
- [ ] Screenshots match actual app UI (no mockups).
- [ ] No competitor trademarks used in metadata.
- [ ] Notifications must be relevant and not spammy.

---

### SECTION 8 — TECHNICAL REQUIREMENTS

- [ ] **targetSdkVersion**: 34+ (2026 Submission Requirement).
- [ ] **64-bit Support**: Flutter default (AAB format required).
- [ ] **Stability**: No crashes on launch; no ANRs in core flows.
- [ ] **URLs**: All external links (Privacy, TOS, Support) must load successfully.
- [ ] **Signing**: Release build must use the approved Play Store upload key.

---

### SECTION 9 — PRIVACY POLICY REQUIREMENTS

**Must include:**
- Exhaustive list of data types collected.
- Purpose of collection (Auth, Sync, Analytics).
- Sharing details (Firebase, Google).
- Data retention and "Right to be Forgotten" (Deletion).
- Contact info for privacy requests.
- Accessible at a live HTTPS URL without login.

---

### SECTION 10 — PRE-SUBMISSION CHECKLIST
*Run this before EVERY upload.*

**Code Check:**
- [ ] `_debugBypassSubscription = false`
- [ ] `overdue_flip_service` debug hooks removed.
- [ ] No `[DIAGNOSTIC]` debugPrint lines in release build.
- [ ] `flutter analyze` returns 0 Errors.
- [ ] Version code incremented in `pubspec.yaml`.

**Branding Check:**
- [ ] No "Invoice Flow" text remains.
- [ ] App label in manifest = "Paydeck".
- [ ] PDF exports show "Paydeck" branding.

**Legal & Testing:**
- [ ] "Delete Account" tested and verified to wipe cloud data.
- [ ] Subscription gate blocks users at correct limits.
- [ ] Pro bypass is verified to be OFF.

---

### SECTION 11 — COMMON REJECTION REASONS
1. **Inaccurate Data Safety form**: Declare every single data point.
2. **Missing account deletion**: In-app + Web URL is mandatory.
3. **Misleading store listing**: UI must match screenshots exactly.
4. **Subscription UI violations**: Auto-renewal disclosure must be prominent.
5. **Crashes during review**: Test on low-end Android devices before bundle generation.
