# Design Tokens

Droplit uses native macOS visual language: system materials, semantic colors,
compact controls, and rounded utility surfaces.

## Main Settings Window

The dedicated configuration surface follows the macOS System Settings pattern:

- default launch content size: 860 x 760
- window resizing: standard user-resizable behavior; content must not force window height
- root layout: `NavigationSplitView` with `.balanced` style on macOS 13+, manual sidebar/detail fallback on macOS 11-12
- sidebar width: 220 minimum, 250 ideal, 280 maximum
- search field: AppKit-backed `NSSearchField` in the sidebar header for cross-version consistency
- selected sidebar row: native source-list highlight and vibrancy
- detail content width: 760 maximum, 32 horizontal inset, top-safe-area underlap, 22 bottom inset
- detail typography: title heading, compact callout subtitle, semantic secondary text
- settings groups: `GroupBox` sections with standard material fill, 16-point horizontal inset, and balanced vertical spacing
- settings rows: fixed leading label column plus trailing value/action or menu picker column, plain button rows for navigation
- deployment target: macOS 11.0; newer SwiftUI APIs are wrapped with availability guards and AppKit/SwiftUI fallbacks

## Main Settings Window

The post-onboarding `ContentView` uses a System Settings-style sidebar/detail
surface:

- minimum content size: 860 x 560
- visual style: native sidebar/detail layout, hidden titlebar/header on supported macOS versions
- layout: sidebar search and navigation on the leading edge, detail page content on the trailing edge
- actions: Queue page imports files directly; Quick Access continues running from app launch and `ContentView.onAppear`

## Onboarding Window

The first-run onboarding surface uses the same main window with a native macOS
material treatment:

- root launch gate: `DroplitLaunchView` switches between onboarding and `ContentView`
- persistence: `@AppStorage("onboarding.isComplete")`
- visual style: `.ultraThinMaterial` content and window container background, hidden toolbar/header
- layout: finite resizable window, centered scrollable content column, native footer buttons, bottom-center dot indicator
- footer actions: 34 horizontal inset, asymmetric 14 top / 24 bottom inset for bottom visual balance
- steps: Welcome, Install dependencies, optional Permissions, Ready
- permission step: hidden while `OnboardingPermissions.requirements` is empty
- dependency step: large thin-stroke circular progress control under the title/subtitle, blocks Continue until all optimizer tools are ready, installs missing Homebrew packages on click, and resolves to Done at 100%
- dependency footer CTA: while required dependencies are missing, the footer primary button becomes Install, then returns to Continue after setup finishes successfully
- Homebrew unavailable state: show Homebrew install link, Refresh action, and manual install fallback copy
- dependency list: paragraph text listing each optimizer name
- ready step: centered Quick Access preview shows media chips and a pointer moving into a raised monochrome material drop card, then becoming a non-overlapping clipped vertical processing stack
- restoration: hidden-titlebar shell keeps the onboarding/settings window in a predictable app-managed layout
- completion: swaps into the main settings window; `AppDelegate` owns launch-time Quick Access bootstrap, while `ContentView.onAppear` starts it after first-run completion

## Color

| Token | Value | Usage |
| --- | --- | --- |
| `color.accent` | `NSColor.controlAccentColor` | Active controls, selected conversion format |
| `color.accentFallback` | `NSColor.systemBlue` | Fallback when dynamic accent unavailable |
| `color.text.primary` | SwiftUI `.primary` | Main labels |
| `color.text.secondary` | SwiftUI `.secondary` | Metadata, inactive icons |
| `color.text.activeOnAccent` | White | Text on accent-filled active controls |
| `color.surface.material` | `.regularMaterial` | Floating chip/button surface |
| `color.surface.materialSubtle` | `.thinMaterial` | Disabled/processing chip surface |
| `color.stroke.card` | White at 16% opacity | Quick Access card border |
| `color.stroke.control` | White at 20% opacity | Inactive small control border |
| `color.overlay.thumbnailTop` | Accent at 18% opacity fading to transparent | Quick Access thumbnail top readability layer |
| `color.overlay.thumbnailBottom` | Black at 66% opacity fading upward | Quick Access card content readability |
| `color.shadow.card` | Black at 4-11% opacity | Soft Quick Access card separation shadow |

## Typography

