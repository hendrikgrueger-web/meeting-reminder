# Datenschutzerklärung — QuickJoin

**Zuletzt aktualisiert:** 21. März 2026

## Überblick

QuickJoin ist eine macOS-Menüleisten-App, die an bevorstehende Kalender-Events erinnert und das Beitreten zu Online-Meetings per Klick ermöglicht. Der Schutz Ihrer Daten ist uns wichtig. Diese Datenschutzerklärung erläutert, welche Daten die App nutzt, wie diese verwendet werden und welche Rechte Sie haben.

**Grundprinzip: Alle Ihre Daten verbleiben auf Ihrem Gerät. Wir erheben, übermitteln oder speichern keine personenbezogenen Daten.**

---

## 1. Verantwortlicher

Hendrik Grüger
Deutschland
E-Mail: hendrik@grueger.dev

---

## 2. Von der App verwendete Daten

### 2.1 Kalender-Events (EventKit)

QuickJoin liest Ihre lokalen Kalender-Events über Apples EventKit-Framework, um anstehende Meetings anzuzeigen und Meeting-Links zu erkennen. Folgende Event-Daten werden ausgelesen:

- Event-Titel
- Start- und Endzeit
- Ort
- Notizen/Beschreibung
- Kalendername und -farbe
- Event-URL
- Ganztägig-Status

**Diese Daten werden ausschließlich lokal auf Ihrem Gerät verarbeitet und niemals an einen Server oder Dritte übermittelt.** Die App ändert, erstellt oder löscht keine Kalender-Events.

### 2.2 Meeting-Link-Erkennung

Die App durchsucht Ort-, Notizen- und URL-Felder von Events, um Meeting-Links folgender Anbieter zu erkennen:

- Microsoft Teams
- Zoom
- Google Meet
- Cisco WebEx
- GoTo Meeting
- Slack Huddles
- Whereby
- Jitsi Meet

Erkannte Links dienen ausschließlich dazu, den „Beitreten"-Button im Erinnerungs-Overlay zu aktivieren. **Meeting-Links werden lokal verarbeitet und weder übermittelt noch über die aktuelle App-Sitzung hinaus gespeichert.**

### 2.3 Lokale Einstellungen (UserDefaults)

Die App speichert Ihre Einstellungen lokal in macOS UserDefaults:

- Ausgewählte Kalender
- Vorlaufzeit für Erinnerungen
- Sound-Einstellungen
- Einstellung für Bildschirmfreigabe-Benachrichtigung
- Filter „Nur Online-Meetings"
- Einstellung „Bei Anmeldung starten"

**UserDefaults-Daten werden ausschließlich auf Ihrem Gerät gespeichert und niemals übermittelt.**

---

## 3. Daten, die wir NICHT erheben

QuickJoin erhebt **keine**:

- Personenbezogenen Daten
- Daten, die über das Internet übertragen werden
- Analyse- oder Tracking-Daten
- Drittanbieter-SDKs oder Werbe-Frameworks
- Benutzerkonten oder -profile
- Cookies oder ähnliche Tracking-Technologien

QuickJoin greift **nicht** zu auf:

- Kontakte, Fotos, Standort, Mikrofon oder Kamera
- Cloud-Dienste zur Datensynchronisation

---

## 4. Netzwerkkommunikation

QuickJoin führt **keine** eigene Netzwerkkommunikation durch. Die einzige Netzwerkaktivität entsteht, wenn Sie den „Beitreten"-Button klicken. Dadurch wird der Meeting-Link in Ihrem Standardbrowser oder der nativen Meeting-App (z. B. Microsoft Teams) geöffnet. Diese Aktion wird von macOS (`NSWorkspace.open`) ausgeführt und nicht von QuickJoin kontrolliert.

---

## 5. In-App-Abonnements

QuickJoin bietet optionale Premium-Funktionen über In-App-Abonnements an, die vollständig von Apple über StoreKit verwaltet werden.

- **Abonnementverwaltung und Zahlungsabwicklung erfolgen ausschließlich durch Apple.**
- Der Entwickler hat keinen Zugriff auf Ihre Zahlungsinformationen, Apple-ID oder Abrechnungsdaten.
- Informationen zum Umgang von Apple mit Abonnementdaten finden Sie in [Apples Datenschutzrichtlinie](https://www.apple.com/de/legal/privacy/).

---

## 6. Datenschutz für Kinder

QuickJoin erhebt keine personenbezogenen Daten von Nutzern jeglichen Alters, einschließlich Kindern unter 16 Jahren (gemäß DSGVO). Die App kann von allen Altersgruppen sicher verwendet werden.

---

## 7. Datensicherheit

Da QuickJoin keine Daten erhebt oder überträgt, besteht kein Risiko von Datenschutzverletzungen durch die App. Alle von der App verwendeten Daten verbleiben auf Ihrem Gerät und werden durch macOS-Sicherheitsmechanismen einschließlich der App Sandbox geschützt.

---

## 8. Ihre Rechte (DSGVO)

Gemäß der Datenschutz-Grundverordnung (DSGVO) haben Sie folgende Rechte:

- **Auskunftsrecht (Art. 15 DSGVO)** — Da keine personenbezogenen Daten erhoben werden, liegen keine Daten zur Auskunft vor.
- **Recht auf Löschung (Art. 17 DSGVO)** — Alle lokal gespeicherten Einstellungen können durch Deinstallation der App entfernt werden.
- **Recht auf Datenübertragbarkeit (Art. 20 DSGVO)** — Es werden keine personenbezogenen Daten von der App erhoben oder gespeichert.
- **Widerspruchsrecht (Art. 21 DSGVO)** — Über den lokalen Gerätebetrieb hinaus findet keine Datenverarbeitung statt.
- **Recht auf Einschränkung der Verarbeitung (Art. 18 DSGVO)** — Der Kalenderzugriff kann jederzeit über die macOS-Systemeinstellungen widerrufen werden.

Kalenderzugriff widerrufen: **Systemeinstellungen > Datenschutz & Sicherheit > Kalender > QuickJoin**

---

## 9. Rechtsgrundlage der Verarbeitung

Die Verarbeitung der Kalenderdaten erfolgt auf Grundlage von **Art. 6 Abs. 1 lit. a DSGVO (Einwilligung)**. Sie erteilen diese Einwilligung durch die Gewährung des Kalenderzugriffs in den macOS-Systemeinstellungen. Die Einwilligung kann jederzeit durch Entzug des Kalenderzugriffs widerrufen werden.

---

## 10. Änderungen dieser Datenschutzerklärung

Wir können diese Datenschutzerklärung von Zeit zu Zeit aktualisieren. Änderungen werden durch das Datum „Zuletzt aktualisiert" am Anfang dieses Dokuments kenntlich gemacht. Die weitere Nutzung der App nach Änderungen gilt als Zustimmung zur aktualisierten Datenschutzerklärung.

---

## 11. Kontakt

Bei Fragen zu dieser Datenschutzerklärung wenden Sie sich bitte an:

Hendrik Grüger
E-Mail: hendrik@grueger.dev

---

*Diese Datenschutzerklärung gilt für QuickJoin für macOS, erhältlich im Mac App Store.*
