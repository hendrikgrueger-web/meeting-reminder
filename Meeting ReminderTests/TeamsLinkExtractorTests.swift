import Testing
import Foundation
@testable import Meeting_Reminder

@Suite("TeamsLinkExtractor Tests")
struct TeamsLinkExtractorTests {

    // MARK: - Klassisches meetup-join Format

    @Test("Einfacher meetup-join Link in Location wird erkannt")
    func einfacherMeetupJoinLinkInLocation() {
        let location = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_ABC123%40thread.v2/0"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
        #expect(result?.host == "teams.microsoft.com")
    }

    @Test("meetup-join Link mit URL-kodierten Zeichen wird erkannt")
    func meetupJoinLinkMitURLKodierung() {
        let location = "https://teams.microsoft.com/l/meetup-join/19%3Ameeting_xyz%40thread.v2/0?context=%7b%22Tid%22%3a%22abc%22%7d"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
        #expect(result?.absoluteString.contains("meetup-join") == true)
    }

    @Test("meetup-join Link mit Query-Parametern bleibt vollstaendig erhalten")
    func meetupJoinLinkMitQueryParametern() {
        let location = "https://teams.microsoft.com/l/meetup-join/19%3meeting@thread.v2/0?context=someContext&tenantId=xyz"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
        #expect(result?.query?.contains("context") == true)
    }

    // MARK: - Neues /meet/ Format

    @Test("meet-Format in Location wird erkannt")
    func meetFormatInLocation() {
        let location = "https://teams.microsoft.com/meet/abc123def456"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
        #expect(result?.absoluteString.contains("/meet/") == true)
    }

    @Test("meet-Format mit Query-Parametern wird erkannt")
    func meetFormatMitQueryParametern() {
        let location = "https://teams.microsoft.com/meet/abc123?p=MyPassword&anon=true"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
        #expect(result?.query?.contains("p=MyPassword") == true)
    }

    // MARK: - Government-Varianten

    @Test("teams.microsoft.us Government-Link wird erkannt")
    func governmentUsLink() {
        let location = "https://teams.microsoft.us/l/meetup-join/19%3ameeting_gov%40thread.v2/0"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
        #expect(result?.host == "teams.microsoft.us")
    }

    @Test("dod.teams.microsoft.us DoD-Government-Link wird erkannt")
    func dodGovernmentLink() {
        let location = "https://dod.teams.microsoft.us/l/meetup-join/19%3ameeting_dod%40thread.v2/0"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
        #expect(result?.host == "dod.teams.microsoft.us")
    }

    // MARK: - Consumer-Variante

    @Test("teams.live.com Consumer-Link wird erkannt")
    func consumerLiveLink() {
        let location = "https://teams.live.com/meet/987654321"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
        #expect(result?.host == "teams.live.com")
    }

    // MARK: - Prioritaet der Felder