| Token | Value | Usage |
| --- | --- | --- |
| `type.cardTitle` | system 13 semibold | Card status titles |
| `type.cardMeta` | system 11 semibold rounded | Size, timing, compact metrics |
| `type.cardCaption` | system 10 medium | File titles and failure text |
| `type.conversionButton` | system 6.5 bold rounded | XS conversion actions |

## Size

| Token | Value | Usage |
| --- | --- | --- |
| `size.quickAccessCard.width` | 184 | Floating card width |
| `size.quickAccessCard.height` | 118 | Floating card height |
| `size.conversionRow.height` | 16 | XS conversion action hit row |
| `size.conversionButton.visualHeight` | 13 | XS conversion action visual pill |
| `size.iconButton.visual` | 18 | Card remove/stop visible control |
| `size.iconButton.hit` | 30 | Card remove/stop invisible hit area |
| `size.kindBadge.width` | 24 | File kind badge |
| `size.kindBadge.height` | 16 | File kind badge |

## Spacing

| Token | Value | Usage |
| --- | --- | --- |
| `space.cardStackGap` | 10 | Vertical card stack spacing |
| `space.conversionRowGap` | 3 | Gap between card and conversion row |
| `space.conversionButtonGap` | 3 | Horizontal gap between conversion buttons |
| `space.panelPadding` | 58 | Floating panel shadow/padding allowance |
| `space.cardContentX` | 12 | Card lower content horizontal padding |

## Radius

| Token | Value | Usage |
| --- | --- | --- |
| `radius.card` | 14 continuous | Quick Access cards |
| `radius.badge` | 6 continuous | File kind badge |
| `radius.buttonPill` | capsule | Conversion format buttons |

## State

| State | Treatment |
| --- | --- |
| `default` | Primary text, regular material, 20% white stroke |
| `processing` | Secondary text, thin material, reduced opacity |
| `activeConversion` | Accent fill, subtle black overlay, white text, accent stroke |
| `disabledProcessingInactive` | 42% opacity, no click action |
| `defaultSourceConversion` | Active state inferred from source extension when target exists |

## Shadow

| Token | Value | Usage |
| --- | --- | --- |
| `shadow.quickAccessCard.ambient` | 29-34 radius, 12-15 y, black 8-11% | Main floating card lift |
| `shadow.quickAccessCard.contact` | 8-11 radius, 3-4 y, black 4-5.5% | Close contact shadow under the card |

## Implementation Map

- app launch shell lives in `DroplitLaunchView`; post-onboarding settings shell lives in `ContentView`
- settings shell lives in `ContentView`; `DroplitModernSettingsRoot` uses `NavigationSplitView` on macOS 13+ and `DroplitLegacySettingsRoot` provides the macOS 11-12 fallback
- first-run onboarding lives in `Features/Onboarding` and uses only native transparent materials, SF Symbols, GroupBox, dot step indicators, and standard buttons
- sidebar only lists top-level destinations; storage, conversion, and concurrency are surfaced from detail pages instead of duplicate source-list entries
- sidebar search uses `DroplitSidebarSearchField`, an AppKit-backed search field that works across the deployment range
- sidebar rows stay flat and Mail-like: one SF Symbol, one title line, one optional secondary line
- detail pages use `DroplitSettingsPage` for heading plus scroll layout
- grouped settings content uses `DroplitSettingsGroup`, `DroplitSettingsControlRow`, `DroplitSettingsValueRow`, `DroplitSettingsMenuPicker`, and a shared aligned-row layout
- Quick Access dimensions live in `QuickAccessLayout`.
- Quick Access shadow allowance lives in `QuickAccessLayout.shadowMargin`.
- Quick Access card shadows use `quickAccessCardShadow(isRaised:)`.
- Quick Access placement uses `QuickAccessPanelEdge` plus `QuickAccessPanelAlignment`; top placement enters from the upper edge and mirrors bottom stack anchoring.
- Top placement compensates for menu/notch safe area so the visual card-boundary inset matches bottom placement; `shadowMargin` only extends the transparent panel canvas.
- Conversion active state lives on `QuickAccessItem.activeConversionTarget`.
- Active color resolves through `NSColor.controlAccentColor`; fallback is system blue.
- Active quick action text is always white; active fill keeps the macOS accent color with a subtle dark overlay for readability.
- Quick action hit area is the full button cell, not only the text label or visual pill.
- Close control separates a compact visible circle from a larger invisible hit area.
- Source extension defaults are `png`, `jpg/jpeg`, `webp`, `heic/heif`, `gif`, `mov`, and `mp4`.

## Unresolved Questions

- None.
