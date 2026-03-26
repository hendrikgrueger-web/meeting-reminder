import Testing
import Foundation
@testable import NevLate

@Suite("MeetingLinkExtractor Tests")
struct MeetingLinkExtractorTests {

    // MARK: - Hilfsfunktion

    private func extract(location: String? = nil, notes: String? = nil, url: URL? = nil) -> MeetingLink? {
        MeetingLinkExtractor.extractMeetingLink(location: location, notes: notes, url: url)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Microsoft Teams
    // ══════════════════════════════════════════════════════════════════

    @Test("Teams: Klassischer meetup-join Link")
    func teamsMeetupJoin() {
        let result = extract(location: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_ABC123%40thread.v2/0")
        #expect(result?.provider == .teams)
        #expect(result?.url.host == "teams.microsoft.com")
    }

    @Test("Teams: Neues /meet/ Format")
    func teamsMeetFormat() {
        let result = extract(location: "https://teams.microsoft.com/meet/abc123def456")
        #expect(result?.provider == .teams)
        #expect(result?.url.absoluteString.contains("/meet/") == true)
    }

    @Test("Teams: meetup-join mit URL-Kodierung und Query-Parametern")
    func teamsMeetupJoinEncoded() {
        let location = "https://teams.microsoft.com/l/meetup-join/19%3Ameeting_xyz%40thread.v2/0?context=%7b%22Tid%22%3a%22abc%22%7d"
        let result = extract(location: location)
        #expect(result?.provider == .teams)
    }

    @Test("Teams: Government/GCC US Link")
    func teamsGovernmentUS() {
        let result = extract(location: "https://teams.microsoft.us/l/meetup-join/19%3ameeting_gov%40thread.v2/0")
        #expect(result?.provider == .teams)
        #expect(result?.url.host == "teams.microsoft.us")
    }

    @Test("Teams: DoD Government Link")
    func teamsDodGovernment() {
        let result = extract(location: "https://dod.teams.microsoft.us/l/meetup-join/19%3ameeting_dod%40thread.v2/0")
        #expect(result?.provider == .teams)
        #expect(result?.url.host == "dod.teams.microsoft.us")
    }

    @Test("Teams: Consumer/Live Link")
    func teamsConsumerLive() {
        let result = extract(location: "https://teams.live.com/meet/987654321")
        #expect(result?.provider == .teams)
        #expect(result?.url.host == "teams.live.com")
    }

    @Test("Teams: /meet/ mit Query-Parametern")
    func teamsMeetWithQuery() {
        let result = extract(location: "https://teams.microsoft.com/meet/abc123?p=MyPassword&anon=true")
        #expect(result?.provider == .teams)
    }

    @Test("Teams: Großbuchstaben im Schema")
    func teamsUppercase() {
        let result = extract(location: "HTTPS://TEAMS.MICROSOFT.COM/meet/uppercase123")
        #expect(result?.provider == .teams)
    }

    @Test("Teams: Gemischte Schreibweise")
    func teamsMixedCase() {
        let result = extract(location: "Https://Teams.Microsoft.Com/meet/mixedCase456")
        #expect(result?.provider == .teams)
    }

    @Test("Teams: Link in HTML-Anchor-Tag")
    func teamsInHTMLAnchor() {
        let notes = #"<a href="https://teams.microsoft.com/meet/anchorTest">Teams Meeting beitreten</a>"#
        let result = extract(notes: notes)
        #expect(result?.provider == .teams)
    }

    @Test("Teams: Outlook Meeting Body mit HTML")
    func teamsOutlookBody() {
        let notes = """
        <html><body>
        <p>Hallo Team,</p>
        <a href="https://teams.microsoft.com/l/meetup-join/19%3Ameeting_outlook%40thread.v2/0&amp;context=%7B%22Tid%22%3A%22company%22%7D">
        Microsoft Teams Meeting
        </a>
        </body></html>
        """
        let result = extract(notes: notes)
        #expect(result?.provider == .teams)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Zoom
    // ══════════════════════════════════════════════════════════════════

    @Test("Zoom: Einfacher Meeting-Link /j/")
    func zoomBasicJoin() {
        let result = extract(location: "https://zoom.us/j/123456789")
        #expect(result?.provider == .zoom)
        #expect(result?.url.host == "zoom.us")
    }

    @Test("Zoom: Link mit Passwort")
    func zoomWithPassword() {
        let result = extract(location: "https://zoom.us/j/123456789?pwd=abc123def456")
        #expect(result?.provider == .zoom)
        #expect(result?.url.query?.contains("pwd=abc123def456") == true)
    }

    @Test("Zoom: Regional-Subdomain us02web")
    func zoomUS02Web() {
        let result = extract(location: "https://us02web.zoom.us/j/987654321?pwd=xyz")
        #expect(result?.provider == .zoom)
    }

    @Test("Zoom: Regional-Subdomain us04web")
    func zoomUS04Web() {
        let result = extract(location: "https://us04web.zoom.us/j/111222333")
        #expect(result?.provider == .zoom)
    }

    @Test("Zoom: Regional-Subdomain us06web")
    func zoomUS06Web() {
        let result = extract(location: "https://us06web.zoom.us/j/444555666")
        #expect(result?.provider == .zoom)
    }

    @Test("Zoom: Persönlicher Raum /my/")
    func zoomPersonalRoom() {
        let result = extract(location: "https://zoom.us/my/johndoe")
        #expect(result?.provider == .zoom)
        #expect(result?.url.absoluteString.contains("/my/") == true)
    }

    @Test("Zoom: Persönlicher Raum mit Subdomain")
    func zoomPersonalRoomSubdomain() {
        let result = extract(location: "https://us02web.zoom.us/my/johndoe")
        #expect(result?.provider == .zoom)
    }

    @Test("Zoom: Webinar /s/")
    func zoomWebinar() {
        let result = extract(location: "https://zoom.us/s/98765432100")
        #expect(result?.provider == .zoom)
    }

    @Test("Zoom: Link in Notes-Text")
    func zoomInNotes() {
        let notes = "Bitte nutze diesen Link zum Beitreten: https://zoom.us/j/123456789?pwd=secret — Wir sehen uns!"
        let result = extract(notes: notes)
        #expect(result?.provider == .zoom)
    }

    @Test("Zoom: Link mit Großbuchstaben")
    func zoomUppercase() {
        let result = extract(location: "HTTPS://ZOOM.US/J/123456789")
        #expect(result?.provider == .zoom)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Google Meet
    // ══════════════════════════════════════════════════════════════════

    @Test("Google Meet: Standard-Format abc-defg-hij")
    func googleMeetStandard() {
        let result = extract(location: "https://meet.google.com/abc-defg-hij")
        #expect(result?.provider == .googleMeet)
        #expect(result?.url.host == "meet.google.com")
    }

    @Test("Google Meet: Mit Query-Parametern")
    func googleMeetWithQuery() {
        let result = extract(location: "https://meet.google.com/xyz-abcd-efg?authuser=0")
        #expect(result?.provider == .googleMeet)
    }

    @Test("Google Meet: In Notes-Feld")
    func googleMeetInNotes() {
        let notes = "Meeting via Google Meet: https://meet.google.com/abc-defg-hij — bitte pünktlich!"
        let result = extract(notes: notes)
        #expect(result?.provider == .googleMeet)
    }

    @Test("Google Meet: Großbuchstaben")
    func googleMeetUppercase() {
        let result = extract(location: "HTTPS://MEET.GOOGLE.COM/ABC-DEFG-HIJ")
        #expect(result?.provider == .googleMeet)
    }

    @Test("Google Meet: Lookup-Link Format")
    func googleMeetLookup() {
        let result = extract(location: "https://meet.google.com/lookup/abc123xyz")
        #expect(result?.provider == .googleMeet)
    }

    @Test("Google Meet: In HTML-Notes")
    func googleMeetHTMLNotes() {
        let notes = "<p>Link: <a href=\"https://meet.google.com/abc-defg-hij\">Meet beitreten</a></p>"
        let result = extract(notes: notes)
        #expect(result?.provider == .googleMeet)
    }

    @Test("Google Meet: Link mit phs Parameter")
    func googleMeetPhs() {
        let result = extract(location: "https://meet.google.com/abc-defg-hij?phs=1&hs=122")
        #expect(result?.provider == .googleMeet)
    }

    @Test("Google Meet: URL-Feld Fallback")
    func googleMeetURLField() {
        let url = URL(string: "https://meet.google.com/abc-defg-hij")!
        let result = extract(url: url)
        #expect(result?.provider == .googleMeet)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - WebEx / Cisco
    // ══════════════════════════════════════════════════════════════════

    @Test("WebEx: /meet/ Format")
    func webexMeet() {
        let result = extract(location: "https://meetingsemea.webex.com/meet/john.doe")
        #expect(result?.provider == .webex)
    }

    @Test("WebEx: /join/ Format")
    func webexJoin() {
        let result = extract(location: "https://company.webex.com/join/john.doe")
        #expect(result?.provider == .webex)
    }

    @Test("WebEx: j.php Format")
    func webexJPhp() {
        let result = extract(location: "https://company.webex.com/company/j.php?MTID=m123456789")
        #expect(result?.provider == .webex)
    }

    @Test("WebEx: Subdomain EMEA")
    func webexEMEA() {
        let result = extract(location: "https://meetingsemea3.webex.com/meet/johndoe")
        #expect(result?.provider == .webex)
    }

    @Test("WebEx: In Notes")
    func webexInNotes() {
        let notes = "WebEx Meeting: https://company.webex.com/meet/john.doe — Passwort: 1234"
        let result = extract(notes: notes)
        #expect(result?.provider == .webex)
    }

    @Test("WebEx: URL-Feld Fallback")
    func webexURLField() {
        let url = URL(string: "https://company.webex.com/meet/john.doe")!
        let result = extract(url: url)
        #expect(result?.provider == .webex)
    }

    @Test("WebEx: Großbuchstaben")
    func webexUppercase() {
        let result = extract(location: "HTTPS://MEETINGSEMEA.WEBEX.COM/MEET/JOHN.DOE")
        #expect(result?.provider == .webex)
    }

    @Test("WebEx: Doppelpunkt-Subdomain")
    func webexComplexSubdomain() {
        let result = extract(location: "https://my-org.webex.com/meet/presenter")
        #expect(result?.provider == .webex)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - GoTo Meeting
    // ══════════════════════════════════════════════════════════════════

    @Test("GoTo: gotomeet.me Kurzlink")
    func gotoShortLink() {
        let result = extract(location: "https://gotomeet.me/JohnDoe")
        #expect(result?.provider == .gotoMeeting)
    }

    @Test("GoTo: gotomeeting.com/join")
    func gotoJoin() {
        let result = extract(location: "https://global.gotomeeting.com/join/123456789")
        #expect(result?.provider == .gotoMeeting)
    }

    @Test("GoTo: meet.goto.com")
    func gotoMeetGoto() {
        let result = extract(location: "https://meet.goto.com/123456789")
        #expect(result?.provider == .gotoMeeting)
    }

    @Test("GoTo: In Notes")
    func gotoInNotes() {
        let notes = "Bitte hier beitreten: https://gotomeet.me/JohnDoe — GoTo Meeting"
        let result = extract(notes: notes)
        #expect(result?.provider == .gotoMeeting)
    }

    @Test("GoTo: Großbuchstaben")
    func gotoUppercase() {
        let result = extract(location: "HTTPS://GOTOMEET.ME/JOHNDOE")
        #expect(result?.provider == .gotoMeeting)
    }

    @Test("GoTo: URL-Feld Fallback")
    func gotoURLField() {
        let url = URL(string: "https://gotomeet.me/JohnDoe")!
        let result = extract(url: url)
        #expect(result?.provider == .gotoMeeting)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Slack Huddle
    // ══════════════════════════════════════════════════════════════════

    @Test("Slack: Huddle Link")
    func slackHuddle() {
        let result = extract(location: "https://app.slack.com/huddle/T12345/C12345")
        #expect(result?.provider == .slack)
    }

    @Test("Slack: Huddle in Notes")
    func slackHuddleInNotes() {
        let notes = "Slack Huddle: https://app.slack.com/huddle/T12345/C67890 – bitte beitreten"
        let result = extract(notes: notes)
        #expect(result?.provider == .slack)
    }

    @Test("Slack: URL-Feld Fallback")
    func slackURLField() {
        let url = URL(string: "https://app.slack.com/huddle/T12345/C12345")!
        let result = extract(url: url)
        #expect(result?.provider == .slack)
    }

    @Test("Slack: Großbuchstaben")
    func slackUppercase() {
        let result = extract(location: "HTTPS://APP.SLACK.COM/HUDDLE/T12345/C12345")
        #expect(result?.provider == .slack)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Whereby
    // ══════════════════════════════════════════════════════════════════

    @Test("Whereby: Einfacher Raum-Link")
    func wherebyRoom() {
        let result = extract(location: "https://whereby.com/my-meeting-room")
        #expect(result?.provider == .whereby)
    }

    @Test("Whereby: In Notes")
    func wherebyInNotes() {
        let notes = "Video-Call: https://whereby.com/team-standup — einfach im Browser öffnen"
        let result = extract(notes: notes)
        #expect(result?.provider == .whereby)
    }

    @Test("Whereby: URL-Feld Fallback")
    func wherebyURLField() {
        let url = URL(string: "https://whereby.com/my-room")!
        let result = extract(url: url)
        #expect(result?.provider == .whereby)
    }

    @Test("Whereby: Großbuchstaben")
    func wherebyUppercase() {
        let result = extract(location: "HTTPS://WHEREBY.COM/MY-ROOM")
        #expect(result?.provider == .whereby)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Jitsi Meet
    // ══════════════════════════════════════════════════════════════════

    @Test("Jitsi: Einfacher Meeting-Link")
    func jitsiBasic() {
        let result = extract(location: "https://meet.jit.si/MyMeetingRoom")
        #expect(result?.provider == .jitsi)
    }

    @Test("Jitsi: In Notes")
    func jitsiInNotes() {
        let notes = "Jitsi Meeting: https://meet.jit.si/team-standup-2024 — kein Account nötig"
        let result = extract(notes: notes)
        #expect(result?.provider == .jitsi)
    }

    @Test("Jitsi: URL-Feld Fallback")
    func jitsiURLField() {
        let url = URL(string: "https://meet.jit.si/MyRoom")!
        let result = extract(url: url)
        #expect(result?.provider == .jitsi)
    }

    @Test("Jitsi: Großbuchstaben")
    func jitsiUppercase() {
        let result = extract(location: "HTTPS://MEET.JIT.SI/MYROOM")
        #expect(result?.provider == .jitsi)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Feld-Priorität
    // ══════════════════════════════════════════════════════════════════

    @Test("Location hat Priorität vor Notes")
    func locationPriorityOverNotes() {
        let location = "https://teams.microsoft.com/meet/fromLocation"
        let notes = "https://zoom.us/j/123456789"
        let result = extract(location: location, notes: notes)
        #expect(result?.provider == .teams)
        #expect(result?.url.absoluteString.contains("fromLocation") == true)
    }

    @Test("Notes hat Priorität vor URL-Feld")
    func notesPriorityOverURL() {
        let notes = "Meeting: https://zoom.us/j/123456789"
        let url = URL(string: "https://teams.microsoft.com/meet/fromURL")!
        let result = extract(notes: notes, url: url)
        #expect(result?.provider == .zoom)
    }

    @Test("Location hat Priorität vor URL-Feld")
    func locationPriorityOverURL() {
        let location = "https://meet.google.com/abc-defg-hij"
        let url = URL(string: "https://teams.microsoft.com/meet/fromURL")!
        let result = extract(location: location, url: url)
        #expect(result?.provider == .googleMeet)
    }

    @Test("Nur Location gesetzt")
    func onlyLocation() {
        let result = extract(location: "https://zoom.us/j/123456789")
        #expect(result != nil)
        #expect(result?.provider == .zoom)
    }

    @Test("Nur Notes gesetzt")
    func onlyNotes() {
        let result = extract(notes: "Link: https://meet.google.com/abc-defg-hij")
        #expect(result != nil)
        #expect(result?.provider == .googleMeet)
    }

    @Test("Nur URL-Feld gesetzt")
    func onlyURLField() {
        let url = URL(string: "https://teams.microsoft.com/meet/onlyURL")!
        let result = extract(url: url)
        #expect(result != nil)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Provider-Priorität (bei mehreren Links in Notes)
    // ══════════════════════════════════════════════════════════════════

    @Test("Teams hat Priorität vor Zoom in Notes")
    func teamsBeforeZoomInNotes() {
        let notes = """
        Zoom Fallback: https://zoom.us/j/111222333
        Teams: https://teams.microsoft.com/meet/primaryLink
        """
        // Teams wird zuerst geprüft, also Teams gewinnt
        let result = extract(notes: notes)
        #expect(result?.provider == .teams)
    }

    @Test("Erster erkannter Provider gewinnt in Notes")
    func firstProviderWinsInNotes() {
        let notes = """
        Alternative: https://meet.google.com/abc-defg-hij
        Primär: https://teams.microsoft.com/meet/primary
        """
        // Teams-Patterns werden vor Google Meet geprüft
        let result = extract(notes: notes)
        #expect(result?.provider == .teams)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - HTML-Dekodierung
    // ══════════════════════════════════════════════════════════════════

    @Test("&amp; wird dekodiert")
    func ampEntityDecoded() {
        let notes = "https://teams.microsoft.com/l/meetup-join/19%3meeting%40thread.v2/0?context=foo&amp;tenantId=bar"
        let result = extract(notes: notes)
        #expect(result != nil)
        #expect(result?.url.absoluteString.contains("&amp;") == false)
    }

    @Test("&lt; und &gt; werden dekodiert")
    func ltGtEntitiesDecoded() {
        let notes = "&lt;Meeting&gt; https://zoom.us/j/123456789 &lt;/Meeting&gt;"
        let result = extract(notes: notes)
        #expect(result != nil)
    }

    @Test("&quot; wird dekodiert")
    func quotEntityDecoded() {
        let notes = "Link: &quot;https://teams.microsoft.com/meet/quotedEntity&quot;"
        let result = extract(notes: notes)
        #expect(result != nil)
    }

    @Test("&#39; wird dekodiert")
    func apostropheEntityDecoded() {
        let notes = "Team&#39;s Meeting: https://meet.google.com/abc-defg-hij"
        let result = extract(notes: notes)
        #expect(result != nil)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Leerzeichen und Einbettung
    // ══════════════════════════════════════════════════════════════════

    @Test("Link mit umgebenden Leerzeichen")
    func linkWithSpaces() {
        let result = extract(location: "   https://zoom.us/j/123456789   ")
        #expect(result != nil)
        #expect(result?.provider == .zoom)
    }

    @Test("Link in Anführungszeichen")
    func linkInQuotes() {
        let notes = #"Meetinglink: "https://teams.microsoft.com/meet/quotedLink" – bitte beitreten"#
        let result = extract(notes: notes)
        #expect(result != nil)
    }

    @Test("Link in langem Text")
    func linkInLongText() {
        let notes = "Das Meeting findet online statt. Bitte nutze folgenden Link: https://zoom.us/j/123456789?pwd=abc – Wir sehen uns dann."
        let result = extract(notes: notes)
        #expect(result?.provider == .zoom)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Kein Meeting-Link
    // ══════════════════════════════════════════════════════════════════

    @Test("Kein Meeting-Link in allen Feldern")
    func noMeetingLink() {
        let result = extract(
            location: "Raum 3.14, Gebäude Ost",
            notes: "Bitte pünktlich erscheinen",
            url: URL(string: "https://example.com")
        )
        #expect(result == nil)
    }

    @Test("Normaler Ortsname")
    func normalLocationName() {
        let result = extract(location: "Konferenzraum Berlin")
        #expect(result == nil)
    }

    @Test("Alle Felder nil")
    func allFieldsNil() {
        let result = extract()
        #expect(result == nil)
    }

    @Test("Leere Strings")
    func emptyStrings() {
        let result = extract(location: "", notes: "")
        #expect(result == nil)
    }

    @Test("Unbekannter Host im URL-Feld")
    func unknownHostInURLField() {
        let url = URL(string: "https://unknown-meeting.com/join/123")!
        let result = extract(url: url)
        #expect(result == nil)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - URL-Feld Fallback
    // ══════════════════════════════════════════════════════════════════

    @Test("URL-Feld: Teams US Host")
    func urlFieldTeamsUS() {
        let url = URL(string: "https://teams.microsoft.us/l/meetup-join/meeting123")!
        let result = extract(url: url)
        #expect(result?.provider == .teams)
    }

    @Test("URL-Feld: DoD Teams Host")
    func urlFieldTeamsDod() {
        let url = URL(string: "https://dod.teams.microsoft.us/l/meetup-join/meeting456")!
        let result = extract(url: url)
        #expect(result?.provider == .teams)
    }

    @Test("URL-Feld: Teams Live Host")
    func urlFieldTeamsLive() {
        let url = URL(string: "https://teams.live.com/meet/liveConsumer")!
        let result = extract(url: url)
        #expect(result?.provider == .teams)
    }

    @Test("URL-Feld: Zoom mit Subdomain")
    func urlFieldZoomSubdomain() {
        let url = URL(string: "https://us02web.zoom.us/j/123456789")!
        let result = extract(url: url)
        #expect(result?.provider == .zoom)
    }

    @Test("URL-Feld: WebEx mit Subdomain")
    func urlFieldWebexSubdomain() {
        let url = URL(string: "https://meetingsemea.webex.com/meet/john")!
        let result = extract(url: url)
        #expect(result?.provider == .webex)
    }

    @Test("URL-Feld: GoTo Meeting")
    func urlFieldGoto() {
        let url = URL(string: "https://meet.goto.com/123456789")!
        let result = extract(url: url)
        #expect(result?.provider == .gotoMeeting)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Deep Links
    // ══════════════════════════════════════════════════════════════════

    @Test("Deep-Link: Teams meetup-join → msteams://")
    func deepLinkTeams() {
        let link = MeetingLink(
            url: URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting%40thread.v2/0")!,
            provider: .teams
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        #expect(deep.absoluteString.hasPrefix("msteams:"))
    }

    @Test("Deep-Link: Teams /meet/ → kein Deep-Link (Browser-Fallback)")
    func deepLinkTeamsMeetFormat() {
        let link = MeetingLink(
            url: URL(string: "https://teams.microsoft.com/meet/abc123")!,
            provider: .teams
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        // /meet/ Format hat keinen Deep-Link, bleibt HTTPS
        #expect(deep.scheme == "https")
    }

    @Test("Deep-Link: Zoom → zoommtg://")
    func deepLinkZoom() {
        let link = MeetingLink(
            url: URL(string: "https://zoom.us/j/123456789?pwd=abc123")!,
            provider: .zoom
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        #expect(deep.scheme == "zoommtg")
        #expect(deep.absoluteString.contains("confno=123456789"))
        #expect(deep.absoluteString.contains("pwd=abc123"))
    }

    @Test("Deep-Link: Zoom ohne Passwort")
    func deepLinkZoomNoPassword() {
        let link = MeetingLink(
            url: URL(string: "https://zoom.us/j/987654321")!,
            provider: .zoom
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        #expect(deep.scheme == "zoommtg")
        #expect(deep.absoluteString.contains("confno=987654321"))
        #expect(deep.absoluteString.contains("pwd") == false)
    }

    @Test("Deep-Link: Zoom /my/ → kein Deep-Link (Browser-Fallback)")
    func deepLinkZoomPersonalRoom() {
        let link = MeetingLink(
            url: URL(string: "https://zoom.us/my/johndoe")!,
            provider: .zoom
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        // Personal rooms haben keine Meeting-ID → kein Deep-Link
        #expect(deep.scheme == "https")
    }

    @Test("Deep-Link: WebEx → webex://")
    func deepLinkWebex() {
        let link = MeetingLink(
            url: URL(string: "https://company.webex.com/meet/johndoe")!,
            provider: .webex
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        #expect(deep.scheme == "webex")
    }

    @Test("Deep-Link: GoTo → gotomeeting://")
    func deepLinkGoto() {
        let link = MeetingLink(
            url: URL(string: "https://gotomeet.me/JohnDoe")!,
            provider: .gotoMeeting
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        #expect(deep.scheme == "gotomeeting")
    }

    @Test("Deep-Link: Google Meet → Browser-Fallback")
    func deepLinkGoogleMeet() {
        let link = MeetingLink(
            url: URL(string: "https://meet.google.com/abc-defg-hij")!,
            provider: .googleMeet
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        #expect(deep.scheme == "https") // Kein Deep-Link, Browser
    }

    @Test("Deep-Link: Jitsi → Browser-Fallback")
    func deepLinkJitsi() {
        let link = MeetingLink(
            url: URL(string: "https://meet.jit.si/MyRoom")!,
            provider: .jitsi
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        #expect(deep.scheme == "https") // Kein Deep-Link
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - MeetingProvider Properties
    // ══════════════════════════════════════════════════════════════════

    @Test("Alle Provider haben ein Icon")
    func allProvidersHaveIcon() {
        for provider in MeetingProvider.allCases {
            #expect(!provider.iconName.isEmpty)
        }
    }

    @Test("Alle Provider haben ein Join-Label")
    func allProvidersHaveJoinLabel() {
        for provider in MeetingProvider.allCases {
            #expect(!provider.joinLabel.isEmpty)
            #expect(provider.joinLabel.contains("beitreten"))
        }
    }

    @Test("Alle Provider haben ein Accessibility-Label")
    func allProvidersHaveA11yLabel() {
        for provider in MeetingProvider.allCases {
            #expect(!provider.accessibilityJoinLabel.isEmpty)
            #expect(provider.accessibilityJoinLabel.contains("Beitreten via"))
        }
    }

    @Test("MeetingProvider hat 8 Cases")
    func providerCount() {
        #expect(MeetingProvider.allCases.count == 8)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - MeetingLink Equatable
    // ══════════════════════════════════════════════════════════════════

    @Test("MeetingLink Equatable: Gleiche Links sind gleich")
    func meetingLinkEquatable() {
        let link1 = MeetingLink(url: URL(string: "https://zoom.us/j/123")!, provider: .zoom)
        let link2 = MeetingLink(url: URL(string: "https://zoom.us/j/123")!, provider: .zoom)
        #expect(link1 == link2)
    }

    @Test("MeetingLink Equatable: Verschiedene Provider sind ungleich")
    func meetingLinkNotEqualDifferentProvider() {
        let link1 = MeetingLink(url: URL(string: "https://zoom.us/j/123")!, provider: .zoom)
        let link2 = MeetingLink(url: URL(string: "https://zoom.us/j/123")!, provider: .teams)
        #expect(link1 != link2)
    }

    @Test("MeetingLink Equatable: Verschiedene URLs sind ungleich")
    func meetingLinkNotEqualDifferentURL() {
        let link1 = MeetingLink(url: URL(string: "https://zoom.us/j/123")!, provider: .zoom)
        let link2 = MeetingLink(url: URL(string: "https://zoom.us/j/456")!, provider: .zoom)
        #expect(link1 != link2)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: Zoom Varianten
    // ══════════════════════════════════════════════════════════════════

    @Test("Zoom: Webinar mit Registrierung /s/ und Query")
    func zoomWebinarRegistration() {
        let result = extract(location: "https://zoom.us/s/98765432100?tk=abc123registration")
        #expect(result?.provider == .zoom)
        #expect(result?.url.absoluteString.contains("/s/") == true)
    }

    @Test("Zoom: Subdomain eu01web")
    func zoomEU01Web() {
        let result = extract(location: "https://eu01web.zoom.us/j/567890123")
        #expect(result?.provider == .zoom)
        #expect(result?.url.absoluteString.contains("eu01web") == true)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: Google Meet Varianten
    // ══════════════════════════════════════════════════════════════════

    @Test("Google Meet: Meeting mit pli Parameter")
    func googleMeetWithPli() {
        let result = extract(location: "https://meet.google.com/abc-defg-hij?pli=1")
        #expect(result?.provider == .googleMeet)
        #expect(result?.url.absoluteString.contains("pli=1") == true)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: WebEx Personal Room
    // ══════════════════════════════════════════════════════════════════

    @Test("WebEx: Persönlicher Raum mit langem Username")
    func webexPersonalRoomLongUsername() {
        let result = extract(location: "https://meetingsemea.webex.com/meet/firstname.lastname.department")
        #expect(result?.provider == .webex)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: GoTo Meeting-ID
    // ══════════════════════════════════════════════════════════════════

    @Test("GoTo: Meeting mit numerischer ID")
    func gotoWithNumericID() {
        let result = extract(location: "https://global.gotomeeting.com/join/987654321")
        #expect(result?.provider == .gotoMeeting)
        #expect(result?.url.absoluteString.contains("987654321") == true)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: Mehrere Provider in einem Feld
    // ══════════════════════════════════════════════════════════════════

    @Test("Mehrere Provider in Notes: Erster Provider in Pattern-Reihenfolge gewinnt")
    func multipleProvidersInNotesFirstPatternWins() {
        let notes = """
        WebEx Fallback: https://company.webex.com/meet/backup
        Zoom: https://zoom.us/j/111222333
        Teams: https://teams.microsoft.com/meet/primary
        Google Meet: https://meet.google.com/abc-defg-hij
        """
        let result = extract(notes: notes)
        // Teams-Patterns werden zuerst geprüft (Reihenfolge im providerPatterns-Array)
        #expect(result?.provider == .teams)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: URL-Formate
    // ══════════════════════════════════════════════════════════════════

    @Test("URL mit Trailing-Slash")
    func urlWithTrailingSlash() {
        let result = extract(location: "https://meet.google.com/abc-defg-hij/")
        #expect(result?.provider == .googleMeet)
    }

    @Test("URL mit Fragment (#)")
    func urlWithFragment() {
        let result = extract(location: "https://zoom.us/j/123456789#success")
        #expect(result?.provider == .zoom)
    }

    @Test("Sehr langer Notes-Text (1000+ Zeichen) mit Link mittendrin")
    func veryLongNotesWithLinkInMiddle() {
        let prefix = String(repeating: "Lorem ipsum dolor sit amet. ", count: 50)
        let suffix = String(repeating: "Consectetur adipiscing elit. ", count: 50)
        let notes = "\(prefix)Bitte treten Sie hier bei: https://zoom.us/j/999888777?pwd=longPassword123 — Vielen Dank!\(suffix)"
        let result = extract(notes: notes)
        #expect(result?.provider == .zoom)
        #expect(result?.url.absoluteString.contains("999888777") == true)
    }

    @Test("HTML-encoded Zoom-Link in Notes (href mit &amp;)")
    func htmlEncodedZoomLinkInNotes() {
        let notes = #"<a href="https://zoom.us/j/123456789?pwd=secret&amp;uname=test">Zoom beitreten</a>"#
        let result = extract(notes: notes)
        #expect(result?.provider == .zoom)
        // &amp; sollte zu & dekodiert worden sein
        #expect(result?.url.absoluteString.contains("&amp;") == false)
    }

    @Test("Link in Markdown-Format [text](url)")
    func linkInMarkdownFormat() {
        let notes = "Hier der Link: [Meeting beitreten](https://teams.microsoft.com/meet/markdown123) — viel Spaß!"
        let result = extract(notes: notes)
        #expect(result?.provider == .teams)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: Provider-Detection vollständig
    // ══════════════════════════════════════════════════════════════════

    @Test("Provider-Detection: Alle 8 Provider werden korrekt erkannt")
    func allEightProvidersDetected() {
        let testCases: [(String, MeetingProvider)] = [
            ("https://teams.microsoft.com/meet/test", .teams),
            ("https://zoom.us/j/123", .zoom),
            ("https://meet.google.com/abc-defg-hij", .googleMeet),
            ("https://company.webex.com/meet/user", .webex),
            ("https://gotomeet.me/User", .gotoMeeting),
            ("https://app.slack.com/huddle/T1/C1", .slack),
            ("https://whereby.com/my-room", .whereby),
            ("https://meet.jit.si/MyRoom", .jitsi),
        ]
        for (url, expectedProvider) in testCases {
            let result = extract(location: url)
            #expect(result?.provider == expectedProvider, "Fehlgeschlagen für: \(url)")
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: Deep-Link
    // ══════════════════════════════════════════════════════════════════

    @Test("Deep-Link: Zoom Webinar /s/ hat kein zoommtg-Schema (kein /j/ Match)")
    func deepLinkZoomWebinarNoDeepLink() {
        let link = MeetingLink(
            url: URL(string: "https://zoom.us/s/98765432100")!,
            provider: .zoom
        )
        let deep = MeetingLinkExtractor.deepLinkURL(for: link)
        // /s/ wird von extractZoomMeetingID erkannt, also gibt es einen Deep-Link
        #expect(deep.scheme == "zoommtg")
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: Leerer Location + echter Link in Notes
    // ══════════════════════════════════════════════════════════════════

    @Test("Leerer String als Location + echter Link in Notes")
    func emptyLocationWithLinkInNotes() {
        let result = extract(location: "", notes: "Meeting-Link: https://teams.microsoft.com/meet/fromNotes")
        #expect(result?.provider == .teams)
        #expect(result?.url.absoluteString.contains("fromNotes") == true)
    }

    @Test("Location ohne Meeting-Link + Link in Notes → Notes wird verwendet")
    func nonLinkLocationFallsBackToNotes() {
        let result = extract(
            location: "Konferenzraum 42, Gebäude Süd",
            notes: "Online-Fallback: https://meet.google.com/xyz-abcd-efg"
        )
        #expect(result?.provider == .googleMeet)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: Zoom /my/ mit Query-Parametern
    // ══════════════════════════════════════════════════════════════════

    @Test("Zoom: Persönlicher Raum /my/ mit Query-Parametern")
    func zoomPersonalRoomWithQuery() {
        let result = extract(location: "https://zoom.us/my/johndoe?pwd=abc123")
        #expect(result?.provider == .zoom)
        #expect(result?.url.absoluteString.contains("/my/") == true)
    }

    // ══════════════════════════════════════════════════════════════════
    // MARK: - Edge Case Tests: Sonderzeichen und Unicode
    // ══════════════════════════════════════════════════════════════════

    @Test("Notes mit deutschen Umlauten und Meeting-Link")
    func notesWithGermanUmlautsAndLink() {
        let notes = "Besprechung für Änderungsantrag — Büro München — https://teams.microsoft.com/meet/überTest123 — Straße 42"
        let result = extract(notes: notes)
        #expect(result?.provider == .teams)
    }
}
