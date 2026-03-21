# Meeting Reminder — Next Level Upgrade Prompt

> Kopiere diesen Prompt in eine neue Claude Code Session.
> Hendrik schläft — arbeite autonom durch, keine Rückfragen.

---

## Prompt

```
Ich gehe schlafen. Du arbeitest autonom durch — keine Rückfragen, keine Bestätigungen, maximale Autonomie.

Projektverzeichnis: /Users/hendrik.grueger/Coding/1_privat/Apple Apps/Meeting Reminder
Lies zuerst CLAUDE.md, die Design-Spec und den Implementierungsplan. Dann lies alle Swift-Dateien.

## Deine Mission

Bringe die Meeting Reminder macOS-App auf das nächste Level. Nutze massiv parallele Agenten (subagent-driven-development). Jeder Agent hat einen klaren Namen, ein klares Modell, eine klare Aufgabe. Dispatche so viele wie sinnvoll parallel. Committe nach jedem fertigen Feature. Pushe regelmäßig.

## Phase 1: Multi-Provider Meeting-Links (3 parallele Agenten)

Aktuell erkennt die App nur MS Teams Links. Erweitere auf ALLE gängigen Meeting-Tools:

**Agent "Zoom-Architect" (sonnet):**
- Zoom-URL-Patterns in TeamsLinkExtractor einbauen (umbenennen zu `MeetingLinkExtractor`)
- Patterns: `https://zoom.us/j/...`, `https://us02web.zoom.us/j/...`, `https://zoom.us/my/...`
- Deep-Link: `zoommtg://zoom.us/join?confno=...`
- Tests: mindestens 10 Zoom-spezifische Tests

**Agent "Google-Meet-Architect" (sonnet):**
- Google Meet URL-Patterns
- Patterns: `https://meet.google.com/...`
- Deep-Link: `googlemeet://meet.google.com/...` (oder Fallback auf Browser)
- Tests: mindestens 8 Google-Meet-spezifische Tests

**Agent "WebEx-Cisco-Architect" (sonnet):**
- WebEx/Cisco-Patterns
- Patterns: `https://meetingsemea.webex.com/...`, `https://*.webex.com/meet/...`, `https://*.webex.com/join/...`
- Deep-Link: `webex://` URL-Scheme
- Tests: mindestens 8 WebEx-spezifische Tests

Nach allen drei: Einen **"Link-Integrator" Agent (opus)** dispatchen der:
- `TeamsLinkExtractor` zu `MeetingLinkExtractor` umbenennt (alle Referenzen updaten)
- Alle drei Provider-Patterns zusammenführt
- Den "Beitreten"-Button dynamisch beschriftet ("Teams beitreten", "Zoom beitreten", "Google Meet beitreten")
- Das passende Provider-Icon zeigt (video.fill für Teams, phone.fill für Zoom, etc.)
- Den `openTeamsDirectly()` zu `openMeetingDirectly()` verallgemeinert mit Provider-spezifischen Deep-Links
- Build + Tests grün
- Commit + Push

## Phase 2: UI/UX Polish (3 parallele Agenten)

**Agent "Overlay-Designer" (opus):**
- AlertOverlayView komplett überarbeiten:
  - Provider-Icon + Provider-Name neben dem Beitreten-Button
  - Sanfter Blur-Hintergrund der den Desktop durchscheinen lässt
  - Kalender-Account-Name unter dem Kalender-Titel
  - Teilnehmer-Anzahl wenn verfügbar (aus Event-Attendees)
  - Animate: Card fliegt sanft von oben rein (nicht nur fade)
  - Wenn Meeting läuft: pulsierender roter Dot + "LIVE" Badge
  - Countdown wird bei < 10 Sekunden größer und rot

**Agent "Settings-Designer" (sonnet):**
- SettingsView überarbeiten:
  - Sektions-Header mit Icons (Kalender-Icon, Glocke-Icon, Zahnrad-Icon)
  - "Über" Sektion mit App-Version + GitHub-Link
  - Kalender nach Account gruppieren (nicht flache Liste)
  - Vorlaufzeit als Stepper mit + / - Buttons statt Picker
  - Animierte Toggles
  - Provider-Filter: welche Meeting-Provider sollen erkannt werden (Teams/Zoom/Meet/WebEx)

**Agent "Menu-Bar-Designer" (sonnet):**
- Dynamisches Menüleisten-Icon verbessern:
  - Badge mit Anzahl der Meetings in den nächsten 30 Min
  - Tooltip beim Hover: "Nächstes Meeting: [Name] in [X] Min"
  - Icon-Animation wenn Alert aktiv ist
  - Rechtsklick-Menü: "Nächstes Meeting anzeigen", "Alle heute", "Beenden"

## Phase 3: Robustheit (2 parallele Agenten)

