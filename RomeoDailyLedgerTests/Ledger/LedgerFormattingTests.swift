import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("Ledger formatting")
struct LedgerFormattingTests {
    @Test func amountUsesApprovedDefaultUSDCurrency() {
        #expect(LedgerFormatting.amount(Decimal(string: "12.50")!) == "$12.50")
    }
}
