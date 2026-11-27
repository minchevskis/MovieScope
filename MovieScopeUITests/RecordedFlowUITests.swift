import XCTest

/// A user flow captured with Xcode 26's UI test recorder.
@MainActor
final class RecordedFlowUITests: XCTestCase {
    func test_recorded_browseTrendingToDetailsThenSearch() {
        // Raw output of Xcode's UI test recorder. Only change: launch through
        // AppLauncher (fixture data) instead of the recorder's XCUIApplication().activate().
        let app = AppLauncher.launch()
        let element = app/*@START_MENU_TOKEN@*/.cells["trending.item.0"].images.firstMatch/*[[".images.element(boundBy: 4)",".cells[\"trending.item.0\"].images.firstMatch"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        element.swipeLeft()
        element.tap()
        app/*@START_MENU_TOKEN@*/.staticTexts["2026 · 2h 45m · Science Fiction, Action, Adventure"]/*[[".otherElements.staticTexts[\"2026 · 2h 45m · Science Fiction, Action, Adventure\"]",".staticTexts[\"2026 · 2h 45m · Science Fiction, Action, Adventure\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.firstMatch.swipeUp()
        
        let element2 = app/*@START_MENU_TOKEN@*/.scrollViews["details.screen"]/*[[".scrollViews",".containing(.staticText, identifier: \"2026 · 2h 45m · Science Fiction, Action, Adventure\")",".containing(.staticText, identifier: \"Meet your doom.\")",".containing(.staticText, identifier: \"Avengers: Doomsday\")",".otherElements.scrollViews[\"details.screen\"]",".scrollViews[\"details.screen\"]"],[[[-1,5],[-1,4],[-1,0,1]],[[-1,3],[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.firstMatch
        element2.tap()
        element2.swipeDown()
        element2.swipeUp()
        
        let windowsQuery = app.windows
        windowsQuery/*@START_MENU_TOKEN@*/.firstMatch/*[[".containing(.other, identifier: nil).firstMatch",".firstMatch"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app/*@START_MENU_TOKEN@*/.buttons["BackButton"]/*[[".navigationBars",".buttons[\"Trending\"]",".buttons[\"BackButton\"]"],[[[-1,2],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()
        app/*@START_MENU_TOKEN@*/.images["magnifyingglass"]/*[[".buttons[\"Search\"].images",".buttons",".images[\"Search\"]",".images[\"magnifyingglass\"]"],[[[-1,3],[-1,2],[-1,1,1],[-1,0]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()
        app/*@START_MENU_TOKEN@*/.searchFields["Movies or TV shows"].firstMatch/*[[".otherElements.searchFields[\"Movies or TV shows\"].firstMatch",".searchFields",".containing(.image, identifier: \"magnifyingglass\").firstMatch",".firstMatch",".searchFields[\"Movies or TV shows\"].firstMatch"],[[[-1,4],[-1,1,1],[-1,0]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        app/*@START_MENU_TOKEN@*/.searchFields["Movies or TV shows"].firstMatch/*[[".otherElements.searchFields[\"Movies or TV shows\"].firstMatch",".searchFields",".containing(.button, identifier: \"Clear text\").firstMatch",".containing(.image, identifier: \"magnifyingglass\").firstMatch",".firstMatch",".searchFields[\"Movies or TV shows\"].firstMatch"],[[[-1,5],[-1,1,1],[-1,0]],[[-1,4],[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.typeText("batman")
        app/*@START_MENU_TOKEN@*/.buttons["search.row.0"]/*[[".buttons",".containing(.staticText, identifier: \"In his second year of fighting crime, Batman uncovers corruption in Gotham City that connects to his own family while facing a serial killer known as the Riddler.\")",".containing(.staticText, identifier: \"2022 · Movie\")",".containing(.staticText, identifier: \"The Batman\")",".otherElements",".buttons[\"The Batman, 2022 · Movie, In his second year of fighting crime, Batman uncovers corruption in Gotham City that connects to his own family while facing a serial killer known as the Riddler.\"]",".buttons[\"search.row.0\"]"],[[[-1,6],[-1,5],[-1,4,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1]],[[-1,6],[-1,5]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()
        windowsQuery.element(boundBy: 1)/*@START_MENU_TOKEN@*/.press(forDuration: 0.5)/*[[".tap()",".press(forDuration: 0.5)"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    
    }
}
