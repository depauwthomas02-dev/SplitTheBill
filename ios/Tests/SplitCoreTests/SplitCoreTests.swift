import XCTest
@testable import SplitCore

final class TicketParserTests: XCTestCase {
    func testDemoTicket() {
        let r = TicketParser.parse(TicketParser.demo, unitPrices: false)
        XCTAssertEqual(r.items, [
            ParsedItem(name: "Pizza Margherita", quantity: 1, cents: 1250),
            ParsedItem(name: "Spritz", quantity: 2, cents: 1700),
            ParsedItem(name: "Burrata", quantity: 1, cents: 1100),
            ParsedItem(name: "Bière pression", quantity: 3, cents: 1350),
            ParsedItem(name: "Tiramisu", quantity: 1, cents: 750),
            ParsedItem(name: "Café", quantity: 1, cents: 280),
        ])
        XCTAssertEqual(r.totalCents, 6430)
    }

    func testUnitPrices() {
        let r = TicketParser.parse("2 Spritz 8,50\nCafé 2,80", unitPrices: true)
        XCTAssertEqual(r.items.map(\.cents), [1700, 280])
    }

    func testExplicitUnitTimesQuantity() {
        let r = TicketParser.parse("Spritz 2 x 8,50 = 17,00", unitPrices: false)
        XCTAssertEqual(r.items, [ParsedItem(name: "Spritz", quantity: 2, cents: 1700)])
    }

    func testTrailingQuantityAndDiscount() {
        let r = TicketParser.parse("Coca x3 9,00\nRemise -2,00\nVISA 7,00", unitPrices: false)
        XCTAssertEqual(r.items, [
            ParsedItem(name: "Coca", quantity: 3, cents: 900),
            ParsedItem(name: "Remise", quantity: 1, cents: -200),
        ])
    }

    func testCleanOCR() {
        XCTAssertEqual(TicketParser.cleanOCR("Pizza 12 50"), "Pizza 12,50")
        XCTAssertEqual(TicketParser.cleanOCR("Burrata 1O.5O €"), "Burrata 10,50")
        XCTAssertEqual(TicketParser.cleanOCR("Café | 2.80"), "Café 2,80")
    }
}

final class SplitCalculatorTests: XCTestCase {
    private func bill(people: [String]) -> Bill {
        var b = Bill()
        for n in people { b.addPerson(n) }
        return b
    }

    func testSharedEvenlyAddsUpToTheCent() {
        var b = bill(people: ["Anna", "Ben", "Chloé"])
        b.setItems([ParsedItem(name: "Pizza", quantity: 1, cents: 1000)], total: nil, engine: .manual)
        b.toggleEveryone(b.items[0])
        let r = SplitCalculator.compute(b)
        XCTAssertEqual(r.totalCents, 1000)
        XCTAssertEqual(r.owed.values.reduce(0, +), 1000)
        XCTAssertEqual(r.owed.values.sorted(), [333, 333, 334])
    }

    func testUnitsOfMultiItem() {
        var b = bill(people: ["Anna", "Ben"])
        b.setItems([ParsedItem(name: "Bière", quantity: 3, cents: 1350)], total: nil, engine: .manual)
        let it = b.items[0], anna = b.people[0], ben = b.people[1]
        b.tap(it, anna)
        XCTAssertTrue(b.isPartial(it))
        XCTAssertEqual(b.unassignedCount, 1)
        b.tap(it, ben); b.tap(it, ben)
        XCTAssertTrue(b.isComplete(b.items[0]))
        let r = SplitCalculator.compute(b)
        XCTAssertEqual(r.owed[anna.id], 450)
        XCTAssertEqual(r.owed[ben.id], 900)
    }

    func testExtraIsProRata() {
        var b = bill(people: ["Anna", "Ben"])
        b.setItems([ParsedItem(name: "A", quantity: 1, cents: 3000), ParsedItem(name: "B", quantity: 1, cents: 1000)], total: 4400, engine: .manual)
        b.tap(b.items[0], b.people[0])
        b.tap(b.items[1], b.people[1])
        XCTAssertEqual(b.gapCents, 400)
        b.addGapAsExtra()
        XCTAssertEqual(b.gapCents, 0)
        let r = SplitCalculator.compute(b)
        XCTAssertEqual(r.owed[b.people[0].id], 3300)
        XCTAssertEqual(r.owed[b.people[1].id], 1100)
        XCTAssertEqual(SplitCalculator.recap(b, r), "SplitTheBill · l’addition\n\n• Anna : 33,00 €\n• Ben : 11,00 €\n\nTotal : 44,00 €")
    }

    func testMoney() {
        XCTAssertEqual(Money.cents("12,5"), 1250)
        XCTAssertEqual(Money.cents("1 234,56"), 123456)
        XCTAssertEqual(Money.eur(123456), "1 234,56 €")
        XCTAssertEqual(Money.input(705), "7,05")
    }
}
