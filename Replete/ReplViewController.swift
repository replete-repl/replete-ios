import UIKit

let messageFontSize: CGFloat = 14
let toolBarMinHeight: CGFloat = 44
let textViewMaxHeight: (portrait: CGFloat, landscape: CGFloat) = (portrait: 272, landscape: 90)

class ReplViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    
    let history: History
    var tableView: UITableView!
    var toolBar: UIToolbar!
    var textView: UITextView!
    var evalButton: UIButton!
    var rotating = false
    var textFieldHeightLayoutConstraint: NSLayoutConstraint!
    var currentKeyboardHeight: CGFloat!
    var initialized = false;
    var enterPressed = false;
    var scrollToBottom = false;
    
    override var inputAccessoryView: UIView! {
        get {
            if toolBar == nil {
                toolBar = UIToolbar(frame: CGRectMake(0, 0, 0, toolBarMinHeight-0.5))
                
                textView = InputTextView(frame: CGRectZero)
                textView.backgroundColor = UIColor(white: 250/255, alpha: 1)
                textView.font = UIFont(name: "Menlo", size: messageFontSize)
                textView.layer.borderColor = UIColor(red: 200/255, green: 200/255, blue: 205/255, alpha:1).CGColor
                textView.layer.borderWidth = 0.5
                textView.layer.cornerRadius = 5
                textView.scrollsToTop = false
                textView.textContainerInset = UIEdgeInsetsMake(6, 3, 6, 3)
                textView.autocorrectionType = UITextAutocorrectionType.No;
                textView.autocapitalizationType = UITextAutocapitalizationType.None;
                textView.delegate = self
                toolBar.addSubview(textView)
                
                evalButton = UIButton(type: .System)
                evalButton.enabled = false
                evalButton.titleLabel?.font = UIFont.boldSystemFontOfSize(17)
                evalButton.setTitle("Eval", forState: .Normal)
                evalButton.setTitleColor(UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1), forState: .Disabled)
                evalButton.setTitleColor(UIColor(red: 1/255, green: 122/255, blue: 255/255, alpha: 1), forState: .Normal)
                evalButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 8)
                evalButton.addTarget(self, action: "sendAction", forControlEvents: UIControlEvents.TouchUpInside)
                toolBar.addSubview(evalButton)
                
                toolBar.translatesAutoresizingMaskIntoConstraints = false
                textView.translatesAutoresizingMaskIntoConstraints = false
                evalButton.translatesAutoresizingMaskIntoConstraints = false

                textFieldHeightLayoutConstraint = NSLayoutConstraint(item: textView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 1)
                toolBar.addConstraint(textFieldHeightLayoutConstraint)

                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .Left, relatedBy: .Equal, toItem: toolBar, attribute: .Left, multiplier: 1, constant: 8))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .Top, relatedBy: .Equal, toItem: toolBar, attribute: .Top, multiplier: 1, constant: 7.5))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .Right, relatedBy: .Equal, toItem: evalButton, attribute: .Left, multiplier: 1, constant: -2))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .Bottom, relatedBy: .Equal, toItem: toolBar, attribute: .Bottom, multiplier: 1, constant: -8))

                toolBar.addConstraint(NSLayoutConstraint(item: evalButton, attribute: .Right, relatedBy: .Equal, toItem: toolBar, attribute: .Right, multiplier: 1, constant: 0))
                toolBar.addConstraint(NSLayoutConstraint(item: evalButton, attribute: .Bottom, relatedBy: .Equal, toItem: toolBar, attribute: .Bottom, multiplier: 1, constant: -4.5))
                
            }
            return toolBar
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.history = History()
        
        super.init(nibName: nil, bundle: nil)
        
        //hidesBottomBarWhenPushed = true
        self.currentKeyboardHeight = 0.0;
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        history.loadedMessages = [
        ]
        
        let whiteColor = UIColor.whiteColor()
        view.backgroundColor = whiteColor
        
        tableView = UITableView(frame: CGRect(x: 0, y: 20, width: view.bounds.width, height: view.bounds.height-20), style: .Plain)
        tableView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        tableView.backgroundColor = whiteColor
        let edgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: toolBarMinHeight, right: 0)
        tableView.contentInset = edgeInsets
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .Interactive
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.separatorStyle = .None
        view.addSubview(tableView)
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "keyboardDidShow:", name: UIKeyboardDidShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "menuControllerWillHide:", name: UIMenuControllerWillHideMenuNotification, object: nil) // #CopyMessage
        
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        appDelegate.setPrintCallback { (incoming: Bool, message: String!) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                self.loadMessage(incoming, text: message)
            }
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            self.loadMessage(false, text:"\nClojureScript 1.9.2\n" +
            "    Docs: (doc function-name)\n" +
            "          (find-doc \"part-of-name\")\n" +
            "  Source: (source function-name)\n" +
            " Results: Stored in *1, *2, *3,\n" +
            "          an exception in *e\n");
        };
        
        NSLog("Initializing...");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            appDelegate.initializeJavaScriptEnvironment()
            
            dispatch_async(dispatch_get_main_queue()) {
                // mark ready
                NSLog("Ready");
                self.initialized = true;
                let hasText = self.textView.hasText()
                self.evalButton.enabled = hasText
                if (hasText) {
                    self.runParinfer()
                }
            }
        }
        
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidAppear(animated: Bool)  {
        super.viewDidAppear(animated)
        //tableView.flashScrollIndicators()
    }
    
    override func viewWillDisappear(animated: Bool)  {
        super.viewWillDisappear(animated)
        //chat.draft = textView.text
    }
    
    // This gets called a lot. Perhaps there's a better way to know when `view.window` has been set?
   override func viewDidLayoutSubviews()  {
        super.viewDidLayoutSubviews()
        
        if true {
            //textView.text = chat.draft
            //chat.draft = ""
            textViewDidChange(textView)
            textView.becomeFirstResponder()
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return history.loadedMessages.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.loadedMessages[section].count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

            let cellIdentifier = NSStringFromClass(HistoryTableViewCell)
            var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! HistoryTableViewCell!
            if cell == nil {
                cell = HistoryTableViewCell(style: .Default, reuseIdentifier: cellIdentifier)
                
                // Add gesture recognizers #CopyMessage
                let action: Selector = "messageShowMenuAction:"
                let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: action)
                doubleTapGestureRecognizer.numberOfTapsRequired = 2
                cell.messageLabel.addGestureRecognizer(doubleTapGestureRecognizer)
                cell.messageLabel.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: action))
            }
            let message = history.loadedMessages[indexPath.section][indexPath.row]
            cell.configureWithMessage(message)
            return cell
        
    }
    
    // Reserve row selection #CopyMessage
    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        return nil
    }
        
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
     
        // Disable default keyboard shortcut where two spaces inserts a '.'
        let currentText = textView.text
        if (range.location > 0 &&
            text == " " &&
            currentText.substringWithRange(currentText.startIndex.advancedBy(range.location-1)...currentText.startIndex.advancedBy(range.location-1)) == " ") {
            textView.text = (textView.text as NSString).stringByReplacingCharactersInRange(range, withString: " ")
            textView.selectedRange = NSMakeRange(range.location+1, 0);
            return false;
        }
        
        if (text == "\n") {
            enterPressed = true;
        }
        return true;
    }
    
    func runParinfer() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        let currentText = textView.text
        let currentSelectedRange = textView.selectedRange
        
        if (currentText != "") {
            
            let result: Array = appDelegate.parinferFormat(currentText, pos:Int32(currentSelectedRange.location), enterPressed:enterPressed)
            textView.text = result[0] as! String
            textView.selectedRange = NSMakeRange(result[1] as! Int, 0)
        }
        enterPressed = false;
    }
    
    // This is a native profile of Parinfer, meant for use when 
    // ClojureScript hasn't yet initialized, but yet the user 
    // is already typing. It covers extremely simple cases that
    // could be typed immediately.
    func runPoorMansParinfer() {
        
        let currentText = textView.text
        let currentSelectedRange = textView.selectedRange
        
        if (currentText != "") {
            if (currentSelectedRange.location == 1) {
                if (currentText == "(") {
                    textView.text = "()";
                } else if (currentText == "[") {
                    textView.text = "[]";
                } else if (currentText == "{") {
                    textView.text = "{}";
                }
                textView.selectedRange = currentSelectedRange;
            }
            
        }
    }
    
    func textViewDidChange(textView: UITextView) {
        if (initialized) {
            runParinfer()
        } else {
            runPoorMansParinfer()
        }
        updateTextViewHeight()
        evalButton.enabled = self.initialized && textView.hasText()
    }
    
    func keyboardWillShow(notification: NSNotification) {
        
        let userInfo = notification.userInfo as NSDictionary!
        let frameNew = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        let insetNewBottom = tableView.convertRect(frameNew, fromView: nil).height
        let insetOld = tableView.contentInset
        let insetChange = insetNewBottom - insetOld.bottom
        let overflow = tableView.contentSize.height - (tableView.frame.height-insetOld.top-insetOld.bottom)
        
        let duration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let animations: (() -> Void) = {
            if !(self.tableView.tracking || self.tableView.decelerating) {
                // Move content with keyboard
                if overflow > 0 {                   // scrollable before
                    self.tableView.contentOffset.y += insetChange
                    if self.tableView.contentOffset.y < -insetOld.top {
                        self.tableView.contentOffset.y = -insetOld.top
                    }
                } else if insetChange > -overflow { // scrollable after
                    self.tableView.contentOffset.y += insetChange + overflow
                }
            }
        }
        if duration > 0 {
            let options = UIViewAnimationOptions(rawValue: UInt((userInfo[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).integerValue << 16)) // http://stackoverflow.com/a/18873820/242933
            UIView.animateWithDuration(duration, delay: 0, options: options, animations: animations, completion: nil)
        } else {
            animations()
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        
        let userInfo = notification.userInfo as NSDictionary!
        let frameNew = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        let insetNewBottom = tableView.convertRect(frameNew, fromView: nil).height
        self.currentKeyboardHeight = frameNew.height
        
        // Inset `tableView` with keyboard
        let contentOffsetY = tableView.contentOffset.y
        tableView.contentInset.bottom = insetNewBottom
        tableView.scrollIndicatorInsets.bottom = insetNewBottom
        // Prevents jump after keyboard dismissal
        if self.tableView.tracking || self.tableView.decelerating {
            tableView.contentOffset.y = contentOffsetY
        }
    }
    
    func updateTextViewHeight() {
        let oldHeight = textView.frame.height
        let newText = textView.text
        let newSize = (newText as NSString).boundingRectWithSize(CGSize(width: textView.frame.width - textView.textContainerInset.right - textView.textContainerInset.left - 10, height: CGFloat.max), options: .UsesLineFragmentOrigin, attributes: [NSFontAttributeName: textView.font!], context: nil)
        let heightChange = newSize.height + textView.textContainerInset.top + textView.textContainerInset.bottom - oldHeight
        
        let maxHeight = self.view.frame.height
            - self.topLayoutGuide.length
            - currentKeyboardHeight
            + toolBar.frame.height
            - textView.textContainerInset.top
            - textView.textContainerInset.bottom
            - 20
        
        if !(textFieldHeightLayoutConstraint.constant + heightChange > maxHeight){
            //ceil because of small irregularities in heightChange
            self.textFieldHeightLayoutConstraint.constant = ceil(heightChange + oldHeight)
            
            //In order to ensure correct placement of text inside the textfield:
            self.textView.setContentOffset(CGPoint.zero, animated: false)
            //To ensure update of placement happens immediately
            self.textView.layoutIfNeeded()
            
        }
        else{
            self.textFieldHeightLayoutConstraint.constant = maxHeight
        }
        
    }
    
    func markString(s: NSMutableAttributedString) -> Bool {
        if (s.string.containsString("\u{001b}[")) {
            
            let text = s.string;
            let range : Range<String.Index> = text.rangeOfString("\u{001b}[")!;
            let index: Int = text.startIndex.distanceTo(range.startIndex);
            let index2 = text.startIndex.advancedBy(index + 2);
            var color : UIColor = UIColor.blackColor();
            if (text.substringFromIndex(index2).hasPrefix("34m")){
                color = UIColor.blueColor();
            } else if (text.substringFromIndex(index2).hasPrefix("32m")){
                color = UIColor.init(colorLiteralRed: 0.0, green: 0.75, blue: 0.0, alpha: 1.0);
            } else if (text.substringFromIndex(index2).hasPrefix("35m")){
                color = UIColor.init(colorLiteralRed: 0.75, green: 0.0, blue: 0.75, alpha: 1.0);
            } else if (text.substringFromIndex(index2).hasPrefix("31m")){
                color = UIColor.init(colorLiteralRed: 1, green: 0.33, blue: 0.33, alpha: 1.0);
            }
            
            s.replaceCharactersInRange(NSMakeRange(index, 5), withString: "");
            s.addAttribute(NSForegroundColorAttributeName,
                           value: color,
                           range: NSMakeRange(index, s.length-index));
            return true;
        }
        
        return false;
    }
    
    func loadMessage(incoming: Bool, text: String) {
        
        if (text != "\n") {
            // NSLog("load: %@", text);
            
            var s = NSMutableAttributedString(string:text);
            
            while (markString(s)) {};
            
            history.loadedMessages.append([Message(incoming: incoming, text: s)])
            
            if (history.loadedMessages.count > 64) {
                history.loadedMessages.removeAtIndex(0);
                tableView.reloadData();
            } else {
            
                let lastSection = tableView.numberOfSections
                tableView.beginUpdates()
                tableView.insertSections(NSIndexSet(index: lastSection), withRowAnimation: .Automatic)
                tableView.insertRowsAtIndexPaths([
                    NSIndexPath(forRow: 0, inSection: lastSection)
                    ], withRowAnimation: .Automatic)
                tableView.endUpdates()
            }
            
            scrollToBottom = true;
            
            let delayTime = dispatch_time(DISPATCH_TIME_NOW,
                                          Int64(50 * Double(NSEC_PER_MSEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                if (self.scrollToBottom) {
                    self.scrollToBottom = false;
                    self.tableViewScrollToBottomAnimated(false)
                }
            }
        }
    }
    
    func sendAction() {
        // Autocomplete text before sending #hack
        //textView.resignFirstResponder()
        //textView.becomeFirstResponder()
        
        let textToEvaluate = textView.text
        
        loadMessage(false, text: textToEvaluate)
        
        textView.text = nil
        updateTextViewHeight()
        evalButton.enabled = false
        
        // Dispatch to be evaluated
        
        let delayTime = dispatch_time(DISPATCH_TIME_NOW,
            Int64(50 * Double(NSEC_PER_MSEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            appDelegate.evaluate(textToEvaluate)
        }

    }
    
    func tableViewScrollToBottomAnimated(animated: Bool) {
        let numberOfSections = tableView.numberOfSections;
        let numberOfRows = tableView.numberOfRowsInSection(numberOfSections-1)
        if numberOfRows > 0 {
            tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: numberOfRows-1, inSection: numberOfSections-1), atScrollPosition: .Bottom, animated: animated)
        }
    }
    
    // Handle actions #CopyMessage
    // 1. Select row and show "Copy" menu
    func messageShowMenuAction(gestureRecognizer: UITapGestureRecognizer) {
        let twoTaps = (gestureRecognizer.numberOfTapsRequired == 2)
        let doubleTap = (twoTaps && gestureRecognizer.state == .Ended)
        let longPress = (!twoTaps && gestureRecognizer.state == .Began)
        if doubleTap || longPress {
            let pressedIndexPath = tableView.indexPathForRowAtPoint(gestureRecognizer.locationInView(tableView))!
            tableView.selectRowAtIndexPath(pressedIndexPath, animated: false, scrollPosition: .None)
            
            let menuController = UIMenuController.sharedMenuController()
            let bubbleImageView = gestureRecognizer.view!
            menuController.setTargetRect(bubbleImageView.frame, inView: bubbleImageView.superview!)
            menuController.menuItems = [UIMenuItem(title: "Copy", action: "messageCopyTextAction:")]
            menuController.setMenuVisible(true, animated: true)
        }
    }
    // 2. Copy text to pasteboard
    func messageCopyTextAction(menuController: UIMenuController) {
        let selectedIndexPath = tableView.indexPathForSelectedRow
        let selectedMessage = history.loadedMessages[selectedIndexPath!.section][selectedIndexPath!.row]
        UIPasteboard.generalPasteboard().string = selectedMessage.text.string
    }
    // 3. Deselect row
    func menuControllerWillHide(notification: NSNotification) {
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRowAtIndexPath(selectedIndexPath, animated: false)
        }
        (notification.object as! UIMenuController).menuItems = nil
    }
    
    override var keyCommands: [UIKeyCommand]? {
        get {
            let commandEnter = UIKeyCommand(input: "\r", modifierFlags: .Command, action: Selector("sendAction"))
            return [commandEnter]
        }
    }
}

// Only show "Copy" when editing `textView` #CopyMessage
class InputTextView: UITextView {
    override func canPerformAction(action: Selector, withSender sender: AnyObject!) -> Bool {
        if (delegate as! ReplViewController).tableView.indexPathForSelectedRow != nil {
            return action == "messageCopyTextAction:"
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    // More specific than implementing `nextResponder` to return `delegate`, which might cause side effects?
    func messageCopyTextAction(menuController: UIMenuController) {
        (delegate as! ReplViewController).messageCopyTextAction(menuController)
    }
}
