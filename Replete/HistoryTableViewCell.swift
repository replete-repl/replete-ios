import UIKit

let incomingTag = 0, outgoingTag = 1

class HistoryTableViewCell: UITableViewCell {

    let messageLabel: UILabel
    var topLayoutConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        
        messageLabel = UILabel(frame: CGRect.zero)
        messageLabel.font = UIFont(name: "Menlo", size: messageFontSize)
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        messageLabel.isUserInteractionEnabled = true   // #CopyMessage

        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        contentView.addSubview(messageLabel)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .left, relatedBy: .equal, toItem: contentView, attribute: .left, multiplier: 1, constant: 10))
        contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .right, relatedBy: .equal, toItem: contentView, attribute: .right, multiplier: 1, constant: -10))
        
        self.topLayoutConstraint = NSLayoutConstraint(item: messageLabel, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: 4);
        contentView.addConstraint(self.topLayoutConstraint)
        
        contentView.addConstraint(NSLayoutConstraint(item: messageLabel, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: -10))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureWithMessage(_ message: Message) {
        
        if (message.incoming) {
            messageLabel.textColor = UIColor.black;
        } else {
            messageLabel.textColor = UIColor.gray;
        }

        messageLabel.attributedText = message.text

        if (message.incoming) {
            self.topLayoutConstraint.constant = -2
        } else {
            self.topLayoutConstraint.constant = 4
        }
        
    }
    
    // Highlight cell #CopyMessage
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        messageLabel.backgroundColor = selected ? UIColor.blue.withAlphaComponent(0.15) : UIColor.white
    }
}
