import XCTest
@testable import FreeSongCore

final class FlowLayoutSolverTests: XCTestCase {
    typealias Size = FlowLayoutSolver.Size

    func testSingleRowWhenItemsFit() {
        let r = FlowLayoutSolver.layout(
            itemSizes: [Size(width: 20, height: 10), Size(width: 30, height: 12)],
            spacing: 5, lineSpacing: 4, maxWidth: 100)
        XCTAssertEqual(r.rows, [[0, 1]])
        XCTAssertEqual(r.total, Size(width: 55, height: 12))   // 20+5+30 ; tallest 12
    }

    func testWrapsToSecondRow() {
        let r = FlowLayoutSolver.layout(
            itemSizes: [Size(width: 60, height: 10), Size(width: 60, height: 10)],
            spacing: 5, lineSpacing: 4, maxWidth: 100)
        XCTAssertEqual(r.rows, [[0], [1]])
        XCTAssertEqual(r.total, Size(width: 60, height: 24)) // 10+4+10
    }

    func testOversizeItemGetsItsOwnRow() {
        let r = FlowLayoutSolver.layout(
            itemSizes: [Size(width: 150, height: 10), Size(width: 20, height: 10)],
            spacing: 5, lineSpacing: 4, maxWidth: 100)
        XCTAssertEqual(r.rows, [[0], [1]])
    }

    func testEmptyInput() {
        let r = FlowLayoutSolver.layout(
            itemSizes: [], spacing: 5, lineSpacing: 4, maxWidth: 100)
        XCTAssertEqual(r.rows, [])
        XCTAssertEqual(r.total, Size(width: 0, height: 0))
    }
}