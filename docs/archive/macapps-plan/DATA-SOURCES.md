# DATA-SOURCES — Detecting "Outdated"

This is the heart of the app. The scanner can list every installed app
trivially, but deciding whether each one is **outdated** requires talking to
five very different update ecosystems. Each one has its own detection
heuristics, its own data formats, and its own failure modes.

We layer the checkers in this order — the first to return a confident answer
wins, the rest are skipped:

1. **Sparkle** — most precise when available, no external CLI needed
2. **Mac App Store** — precise if `mas` is installed, else `.unknown`
3. **Homebrew Cask** — precise if `brew` is installed, else `.unknown`
4. **Heuristic** — last-resort signal based on file modification time, used
   only for direct-download apps with no updater

---

## 1. Sparkle

Sparkle is the de-facto auto-updater for indie Mac apps. It is embedded in
apps like Slack, Discord, Sketch, 1Password 7, BBEdit, Acorn, and many more.
Any app that has `SUFeedURL` in its `Info.plist` is using Sparkle (or a
Sparkle-compatible updater).

### 1.1 Detection

```swift
let feedURLString = infoPlist["SUFeedURL"] as? String
guard let feedURL = feedURLString.flatMap(URL.init(string:)) else {
    // not a Sparkle app
}
```

We treat the presence of `SUFeedURL` as sufficient. We do not also check
for the Sparkle framework binary because some apps vendor a fork of Sparkle
without changing the Info.plist key.

### 1.2 The appcast feed

Sparkle fetches an `appcast.xml` (or sometimes `appcast.json`) from the
`SUFeedURL`. The XML is RSS-flavored:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     version="2.0">
  <channel>
    <title>Acorn updates</title>
    <item>
      <title>7.3.4</title>
      <pubDate>Mon, 15 Sep 2025 10:00:00 +0000</pubDate>
      <enclosure
        url="https://flyingmeat.com/download/Acorn7.3.4.zip"
        sparkle:version="68420"
        sparkle:shortVersionString="7.3.4"
        length="12345678"
        type="application/octet-stream" />
    </item>
    <item>
      <title>7.3.3</title>
      <pubDate>...</pubDate>
      <enclosure sparkle:shortVersionString="7.3.3" ... />
    </item>
    <!-- more items, newest first -->
  </channel>
