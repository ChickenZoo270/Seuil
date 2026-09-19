// Downloads the active App Store provisioning profiles for Seuil from the
// App Store Connect API, installs them, and writes the signing settings used
// by the TestFlight workflow. Never prints key material.
import { createPrivateKey, sign } from "node:crypto";
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const TARGETS = {
  Intention: "com.chickenzoo.seuil",
  ShieldConfiguration: "com.chickenzoo.seuil.shieldconfiguration",
  ShieldAction: "com.chickenzoo.seuil.shieldaction",
  Monitor: "com.chickenzoo.seuil.monitor",
};
const REQUIRED_ENTITLEMENTS = [
  "com.apple.developer.family-controls",
  "com.apple.security.application-groups",
];
const TOKEN_LIFETIME_SECONDS = 15 * 60;

const { ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, RUNNER_TEMP, GITHUB_ENV } = process.env;
for (const [name, value] of Object.entries({ ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, RUNNER_TEMP, GITHUB_ENV })) {
  if (!value) throw new Error(`Missing environment variable ${name}`);
}

const base64url = (input) => Buffer.from(input).toString("base64url");

function createToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "ES256", kid: ASC_KEY_ID, typ: "JWT" }));
  const payload = base64url(JSON.stringify({
    iss: ASC_ISSUER_ID,
    iat: now,
    exp: now + TOKEN_LIFETIME_SECONDS,
    aud: "appstoreconnect-v1",
  }));
  const key = createPrivateKey(readFileSync(ASC_KEY_PATH));
  const signature = sign("sha256", Buffer.from(`${header}.${payload}`), { key, dsaEncoding: "ieee-p1363" });
  return `${header}.${payload}.${base64url(signature)}`;
}

async function fetchProfiles(token) {
  const url = new URL("https://api.appstoreconnect.apple.com/v1/profiles");
  url.searchParams.set("filter[profileType]", "IOS_APP_STORE");
  url.searchParams.set("filter[profileState]", "ACTIVE");
  url.searchParams.set("include", "bundleId");
  url.searchParams.set("limit", "200");
  const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!response.ok) {
    throw new Error(`App Store Connect API ${response.status}: ${await response.text()}`);
  }
  return response.json();
}

// Profiles are CMS-signed plists; the embedded XML is readable as plain text.
function entitlementsOf(profileBytes) {
  const xml = profileBytes.toString("latin1");
  const start = xml.indexOf("<key>Entitlements</key>");
  const end = xml.indexOf("</dict>", start);
  return start === -1 ? "" : xml.slice(start, end);
}

function pickProfile(body, bundleIdentifier) {
  const bundleIds = new Map(
    (body.included ?? [])
      .filter((item) => item.type === "bundleIds")
      .map((item) => [item.id, item.attributes.identifier]),
  );
  const matches = body.data
    .filter((profile) => bundleIds.get(profile.relationships?.bundleId?.data?.id) === bundleIdentifier)
    .sort((a, b) => b.attributes.expirationDate.localeCompare(a.attributes.expirationDate));
  if (matches.length === 0) {
    throw new Error(`No active IOS_APP_STORE profile for ${bundleIdentifier}. Create one in Certificates, Identifiers & Profiles.`);
  }
  return matches[0];
}

const body = await fetchProfiles(createToken());
const profileDir = join(homedir(), "Library", "MobileDevice", "Provisioning Profiles");
mkdirSync(profileDir, { recursive: true });

const exportProfiles = [];
for (const [target, bundleIdentifier] of Object.entries(TARGETS)) {
  const profile = pickProfile(body, bundleIdentifier);
  const { name, uuid, profileContent, expirationDate } = profile.attributes;
  const bytes = Buffer.from(profileContent, "base64");
  const entitlements = entitlementsOf(bytes);
  const missing = REQUIRED_ENTITLEMENTS.filter((key) => !entitlements.includes(key));
  if (missing.length > 0) {
    throw new Error(`Profile "${name}" (${bundleIdentifier}) lacks ${missing.join(", ")}. Regenerate it after enabling the capability on the App ID.`);
  }
  writeFileSync(join(profileDir, `${uuid}.mobileprovision`), bytes);
  appendFileSync(GITHUB_ENV, `SEUIL_PROFILE_${target}=${name}\n`);
  exportProfiles.push(`    <key>${bundleIdentifier}</key>\n    <string>${uuid}</string>`);
  console.log(`${target}: "${name}" (${uuid}), expires ${expirationDate}`);
}

const exportOptions = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>upload</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Apple Distribution</string>
  <key>teamID</key>
  <string>${process.env.APPLE_TEAM_ID}</string>
  <key>provisioningProfiles</key>
  <dict>
${exportProfiles.join("\n")}
  </dict>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
`;
const exportOptionsPath = join(RUNNER_TEMP, "ExportOptions.plist");
writeFileSync(exportOptionsPath, exportOptions);
appendFileSync(GITHUB_ENV, `EXPORT_OPTIONS_PATH=${exportOptionsPath}\n`);
