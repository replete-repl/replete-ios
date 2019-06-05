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
                toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: toolBarMinHeight-0.5))
                toolBar.layoutIfNeeded() // see SO answer re: iOS 11 and UIToolbar - https://bit.ly/2wIPF5n
                
                textView = InputTextView(frame: CGRect.zero)
                textView.backgroundColor = UIColor(white: 250/255, alpha: 1)
                textView.font = UIFont(name: "Fira Code", size: messageFontSize)
                textView.layer.borderColor = UIColor(red: 200/255, green: 200/255, blue: 205/255, alpha:1).cgColor
                textView.layer.borderWidth = 0.5
                textView.layer.cornerRadius = 5
                textView.scrollsToTop = false
                textView.isScrollEnabled = false
                textView.textContainerInset = UIEdgeInsetsMake(3, 6, 3, 6)
                textView.autocorrectionType = UITextAutocorrectionType.no;
                textView.autocapitalizationType = UITextAutocapitalizationType.none;
                textView.keyboardType = UIKeyboardType.asciiCapable;
                textView.delegate = self
                toolBar.addSubview(textView)
                
                evalButton = UIButton(type: .system)
                evalButton.isEnabled = false
                evalButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
                evalButton.setTitle("Eval", for: UIControlState())
                evalButton.setTitleColor(UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1), for: .disabled)
                evalButton.setTitleColor(UIColor(red: 1/255, green: 122/255, blue: 255/255, alpha: 1), for: UIControlState())
                evalButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 8)
                evalButton.addTarget(self, action: #selector(ReplViewController.sendAction), for: UIControlEvents.touchUpInside)
                toolBar.addSubview(evalButton)
                
                toolBar.translatesAutoresizingMaskIntoConstraints = false
                textView.translatesAutoresizingMaskIntoConstraints = false
                evalButton.translatesAutoresizingMaskIntoConstraints = false

                textFieldHeightLayoutConstraint = NSLayoutConstraint(item: textView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 1)
                toolBar.addConstraint(textFieldHeightLayoutConstraint)

                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .left, relatedBy: .equal, toItem: toolBar, attribute: .left, multiplier: 1, constant: 8))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .top, relatedBy: .equal, toItem: toolBar, attribute: .top, multiplier: 1, constant: 7.5))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .trailing, relatedBy: .equal, toItem: evalButton, attribute: .leading, multiplier: 1, constant: -2))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .bottom, relatedBy: .equal, toItem: toolBar, attribute: .bottom, multiplier: 1, constant: -8))

                toolBar.addConstraint(NSLayoutConstraint(item: evalButton, attribute: .right, relatedBy: .equal, toItem: toolBar, attribute: .right, multiplier: 1, constant: 0))
                toolBar.addConstraint(NSLayoutConstraint(item: evalButton, attribute: .bottom, relatedBy: .equal, toItem: toolBar, attribute: .bottom, multiplier: 1, constant: -4.5))
                evalButton.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
                evalButton.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
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
    
    override var canBecomeFirstResponder : Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        history.loadedMessages = [
        ]
        
        let whiteColor = UIColor.white
        view.backgroundColor = whiteColor
        
        if #available(iOS 11.0, *) {
            let safeAreaInsets = UIApplication.shared.delegate?.window??.safeAreaInsets;
            tableView = UITableView(frame: CGRect(x: safeAreaInsets!.left,
                                                  y: max(safeAreaInsets!.top, 20),
                                                  width: view.bounds.width - safeAreaInsets!.left - safeAreaInsets!.right,
                                                  height: view.bounds.height - max(safeAreaInsets!.top, 20) - safeAreaInsets!.bottom),
                                    style: .plain)
        } else {
            tableView = UITableView(frame: CGRect(x: 0,
                                                  y: 20,
                                                  width: view.bounds.width,
                                                  height: view.bounds.height - 20),
                                    style: .plain)
        }
        
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = whiteColor
        let edgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: toolBarMinHeight, right: 0)
        tableView.contentInset = edgeInsets
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(ReplViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(ReplViewController.keyboardDidShow(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(ReplViewController.menuControllerWillHide(_:)), name: NSNotification.Name.UIMenuControllerWillHideMenu, object: nil) // #CopyMessage
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        appDelegate.setPrintCallback { (incoming: Bool, message: String!) -> Void in
            DispatchQueue.main.async {
                self.loadMessage(incoming, text: message)
            }
        }
        
        DispatchQueue.main.async {
            let version = appDelegate.getClojureScriptVersion()
            let masthead = "\nClojureScript \(version!)\n" +
            "    Docs: (doc function-name)\n" +
            "          (find-doc \"part-of-name\")\n" +
            "  Source: (source function-name)\n" +
            " Results: Stored in *1, *2, *3,\n" +
            "          an exception in *e\n";
            self.loadMessage(false, text: masthead)
        };
        
        NSLog("Initializing...");
        DispatchQueue.global(qos: .background).async {
            appDelegate.initializeJavaScriptEnvironment()
            self.initialized = true;
            DispatchQueue.main.async {
                // mark ready
                NSLog("Ready");
                let hasText = self.textView.hasText
                self.evalButton.isEnabled = hasText
                if (hasText) {
                    self.runParinfer()
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool)  {
        super.viewDidAppear(animated)
        //tableView.flashScrollIndicators()
    }
    
    override func viewWillDisappear(_ animated: Bool)  {
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
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return history.loadedMessages.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.loadedMessages[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

            let cellIdentifier = NSStringFromClass(HistoryTableViewCell.self)
            var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! HistoryTableViewCell?
            if cell == nil {
                cell = HistoryTableViewCell(style: .default, reuseIdentifier: cellIdentifier)
                
                // Add gesture recognizers #CopyMessage
                let action: Selector = #selector(ReplViewController.messageShowMenuAction(_:))
                let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: action)
                doubleTapGestureRecognizer.numberOfTapsRequired = 2
                cell?.messageLabel.addGestureRecognizer(doubleTapGestureRecognizer)
                cell?.messageLabel.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: action))
            }
            let message = history.loadedMessages[indexPath.section][indexPath.row]
            cell?.configureWithMessage(message)
            return cell!
        
    }
    
    // Reserve row selection #CopyMessage
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
        
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
     
        // Disable default keyboard shortcut where two spaces inserts a '.'
        let currentText = textView.text
        if (range.location > 0 &&
            text == " " &&
            currentText![currentText!.index(currentText!.startIndex, offsetBy: range.location-1)..<currentText!.index(currentText!.startIndex, offsetBy: range.location)] == " ") {
            textView.text = (textView.text as NSString).replacingCharacters(in: range, with: " ")
            textView.selectedRange = NSMakeRange(range.location+1, 0);
            return false;
        }
        
        if (text == "\n") {
            enterPressed = true;
        }
        
        if (enterPressed && range.location == currentText!.count) {
            enterPressed = false
            while (!self.initialized) {
                Thread.sleep(forTimeInterval: 0.1);
            }
            sendAction()
            return false;
        }
        
        if (textView.intrinsicContentSize.width >= textView.frame.width - evalButton.frame.width - 12){ // the magic number is inset widths summed
            textView.isScrollEnabled = true
        }
        else{
            textView.isScrollEnabled = false
        }
        return true;
    }
    
    func runParinfer() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
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
    
    func textViewDidChange(_ textView: UITextView) {
        if (initialized) {
            runParinfer()
        } else {
            runPoorMansParinfer()
        }
        updateTextViewHeight()
        evalButton.isEnabled = self.initialized && textView.hasText
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        
        let userInfo = notification.userInfo as NSDictionary?
        let frameNew = (userInfo?[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let insetNewBottom = tableView.convert(frameNew, from: nil).height
        let insetOld = tableView.contentInset
        let insetChange = insetNewBottom - insetOld.bottom
        let overflow = tableView.contentSize.height - (tableView.frame.height-insetOld.top-insetOld.bottom)
        
        let duration = (userInfo?[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let animations: (() -> Void) = {
            if !(self.tableView.isTracking || self.tableView.isDecelerating) {
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
            let options = UIViewAnimationOptions(rawValue: UInt((userInfo?[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).intValue << 16)) // http://stackoverflow.com/a/18873820/242933
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: animations, completion: nil)
        } else {
            animations()
        }
    }
    
    @objc func keyboardDidShow(_ notification: Notification) {
        
        let userInfo = notification.userInfo as NSDictionary?
        let frameNew = (userInfo?[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let insetNewBottom = tableView.convert(frameNew, from: nil).height
        self.currentKeyboardHeight = frameNew.height
        
        // Inset `tableView` with keyboard
        let contentOffsetY = tableView.contentOffset.y
        tableView.contentInset.bottom = insetNewBottom
        tableView.scrollIndicatorInsets.bottom = insetNewBottom
        // Prevents jump after keyboard dismissal
        if self.tableView.isTracking || self.tableView.isDecelerating {
            tableView.contentOffset.y = contentOffsetY
        }
    }
    
    func updateTextViewHeight() {
        let oldHeight = textView.frame.height
        let newText = textView.text
        let newSize = (newText! as NSString).boundingRect(with: CGSize(width: textView.frame.width - textView.textContainerInset.right - textView.textContainerInset.left - 10, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [NSAttributedStringKey.font: textView.font!], context: nil)
        let heightChange = newSize.height + textView.textContainerInset.top + textView.textContainerInset.bottom - oldHeight
        
        let containerInsetsSum = textView.textContainerInset.top + textView.textContainerInset.bottom
        
        let maxHeightDeltas = toolBar.frame.height
            - self.topLayoutGuide.length
            - currentKeyboardHeight
            - containerInsetsSum
            - 20
        
        let maxHeight = self.view.frame.height - maxHeightDeltas
        
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
    
    func markString(_ s: NSMutableAttributedString) -> Bool {
        if (s.string.contains("\u{001b}[")) {
            
            let text = s.string;
            let range : Range<String.Index> = text.range(of: "\u{001b}[")!;
            let index: Int = text.distance(from: text.startIndex, to: range.lowerBound);
            let index2 = text.index(text.startIndex, offsetBy: index + 2);
            var color : UIColor = UIColor.black;
            if (text[index2...].hasPrefix("34m")){
                color = UIColor.blue;
            } else if (text[index2...].hasPrefix("32m")){
                color = UIColor(red: 0.0, green: 0.75, blue: 0.0, alpha: 1.0);
            } else if (text[index2...].hasPrefix("35m")){
                color = UIColor(red: 0.75, green: 0.0, blue: 0.75, alpha: 1.0);
            } else if (text[index2...].hasPrefix("31m")){
                color = UIColor(red: 1, green: 0.33, blue: 0.33, alpha: 1.0);
            }
            
            s.replaceCharacters(in: NSMakeRange(index, 5), with: "");
            s.addAttribute(NSAttributedStringKey.foregroundColor,
                           value: color,
                           range: NSMakeRange(index, s.length-index));
            return true;
        }
        
        return false;
    }
    
    func loadMessage(_ incoming: Bool, text: String) {
        let s = prepareMessageForDisplay(text)
        addPreparedMessageToDisplay(incoming, text: s)
        
        let delayTime = DispatchTime.now() + Double(Int64(50 * Double(NSEC_PER_MSEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delayTime) {
            if (self.scrollToBottom) {
                self.scrollToBottom = false;
                self.tableViewScrollToBottomAnimated(false)
            }
        }
    }
    
    func prepareMessageForDisplay(_ text: String) -> NSMutableAttributedString? {
        if (text != "\n") {
            let s = NSMutableAttributedString(string:text);
            while (markString(s)) {};
            return s
        }
        return nil
    }
    
    func addPreparedMessageToDisplay(_ incoming: Bool, text: NSMutableAttributedString?) {
        guard let text = text else {
            return
        }
        history.loadedMessages.append([Message(incoming: incoming, text: text)])
        
        if (history.loadedMessages.count > 64) {
            history.loadedMessages.remove(at: 0);
            tableView.reloadData();
        } else {
            
            let lastSection = tableView.numberOfSections
            tableView.beginUpdates()
            tableView.insertSections(IndexSet(integer: lastSection), with: .automatic)
            tableView.insertRows(at: [
                IndexPath(row: 0, section: lastSection)
                ], with: .automatic)
            tableView.endUpdates()
        }
        
        scrollToBottom = true;
    }
    
    @objc func sendAction() {
        // Autocomplete text before sending #hack
        //textView.resignFirstResponder()
        //textView.becomeFirstResponder()
        
        let textToEvaluate = textView.text
        
        loadMessage(false, text: textToEvaluate!)
        
        textView.text = nil
        updateTextViewHeight()
        evalButton.isEnabled = false
        
        // Dispatch to be evaluated
        
        let delayTime = DispatchTime.now() + Double(Int64(50 * Double(NSEC_PER_MSEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delayTime) {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.evaluate(textToEvaluate)
        }

    }
    
    func tableViewScrollToBottomAnimated(_ animated: Bool) {
        let numberOfSections = tableView.numberOfSections;
        let numberOfRows = tableView.numberOfRows(inSection: numberOfSections-1)
        if numberOfRows > 0 {
            tableView.scrollToRow(at: IndexPath(row: numberOfRows-1, section: numberOfSections-1), at: .bottom, animated: animated)
        }
    }
    
    // Handle actions #CopyMessage
    // 1. Select row and show "Copy" menu
    @objc func messageShowMenuAction(_ gestureRecognizer: UITapGestureRecognizer) {
        let twoTaps = (gestureRecognizer.numberOfTapsRequired == 2)
        let doubleTap = (twoTaps && gestureRecognizer.state == .ended)
        let longPress = (!twoTaps && gestureRecognizer.state == .began)
        if doubleTap || longPress {
            let pressedIndexPath = tableView.indexPathForRow(at: gestureRecognizer.location(in: tableView))!
            tableView.selectRow(at: pressedIndexPath, animated: false, scrollPosition: .none)
            
            let menuController = UIMenuController.shared
            let bubbleImageView = gestureRecognizer.view!
            menuController.setTargetRect(bubbleImageView.frame, in: bubbleImageView.superview!)
            menuController.menuItems = [UIMenuItem(title: "Copy", action: #selector(ReplViewController.messageCopyTextAction(_:)))]
            menuController.setMenuVisible(true, animated: true)
        }
    }
    // 2. Copy text to pasteboard
    @objc func messageCopyTextAction(_ menuController: UIMenuController) {
        let selectedIndexPath = tableView.indexPathForSelectedRow
        let selectedMessage = history.loadedMessages[selectedIndexPath!.section][selectedIndexPath!.row]
        UIPasteboard.general.string = selectedMessage.text.string
    }
    // 3. Deselect row
    @objc func menuControllerWillHide(_ notification: Notification) {
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: false)
        }
        (notification.object as! UIMenuController).menuItems = nil
    }
    
    override var keyCommands: [UIKeyCommand]? {
        get {
            let commandEnter = UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(ReplViewController.sendAction))
            return [commandEnter]
        }
    }
}

// Only show "Copy" when editing `textView` #CopyMessage
class InputTextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any!) -> Bool {
        if (delegate as! ReplViewController).tableView.indexPathForSelectedRow != nil {
            return action == #selector(InputTextView.messageCopyTextAction(_:))
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    // More specific than implementing `nextResponder` to return `delegate`, which might cause side effects?
    @objc func messageCopyTextAction(_ menuController: UIMenuController) {
        (delegate as! ReplViewController).messageCopyTextAction(menuController)
    }
}
