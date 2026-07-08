# Releasing Headwind

The `Release to TestFlight` workflow builds, signs, and uploads the app to
App Store Connect from CI. No certificates or passwords live in the repo —
signing is cloud-managed by Xcode using an App Store Connect API key.

## One-time setup (≈10 minutes, requires the account holder)

1. **Enroll in the Apple Developer Program** ($99/yr) at
   [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll)
   if not already enrolled.

2. **Create the App ID** — [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers)
   → `+` → App IDs → App → Bundle ID **explicit** `com.headwind.app`.
   No extra capabilities needed for v1.

3. **Create the app record** — [App Store Connect](https://appstoreconnect.apple.com)
   → My Apps → `+` → New App:
   - Platform: iOS
   - Name: **Headwind**
   - Primary language: English (U.S.)
   - Bundle ID: `com.headwind.app`
   - SKU: `headwind-ios`

4. **Generate an App Store Connect API key** — App Store Connect →
   Users and Access → Integrations → App Store Connect API → Team Keys →
   `+`. Role: **Admin** (cloud signing needs it to create the distribution
   certificate). Download the `.p8` file — **it can only be downloaded
   once** — and note the Key ID and Issuer ID shown on that page.

5. **Add four GitHub repository secrets** — repo → Settings →
   Secrets and variables → Actions → New repository secret:

   | Secret | Value |
   |---|---|
   | `ASC_KEY_ID` | Key ID from step 4 |
   | `ASC_ISSUER_ID` | Issuer ID from step 4 |
   | `ASC_KEY_P8` | Entire contents of the `.p8` file (open in a text editor, copy all) |
   | `APPLE_TEAM_ID` | 10-character Team ID from [Membership](https://developer.apple.com/account#MembershipDetailsCard) |

Never paste the `.p8`, your Apple ID password, or any of these values into
chat, issues, or commits — GitHub secrets only.

## Every release

1. Run the **Release to TestFlight** workflow (Actions tab → Release to
   TestFlight → Run workflow). The build number is set automatically from
   the CI run number; the marketing version comes from
   `MARKETING_VERSION` in the project.
2. Wait ~15 minutes for Apple's processing, then the build appears in
   App Store Connect → TestFlight. Add yourself as an internal tester and
   install via the TestFlight app.
3. **Fly with it** (or drive) before submitting: track recording,
   background location, and battery behavior can only be validated on a
   real device.
4. When satisfied: App Store Connect → App Store tab → create the version,
   attach the build, paste the listing copy from
   `docs/store/app-store-listing.md`, upload screenshots from
   `docs/screenshots/`, and submit for review.

## Notes

- `export-only` mode in the workflow dispatch builds and signs the IPA and
  attaches it as a CI artifact instead of uploading — useful for
  inspecting the bundle.
- Version bumps: edit `MARKETING_VERSION` in
  `Headwind.xcodeproj/project.pbxproj` (two occurrences, Debug + Release).
- The privacy manifest (`PrivacyInfo.xcprivacy`) and
  `ITSAppUsesNonExemptEncryption=NO` are already configured, so no export
  compliance questions should appear at submission.
