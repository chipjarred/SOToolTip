import AppKit

// MARK:- Custom Tool Tip Window
// -------------------------------------
/**
 Window for displaying custom tool tips.
 */
class CustomToolTipWindow: NSWindow
{
    // -------------------------------------
    static func makeAndShow(
        toolTipView: NSView,
        for owner: NSView) -> CustomToolTipWindow
    {
        let window = CustomToolTipWindow(toolTipView: toolTipView, for: owner)
        window.orderFront(self)
        return window
    }
    
    // -------------------------------------
    init(toolTipView: NSView, for toolTipOwner: NSView)
    {
        super.init(
            contentRect: toolTipView.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = NSColor.windowBackgroundColor
        
        let border = BorderedView.init(frame: toolTipView.frame)
        border.addSubview(toolTipView)
        contentView = border
        contentView?.isHidden = false
        
        reposition(relativeTo: toolTipOwner)
    }
    
    // -------------------------------------
    deinit { orderOut(nil) }
    
    // -------------------------------------
    /**
     Place the tool tip window's frame in a sensible place relative to the
     tool tip's owner view on the screen.
     
     If the current layout direction is left-to-right, the preferred location is
     below and shifted to the right relative to the owner.  If the layout
     direction is right-to-left, the preferred location is below and shifted to
     the left relative to the owner.
     
     The preferred location is overridden when any part of the tool tip would be
     drawn off of the screen.  For conflicts with horizontal edges, it is moved
     to be some "safety" distance within the screen bounds.  For conflicts with
     the bottom edge, the tool tip is positioned above the owning view.
     
     Non-flipped coordinates (y = 0 at bottom) are assumed.
     */
    func reposition(relativeTo toolTipOwner: NSView)
    {
        guard let ownerRect =
            toolTipOwner.window?.convertToScreen(toolTipOwner.frame),
            let screenRect = toolTipOwner.window?.screen?.visibleFrame
        else { return }
        
        let hPadding: CGFloat = ownerRect.width / 2
        let hSafetyPadding: CGFloat = 20
        let vPadding: CGFloat = 0
        
        var newRect = frame
        newRect.origin = ownerRect.origin
        
        // Position tool tip window slightly below the onwer on the screen
        newRect.origin.y -= newRect.height + vPadding

        if NSApp.userInterfaceLayoutDirection == .leftToRight
        {
            /*
             Position the tool tip window to the right relative to the owner on
             the screen.
             */
            newRect.origin.x += hPadding
            
            // Make sure we're not drawing off the right edge
            newRect.origin.x = min(
                newRect.origin.x,
                screenRect.maxX - newRect.width - hSafetyPadding
            )
        }
        else
        {
            /*
             Position the tool tip window to the left relative to the owner on
             the screen.
             */
            newRect.origin.x -= hPadding
            
            // Make sure we're not drawing off the left edge
            newRect.origin.x =
                max(newRect.origin.x, screenRect.minX + hSafetyPadding)
        }
        
        
        /*
         Make sure we're not drawing off the bottom edge of the visible area.
         Non-flipped coordinates (y = 0 at bottom) are assumed.
         If we are, move the tool tip above the onwer.
         */
        if newRect.minY < screenRect.minY  {
            newRect.origin.y = ownerRect.maxY + vPadding
        }
        
        self.setFrameOrigin(newRect.origin)
    }
    
    // -------------------------------------
    /// Provides thin border around the tool tip.
    private class BorderedView: NSView
    {
        override func draw(_ dirtyRect: NSRect)
        {
            super.draw(dirtyRect)
            
            guard let context = NSGraphicsContext.current?.cgContext else {
                return
            }
            
            context.setStrokeColor(NSColor.black.cgColor)
            context.stroke(self.frame, width: 2)
        }
    }
}
