---
status: resolved
priority: p2
issue_id: "016"
tags: [code-review, simplicity, yagni]
dependencies: []
---

# Provider-Filter Feature entfernen (YAGNI)

## Problem Statement

Die App hat 8 Meeting-Provider-Toggles in den Einstellungen (Teams, Zoom, Meet, WebEx, GoTo, Slack, Whereby, Jitsi). Kein realistisches User-Szenario rechtfertigt das selektive Deaktivieren einzelner Provider. Der "Nur Online-Meetings"-Toggle deckt den echten Use Case bereits ab.

~50 LOC in CalendarService + SettingsView + Filterlogik für ein Feature das niemand nutzt.

## Proposed Solutions

### Option A: Komplett entfernen (empfohlen)
- `enabledProviders` Property + JSON-Persistenz aus CalendarService entfernen
- Provider-Filter in `isRelevant` entfernen
- Provider-Section aus SettingsView entfernen
- ~50 LOC weniger, einfacheres Settings-UI
- **Effort:** Small
- **Risk:** None — Feature hat keinen realen Nutzen

### Option B: Behalten aber zu Set<MeetingProvider> migrieren
- Nur wenn das Feature langfristig Sinn macht
- **Effort:** Medium

## Acceptance Criteria

- [ ] Alle erkannten Provider-Links lösen immer Reminder aus
- [ ] Provider-Toggles aus Settings entfernt
- [ ] enabledProviders aus UserDefaults/CalendarService entfernt

## Work Log

| Datum | Aktion |
|-------|--------|
| 2026-03-26 | Finding erstellt via Code Review |
