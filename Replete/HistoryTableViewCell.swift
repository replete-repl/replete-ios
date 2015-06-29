import UIKit

let incomingTag = 0, outgoingTag = 1

class HistoryTableViewCell: UITableViewCell {

    let messageLabel: UILabel

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        
        messageLabel = UILabel(frame: CGRectZero)
        messageLabel.font = UIFont(name: "Menlo", size: messageFontSize)
        messageLabel.numberOfLines = 0
        messageLabel.userInteractionEnabled = true   // #CopyMessage

        super.init(style: .Default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .None

        contentView.addSubview(messageLabel)
        messageLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureWithMessage(message: Message) {
        
        messageLabel.text = message.text
        
        var layoutAttribute: NSLayoutAttribute
        var layoutConstant: CGFloat
        
        if (message.incoming) {
            messageLabel.textColor = UIColor.blackColor();
        } else {
            messageLabel.textColor = UIColor.grayColor();
        }
        
        messageLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .Left, relatedBy: .Equal, toItem: contentView, attribute: .Left, multiplier: 1, constant: 10))
        
        if (message.incoming) {
            contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1, constant: -2))
        } else {
            contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1, constant: 4))
        }
        
        contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .Bottom, relatedBy: .Equal, toItem: contentView, attribute: .Bottom, multiplier: 1, constant: -5))
        
    }
    
    // Highlight cell #CopyMessage
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        messageLabel.highlighted = selected
    }
}
