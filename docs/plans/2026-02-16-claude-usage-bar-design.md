# ClaudeUsageBar - macOS Menubar App

## Overview

A native macOS menubar app replacing the SwiftBar bash script `claude-usage.5m.sh`. Renders two stacked horizontal usage bars (5h session + 7d weekly) as a high-resolution Core Graphics image in the menubar.

## Architecture

Minimal macOS app with no main window. Runs as menu-bar-only (`LSUIElement = true`).

### Components

- **`AppDelegate`** - Sets up `NSStatusItem`, owns the 5-minute refresh timer, coordinates refresh
- **`UsageAPI`** - Keychain credential retrieval, OAuth token refresh, usage fetching (port of bash logic)
- **`MenuBarRenderer`** - Draws two stacked bars as an `NSImage` using Core Graphics
- **`UsageMenu`** - Builds `NSMenu` dropdown with text-only usage info

### Menubar Icon

~80x18pt image (@2x for Retina):
- Top bar: 5h session usage (~7px tall)
- Bottom bar: 7d weekly usage (~7px tall)
- 1px gap between bars
- Each bar has 3 layers: dim background (remaining), gray (time elapsed), green/yellow (usage consumed)
- Non-template image (needs color)

### Dropdown Menu

```
5h: 42%  (2h13m left)
7d: 18%  (4d 6h left)
---
Refresh
Open Usage Settings...
---
Launch at Login  [checkmark toggle]
```

### Token Management

1. Read from macOS Keychain (`Claude Code-credentials`)
2. Parse JSON, extract `claudeAiOauth.{accessToken, expiresAt, refreshToken}`
3. If expired, POST to `api.anthropic.com/api/oauth/token` with refresh token
4. Update keychain with new credentials
5. Fetch `api.anthropic.com/api/oauth/usage`

### Refresh

- `Timer.scheduledTimer` every 5 minutes
- Also on app launch
- Manual refresh via dropdown

### Login Item

`SMAppService.mainApp` (macOS 13+) for launch-at-login toggle in dropdown.

### Project Structure

```
ClaudeUsageBar/
  ClaudeUsageBar.xcodeproj/
  ClaudeUsageBar/
    AppDelegate.swift
    UsageAPI.swift
    MenuBarRenderer.swift
    Info.plist
```