**Agent "Edge-Case-Hunter" (opus):**
- Alle Edge Cases aus der Spec implementieren und testen:
  - Event wird gelöscht während Overlay angezeigt → Overlay schließen
  - Kalender-Berechtigung wird nachträglich entzogen → graceful degradation
  - App startet und Meeting läuft bereits → sofort Overlay
  - Recurring Events: jede Occurrence unabhängig behandeln
  - Events < 5 Minuten: Vorlaufzeit automatisch anpassen
  - Gleichzeitige Events: Queue mit Navigation ("1/3", "2/3", "3/3")
  - Tests für JEDEN Edge Case

**Agent "Performance-Guardian" (sonnet):**
- Performance-Optimierungen:
  - EventKit-Abfrage auf exakt nötige Properties beschränken
  - Regex-Patterns lazy kompilieren
  - Timer-Genauigkeit: DispatchSourceTimer statt Foundation Timer für präzisere Wakeups
  - Memory-Profiling: sicherstellen dass dismissed-Set nicht wächst
  - Instruments-taugliche Signposts für Debugging
  - Tests für Timer-Genauigkeit

## Phase 4: Neue Features (3 parallele Agenten)

**Agent "Notification-Center-Builder" (sonnet):**
- macOS Notification Center Integration:
  - Notification Actions: "Beitreten" + "Snooze" als Notification-Buttons
  - Notification Categories mit UNNotificationCategory
  - Notifications als Alternative wenn Overlay deaktiviert
  - Einstellung: "Overlay" vs "Notification" vs "Beides"

**Agent "Today-Widget-Builder" (sonnet):**
- "Heute"-Übersicht im Popover:
  - Alle heutigen Meetings chronologisch
  - Vergangene ausgegraut, aktuelle hervorgehoben, zukünftige normal
  - Klick auf Meeting → Details (Teilnehmer, Ort, Link)
  - Kompakte vs. detaillierte Ansicht toggle

**Agent "Quick-Join-Builder" (sonnet):**
- Globaler Keyboard Shortcut (Cmd+Shift+J):
  - Zeigt sofort das nächste Meeting als kleines Popup
  - Ein weiterer Enter-Druck → beitreten
  - Registriert via NSEvent.addGlobalMonitorForEvents
  - Einstellbar in Settings

## Phase 5: Quality & Polish (2 Agenten sequentiell)

**Agent "Test-Maximizer" (opus):**
- Testabdeckung auf Maximum bringen:
  - MeetingLinkExtractor: Tests für JEDEN Provider, JEDES Format, JEDE Edge Case (50+ Tests)
  - CalendarService: Mock-basierte Tests für Timer-Logik, Snooze, Sleep/Wake (30+ Tests)
  - UI-Tests: AlertOverlayView mit verschiedenen Event-Typen als Snapshots
  - Gesamtziel: 100+ Tests

**Agent "Final-Reviewer" (opus):**
- Gesamtes Projekt reviewen:
  - Code-Qualität, Naming, Konsistenz
  - Accessibility vollständig (VoiceOver auf jedem Screen)
  - Memory Leaks, Retain Cycles
  - Alle Compiler-Warnings beheben
  - CLAUDE.md aktualisieren
  - Landing Page aktualisieren (neue Features, neue Provider-Logos)
  - Finaler Commit + Push

## Regeln

1. **Keine Rückfragen.** Triff Entscheidungen selbst. Im Zweifel: einfacher ist besser.
2. **Committe nach JEDEM fertigen Feature.** Kleine Commits, klare Messages auf Deutsch.
3. **Pushe nach jeder Phase.** `git push origin HEAD` nach Phase 1, 2, 3, 4, 5.
4. **Build muss IMMER grün sein.** Nie committen wenn der Build bricht.
5. **Tests zuerst schreiben** wo möglich (TDD).
6. **xcodegen generate** vor jedem Build (neue Dateien!).
7. **Deployment Target: macOS 26.0** (Tahoe, für Liquid Glass).
8. **Signing:** CODE_SIGN_IDENTITY="Apple Development: Hendrik Grueger (HY44A7L7D7)" DEVELOPMENT_TEAM=CU87QNNB3N
9. **Build-Verzeichnis:** `-derivedDataPath ./build` (lokales Build-Dir)
10. **Sprache:** Deutsch für Commits, Kommentare, UI-Texte. Englisch für Code-Identifier.
11. **Am Ende:** App in ~/Applications installieren: `cp -R "./build/Build/Products/Release/Meeting Reminder.app" ~/Applications/`

## Erwartetes Ergebnis am Morgen

- 8+ Meeting-Provider (Teams, Zoom, Google Meet, WebEx, GoTo, Slack Huddle, etc.)
- Wunderschönes Overlay mit Provider-Icons und Animationen
- Gruppierte Kalender-Einstellungen mit Provider-Filtern
- Heute-Übersicht aller Meetings im Popover
- Globaler Keyboard Shortcut (Cmd+Shift+J)
- Notification-Center-Integration
- 100+ Tests
- Sauberer Code, reviewed, documented
- Alles gepusht auf GitHub
- Landing Page aktualisiert
- App in ~/Applications installiert und lauffähig
```
