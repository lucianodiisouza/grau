# DESIGN — Grau's visual language

This doc defines how Grau *looks and feels*. It is not a pixel-perfect
mockup; it is a set of constraints the AI follows when building any
UI in the app. If a future contributor asks "what color is the
accent?", the answer is here.

The promise is "modern native macOS feel." That means:

- System materials (`.regular`, `.sidebar`, `.popover`)
- SF Pro typography
- SF Symbols over custom icons
- Native window chrome (`.windowStyle(.titleBar)`, traffic lights)
- Native menus (`CommandMenu`, `.commands`)
- Smart dark mode (everything below has a light + dark variant)
- Vibrancy in the right places, never gratuitously
- Subtle, *fast* animations (200–400 ms, easeInOut)
- Keyboard-first: every action has a shortcut, every shortcut is
  discoverable in the menu

The reference points: **Linear**, **Things 3**, **Raycast**, **Arc**,
**Setapp**. Not "default Xcode template", not "designed on iOS".

---

## 1. Brand

### 1.1 Name
**Grau.** Always capitalized. Always one word. Never "Grau App" or
"the Grau app" in UI text — just "Grau".

### 1.2 Color palette

The palette is intentionally restrained. "Grau" is "gray" in
Portuguese, and the visual identity is built around that:

#### Primary (Gray scale)
| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `grau/gray/50`  | `#FAFAF9` | `#1A1A1C` | Background base |
| `grau/gray/100` | `#F2F2F0` | `#232326` | Surface raised |
| `grau/gray/200` | `#E5E5E2` | `#2C2C30` | Border subtle |
| `grau/gray/300` | `#D1D1CD` | `#3A3A40` | Border strong |
| `grau/gray/500` | `#8B8B86` | `#75757A` | Text secondary |
| `grau/gray/700` | `#4A4A48` | `#C8C8CC` | Text primary |
| `grau/gray/900` | `#1A1A1A` | `#F5F5F7` | Text on surface |

#### Accent
| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `grau/accent` | `#5B7A6E` | `#8FB3A3` | Brand color, primary buttons |
| `grau/accentMuted` | `#E0E8E4` | `#2F3D38` | Accent backgrounds |

The accent is a muted **sage green**. Not the bright "I'm a Mac utility
blue" the OS uses. Sage communicates "calm, considered, not alarming"
which matches the trust-first positioning.

#### Semantic
| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `grau/success` | `#3D8B5F` | `#5BAE7B` | Cleanup success, healthy state |
| `grau/warning` | `#C4892B` | `#DBA956` | Outdated, large size, caution |
| `grau/danger`  | `#B85450` | `#D17570` | Destructive action confirmed |

**Critical:** no bright red. `danger` is muted coral. Grau never
alarms the user.

### 1.3 Typography
- **Family:** SF Pro (system default). Never a custom font in v1.
- **Display:** 28pt, semibold (Dashboard greeting, e.g.)
- **Title 1:** 22pt, semibold (Section headers)
- **Title 2:** 17pt, semibold (Card titles)
- **Body:** 13pt, regular (default)
- **Caption:** 11pt, regular (timestamps, metadata)
- **Mono:** SF Mono 12pt (for sizes: "12.4 GB")

Use `.font(.system(...))` with the platform styles where possible
(`.largeTitle`, `.title`, `.headline`, `.body`, `.caption`). Custom
sizes only when the platform default is wrong.

