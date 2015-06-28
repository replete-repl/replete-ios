import Foundation.NSDate

class Message {
    let incoming: Bool
    let text: String

    init(incoming: Bool, text: String) {
        self.incoming = incoming
        self.text = text
    }
}
