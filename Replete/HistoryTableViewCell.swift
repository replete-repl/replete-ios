import UIKit

let incomingTag = 0, outgoingTag = 1

class HistoryTableViewCell: UITableViewCell {

    let messageLabel: UILabel
    var topLayoutConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        
        messageLabel = UILabel(frame: CGRectZero)
        messageLabel.font = UIFont(name: "Menlo", size: messageFontSize)
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        messageLabel.userInteractionEnabled = true   // #CopyMessage

        super.init(style: .Default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .None

        contentView.addSubview(messageLabel)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .Left, relatedBy: .Equal, toItem: contentView, attribute: .Left, multiplier: 1, constant: 10))
        contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .Right, relatedBy: .Equal, toItem: contentView, attribute: .Right, multiplier: 1, constant: -10))
        
        self.topLayoutConstraint = NSLayoutConstraint(item: messageLabel, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1, constant: 4);
        contentView.addConstraint(self.topLayoutConstraint)
        
        contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .Bottom, relatedBy: .Equal, toItem: contentView, attribute: .Bottom, multiplier: 1, constant: -10))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureWithMessage(message: Message) {
        
        if (message.incoming) {
            messageLabel.textColor = UIColor.blackColor();
        } else {
            messageLabel.textColor = UIColor.grayColor();
        }

        messageLabel.attributedText = message.text

        if (message.incoming) {
            self.topLayoutConstraint.constant = -2
        } else {
            self.topLayoutConstraint.constant = 4
        }
        
    }
    
    // Highlight cell #CopyMessage
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        messageLabel.backgroundColor = selected ? UIColor.blueColor().colorWithAlphaComponent(0.15) : UIColor.whiteColor()
    }
}