    @Test("Location hat Prioritaet vor Notes")
    func locationHatPrioritaetVorNotes() {
        let location = "https://teams.microsoft.com/meet/fromLocation"
        let notes = "https://teams.microsoft.com/meet/fromNotes"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: notes, url: nil)
        #expect(result?.absoluteString.contains("fromLocation") == true)
    }

    @Test("Notes hat Prioritaet vor URL-Feld")
    func notesHatPrioritaetVorURL() {
        let notes = "Bitte tritt hier bei: https://teams.microsoft.com/meet/fromNotes"
        let url = URL(string: "https://teams.microsoft.com/meet/fromURL")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: url)
        #expect(result?.absoluteString.contains("fromNotes") == true)
    }

    @Test("Location hat Prioritaet vor URL-Feld")
    func locationHatPrioritaetVorURL() {
        let location = "https://teams.microsoft.com/meet/fromLocation"
        let url = URL(string: "https://teams.microsoft.com/meet/fromURL")!
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: url)
        #expect(result?.absoluteString.contains("fromLocation") == true)
    }

    @Test("Nur Location gesetzt – Link wird gefunden")
    func nurLocationGesetzt() {
        let result = TeamsLinkExtractor.extractURL(
            location: "https://teams.microsoft.com/meet/onlyLocation",
            notes: nil,
            url: nil
        )
        #expect(result != nil)
    }

    @Test("Nur Notes gesetzt – Link wird gefunden")
    func nurNotesGesetzt() {
        let result = TeamsLinkExtractor.extractURL(
            location: nil,
            notes: "Meeting-Link: https://teams.microsoft.com/meet/onlyNotes",
            url: nil
        )
        #expect(result != nil)
    }

    @Test("Nur URL-Feld gesetzt – Link wird gefunden")
    func nurURLFeldGesetzt() {
        let url = URL(string: "https://teams.microsoft.com/meet/onlyURL")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        #expect(result != nil)
        #expect(result == url)
    }

    // MARK: - HTML-Dekodierung

    @Test("amp-Entitaet in Notes wird korrekt dekodiert")
    func ampEntitaetWirdDekodiert() {
        let notes = "https://teams.microsoft.com/l/meetup-join/19%3meeting%40thread.v2/0?context=foo&amp;tenantId=bar"
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        #expect(result != nil)
        // Nach Dekodierung soll & statt &amp; stehen, URL muss gueltig sein
        #expect(result?.absoluteString.contains("&amp;") == false)
    }

    @Test("lt-gt-Entitaeten in Notes werden dekodiert")
    func ltGtEntitaetenWerdenDekodiert() {
        let notes = "&lt;Meeting&gt; https://teams.microsoft.com/meet/decoded123 &lt;/Meeting&gt;"
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        #expect(result != nil)
    }

    @Test("Teams-Link in HTML-Anchor-Tag wird extrahiert")
    func linkInHTMLAnchorTag() {
        let notes = #"<a href="https://teams.microsoft.com/meet/anchorTest">Teams Meeting beitreten</a>"#
        // Nach HTML-Decode wird " zu " – Regex stoppt davor
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        // Der Link endet vor dem abschliessenden " – URL sollte trotzdem erkannt werden
        #expect(result != nil)
    }

    @Test("Komplexer Outlook-Meeting-Body mit HTML-Teams-Block wird verarbeitet")
    func outlookMeetingBodyMitHTMLBlock() {
        let notes = """
        <html><body>
        <p>Hallo Team,</p>
        <p>Bitte tritt dem Meeting bei:</p>
        <a href="https://teams.microsoft.com/l/meetup-join/19%3Ameeting_outlook%40thread.v2/0&amp;context=%7B%22Tid%22%3A%22company%22%7D">
        Microsoft Teams Meeting
        </a>
        <p>Meeting-ID: 123 456 789</p>
        </body></html>
        """
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        #expect(result != nil)
        #expect(result?.host == "teams.microsoft.com")
    }

    // MARK: - Kein Teams-Link

    @Test("Kein Teams-Link in keinem Feld ergibt nil")
    func keinTeamsLinkInAllenFeldern() {
        let result = TeamsLinkExtractor.extractURL(
            location: "Raum 3.14, Gebaeude Ost",
            notes: "Bitte puenktlich erscheinen",
            url: URL(string: "https://example.com")
        )
        #expect(result == nil)
    }

    @Test("Normaler Ortsname ohne URL ergibt nil")
    func normalerOrtsname() {
        let result = TeamsLinkExtractor.extractURL(
            location: "Konferenzraum Berlin",
            notes: nil,
            url: nil
        )
        #expect(result == nil)
    }

    @Test("Zoom-Link wird nicht als Teams-Link erkannt")
    func zoomLinkWirdNichtErkannt() {
        let result = TeamsLinkExtractor.extractURL(
            location: "https://zoom.us/j/123456789?pwd=abc",
            notes: nil,
            url: URL(string: "https://zoom.us/j/123456789")
        )
        #expect(result == nil)
    }

    @Test("Google-Meet-Link wird nicht als Teams-Link erkannt")
    func googleMeetLinkWirdNichtErkannt() {
        let result = TeamsLinkExtractor.extractURL(
            location: "https://meet.google.com/abc-defg-hij",
            notes: nil,
            url: URL(string: "https://meet.google.com/abc-defg-hij")
        )
        #expect(result == nil)
    }

    @Test("Alle Felder nil ergibt nil")
    func alleFelderNil() {
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: nil)
        #expect(result == nil)
    }

    // MARK: - Gross-/Kleinschreibung

    @Test("Teams-URL mit Grossbuchstaben im Schema wird erkannt")
    func grossbuchstabenImSchema() {
        let location = "HTTPS://TEAMS.MICROSOFT.COM/meet/uppercase123"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
    }

    @Test("Teams-URL mit gemischter Schreibweise wird erkannt")
    func gemischteSchreibweise() {
        let location = "Https://Teams.Microsoft.Com/meet/mixedCase456"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
    }

    // MARK: - Leerzeichen und Einbettung

    @Test("Teams-Link mit umgebenden Leerzeichen wird erkannt")
    func linkMitUmgebendenLeerzeichen() {
        let location = "   https://teams.microsoft.com/meet/spacedLink   "
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        #expect(result != nil)
    }

    @Test("Teams-Link in Anfuehrungszeichen eingebettet wird extrahiert")
    func linkInAnfuehrungszeichen() {
        let notes = #"Meetinglink: "https://teams.microsoft.com/meet/quotedLink" – bitte beitreten"#
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        #expect(result != nil)
        #expect(result?.absoluteString.contains("quotedLink") == true)
    }

    @Test("Teams-Link mitten in laengeren Text eingebettet wird erkannt")
    func linkInLangemText() {
        let notes = "Das Meeting findet online statt. Bitte nutze folgenden Link: https://teams.microsoft.com/meet/embeddedInText?p=pass123 – Wir sehen uns dann."
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        #expect(result != nil)
        #expect(result?.absoluteString.contains("embeddedInText") == true)
    }

    // MARK: - URL-Feld Fallback

    @Test("URL-Feld mit nicht-Teams-Host ergibt nil wenn keine anderen Felder gesetzt")
    func urlFeldMitFremdemHost() {
        let url = URL(string: "https://webex.com/meet/xyz")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        #expect(result == nil)
    }

    @Test("URL-Feld mit teams.microsoft.us Host wird als Fallback erkannt")
    func urlFeldTeamsUSAlsFallback() {
        let url = URL(string: "https://teams.microsoft.us/l/meetup-join/meeting123")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        #expect(result != nil)
        #expect(result == url)
    }

    @Test("URL-Feld mit dod.teams.microsoft.us Host wird als Fallback erkannt")
    func urlFeldDodTeamsAlsFallback() {
        let url = URL(string: "https://dod.teams.microsoft.us/l/meetup-join/meeting456")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        #expect(result != nil)
        #expect(result == url)
    }

    @Test("URL-Feld mit teams.live.com Host wird als Fallback erkannt")
    func urlFeldTeamsLiveAlsFallback() {
        let url = URL(string: "https://teams.live.com/meet/liveConsumer")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        #expect(result != nil)
        #expect(result == url)
    }

    // MARK: - Grenzfaelle

    @Test("Leere Strings in Location und Notes ergeben nil")
    func leereStrings() {
        let result = TeamsLinkExtractor.extractURL(location: "", notes: "", url: nil)
        #expect(result == nil)
    }

    @Test("Mehrere Links in Notes – erster Teams-Link wird zurueckgegeben")
    func mehrereLinksInNotes() {
        let notes = """
        Alternative: https://zoom.us/j/111
        Teams: https://teams.microsoft.com/meet/firstTeamsLink
        Weiterer: https://teams.microsoft.com/meet/secondTeamsLink
        """
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        #expect(result != nil)
        #expect(result?.absoluteString.contains("firstTeamsLink") == true)
    }

    @Test("quot-Entitaet in Notes wird korrekt dekodiert")
    func quotEntitaetWirdDekodiert() {
        let notes = "Link: &quot;https://teams.microsoft.com/meet/quotedEntity&quot;"
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        #expect(result != nil)
    }

    @Test("39-Entitaet (Apostroph) in Notes wird korrekt dekodiert")
    func apostrophEntitaetWirdDekodiert() {
        let notes = "Team&#39;s Meeting: https://teams.microsoft.com/meet/apostrophe123"
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        #expect(result != nil)
    }
}