### 1.4 Iconography
- **SF Symbols** everywhere. Never custom PNG icons for actions.
- For brand icon: a **placeholder** generated in Phase 6a as text
  (the letter "G" in `grau/accent` on a `grau/gray/50` background).
  The user provides a real designed icon before 1.0; see
  [REVIEW.md S8](./REVIEW.md#3-structural-simplifications-s1s13).
  We do not pretend the AI can design a good app icon.
- Menu bar: **template image**, no color (OS tints it). See § 3.1.
- Treemap (v1.1, not v1): uses `grau/accent` shades (10 levels) for
  color-coded segments. Hash of node path → shade.

### 1.5 Spacing scale
A 4-pt grid: 4, 8, 12, 16, 20, 24, 32, 48, 64.

| Token | Value | Use |
| --- | --- | --- |
| `space/xs` | 4 | Tight inline |
| `space/sm` | 8 | Within a button |
| `space/md` | 12 | Within a card row |
| `space/lg` | 16 | Card padding |
| `space/xl` | 24 | Section spacing |
| `space/2xl` | 32 | Between cards |
| `space/3xl` | 48 | Top of page |

### 1.6 Corner radius
- 4pt: small chips, inline tags
- 8pt: buttons, inputs
- 12pt: cards
- 16pt: hero cards, modals

---

## 2. Layout primitives

### 2.1 The window

Grau's main window uses a **two-column layout**:
- **Sidebar** (220 pt, fixed): feature navigation
- **Detail** (flex, min 600 pt): the active feature

```swift
NavigationSplitView {
    List(...) { ... }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
} detail: {
    FeatureView(...)
}
```

Sidebar items: Dashboard, Clean, Uninstaller, Disk Lens, Duplicates,
Settings. **Dev Mode is hidden by default** and appears only when
the user enables "Show developer features" in Settings. This is
because the two audiences are different (non-technical users see
"clean junk"; developers see "node_modules + Docker + 16 caches"),
and surfacing Dev Mode to non-devs creates confusion. See
[REVIEW.md S9](./REVIEW.md#3-structural-simplifications-s1s13).

Each item has an SF Symbol.

### 2.2 The dashboard

The dashboard is a vertical stack of **cards** (rounded rectangles
with system material). Each card represents one concern:

- **Storage card** (full width): a horizontal bar showing used / free,
  with a "Clean up to free X" button if applicable.
- **Trash card** (third width): trash size, "Open Trash" button,
  "Empty Trash" button (destructive, requires confirmation).
- **Last scan card** (two-thirds width): summary of last junk scan,
  "Scan now" button.
- **Quick actions card** (full width): a row of large buttons —
  "Scan Junk", "Find Duplicates", "View Disk", "Open Dev Mode".

The dashboard has a greeting at the top: "Good morning, Luci." (uses
`whoami` or the user's first name from `NSFullUserName`).

### 2.3 Feature views

Each feature has a consistent shape:

```
┌────────────────────────────────────────────────┐
│  Feature Title                  [Scan] [⋯]    │ ← toolbar
├────────────────────────────────────────────────┤
│                                                │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│  │ Card A  │  │ Card B  │  │ Card C  │       │ ← summary cards
│  └─────────┘  └─────────┘  └─────────┘       │
│                                                │
│  ─── Detail list ──────────────────────        │
│  ┌──────────────────────────────────┐          │
│  │ Item 1                  [clean]  │          │
│  │ Item 2                  [clean]  │          │
│  │ ...                              │          │
│  └──────────────────────────────────┘          │
│                                                │
│                  [ Clean Selected ]            │ ← bottom action bar
└────────────────────────────────────────────────┘
```

### 2.4 Cards

```swift
struct CardView<Content: View>: View {
    let content: Content
    var body: some View {
        content
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color("grau/gray/200"), lineWidth: 0.5)
            )
    }
}
```

### 2.5 Pills (status badges)

```swift
struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
```

Used for: "12.4 GB" size pills, "Outdated" status, "FDA required"
warning.

### 2.6 Buttons

- **Primary:** filled with `grau/accent`, white text, 8pt radius.
- **Secondary:** transparent background, `grau/accent` text, 1pt
  border in `grau/accent`.
- **Destructive:** filled with `grau/danger`, white text, 1pt border.
  Requires `.confirmationDialog` before action.
- **Tertiary:** plain text in `grau/accent`, no border.

Button height: 32pt default, 28pt for inline, 40pt for hero (dashboard
quick actions).

### 2.7 Progress

- **Linear progress:** a thin (4pt) bar at the top of a card, using
  `grau/accent`. Used for ongoing scans.
- **Ring progress:** an SF Symbol with a fill animation, for the
  scanning state. Used in the menu bar popover.
- **Indeterminate:** macOS's native spinner, never a custom one.

---

## 3. Menu bar (tray)

### 3.1 The icon

A small monogram "G" rendered as a **template image** (no color in
the asset). The OS tints it to match the menu bar (light or dark).
This is the macOS-standard approach and avoids the previous spec's
color debate. See [REVIEW.md S11](./REVIEW.md#3-structural-simplifications-s1s13).

When there are actionable items (junk found, trash full, etc.), show
a small red dot overlay (NOT a number — too noisy). Click the dot to
open the popover.

### 3.2 The popover

Width: 320pt. Height: variable, max 480pt. Material: `.popover`.

Contents (top to bottom):
1. **Header:** "Grau" + free space text ("142.3 GB free of 500 GB")
2. **Storage bar:** 4pt horizontal bar showing used vs. free.
3. **Quick actions:** 3 rows of buttons
   - "Scan Junk" → triggers junk scan, switches to main window
   - "Empty Trash" (only shown if trash > 0)
   - "Find Duplicates" → switches to duplicates
4. **Status section:** list of currently-pending items (max 5)
   - "12.4 GB of junk found"
   - "Trash has 8.2 GB"
5. **Footer:** "Open Grau" button + version number

Popover never scrolls; if the user wants more, they click "Open Grau"
to the main window.

---

## 4. Notifications

### 4.1 Style
- **Banner** (transient, slides in from top-right).
- Title: "Grau" (or "Grau — Junk" for category-specific).
- Body: one sentence, no exclamation marks.
- Action button: "Review" or "Open" depending on context.

### 4.2 Examples
- "Grau found 12.4 GB of cleanable junk. **Review**"
- "Your disk is 92% full. **Open Grau**"
- "Trash has 8.2 GB waiting. **Open Trash**"
- "Grau 0.5.0 is available. **Update**"

### 4.3 Anti-patterns (do not do)
- "URGENT: DISK SPACE LOW" — never.
- Two notifications in a row within 5 min.
- Notifications while the user is in the Grau app.

---

## 5. Motion

### 5.1 Durations
- **Micro** (button hover, toggle): 100 ms
- **Standard** (card appearance, sidebar selection): 200 ms
- **Macro** (scan start, navigation push): 300 ms
- **Hero** (success animation, big state change): 400 ms

### 5.2 Easing
- Default: `.easeInOut`
- In: `.easeOut`
- Out: `.easeIn`
- Never: `.linear` (feels robotic)

### 5.3 Specifics
- Scan progress: linear bar updates 30 fps. No animation per byte.
- Treemap drill-down: layout animates from parent to children over
  300 ms. Children fade in 50 ms after layout starts.
- Card appearance: 200 ms fade + 4pt slide up.
- Empty state → filled state: 400 ms cross-fade.

### 5.4 Reduced motion
Respect `accessibilityReduceMotion`. Replace all animations with
cross-fades when true.

---

## 6. Iconography for the treemap

The disk lens treemap uses a color gradient based on the node's
**depth + hash**:

```swift
func treemapColor(for node: DiskTreeNode) -> Color {
    let hue = ... // derived from hash of node.path
    let saturation = 0.15 + (0.35 * (1.0 - depth/10.0))
    let brightness = 0.85 - (0.10 * (1.0 - depth/10.0))
    return Color(hue: hue, saturation: saturation, brightness: brightness)
}
```

Top-level dirs (small depth) are more saturated. Deep files are
almost gray. This creates a natural visual hierarchy.

The same color is used in the sidebar's directory tree, so a folder
highlighted in the treemap is also highlighted in the sidebar.

---

## 7. Empty states

Every feature has a meaningful empty state.

### 7.1 Junk cleaner — clean
"🎉 All clear. No cleanable junk found."
[Run scan again]

### 7.2 Junk cleaner — first run
"Run a scan to see what's eating your space."
[Scan now]

### 7.3 Duplicates — no duplicates
"No duplicates found in ~/Documents."
[Pick a different folder]

### 7.4 Uninstaller — no apps
"No installed apps found."

### 7.5 Permission required
"To clean system caches, grant Full Disk Access."
[Open System Settings]

---

## 8. Error states

Always:
1. Icon: an SF Symbol warning (`exclamationmark.triangle`) in
   `grau/warning`.
2. Title: a short, plain-language description.
3. Body: one sentence on what to do.
4. Action button: the next step (Retry, Open Settings, etc.).

Never:
- Red exclamation marks
- Error codes (EACCES) in user-facing text
- Stack traces
- "Something went wrong" with no next step

---

## 9. Accessibility

Grau targets **WCAG 2.1 AA** for color contrast.

Specifics:
- All text on `grau/gray/50` background uses `grau/gray/700` or
  darker (contrast 7.1:1).
- All interactive elements have a focus ring (system default).
- The treemap is keyboard-navigable (arrow keys, enter to drill in).
- The sidebar is keyboard-navigable (arrow keys, enter to activate).
- All custom controls have accessibility labels and hints.
- `accessibilityReduceMotion` honored (see § 5.4).
- `accessibilityDifferentiateWithoutColor` honored (use icons +
  text, not color alone for status).

The treemap is the trickiest case — color is the primary signal.
We add **patterns** (diagonal stripes for "system file", solid for
"user file") as a secondary signal so colorblind users can
distinguish.

---

## 10. Localization-ready strings

All user-facing strings are wrapped in `LocalizedStringKey`:

```swift
Text("dashboard.greeting.morning", defaultValue: "Good morning")
```

Strings live in `grau/Resources/Localizable.strings` (or `.xcstrings`
in Xcode 15) with the EN baseline. PT-BR is the second locale,
added in v2.

**No** string concatenation in views. Use interpolation:
```swift
Text("junk.found \(size)")
```
not
```swift
Text("Found " + size + " of junk")
```

---

## 11. Implementation: DesignSystem module

All design tokens and reusable views live in `grau/DesignSystem/`:

```
grau/DesignSystem/
├── Colors/
│   ├── GrauColors.swift           // Color("grau/...") extensions
│   └── GrauColors.xcassets/       // light + dark variants
├── Typography/
│   └── GrauTypography.swift       // font helpers
├── Components/
│   ├── CardView.swift
│   ├── Pill.swift
│   ├── PrimaryButton.swift
│   ├── SecondaryButton.swift
│   ├── DestructiveButton.swift
│   ├── StorageBar.swift
│   ├── ProgressRing.swift
│   ├── EmptyStateView.swift
│   ├── ErrorStateView.swift
│   └── PermissionPrimerView.swift
└── Spacing/
    └── Spacing.swift              // space/xs, space/sm, etc.
```

**Rule:** feature views import `DesignSystem` and use only these
components. They never define their own button or card. If a
component is needed twice, it goes in `DesignSystem` first.

---

## 12. What we don't do

Grau's UI does not:

- Use bright blue (it looks like Apple's UI; we differentiate).
- Use red as a status color (it alarms; we want calm).
- Use gradients on UI chrome (dated).
- Use 3D / skeuomorphic effects (dated).
- Use emoji as UI affordances (only in the success-empty-state of
  the junk cleaner, as a celebration).
- Use custom cursors.
- Make its own scrollbar (always system).
- Replace the window's traffic-light buttons.
