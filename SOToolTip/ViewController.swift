import Cocoa
import CustomToolTip

class ViewController: NSViewController
{
    override func loadView() {
        super.loadView()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        if let button = findPushButton(in: view)
        {
            button.customToolTip = makeCustomToolTip()
            button.customToolTipBackgroundColor = #colorLiteral(red: 0.1921568662, green: 0.007843137719, blue: 0.09019608051, alpha: 1)
        }
    }
    
    func findPushButton(in view: NSView) -> NSButton?
    {
        if let button = view as? NSButton { return button }
        
        for subview in view.subviews
        {
            if let button = findPushButton(in: subview) {
                return button
            }
        }
        return nil
    }
    
    func makeCustomToolTip() -> NSView
    {
        let titleText = "Custom tool tips are cool!"
        let bodyText =
            """
            
            \tYou can create rich tool tips with any content you like,
            \tand attach them to views with one line of code as easily
            \tas you can attach the old boring plain text standard
            \ttool tips.
            """
        
        let titleFont = NSFont.systemFont(ofSize: 14, weight: .bold)
        let title = NSAttributedString(
            string: titleText,
            attributes: [.font: titleFont]
        )
        
        let bodyFont = NSFont.systemFont(ofSize: 10)
        let body = NSAttributedString(
            string: bodyText,
            attributes: [.font: bodyFont]
        )
        
        let attrStr = NSMutableAttributedString(attributedString: title)
        attrStr.append(body)
        
        let label = NSTextField(labelWithAttributedString: attrStr)
        
        let imageView = NSImageView(frame: CGRect(origin: .zero, size: CGSize(width: label.frame.height, height: label.frame.height)))
        imageView.image = #imageLiteral(resourceName: "Swift_logo")
        
        let toolTipView = NSView(
            frame: CGRect(
                origin: .zero,
                size: CGSize(
                    width: imageView.frame.width + label.frame.width + 5,
                    height: imageView.frame.height
                )
            )
        )
        
        toolTipView.addSubview(imageView)
        
        label.frame.origin.x += imageView.frame.maxX + 5
        toolTipView.addSubview(label)
        
        return toolTipView
    }
}