</rss>
```

We need `sparkle:shortVersionString` from the first `<item>`.

### 1.3 Parsing strategy

Use `XMLParser` (Foundation) — not a third-party XML library. The relevant
fields per item are:

- `sparkle:shortVersionString` (preferred)
- `sparkle:version` (build number fallback)
- `<pubDate>` (RFC 822)

We only need the **first** `<item>` (newest), but we still parse the full
document so the test fixtures can verify ordering.

### 1.4 HTTP fetching

```swift
let (data, response) = try await URLSession.shared.data(from: feedURL)
guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
    throw MacAppsError.sparkleFeedUnreachable(feedURL)
}
let appcast = try AppcastParser.parse(data: data)
```

- Timeout: 10 s per feed.
- `URLSession.shared` is fine. We are not in a sandbox.
- Cache-Control: ignored. The user is explicitly hitting refresh.
- Concurrent fetches: limit to 6 in flight (custom `URLSession` configuration
  with `httpMaximumConnectionsPerHost = 6`). Realistically there are < 20
  Sparkle apps on a Mac.

### 1.5 Comparing versions

`Version.compare("7.3.4", "7.3.3") == .orderedDescending`. See
`macappsCore/Parsing/Version.swift` for the implementation rules. Crucial:
**numeric, not lexicographic**. `"7.10.0" > "7.9.0"`.

### 1.6 Gotchas

- **JSON appcasts.** Some apps (e.g., newer forks of Sparkle) publish
  `appcast.json` instead of XML. The feed URL hints at the format. If
  `URL.pathExtension == "json"`, parse differently. Add a parser branch.
- **`<enclosure>` only, no `sparkle:shortVersionString`.** Fall back to
  `sparkle:version` (build), then to the `<title>` parsed as a version. If
  none work, treat as `.unknown`.
- **Channel-style feeds** (multiple `<item>` with `<sparkle:channel>`).
  Skip the implementation in v1. Most apps don't use this.
- **Minimum system version filtering.** Some feeds include
  `<sparkle:minimumSystemVersion>`. We don't filter on this — show the
  user all available updates and let them decide.
- **EdDSA signatures.** Some feeds require `<sparkle:edSignature>`
  validation. We **do not** validate — we are not downloading binaries, just
  reading version strings.
- **HTTPS-only.** Reject non-HTTPS feeds. None of the major apps use plain
  HTTP.
- **Feed URL is invalid.** Wrap in `.unknown(reason: "Feed URL unreachable")`.
- **Feed is huge.** Some dev-team feeds include 10+ years of releases. We
  stop parsing after the first 50 `<item>`s.

---

## 2. Mac App Store (MAS)

Apps installed through the Mac App Store are owned by Apple. Determining
their latest version requires either the App Store JSON API or the `mas`
CLI by argon (https://github.com/mas-cli/mas).

### 2.1 Detection (per app)

A bundle was installed via MAS iff it has a non-empty receipt at
`<bundle>/Contents/_MASReceipt/receipt`. The presence of the directory is
sufficient — we do not validate the receipt cryptographically.

```swift
let receipt = bundleURL.appendingPathComponent("Contents/_MASReceipt/receipt")
let isMAS = (try? receipt.checkResourceIsReachable()) == true
```

**Edge case:** some apps bundle a placeholder receipt for development but
ship through direct download. There is no reliable way to detect this in
v1. We trust the receipt.

### 2.2 The `mas` CLI

`mas` is a small, signed, open-source CLI. It requires the user to be
signed in to the Mac App Store on the same machine.

**Check whether installed:**

```bash
command -v mas && mas version
```

**List installed (for cross-reference):**

```bash
mas list
# 123456789  App Name             1.2.3
```

**List outdated (the one we actually want):**

```bash
mas outdated
# 123456789  App Name             1.2.3
```

Note: `mas outdated` does not have a JSON flag. We parse its text output
line-by-line. Each line is: `<numeric_id>\t<name>\t<installed_version>`.

### 2.3 Mapping `mas` results to our apps

`mas` does not return bundle IDs, only app names. We have to fuzzy-match by
name. Strategy:

1. Build a `[String: InstalledApp]` keyed by lowercased name from our scan.
2. For each `mas` line, look up the name.
3. On a single match: associate the MAS appStore ID with our app.
4. On a collision (multiple installed apps with the same name): fall back to
   the `CFBundleIdentifier` matching `mas`'s known `bundleId` field (we'd
   need a local database, which `mas` does not provide). In v1, just use
   the first match and log a warning.
5. On no match: the `mas` line is for an app we didn't find (rare — apps
   hidden by the user, or a system app). Ignore.

### 2.4 Cross-check: which MAS apps are up-to-date?

We need to know both the installed version (from our scan, always
available) and the latest version (from `mas`). Then compare.

`mas` does **not** give us "latest version per app" directly. It only gives
us "outdated apps" — apps where installed != latest. The assumption is: if
an app is not in the `mas outdated` list, it is up-to-date. This is
correct as long as the user has run App Store updates at least once (so
`mas` knows the local version). We document this assumption in the UI.

### 2.5 Subprocess invocation

```swift
let runner = CLIRunner(timeout: 10)
let result = try await runner.run("/usr/local/bin/mas", ["outdated"])
let outdatedIDs = parseMasOutdated(result.stdout)
```

`CLIRunner` returns a `CLIResult` with stdout/stderr/exitCode. We always
check exit code and surface non-zero as `.unknown(reason: stderr)`.

### 2.6 Fallback when `mas` is missing

If `command -v mas` fails, we mark **every** MAS app as
`.unknown(reason: "Install `mas` to check Mac App Store updates: brew install mas")`.

The user can then click the row → "Open in Mac App Store" action to update
manually.

### 2.7 Gotchas

- **`mas` requires user to be signed in.** If not, `mas outdated` exits
  non-zero with a specific error. We capture stderr and surface it.
- **App is hidden by the user.** `mas list` excludes hidden apps. The
  installed version is still in our scan. We just won't get the
  "up-to-date" answer.
- **The `mas` GitHub project is no longer actively maintained.** Risk of
  bit-rot. Mitigation: we wrap `mas` in our `CLIRunner`, so if the binary
  format changes, we update one parser.
- **iOS apps on Apple Silicon.** These also have `Contents/_MASReceipt`
  but are not user-facing macOS apps. We currently scan only the
  user-Applications directories and skip `~/Library/Developer/CoreSimulator`,
  so this is handled implicitly.

---

## 3. Homebrew Cask

Homebrew installs apps via **formulae** (CLI tools) and **casks** (GUI
apps). For "outdated apps" we care about casks. Homebrew maintains a
local cache of metadata, so updates can be detected offline (latest version
is known after a `brew update`).

### 3.1 Detection (per app)

A `.app` was installed by Homebrew Cask iff it lives under Homebrew's
prefix. The prefix differs by arch:

- Apple Silicon: `/opt/homebrew/Caskroom/<token>/<version>/<token>.app`
- Intel: `/usr/local/Caskroom/<token>/<version>/<token>.app`

We resolve the prefix once per scan via `brew --prefix` if `brew` is
installed; otherwise we hardcode the two prefixes above.

```swift
let brewPrefixes = [
    URL(fileURLWithPath: "/opt/homebrew/Caskroom"),
    URL(fileURLWithPath: "/usr/local/Caskroom"),
]

