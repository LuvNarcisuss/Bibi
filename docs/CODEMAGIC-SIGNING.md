# Codemagic App Store signing

## Failure and correction

The reported error was `No matching profiles found for bundle identifier
"com.bibi.quadratic" and distribution type "app_store"`.
The previous environment.ios_signing selector required a matching provisioning
profile already stored in Codemagic Code signing identities. Selection happens
before workflow scripts, so a later xcode-project use-profiles could not repair
that missing input. The source project and generator already agree on the Bundle
ID and team; changing the application identity is not the remedy.

The workflow now uses Codemagic's documented CLI signing flow: initialize its
keychain, fetch signing files for the exact bundle with IOS_APP_STORE and --create,
import certificates, then apply profiles from BibiApp. The old upfront profile
selector is removed; these are alternative signing approaches, not two independent
ways to run simultaneously. Existing identity, schemes, notifications, build
number handling and review-submission settings are preserved.

## Required Codemagic configuration

1. Keep the App Store Connect integration named Bibi. It must belong to Apple
   team JPTS6M4T5B and have Certificates, Identifiers & Profiles permissions.
2. Create an application/team environment group named bibi_signing and grant the
   Bibi application access to it. Add CERTIFICATE_PRIVATE_KEY as a Secret. Its
   value is the PEM private key matching the intended Apple Distribution
   certificate. This is distinct from the App Store Connect .p8 API key already
   managed by the Bibi integration. Do not paste either key into chat or Git.
3. Reuse the existing distribution certificate/key. With --create, the CLI may
   register a missing bundle/profile or create a certificate if its supplied key
   has no match. Do not rotate/revoke existing certificates or repeatedly create
   keys to work around Apple's certificate limit. Inspect the account if fetching
   fails; check expiry, permissions and team before retrying.
4. Confirm that Apple app 6828253391 belongs to com.bibi.quadratic in that team.
   An existing App Store record with a different Bundle ID is not repaired by
   changing a YAML variable. Resolve that identity in the Apple account first.
5. Use the revised YAML in the remote branch. Resource delivery uses the pinned CI recovery workflow in CI-RESOURCES.md;
   commit its snapshot, scripts and Git-owned Assets with the workflow.

If retaining Code signing identities instead, upload/fetch a valid App Store
profile for this exact Bundle ID and its matching distribution certificate/private
key, then explicitly restore that workflow mode. A Development or Ad Hoc profile,
an expired profile, or a profile for the former Bundle ID cannot satisfy the
original app_store selector.

## Evidence and limits

This revision has static YAML parsing, workflow ordering/identity checks and Bash
syntax inspection only. No signing files were fetched, no Apple resources were
created, and no keychain, build, simulator, Codemagic job or upload was executed.
The original cloud failure is not claimed runtime-resolved. The first authorized
remote run must confirm the group/secret, integration permissions, matching team,
profile and successful archive/export. Keep secret values out of diagnostic logs.

Official references:
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
- https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/
