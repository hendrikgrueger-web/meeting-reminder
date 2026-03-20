import XCTest
import Foundation
@testable import Meeting_Reminder

final class TeamsLinkExtractorTests: XCTestCase {

    // MARK: - Klassisches meetup-join Format

    func testEinfacherMeetupJoinLinkInLocation() {
        let location = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_ABC123%40thread.v2/0"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, "teams.microsoft.com")
    }

    func testMeetupJoinLinkMitURLKodierung() {
        let location = "https://teams.microsoft.com/l/meetup-join/19%3Ameeting_xyz%40thread.v2/0?context=%7b%22Tid%22%3a%22abc%22%7d"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.absoluteString.contains("meetup-join") == true)
    }

    func testMeetupJoinLinkMitQueryParametern() {
        let location = "https://teams.microsoft.com/l/meetup-join/19%3meeting@thread.v2/0?context=someContext&tenantId=xyz"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.query?.contains("context") == true)
    }

    // MARK: - Neues /meet/ Format

    func testMeetFormatInLocation() {
        let location = "https://teams.microsoft.com/meet/abc123def456"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.absoluteString.contains("/meet/") == true)
    }

    func testMeetFormatMitQueryParametern() {
        let location = "https://teams.microsoft.com/meet/abc123?p=MyPassword&anon=true"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.query?.contains("p=MyPassword") == true)
    }

    // MARK: - Government-Varianten

    func testGovernmentUsLink() {
        let location = "https://teams.microsoft.us/l/meetup-join/19%3ameeting_gov%40thread.v2/0"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, "teams.microsoft.us")
    }

    func testDodGovernmentLink() {
        let location = "https://dod.teams.microsoft.us/l/meetup-join/19%3ameeting_dod%40thread.v2/0"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, "dod.teams.microsoft.us")
    }

    // MARK: - Consumer-Variante

    func testConsumerLiveLink() {
        let location = "https://teams.live.com/meet/987654321"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, "teams.live.com")
    }

    // MARK: - Prioritaet der Felder

    func testLocationHatPrioritaetVorNotes() {
        let location = "https://teams.microsoft.com/meet/fromLocation"
        let notes = "https://teams.microsoft.com/meet/fromNotes"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: notes, url: nil)
        XCTAssertTrue(result?.absoluteString.contains("fromLocation") == true)
    }

    func testNotesHatPrioritaetVorURL() {
        let notes = "Bitte tritt hier bei: https://teams.microsoft.com/meet/fromNotes"
        let url = URL(string: "https://teams.microsoft.com/meet/fromURL")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: url)
        XCTAssertTrue(result?.absoluteString.contains("fromNotes") == true)
    }

    func testLocationHatPrioritaetVorURL() {
        let location = "https://teams.microsoft.com/meet/fromLocation"
        let url = URL(string: "https://teams.microsoft.com/meet/fromURL")!
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: url)
        XCTAssertTrue(result?.absoluteString.contains("fromLocation") == true)
    }

    func testNurLocationGesetzt() {
        let result = TeamsLinkExtractor.extractURL(
            location: "https://teams.microsoft.com/meet/onlyLocation",
            notes: nil,
            url: nil
        )
        XCTAssertNotNil(result)
    }

    func testNurNotesGesetzt() {
        let result = TeamsLinkExtractor.extractURL(
            location: nil,
            notes: "Meeting-Link: https://teams.microsoft.com/meet/onlyNotes",
            url: nil
        )
        XCTAssertNotNil(result)
    }

    func testNurURLFeldGesetzt() {
        let url = URL(string: "https://teams.microsoft.com/meet/onlyURL")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, url)
    }

    // MARK: - HTML-Dekodierung

    func testAmpEntitaetWirdDekodiert() {
        let notes = "https://teams.microsoft.com/l/meetup-join/19%3meeting%40thread.v2/0?context=foo&amp;tenantId=bar"
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.absoluteString.contains("&amp;") ?? false)
    }

    func testLtGtEntitaetenWerdenDekodiert() {
        let notes = "&lt;Meeting&gt; https://teams.microsoft.com/meet/decoded123 &lt;/Meeting&gt;"
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        XCTAssertNotNil(result)
    }

    func testLinkInHTMLAnchorTag() {
        let notes = #"<a href="https://teams.microsoft.com/meet/anchorTest">Teams Meeting beitreten</a>"#
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        XCTAssertNotNil(result)
    }

    func testOutlookMeetingBodyMitHTMLBlock() {
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
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, "teams.microsoft.com")
    }

    // MARK: - Kein Teams-Link

    func testKeinTeamsLinkInAllenFeldern() {
        let result = TeamsLinkExtractor.extractURL(
            location: "Raum 3.14, Gebaeude Ost",
            notes: "Bitte puenktlich erscheinen",
            url: URL(string: "https://example.com")
        )
        XCTAssertNil(result)
    }

    func testNormalerOrtsname() {
        let result = TeamsLinkExtractor.extractURL(
            location: "Konferenzraum Berlin",
            notes: nil,
            url: nil
        )
        XCTAssertNil(result)
    }

    func testZoomLinkWirdNichtErkannt() {
        let result = TeamsLinkExtractor.extractURL(
            location: "https://zoom.us/j/123456789?pwd=abc",
            notes: nil,
            url: URL(string: "https://zoom.us/j/123456789")
        )
        XCTAssertNil(result)
    }

    func testGoogleMeetLinkWirdNichtErkannt() {
        let result = TeamsLinkExtractor.extractURL(
            location: "https://meet.google.com/abc-defg-hij",
            notes: nil,
            url: URL(string: "https://meet.google.com/abc-defg-hij")
        )
        XCTAssertNil(result)
    }

    func testAlleFelderNil() {
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: nil)
        XCTAssertNil(result)
    }

    // MARK: - Gross-/Kleinschreibung

    func testGrossbuchstabenImSchema() {
        let location = "HTTPS://TEAMS.MICROSOFT.COM/meet/uppercase123"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
    }

    func testGemischteSchreibweise() {
        let location = "Https://Teams.Microsoft.Com/meet/mixedCase456"
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
    }

    // MARK: - Leerzeichen und Einbettung

    func testLinkMitUmgebendenLeerzeichen() {
        let location = "   https://teams.microsoft.com/meet/spacedLink   "
        let result = TeamsLinkExtractor.extractURL(location: location, notes: nil, url: nil)
        XCTAssertNotNil(result)
    }

    func testLinkInAnfuehrungszeichen() {
        let notes = #"Meetinglink: "https://teams.microsoft.com/meet/quotedLink" – bitte beitreten"#
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.absoluteString.contains("quotedLink") == true)
    }

    func testLinkInLangemText() {
        let notes = "Das Meeting findet online statt. Bitte nutze folgenden Link: https://teams.microsoft.com/meet/embeddedInText?p=pass123 – Wir sehen uns dann."
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.absoluteString.contains("embeddedInText") == true)
    }

    // MARK: - URL-Feld Fallback

    func testUrlFeldMitFremdemHost() {
        let url = URL(string: "https://webex.com/meet/xyz")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        XCTAssertNil(result)
    }

    func testUrlFeldTeamsUSAlsFallback() {
        let url = URL(string: "https://teams.microsoft.us/l/meetup-join/meeting123")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, url)
    }

    func testUrlFeldDodTeamsAlsFallback() {
        let url = URL(string: "https://dod.teams.microsoft.us/l/meetup-join/meeting456")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, url)
    }

    func testUrlFeldTeamsLiveAlsFallback() {
        let url = URL(string: "https://teams.live.com/meet/liveConsumer")!
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: nil, url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, url)
    }

    // MARK: - Grenzfaelle

    func testLeereStrings() {
        let result = TeamsLinkExtractor.extractURL(location: "", notes: "", url: nil)
        XCTAssertNil(result)
    }

    func testMehrereLinksInNotes() {
        let notes = """
        Alternative: https://zoom.us/j/111
        Teams: https://teams.microsoft.com/meet/firstTeamsLink
        Weiterer: https://teams.microsoft.com/meet/secondTeamsLink
        """
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.absoluteString.contains("firstTeamsLink") == true)
    }

    func testQuotEntitaetWirdDekodiert() {
        let notes = "Link: &quot;https://teams.microsoft.com/meet/quotedEntity&quot;"
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        XCTAssertNotNil(result)
    }

    func testApostrophEntitaetWirdDekodiert() {
        let notes = "Team&#39;s Meeting: https://teams.microsoft.com/meet/apostrophe123"
        let result = TeamsLinkExtractor.extractURL(location: nil, notes: notes, url: nil)
        XCTAssertNotNil(result)
    }
}