func detect(bundleURL: URL) -> (Bool, String?) {
    for prefix in brewPrefixes {
        // bundleURL.path == /opt/homebrew/Caskroom/<token>/<version>/<token>.app
        if bundleURL.path.hasPrefix(prefix.path) {
            let relPath = bundleURL.path.dropFirst(prefix.path.count)
            let components = relPath.split(separator: "/")
            if let token = components.first {
                return (true, String(token))
            }
        }
    }
    return (false, nil)
}
```

### 3.2 The `brew` CLI

**Check whether installed:**

```bash
command -v brew && brew --version
```

**List installed casks (for cross-reference):**

```bash
brew list --cask --json=v2
```

Returns:
```json
{
  "casks": [
    { "token": "firefox", "installed": "131.0", "version": "131.0", ... },
    ...
  ]
}
```

**List outdated casks (the one we want):**

```bash
brew outdated --cask --json=v2
```

Returns:
```json
{
  "casks": [
    {
      "token": "firefox",
      "installed_versions": ["130.0"],
      "current_version": "131.0",
      "outdated": true
    },
    ...
  ]
}
```

### 3.3 Mapping brew casks to our apps

`brew outdated --cask` gives us cask tokens, not bundle paths. We need to
map token → bundle. Two options:

- **(preferred)** `brew info --cask --json=v2 <token>` returns the cask
  metadata, including the `artifacts` section. For casks that install a
  single `.app`, this gives us the path. We batch the calls in parallel.
- **(fallback)** `lsregister -dump | grep -A 1 "bundle_id" | grep <token>`
  — works but slow and brittle.

For v1, we batch `brew info --cask --json=v2` for every outdated cask and
build a `[token: bundleURL]` map. Then we walk our `InstalledApp` list and
match by bundleURL. Apps installed by brew but not in the outdated list are
treated as `.upToDate`.

### 3.4 Subprocess invocation

```swift
let result = try await runner.run("/opt/homebrew/bin/brew", [
    "outdated", "--cask", "--json=v2"
])
let payload = try JSONDecoder().decode(BrewOutdatedResponse.self, from: Data(result.stdout.utf8))
```

### 3.5 Fallback when `brew` is missing

Same pattern as `mas`. Apps in `/opt/homebrew/Caskroom` (detected via
filesystem) get marked
`.unknown(reason: "Install Homebrew to check updates: https://brew.sh")`.

### 3.6 Gotchas

- **`brew` is slow.** First invocation loads its environment script
  (~0.3–0.5 s). We invoke it once at scan start, then chain the rest.
- **`brew update` is needed for accurate "latest".** If the user hasn't run
  it, `current_version` is stale. We do **not** run `brew update`
  automatically — that modifies system state. Instead, we surface a banner
  "brew cache may be stale — run `brew update`" if `outdated` returns
  suspiciously few entries (< 5% of installed casks).
- **Casks without a `version` field.** Some casks use `:latest`. We skip
  these — we can't compare, so we can't say "outdated".
- **Greedy vs non-greedy casks.** Modern brew has a `--greedy` flag for
  casks that track multiple versions. We use `brew outdated --cask` without
  `--greedy` to match normal user expectations.
- **Architecture mismatch.** A cask may install an app into both
  `/Applications` (symlink) and the Caskroom. We scan the Caskroom first,
  match by token, and only fall back to `/Applications` if not found.

---

## 4. Heuristic fallback (for direct downloads)

For apps not covered by any of the above (direct downloads without Sparkle,
e.g., some Adobe apps, Notion legacy, niche utilities), we have no
machine-readable "latest version" source. We fall back to a heuristic signal.

### 4.1 Signals

| Signal | What it tells us |
| --- | --- |
| Bundle directory mtime | When the .app was last written to disk. Updated every time the app itself is updated; sometimes updated by app self-modification. |
| `Contents/Info.plist` mtime | When the bundle metadata was last changed. |
| `Contents/MacOS/<binary>` mtime | When the executable was compiled. Most reliable "build time" signal. |
| `codesign -dvv` signing date | When the app was last signed. Updated on every re-sign, including re-signs that don't change behavior. |

### 4.2 Heuristic rule (v1)

```
if mtime > 1 year ago:
    .outdated(latest: "unknown", source: .vendorWebsite(bundleURL))
