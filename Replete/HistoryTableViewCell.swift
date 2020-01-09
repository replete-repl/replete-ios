import UIKit

let incomingTag = 0, outgoingTag = 1

class HistoryTableViewCell: UITableViewCell {

    let messageLabel: UILabel
    var topLayoutConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        
        messageLabel = UILabel(frame: CGRect.zero)
        messageLabel.font = UIFont(name: "Fira Code", size: messageFontSize)
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

    func getTextColor(incoming : Bool) -> UIColor {
        if #available(iOS 13.0, *) {
            return incoming ?
                (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black)
                : (traitCollection.userInterfaceStyle == .dark ? UIColor.lightGray : UIColor.darkGray);
        } else {
            return incoming ? UIColor.black : UIColor.darkGray;
        }
    }
    
    func configureWithMessage(_ message: Message) {
        
        messageLabel.textColor = self.getTextColor(incoming: message.incoming)

        messageLabel.attributedText = message.text

        if (message.incoming) {
            self.topLayoutConstraint.constant = -2
        } else {
            self.topLayoutConstraint.constant = 4
        }
        
    }
    
    func getBackgroundColor(selected : Bool) -> UIColor {
        if #available(iOS 13.0, *) {
            return selected ?
                (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.blue.withAlphaComponent(0.15))
                : UIColor.systemBackground;
        } else {
            return selected ? UIColor.blue.withAlphaComponent(0.15) : UIColor.white;
        }
    }
    
    // Highlight cell #CopyMessage
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        messageLabel.backgroundColor = self.getBackgroundColor(selected: selected)
    }
}
