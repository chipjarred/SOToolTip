import Cocoa

class ViewController: NSViewController
{
    override func loadView() {
        super.loadView()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        findPushButton(in: view)?.customToolTip = makeCustomToolTip()
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
        let titleText = "Custom Tool Tip"
        let bodyText = "\n\tThis demonstrates that its possible,\n\tand if I can do it, so you can you"
        
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
                    width: imageView.frame.width + label.frame.width + 15,
                    height: imageView.frame.height + 10
                )
            )
        )
        
        imageView.frame.origin.x += 5
        imageView.frame.origin.y += 5
        toolTipView.addSubview(imageView)
        
        label.frame.origin.x += imageView.frame.maxX + 5
        label.frame.origin.y += 5
        toolTipView.addSubview(label)
        
        return toolTipView
    }
}