elif mtime > 6 months ago:
    .unknown(reason: "Last updated >6 months ago — open vendor site to check")
else:
    .unknown(reason: "No automatic update source found")
```

The "outdated" call is intentionally noisy. We mark it
`source: .vendorWebsite(<apple.com/app/...>)` only if we can infer the
vendor site from the bundle ID reverse-DNS. For unknown vendors, we just
say `.unknown` and offer an "Open bundle in Finder" action.

### 4.3 Vendor site inference (optional v2)

The bundle ID's first component is the vendor's reverse-DNS prefix
(`com.apple.Safari`, `com.google.Chrome`). We can map known prefixes to
vendor update pages:

```
com.google.Chrome  → https://www.google.com/chrome/
com.apple.*        → bundled with macOS, ignore
com.adobe.*        → Adobe Creative Cloud
com.jetbrains.*    → Toolbox App
com.microsoft.*    → Microsoft AutoUpdate
...
```

This is a static lookup table in `macappsCore`. In v1 we ship it empty and
let the heuristic fall through to `.unknown`.

### 4.4 Gotchas

- **App writes to its own bundle.** Some apps (e.g., Electron-based) write
  logs or caches inside the `.app`. This resets the mtime without indicating
  an update. Mitigation: prefer the `MacOS/<binary>` mtime.
- **Re-sign without update.** A user with `xattr -cr` habits or
  re-signed-by-OS apps can have a fresh signing date with an old binary.
  Prefer the binary's mtime.
- **Timezone issues.** mtime is in the user's local TZ. Not a correctness
  issue, but tests should be TZ-agnostic.
- **Snapshots / sandbox-temp installs.** Some CI tools install apps to
  `/private/var/...`. We don't scan those paths.

---

## 5. Putting it together

For each `InstalledApp`, the `OutdatednessEngine` asks exactly one checker:

```
if installMethod == .sparkle(feedURL):
    return await SparkleChecker.check(app)
elif installMethod == .macAppStore:
    return await MacAppStoreChecker.check(app)   // uses cached `mas outdated` result
elif installMethod == .homebrew(caskName):
    return await HomebrewChecker.check(app)      // uses cached `brew outdated` result
else:
    return await HeuristicChecker.check(app)
```

MAS and Homebrew checkers internally cache their CLI results for the
duration of one scan, so we invoke `mas` and `brew` **once per scan**, not
once per app.

The final `OutdatedStatus` per app is what the UI binds to.

## 6. (v2) Vendor-specific HTTP APIs

For apps whose vendor publishes version JSON at a known URL (e.g., GitHub
releases for OSS tools), we could add a `GitHubReleaseChecker` that:

1. Reads `SUFeedURL` (or a separate `VendorVersionURL` key we add to our
   config) and detects GitHub-shaped URLs.
2. Calls `https://api.github.com/repos/<owner>/<repo>/releases/latest`.
3. Compares the `tag_name` with installed version.

This is a v2 addition. The architecture supports it without changes.

## 7. (v2) Self-update for macapps itself

macapps can use Sparkle to update itself — its own SUFeedURL points at
GitHub releases. Adding this is a separate doc; not part of v1.
