import Foundation.NSDate

class Message {
    let incoming: Bool
    let text: NSAttributedString

    init(incoming: Bool, text: NSAttributedString) {
        self.incoming = incoming
        self.text = text
    }
}
