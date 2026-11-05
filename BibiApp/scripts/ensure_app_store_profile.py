"""Repair Bibi's production push profile using the existing Codemagic integration."""
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile


BUNDLE = "com.bibi.quadratic"
TEAM = "93BX5X327N"
OUTPUT = Path(os.environ.get("CM_BUILD_DIR", Path.cwd().parent)) / "build/signing"


def run(command):
    result = subprocess.run(command, capture_output=True, timeout=180)
    if result.returncode:
        label = " ".join(command[:3])
        status = re.search(rb"\b(401|403|409|429|5\d\d)\b", result.stderr)
        suffix = f" (HTTP {status[0].decode()})" if status else ""
        raise RuntimeError(f"{label} failed{suffix}. Check the Bibi integration's signing permissions.")
    return result.stdout


def asc(*arguments):
    data = json.loads(run(["app-store-connect", *arguments, "--json", "--no-color"]))
    if isinstance(data, dict) and "data" in data:
        data = data["data"]
    return data if isinstance(data, list) else [data]


def decode_profile(content):
    with tempfile.NamedTemporaryFile(suffix=".mobileprovision") as file:
        file.write(content)
        file.flush()
        return plistlib.loads(run(["security", "cms", "-D", "-i", file.name]))


def eligible(profile, identities):
    entitlements = profile.get("Entitlements", {})
    application = entitlements.get("application-identifier", "")
    expires = profile.get("ExpirationDate", dt.datetime.min)
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=dt.timezone.utc)
    certificates = {
        hashlib.sha1(cert).hexdigest().upper() for cert in profile.get("DeveloperCertificates", [])
    }
    return (
        TEAM in profile.get("TeamIdentifier", [])
        and application.endswith("." + BUNDLE)
        and not entitlements.get("get-task-allow", False)
        and not profile.get("ProvisionedDevices")
        and not profile.get("ProvisionsAllDevices", False)
        and expires > dt.datetime.now(dt.timezone.utc)
        and bool(certificates & identities)
    )


def save(content, identities):
    profile = decode_profile(content)
    if not eligible(profile, identities) or profile["Entitlements"].get("aps-environment") != "production":
        raise RuntimeError("Apple's returned profile does not match Bibi's team, identity and production push requirements.")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "Bibi-AppStore-Push.mobileprovision").write_bytes(content)
    summary = {
        "bundle_id": BUNDLE, "team": TEAM, "name": profile["Name"],
        "uuid": profile["UUID"], "aps_environment": "production",
        "expires": profile["ExpirationDate"].isoformat(),
        "matching_private_key_installed": True,
    }
    (OUTPUT / "profile-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Verified App Store profile {profile['Name']} for {TEAM}.{BUNDLE}, production APNs.")


def main():
    if os.environ.get("BUNDLE_ID") != BUNDLE or os.environ.get("APPLE_TEAM_ID") != TEAM:
        raise RuntimeError("This repair is restricted to Bibi's confirmed bundle and team.")
    identity_output = run(["security", "find-identity", "-v", "-p", "codesigning"])
    identities = set(re.findall(rb"\b[0-9A-Fa-f]{40}\b", identity_output))
    identities = {value.decode().upper() for value in identities}
    candidates = []
    for directory in (
        Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
        Path.home() / "Library/MobileDevice/Provisioning Profiles",
    ):
        for path in sorted(directory.glob("*.mobileprovision")):
            content = path.read_bytes()
            profile = decode_profile(content)
            if eligible(profile, identities):
                if profile["Entitlements"].get("aps-environment") == "production":
                    save(content, identities)
                    return
                candidates.append(profile)
    if not candidates:
        raise RuntimeError("No installed App Store profile matches Bibi's team and a usable signing identity. Check Codemagic Code signing identities.")

    print("Installed Bibi profile lacks production push; checking the existing Bibi API integration.")
    bundles = asc("bundle-ids", "list", "--bundle-id-identifier", BUNDLE, "--strict-match-identifier")
    bundles = [item for item in bundles if item.get("attributes", {}).get("identifier") == BUNDLE]
    if len(bundles) != 1:
        raise RuntimeError("The Bibi API integration cannot access the exact existing Bundle ID. No identifier was created or changed.")
    bundle_id = bundles[0]["id"]

    certificate_hashes = {
        hashlib.sha1(cert).hexdigest().upper()
        for profile in candidates for cert in profile["DeveloperCertificates"]
    } & identities
    certificates = asc("certificates", "list", "--profile-type", "IOS_APP_STORE")
    certificate_ids = [
        item["id"] for item in certificates
        if hashlib.sha1(base64.b64decode(item["attributes"]["certificateContent"])).hexdigest().upper()
        in certificate_hashes
    ]
    if not certificate_ids:
        raise RuntimeError("The API integration cannot find the installed profile's existing signing certificate. No new certificate was created.")

    capabilities = asc("bundle-ids", "capabilities", bundle_id)
    if not any(item.get("attributes", {}).get("capabilityType") == "PUSH_NOTIFICATIONS" for item in capabilities):
        run(["app-store-connect", "bundle-ids", "enable-capabilities", bundle_id,
             "--capability", "Push Notifications", "--no-color"])
        capabilities = asc("bundle-ids", "capabilities", bundle_id)
        if not any(item.get("attributes", {}).get("capabilityType") == "PUSH_NOTIFICATIONS" for item in capabilities):
            raise RuntimeError("Push Notifications was not present on Apple's capability readback.")
        print("Enabled Push Notifications on Bibi's existing App ID.")

    for item in asc("bundle-ids", "profiles", bundle_id):
        attributes = item.get("attributes", {})
        if attributes.get("profileType") != "IOS_APP_STORE" or attributes.get("profileState") != "ACTIVE":
            continue
        if not attributes.get("profileContent"):
            attributes = asc("profiles", "get", item["id"])[0]["attributes"]
        content = base64.b64decode(attributes["profileContent"])
        profile = decode_profile(content)
        if eligible(profile, identities) and profile["Entitlements"].get("aps-environment") == "production":
            save(content, identities)
            return

    index = os.environ.get("BUILD_NUMBER", dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d%H%M%S"))
    name = f"Bibi App Store Push {index}"
    created = asc("profiles", "create", bundle_id, "--certificate-ids", certificate_ids[0],
                  "--type", "IOS_APP_STORE", "--name", name)
    if len(created) != 1:
        raise RuntimeError("Apple did not return exactly one new provisioning profile.")
    save(base64.b64decode(created[0]["attributes"]["profileContent"]), identities)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, KeyError, OSError, subprocess.TimeoutExpired) as error:
        sys.exit(f"ERROR: {error}")
