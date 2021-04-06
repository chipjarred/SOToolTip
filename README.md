# macOS ToolTips with Any View for Content

This repo is basically my answer to [this stackoverflow question](https://stackoverflow.com/q/66932781/15280114) about how to implement tool tips with styled text or even arbitrary content on macOS.  When I started to answer,  I realized that the result would be something I might want to use myself, so it ended up being a much bigger thing that I originally intended... and much bigger than SO allows for their answers.  I had to trim it down quite a lot in order to post it, and therefore had omit a lot of key details.  So what follows is my full original version of the answer.  Of course, this repo has all of the source code ready to compile.

To build it and see the tool tip work, clone this repo from the command line:

```bash
git clone https://github.com/chipjarred/SOToolTip.git
```

Then open the  `SoToolTip` Xcode project.

That version has all the source code directly in the project.

I've also extracted the code into a Swift package: [https://github.com/chipjarred/CustomToolTip.git](https://github.com/chipjarred/CustomToolTip.git).  

To build a verson of this repo that uses the `CustomToolTip` package 
```bash
git checkout UsePackage
```

## My Original Stack Overflow Answer

Stephan's answer prompted me to do my own implementation of tool tips.   My solution produces tool tips that look like the standard tool tips, except you can put any view you like inside them, so not just styled text, but images... you could even use a WebKit view, if you wanted to. 

[![Screenshot][1]][1]

Obviously it doesn't make sense to put some kinds of views in it.  Anything that only makes sense with user interaction would be meaningless since the tool tip would disappear as soon as they move the mouse cursor to interact with it... though that would be good April Fools joke.

Before I get to my solution, I want to mention that there is another way to make Stephan's solution a little easier to use, which is to use the "decorator" pattern by subclassing `NSView` to wrap another view.  Your wrapper is the part that hooks into to the tool tips, and handles the tracking areas.  Just make sure you forward those calls to the wrapped view too, in case it also has tracking areas (perhaps it changes the cursor or something, like `NSTextView` does.)  Using a decorator means you don't subclass every view... just put the view you want to add a tool tip for inside of a `ToolTippableView` or whatever you decide to call it.  I don't think you'll need to override all `NSView` methods as long as you wrap the view by adding it to your `subviews`.   The view heirarchy and responder chain should take care of dispatching the events and messages you're not interested in to the subview.  You should only need to forward the ones you handle for the tool tips (`mouseEntered`, `mouseExited`, etc...)


## My solution
However, I went to an evil extreme... and spent way more time on it than I probably should have, but it seemed like something I might want to use at some point.  I swizzled ("monkey patched") `NSVIew` methods to handle custom tool tips, which combined with an extension on `NSView` means I don't have subclass anything to add custom tool tips, I can just write:

```swift
myView.customToolTip = myCustomToolTipContent
```

where `myCustomToolTipContent` is whatever  `NSView` I want to display in the tool tip.


### The Tool Tip itself
The main thing is the tool tip itself.  It's just a window.  It sizes itself to whatever content you put in it, so make sure you've set your tip content's view `frame` to the size you want before setting `customToolTip`.  Here's the tool tip window code:

```swift
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
     direction is right-to-left, the preferred location is below and shift to
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
```

The tool tip window is the easy part.   This implementation positions the window relative to its owner (the view to which the tool tip is attached) while also avoiding drawing offscreen.  I don't handle the pathalogical case where the tool tip is so large that it can't fit onto screen without obscuring the thing it's a tool tip for.  Nor do I handle the case where the thing you're attaching the tool tip to is so large that even though the tool tip itself is a reasonable size, it can't go outside of the area occupied by the view to which it's attached.  That case shouldn't be too hard to handle.  I just didn't do it.  I do handle responding to the currently set layout direction.

If you want to incorporate it into another solution, the code to show the tool tip is

```swift
let toolTipWindow = CustomToolTipWindow.makeAndShow(toolTipView: toolTipView, for: ownerView)
```

where `toolTipView` is the view to be displayed in the tool tip.  `ownerView` is the view to which you're attaching the tool tip.  You'll need to store `toolTipWindow` somehere, for example in Stephan's `ToolTipHandler`.

To hide the tool tip:

```swift
toolTipWindow.orderOut(self)
```

or just set the last reference you keep to it to `nil`. 

I think that gives you everything you need to incorporate it into another solution if you like.


### Tool Tip handling code

As a small convenience, I use this extension on `NSTrackingArea`

```swift
// -------------------------------------
/*
 Convenice extension for updating a tracking area's `rect` property.
 */
fileprivate extension NSTrackingArea
{
    func updateRect(with newRect: NSRect) -> NSTrackingArea
    {
        return NSTrackingArea(
            rect: newRect,
            options: options,
            owner: owner,
            userInfo: nil
        )
    }
}
```

Since I'm swizzling `NSVew` (actually its subclasses as you add tool tips), I don't have a `ToolTipHandler`-like object.  I just put it all in an extension on `NSView` and use global storage.  To do that I have a `ToolTipControl` struct and a `ToolTipControls` wrapper around an array of them:

```swift
// -------------------------------------
/**
 Data structure to hold information used for holding the tool tip and for
 controlling when to show or hide it.
 */
fileprivate struct ToolTipControl
{
    /**
     `Date` when mouse was last moved within the tracking area.  Should be
     `nil` when the mouse is not in the tracking area.
     */
    var mouseEntered: Date?
    
    /// View to which the custom tool tip is attached
    weak var onwerView: NSView?
    
    /// The content view of the tool tip
    var toolTipView: NSView?
    
    /// `true` when the tool tip is currently displayed.  `false` otherwise.
    var isVisible: Bool = false
    
    /**
     The tool tip's window.  Should be `nil` when the tool tip is not being
     shown.
     */
    var toolTipWindow: NSWindow? = nil
    
    init(
        mouseEntered: Date? = nil,
        hostView: NSView,
        toolTipView: NSView? = nil)
    {
        self.mouseEntered = mouseEntered
        self.onwerView = hostView
        self.toolTipView = toolTipView
    }
}

// -------------------------------------
/**
 Data structure for holding `ToolTipControl` instances.  Since we only need
 one collection of them for the application, all its methods and properties
 are `static`.
 */
fileprivate struct ToolTipControls
{
    private static var controlsLock = os_unfair_lock()
    private static var controls: [ToolTipControl] = []
    
    // -------------------------------------
    static func getControl(for hostView: NSView) -> ToolTipControl? {
        withLock { return controls.first { $0.onwerView === hostView } }
    }
    
    // -------------------------------------
    static func setControl(for hostView: NSView, to control: ToolTipControl)
    {
        withLock
        {
            if let i = index(for: hostView) { controls[i] = control }
            else { controls.append(control) }
        }
    }
    
    // -------------------------------------
    static func removeControl(for hostView: NSView)
    {
        withLock
        {
            controls.removeAll {
                $0.onwerView == nil || $0.onwerView === hostView
            }
        }
    }
    
    // -------------------------------------
    private static func index(for hostView: NSView) -> Int? {
        controls.firstIndex { $0.onwerView == hostView }
    }
    
    // -------------------------------------
    private static func withLock<R>(_ block: () -> R) -> R
    {
        os_unfair_lock_lock(&controlsLock)
        defer { os_unfair_lock_unlock(&controlsLock) }
        
        return block()
    }
    
    // -------------------------------------
    private init() { } // prevent instances
}
```

These are `fileprivate` in the same file as my extension on `NSView`.  I also have to have a way to differentiate between my tracking areas and any others the view might have.  They have a  `userInfo` dictionary that I use for that.  I don't need to store different individualized information in each one, so I just make a global one I reuse.

```swift
fileprivate let bundleID = Bundle.main.bundleIdentifier ?? "com.CustomToolTips"
fileprivate let toolTipKeyTag = bundleID + "CustomToolTips"
fileprivate let customToolTipTag = [toolTipKeyTag: true]
```

And I need a dispatch queue:

```swift
fileprivate let dispatchQueue = DispatchQueue(
    label: toolTipKeyTag,
    qos: .background
)
```

### NSView extension
My `NSView` extension has a lot in it, the vast majority of which is `private`, including swizzled methods, so I'll break it into pieces

In order to be able to attach a custom tool tip as easily as you do for a standard tool tip, I provide a computed property.  In addition to actually setting the tool tip view, it also checks to see if the `Self` (that is the particular subclass of `NSView`) has already been swizzled, and does that if it hasn't been, and it's adds the mouse tracking area.

```swift
// -------------------------------------
/**
 Adds a custom tool tip to the receiver.  If set to `nil`, the custom tool
 tip is removed.
 
 This view's `frame.size` will determine the size of the tool tip window
 */
public var customToolTip: NSView?
{
    get { toolTipControl?.toolTipView }
    set
    {
        Self.initializeCustomToolTips()

        if let newValue = newValue
        {
            addCustomToolTipTrackingArea()
            var current = toolTipControl ?? ToolTipControl(hostView: self)
            current.toolTipView = newValue
            toolTipControl = current
        }
        else { toolTipControl = nil }
    }
}

// -------------------------------------
/**
 Adds a tracking area encompassing the receiver's bounds that will be used
 for tracking the mouse for determining when to show the tool tip.  If a
 tacking area already exists for the receiver, it is removed before the
 new tracking area is set. This method should only be called when a new
 tool tip is attached to the receiver.
 */
private func addCustomToolTipTrackingArea()
{
    if let ta = trackingAreaForCustomToolTip {
        removeTrackingArea(ta)
    }
    addTrackingArea(
        NSTrackingArea(
            rect: self.bounds,
            options:
                [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: customToolTipTag
        )
    )
}

// -------------------------------------
/**
 Returns the custom tool tip tracking area for the receiver.
 */
private var trackingAreaForCustomToolTip: NSTrackingArea?
{
    trackingAreas.first {
        $0.owner === self && $0.userInfo?[toolTipKeyTag] != nil
    }
}
```

`trackingAreaForCustomToolTip` is where I use the global tag to sort my tracking area from any others that the view might have.

Of course, I also have to implement `updateTrackingAreas` and this where we start to see some of evidence of swizzling.

```swift
// -------------------------------------
/**
 Updates the custom tooltip tracking aread when `updateTrackingAreas` is
 called.
 */
@objc private func updateTrackingAreas_CustomToolTip()
{
    if let ta = trackingAreaForCustomToolTip
    {
        removeTrackingArea(ta)
        addTrackingArea(ta.updateRect(with: self.bounds))
    }
    else { addCustomToolTipTrackingArea() }
    
    callReplacedMethod(for: #selector(self.updateTrackingAreas))
}
```
The method isn't called `updateTrackingAreas` because I'm not overriding it in the usual sense. I actually replace the implementation of the current class's `updateTrackingAreas` with the implementation of my `updateTrackingAreas_CustomToolTip`, saving off the original implementation so I can forward to it.  `callReplacedMethod` where I do that forwarding.  If you look into swizzling, you find lots of examples where people call what looks like an infinite recursion, but isn't because they *exchange* method implementations.   That works most of the time, but it can subtly mess up the underlying Objective-C messaging because the selector used to calling the old method is no longer the original selector.   The way I've done it preserves the selector, which makes it less fragile when something depends on the actual selector remaining the same.  Anyway more on swizzling later.  For now, think of `callReplacedMethod` as similar to calling `super` if I were doing this by subclassing.

Then there's scheduling to show the tool tip.  I do this kind of similarly to Stephan, but I wanted the behavior that the tool tip isn't shown until the mouse stops moving for a certain delay.  I currently use 1 second.  

As I'm writing this, I just noticed that I do deviate from the standard behavior once the tool tip is displayed.   The standard behavior is that once shown, it continues to show the tool tip even if the mouse is moved as long as it remains in the tracking area.  So once shown the standard behavior doesn't hide the tool tip until the mouse leaves the tracking area.   I hide it as soon as you move the mouse.  Doing it the standard way is actually simpler, but the way I do it would allow for the tool tip to be shown over large views (for example a `NSTextView` for a large document) where it has to actually be in the same area of the screen that its owner occupies.   I don't currently position the tool tip that way, but if I do, you'd want any mouse movement to hide the tool tip, otherwise the tool tip would obscure part of what the user needs to interact with.

Anyway, here's what that scheduling code looks like
```swift
// -------------------------------------
/**
 Controls how many seconds the mouse must be motionless within the tracking
 area in order to show the tool tip.
 */
private var customToolTipDelay: TimeInterval { 1 /* seconds */ }

// -------------------------------------
/**
 Schedules to potentially show the tool tip after `delay` seconds.
 
 The tool tip is not *necessarily* shown as a result of calling this method,
 but rather this method begins a sequence of chained asynchronous calls that
 determine whether or not to display the tool tip based on whether the tool
 tip is already visible, and how long it's been since the mouse was moved
 withn the tracking area.
 
 - Parameters:
    - delay: Number of seconds to wait until determining whether or not to
        display the tool tip
    - mouseEntered: Set to `true` when calling from `mouseEntered`,
        otherwise set to `false`
 */
private func scheduleShowToolTip(delay: TimeInterval, mouseEntered: Bool)
{
    guard var control = toolTipControl else { return }
    
    if mouseEntered
    {
        control.mouseEntered = Date()
        toolTipControl = control
    }

    let asyncDelay: DispatchTimeInterval = .milliseconds(Int(delay * 1000))
    dispatchQueue.asyncAfter(deadline: .now() + asyncDelay) {
        [weak self] in self?.scheduledShowToolTip()
    }
}

// -------------------------------------
/**
 Display the tool tip now, *if* the mouse is in the tracking area and has
 not moved for at least `customToolTipDelay` seconds.  Otherwise, schedule
 to check again after a short delay.
 */
private func scheduledShowToolTip()
{
    let repeatDelay: TimeInterval = 0.1
    /*
     control.mouseEntered is set to nil when exiting the tracking area,
     so this guard terminates the async chain
     */
    guard let control = self.toolTipControl,
          let mouseEntered = control.mouseEntered
    else { return }
    
    if control.isVisible {
        scheduleShowToolTip(delay: repeatDelay, mouseEntered: false)
    }
    else if Date().timeIntervalSince(mouseEntered) >= customToolTipDelay
    {
        DispatchQueue.main.async
        { [weak self] in
            if let self = self
            {
                self.showToolTip()
                self.scheduleShowToolTip(
                    delay: repeatDelay,
                    mouseEntered: false
                )
            }
        }
    }
    else { scheduleShowToolTip(delay: repeatDelay, mouseEntered: false) }
}
```
Earlier I gave the code for how to show and hide the tool tip window.  Here are the functions where that code lives with its interaction with `toolTipControl` to control the corresponding loop.

```swift
// -------------------------------------
/**
 Displays the tool tip now.
 */
private func showToolTip()
{
    guard var control = toolTipControl else { return }
    defer
    {
        control.mouseEntered = Date.distantPast
        toolTipControl = control
    }
    
    guard let toolTipView = control.toolTipView else
    {
        control.isVisible = false
        return
    }
    
    if !control.isVisible
    {
        control.isVisible = true
        control.toolTipWindow = CustomToolTipWindow.makeAndShow(
            toolTipView: toolTipView,
            for: self
        )
    }
}

// -------------------------------------
/**
 Hides the tool tip now.
 */
private func hideToolTip(exitTracking: Bool)
{
    guard var control = toolTipControl else { return }
    
    control.mouseEntered = exitTracking ? nil : Date()
    control.isVisible = false
    let window = control.toolTipWindow
    
    control.toolTipWindow = nil
    window?.orderOut(self)
    control.toolTipWindow = nil
    
    toolTipControl = control

    print("Hiding tool tip")
}
```

The only thing that's left before getting to the actual swizzling is handling the mouse movements.  I do this with `mouseEntered`, `mouseExited` and `mouseMoved`, or rather, their swizzled implementations:

```swift
// -------------------------------------
/**
 Schedules potentially showing the tool tip when the `mouseEntered` is
 called.
 */
@objc private func mouseEntered_CustomToolTip(with event: NSEvent)
{
    scheduleShowToolTip(delay: customToolTipDelay, mouseEntered: true)
    
    callReplacedEventMethod(
        for: #selector(self.mouseEntered(with:)),
        with: event
    )
}

// -------------------------------------
/**
 Hides the tool tip if it's visible when `mouseExited` is called, cancelling
 further `async` chaining that checks to show it.
 */
@objc private func mouseExited_CustomToolTip(with event: NSEvent)
{
    hideToolTip(exitTracking: true)

    callReplacedEventMethod(
        for: #selector(self.mouseExited(with:)),
        with: event
    )
}

// -------------------------------------
/**
 Hides the tool tip if it's visible when `mousedMoved` is called, and
 resets the time for it to be displayed again.
 */
@objc private func mouseMoved_CustomToolTip(with event: NSEvent)
{
    hideToolTip(exitTracking: false)
    
    callReplacedEventMethod(
        for: #selector(self.mouseMoved(with:)),
        with: event
    )
}
```

Now for the swizzling.  This was by far the thing that took the longest, and there was much wailing and gnashing of teeth before getting it to work.  Swift isn't designed for swizzling, and it's only possible here because Cocoa classes are all Objective-C when it comes down to it.  Bascially you have to make calls into the Objective-C runtime that normally Swift (or Objective-C) handles for you.

In  the code that follows you'll note that I refer to `Self` and not `NSView`.  That's because for purposes of swizzling, in the extension `Self` evaluates to be the dynamic type of the subclass using the `NSView` extension, whereas using `NSView` would be specifically `NSView`.   I don't want to burden every possible `NSView` subclass with custom tool tip support, just the ones that I specifically set custom tool tips for.  So even though this is an extension on `NSView`, we're actually swizzling `NSButton` or `NSTextView` or whatever other specific view type the object that's being given a custom tool tip happens to be.


Earlier in the `customToolTip` setter, there were references to `isSwizzled` and  `initializeCustomToolTips`. 

Here are their implementations:

```swift
// -------------------------------------
/**
 Swizzle methods if they have not already been swizzed for the current
 `NSView` subclass.
 */
private static func initializeCustomToolTips() {
    if !isSwizzled { swizzleCustomToolTipMethods() }
}

// -------------------------------------
/**
 `true` if the current `NSView` subclass has already been swizzled;
 otherwise, `false`
 */
private static var isSwizzled: Bool
{
    return nil != Self.implementation(
        for: #selector(self.mouseMoved(with:))
    )
}

// -------------------------------------
/**
 Replace the implementatons of certain methods in the current subclass of
 `NSView` with custom implementations to implement custom tool tips.
 */
private static func swizzleCustomToolTipMethods()
{
    replaceMethod(
        #selector(self.updateTrackingAreas),
        with: #selector(self.updateTrackingAreas_CustomToolTip)
    )
    replaceMethod(
        #selector(self.mouseEntered(with:)),
        with: #selector(self.mouseEntered_CustomToolTip(with:))
    )
    replaceMethod(
        #selector(self.mouseExited(with:)),
        with: #selector(self.mouseExited_CustomToolTip(with:))
    )
    replaceMethod(
        #selector(self.mouseMoved(with:)),
        with: #selector(self.mouseMoved_CustomToolTip(with:))
    )
}
```

Originally I thought I'd do more in `initializeCustomToolTips`, but that turned out not to be the case.  It just forwards to `swizzleCustomToolTipMethods`.

`replaceMethod` is a method I've added to an extension on `NSObject`.  I could have put it in the extension for `NSView` for this particular use, but putting it in `NSObject` will allow me to more easily swizzle non-view types, like maybe `NSText`, if ever have a reason to do that.

 `isSwizzled` refers to `Self.implementation(for:)` which is also defined in my `NSObject` extension.  As you'll see, `implementation(for:)` is a method for getting the previous implemention for a selector, which is to say, the implemenation before I swizzled it.  If I haven't swizzled it, it will return `nil`.  So check if `Self` has already been swizzled, I just need to see if any one of the methods I swizzle has previous implementation.  If it does, then we don't need to swizzle again.
 
 Before we leave `NSView`, let's look at `callReplacedMethod(for:with:)`

```swift
// -------------------------------------
/**
 Call the old implementation that takes an `NSEvent` parameter, if it
 exists for a `selector` that has been replaced by swizzling.
 
 - Parameters:
    - selector: The `selector` whose previous implementation is to be called
    - event: The `NSEvent` to be forwarded to the previous implementation.
 */
private func callReplacedEventMethod(
    for selector: Selector,
    with event: NSEvent)
{
    if let imp = Self.implementation(for: selector) {
        callIMP_withObject(imp, self, selector, event)
    }
}
```

It retrieves the previous implementation, which has type `IMP` (not my choice, that's Objective-C).  If it exists, then we need to cal that old implemenation.   `IMP` is essentially a C function pointer for a function that takes a reference to the object being called, so `self` in this case, and the `selector`, as well as whatever parameters.  However, even though I've gotten casting an `IMP` to a C function to work before in Swift, in this context it always crashed, so these methods call some small Objective-C helper functions, `callIMP_...`, to do the actual forwarding.

The swizzled method for `updateTrackingAreas` used a different forwarding call, `callReplacedMethod(for:)`, because unlike the `mouse...` methods, it doesn't take a parameter.  It looks similar:

```swift
// -------------------------------------
/**
 Call the old implementation that takes no parameters, if it exists for a
 `selector` that has been replaced by swizzling.
 
 - Parameter selector: The `selector` whose previous implementation is to
    be called
 */
private func callReplacedMethod(for selector: Selector)
{
    if let imp = Self.implementation(for: selector) {
        callIMP(imp, self, selector)
    }
}
```

### NSObject Extension
OK, so now for the extension on `NSObject`.  That's where I put the code that actually does the swizzling.

In order to be able to forward to the previous method implementations, I needed a way to store them.  I solved that the same way I did for `NSView`.  I used `fileprivate` global storage:

```swift
// -------------------------------------
/**
 Data structure to use a `Dictionary.Key` for mapping a class and swizzled
 selector to its previous implementation
 */
fileprivate struct IMPMapKey: Hashable
{
    let classType: AnyClass
    let selector: Selector
    
    static func == (left: Self, right: Self) -> Bool
    {
        return left.classType == right.classType
            && left.selector == right.selector
    }
    
    func hash(into hasher: inout Hasher)
    {
        hasher.combine(classType.description())
        hasher.combine(selector)
    }
}

/**
 `Dictionary` mapping class-selector combinations to their corresponding
 previous implementation.
 */
fileprivate var implementationMap: [IMPMapKey: IMP] = [:]
```

And in the `NSObject` extension: 

```swift
// -------------------------------------
/**
 Get the previous implementation for `selector` or `nil` if `selector` has
 no previous implementation (possible it wasn't swizzled).
 */
static func implementation(for selector: Selector) -> IMP?
{
    let key = IMPMapKey(classType: Self.self, selector: selector)
    return implementationMap[key]
}
```

Now let's look at `replaceMethod(_:with:)`.  This is where we start to get into the Objective-C runtime calls.  You can tell which those are by the presence of underscores in the names.

```swift
// -------------------------------------
/**
 Replace the implementation of `oldSelector` with the implementation of
 `newSelector`.  It's up to the new implemenatoin to forward to the old
 one.
 
 If `oldSelector` is not implemented,, it will be added using
 `newSelector`'s implementation.
 
 - Parameters:
    - oldSelector: `Selector` for existing method whose implementation is
        to be replaced.
    - newSelector: `Selector` of the method whose implementaton will be
        used to replace `oldSelector`'s implementation.
 */
static func replaceMethod(
    _ oldSelector: Selector,
    with newSelector: Selector)
{
    guard let newMethod = instanceMethod(for: newSelector) else {
        fatalError("Failed to get implementation for \(newSelector)")
    }
    
    let newImp = method_getImplementation(newMethod)
    if let oldImp = replaceSelectorImplementation(
        selector: oldSelector,
        newImplementation: newImp)
    {
        let key = IMPMapKey(classType: Self.self, selector: oldSelector)
        implementationMap[key] = oldImp
    }
}
```
The idea is to first get a `METHOD` from the class we're swizzling, which is what `class_getInstanceMethod()` returns, which I'm calling from `instanceMethod(for:)`.  This is different from, `IMP`, which is the implementation for that method.  `METHOD` is a `struct` that describes things about the method.  `class_getInstanceMethod()` will return a `METHOD` if the class has the specified selector defined.  So if we were to call it for an `NSResponder` that isn't an `NSView` requesting the `METHOD` for `#selector(NSView.viewDidMoveToWindow)` it would return `nil`, but would return a `METHOD` for `#selector(NSView.mouseDown(with:))` because `mouseDown(with:)` is defined in `NSResponder`.  For `#selector`, the class or instance preceding the method name only matters for the sake of type checking.  Once the compiler has made a `Selector` from it, it only refers to the method name.

In `replaceMethod`, I'm using this to get the implementation for the my customized methods, so that I can replace the existing implementations with them.

`replaceSelectorImplementation` is my own method and we'll get to it shortly, but it does what it says on the tin.  It replaces the implementation for the method named by the `selector` you pass to it with the implemenation you also pass to it.  It also returns whatever previous implementation there may have been.

If it does return a previous implementation, that's when I store it my global `Dictionary` so that I have a way to forward to it.

```swift
// -------------------------------------
/**
 Replaces the implementation of the method specified by `Selector` in the receiving `class` with `newImplementation`.
 
 - Note: `IMP` is an Objective-C runtime type.  It is an `OpaquePointer` to
    a C function.
 
 - Parameters:
    - selector: The `Selector` whose corresponding method's implementation
        will be replaced by `newImplementation`.
    - newImplementation: The implmenetation, specified as an `IMP`, to
        replace the implementation for `Selector`.
 - Returns: The previous implementation of `Selector` or `nil` if there
    isn't one.
 */
private static func replaceSelectorImplementation(
    selector: Selector,
    newImplementation: IMP) -> IMP?
{
    print("Swizzling \(Self.self).\(selector)")
    guard self.superclass() != nil else {
        fatalError("Swizzling NSObject itself - don't do that")
    }
    
    guard let method = instanceMethod(for: selector) else {
        fatalError("Failed to get implementation for \(selector)")
    }
    
    /*
     If the method already exists, we can just replace it, because we'll
     chain to its old implementaton.  If it doesn't exist, then we need to
     add one to call super first
     */
    let types = method_getTypeEncoding(method)
    addMethodThatCallsSuper(Self.self, selector, types)
    let oldImp = class_replaceMethod(
        Self.self,
        selector,
        newImplementation,
        types
    )

    return oldImp
}
```
So the first thing I do in `replaceSelectorImplementation` is make sure we have a superclass.  If we don't, that means we're trying to swizzle `NSObject` itself.   Technically you can do that, but it just seems like a bad idea, and any behavior I can imagine I'd want to swizzle is in a subclass of it.

Then I get the `METHOD` for the `Selector` I'm replacing.  `method_getTypeEncoding()` gets a C string whose characters describe the parameter types and return type for the method.  We don't need to do anything with it other than pass it on to other Obj-C runtime functions.

The thinking behind `addMethodThatCallsSuper`, which is another of my own Obj-C runtime wrappers, is that under normal circumstances, if you were to call an Obj-C method that the object's class doesn't define, the runtime would crawl up the inheritance hierarchy, which has the effect of calling `super`.  But we're about to mess with the natural order of things.  When we "replace" the method in such a case, it actually adds the method, but then we will have screwed things up, because we'll get `nil` for the old implementation, since there wasn't one, so we won't have anyhing to chain to, which means the call chain will end at our replacement implementation.  What should happen is after our method is called, it should continue to crawl up the inheritance hierarchy, or at least behave as if it did.  So if there is no current implementation, what we want to do is add one that expliclty calls `super`,  then replace that one.  That way we have something to chain to that continues the crawl up the hierarchy.  That's what `addMethodThatCallsSuper` does.  

As for the implementation of `addMethodThatCallsSuper`, it's one of the things I had to do in Objective-C.

There are just some things I couldn't get to work in Swift, so I had to delegate them to Objective-C functions, like those we saw earlier for forwarding calls.   To add a method that calls  `super`  I have to use `objc_msgSendSuper` in it's implementation, but it's completely unavailable in Swift.

But that wasn't the only problem.  I also have to make a `objc_super`, which is simple 2-member struct, but one of those member fields is an `Unmanaged<AnyObject>`.  The *compiler crashes* with `Abort 6` when trying to set it.   That should never ever happen.  If we do something illegal, the compiler should emit an error, but it should *not* crash.  The only output I had to work with to figure out what was happening was an uncaught C++ exception stack trace, which would be totally useful if I were debugging the Swift compiler's C++ code.  It was much less useful for fixing the Swift code I'm using the compiler for.  I did manage to work out which line of code the compiler was choking on, but after 6 hours of trying to find some formulation to express it in a way that wouldn't cause the compiler to die on me, I finally said, "Screw it.  I'll do it in Objective-C."

Using even just one line of C or Objective-C means you need a bridging header, and make sure you `#import` the Objective-C `.h` file for your `.m` file in it.

My bridging header looked like this:

```objc
#import "swizzleHelper.h"
```

I know, it's bit anticlimatic.

This is `swizzleHelper.h`:

```objc
#ifndef swizzleHelper_h
#define swizzleHelper_h

#import <objc/runtime.h>
#import <objc/NSObject.h>

// -------------------------------------
/**
 @abstract Add an instance method to `cls` that forwards to it's `super`
 
 @discussion The method will be added only if it doesn't already exist.
 
 @param cls Class to which to add the instance method to call to super
 @param selector selector for the method to add the call to super
 @param types Objective-C type encoding string to used idefining the method.
 
 @returns `TRUE` if the method was added., or `FALSE` if it wasn't.
 */
BOOL addMethodThatCallsSuper(
    Class  _Nonnull __unsafe_unretained cls,
    SEL _Nonnull selector,
    const char* _Nullable types);


// -------------------------------------
/*!
 @abstract Call the functoin specified by `imp` passing the `receiver` and
 `selector`with no other parameters.
 @param imp the implementation function to be called
 @param receiver the receiver of the implementatoin call
 @param selector the selector to be used for the implemenation call.
 */
void callIMP(
    IMP _Nonnull imp,
    _Nonnull __unsafe_unretained id receiver,
    _Nonnull SEL selector);

// -------------------------------------
/*!
 @abstract Call the functoin specified by `imp` passing the `receiver`,
 `selector`, and a pointer to an `NSObject`.
 @param imp the implementation function to be called
 @param receiver the receiver of the implementatoin call
 @param selector the selector to be used for the implemenation call.
 @param param the `NSObject` to pass as a parameter in the implementation call.
 */
void callIMP_withObject(
     IMP _Nonnull imp,
     __unsafe_unretained id _Nonnull receiver,
     _Nonnull SEL selector,
     NSObject* _Nullable param);

// -------------------------------------
/*!
 @abstract Call the functoin specified by `imp` passing the `receiver`,
 `selector`, and a void pointer
 @param imp the implementation function to be called
 @param receiver the receiver of the implementatoin call
 @param selector the selector to be used for the implemenation call.
 @param param the `void *` to pass as a parameter in the implementation call.
 */
void callIMP_withPointer(
    IMP _Nonnull imp,
    __unsafe_unretained id _Nonnull receiver,
    _Nonnull SEL selector,
    const void * _Nullable param);


#endif /* swizzleHelper_h */
```

And `swizzleHelper.m`:

```objc
#import <Foundation/Foundation.h>
#import "swizzleHelper.h"
#import <objc/message.h>

/*
 All of the callIMP_... functions are implemented in Objective-C instead of
 Swift because I could not get Swift to properly cast them `IMP` to the correct
 type of function, resulting in crashing when calling them.
 
 The same is true for forwardToSuperFromSwizzle, but it had the additional
 problem that when making the objc_super structure, the Swift *compiler* would
 crash trying to assign its `receiver` member field, which translates to Swift
 as an Unmanaged<AnyObject>.  That seems to have been a problem in a @_cdecl
 context.

 In addition the call to objc_msgSendSuper in forwardToSuperFromSwizzle can't
 be done at all in Swift, because it's simply not available... at all.  The
 only way to call it is from Objective-C.
 */

// -------------------------------------
void callIMP(
     IMP _Nonnull imp,
     _Nonnull __unsafe_unretained id receiver,
     _Nonnull SEL selector)
{
    typedef void (*funcPtr)(__unsafe_unretained id, SEL);
    ((funcPtr)imp)(receiver, selector);
}

// -------------------------------------
void callIMP_withObject(
     IMP _Nonnull imp,
     __unsafe_unretained id _Nonnull receiver,
     _Nonnull SEL selector,
     NSObject* _Nullable param)
{
    callIMP_withPointer(
        imp,
        receiver,
        selector,
        (const void*) CFBridgingRetain(param)
    );
}

// -------------------------------------
void callIMP_withPointer(
     IMP _Nonnull imp,
     __unsafe_unretained id _Nonnull receiver,
     _Nonnull SEL selector,
     const void * _Nullable param)
{
    typedef void (*funcPtr)(__unsafe_unretained id, SEL, const void *param);
    ((funcPtr)imp)(receiver, selector, param);
}

// -------------------------------------
id forwardToSuperFromSwizzle(
   _Nonnull __unsafe_unretained id receiver,
    SEL selector,
    va_list args)
{
    typedef id (*funcPtr)(struct objc_super *, SEL, va_list);
    struct objc_super superInfo = {
        .receiver = receiver,
        .super_class = class_getSuperclass(object_getClass(receiver))
    };

    return ((funcPtr)objc_msgSendSuper)(&superInfo, selector, args);
}

// -------------------------------------
BOOL addMethodThatCallsSuper(
     Class  _Nonnull __unsafe_unretained cls,
     SEL _Nonnull selector,
     const char* _Nullable types)
{
    return class_addMethod(cls, selector, (IMP)forwardToSuperFromSwizzle, types);
}
```

That's all of the Objective-C.  I wanted to do it 100% in Swift, but since that wasn't possible, I think that's an acceptably minimal amount of Objective-C.

That puts everything in place, so now you just have to use it.  I was just using Xcode's default Cocoa App template, so it uses a Storyboard (which normally I prefer not to).  I just added an ordinary `NSButton` in the Storyboard.  That means I don't start with a reference to it anywhere in the source code, so in `ViewController`, for the sake of building an example I just do a quick recursive search through the view hierarchy looking for an `NSButton`. 

```swift
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
```
And I need to make a tool tip view.  I wanted to demonstrate using more than just text, so I hacked this together

```swift

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
```

And then in `viewDidLoad()`

```swift
override func viewDidLoad() 
{
    super.viewDidLoad()
    findPushButton(in: view)?.customToolTip = makeCustomToolTip()
}
```
[1]: https://i.stack.imgur.com/zuv1Q.png
