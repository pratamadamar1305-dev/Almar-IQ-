# JedaSholat — Ruang Jeda

Design direction for the native Android refresh (0.2.0).

## Intent
A calm, distinctly Indonesian prayer-pause companion. The next prayer is the visual anchor; everything else is quiet, legible and actionable. This is a native wellbeing tool, not a dashboard copied from the web and not a whole-device lock.

## Tokens
- Evergreen `#124D40`: primary actions and the single hero surface.
- Ink `#172F29`: primary text in light mode.
- Porcelain `#F5F7F4`: light background (cool, not beige).
- Mint `#DCEDE4`: selected/ready states.
- Brass `#C7A568`: small brand accent, never body text on light surfaces.
- Night `#101C19` / raised night `#192A24`: dark surfaces.
- Plus Jakarta Sans, bundled offline under SIL OFL 1.1. System sans remains the accessibility fallback.
- 4 dp micro spacing; 8 dp baseline; 20 dp screen gutters; 48 dp minimum touch targets.
- Shape hierarchy: 12 dp controls, 20 dp cards, 28 dp hero. No blanket glass/shadow treatment.

## Layout
Home: brand + location → greeting → one next/active prayer hero → readiness → today's five prayers → privacy note.
Schedule: day selector → expandable per-prayer rules → transparent calculation note.
Apps: search → restricted/always-allowed tabs → large tappable rows with real package icons.
Settings: protection → permissions → location → simulation → appearance → history → destructive data actions.
Onboarding: four honest steps, persistent bottom actions, no silently granted permissions.
Overlay: same brand and countdown, scrollable at large font sizes, Home/dialer always available; strict mode has no continue-playing action.

## Icon
Original crescent + pause-bars mark. The crescent means returning to prayer; the bars mean a temporary pause, not a permanent lock. Adaptive layers are separate; Android 13+ receives a monochrome layer. The notification icon is a separate single-color silhouette.

## Skill references consulted
- aitmpl.com → `creative-design/frontend-design`: subject-specific identity, restrained hierarchy, deliberate type, critique with screenshots.
- aitmpl.com → `creative-design/mobile-design` + `platform-android`: touch-first Material 3, 48 dp targets, sp typography, offline/battery awareness, Android back behavior.
- aitmpl.com → `development/code-reviewer`: review checklist and regression tests; third-party scripts were not installed or executed.

## Verification boundary
Compose/Android resources are compiled and linted in CI. Native UI smoke tests capture screenshots on an emulator. Accessibility enforcement still requires the physical-device checklist; a green UI test is not proof of OEM enforcement reliability. Dojo Tarung is not modified.
