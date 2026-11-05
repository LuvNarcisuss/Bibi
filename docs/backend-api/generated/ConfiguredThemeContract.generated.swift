// Generated concrete theme protocol; no action descriptions or fixture payloads.
import Foundation

enum ConfiguredThemeContract {
    enum Signal: String, CaseIterable {
        case `circleContentChanged` = "CircleContentChanged"
        case `conversationMessagesChanged` = "ConversationMessagesChanged"
        case `businessApplied` = "OrbitBusinessApplied"
        case `receiptAcknowledged` = "OrbitReceiptAcknowledged"
        case `replayRequested` = "OrbitReplayRequested"
    }
    enum Direction { case inbound, outbound }
    enum ValueType { case string, integer, number, boolean, object, array }
    struct Field { let path: [String]; let type: ValueType; let required: Bool }
    struct Rule { let discriminator: [String]; let direction: Direction; let fields: [String: Field] }
    static func rule(for signal: Signal) -> Rule {
        switch signal {
        case .`circleContentChanged`: return Rule(discriminator: ["signal"], direction: .inbound, fields: ["contentReference": Field(path: ["work", "reference"], type: .string, required: true)])
        case .`conversationMessagesChanged`: return Rule(discriminator: ["signal"], direction: .inbound, fields: ["conversationReference": Field(path: ["conversation", "reference"], type: .string, required: true)])
        case .`businessApplied`: return Rule(discriminator: ["signal"], direction: .outbound, fields: ["receiptReference": Field(path: ["receipt", "reference"], type: .string, required: true), "originReference": Field(path: ["receipt", "origin"], type: .string, required: true), "originSignal": Field(path: ["receipt", "signal"], type: .string, required: true), "stage": Field(path: ["receipt", "stage"], type: .string, required: true), "sequence": Field(path: ["receipt", "sequence"], type: .integer, required: true)])
        case .`receiptAcknowledged`: return Rule(discriminator: ["signal"], direction: .inbound, fields: ["receiptReference": Field(path: ["receipt", "reference"], type: .string, required: true)])
        case .`replayRequested`: return Rule(discriminator: ["signal"], direction: .outbound, fields: ["syncReference": Field(path: ["replay", "reference"], type: .string, required: true), "reason": Field(path: ["replay", "reason"], type: .string, required: true), "pendingReferences": Field(path: ["replay", "pending"], type: .array, required: true)])
        }
    }
}
