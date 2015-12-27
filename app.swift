#!/usr/bin/env xcrun swift
import Cocoa

class MyAppDelegate: NSObject, NSApplicationDelegate {
    let window = NSWindow()
    var didFinishLaunching: NSWindow -> () = { _ in () }
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        didFinishLaunching(window)
    }
}

public class App {
    private var application: NSApplication

    init(_ theApplication: NSApplication) {
        application = theApplication
    }

    func exit() {
        application.terminate(nil)
    }
}

public func app(title: String, width: Int = 400, height: Int = 200, rootView: App -> View) {
    let app = NSApplication.sharedApplication()
    let appDelegate = MyAppDelegate()
    app.setActivationPolicy(.Regular)
    let view = rootView(App(app))
    appDelegate.didFinishLaunching = { window in
        window.setContentSize(NSSize(width:width, height:height))
        window.styleMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
        window.opaque = false
        window.center()
        window.title = title
        window.contentView!.wantsLayer = true

        window.makeKeyAndOrderFront(window)
        let contentView = window.contentView!

        contentView.addSubview(view.rootView)
        if view.rootView.frame == CGRectZero {
            view.rootView.sizeToParent()
        }
        window.layoutIfNeeded()
        view.afterAdding()
        app.activateIgnoringOtherApps(true)
    }

    app.delegate = appDelegate
    app.run()
    print(view) // Make sure we keep a reference around
}

extension NSView {
    func sizeToParent() {
        frame = superview!.bounds
        autoresizingMask = NSAutoresizingMaskOptions([.ViewWidthSizable, .ViewMaxXMargin, .ViewMinYMargin, .ViewHeightSizable, .ViewMaxYMargin])
    }
}

public struct TextViewConfiguration {
    var text: String = ""
    var size: NSSize? = NSMakeSize(180,160)
    var origin: NSPoint? = NSMakePoint(20,10)
    var editable: Bool = false
    var selectable: Bool = true
}

public protocol View {
    var rootView: NSView { get }
    var afterAdding: () -> () { get }
}

public class TextView: View {
    public var rootView: NSView
    var textView: NSTextView
    public var afterAdding: () -> ()
    var text: String {
        get {
            return textView.string ?? ""
        }
        set { 
            textView.string = newValue
        }
    }
    init(rootView: NSView, textView: NSTextView, afterAdding: () -> () = { _ in () } ) {
        self.rootView = rootView
        self.afterAdding = afterAdding
        self.textView = textView
    }
}

public class SimpleView: View {
    public var rootView: NSView
    public var afterAdding: () -> ()
    var delegate: AnyObject?
    init(rootView: NSView, delegate: AnyObject? = nil, afterAdding: () -> () = { _ in () } ) {
        self.rootView = rootView
        self.delegate = delegate
        self.afterAdding = afterAdding
    }
}

public func textView(text: String, editable: Bool) -> TextView {
    var configuration = TextViewConfiguration()
    configuration.text = text
    configuration.editable = editable
    return textView(configuration)
}

public func textView(configuration: TextViewConfiguration) -> TextView {
    let scrollView = NSScrollView(frame: CGRectZero)
    scrollView.borderType = .NoBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    
    let ed = NSTextView(frame: CGRectZero)

    let afterAdding = {
        ed.frame = scrollView.bounds
        ed.minSize = scrollView.bounds.size
        ed.maxSize = NSSize(width: CGFloat.max, height: CGFloat.max)
        ed.string = configuration.text
        ed.editable = configuration.editable
        ed.selectable = configuration.selectable
        ed.verticallyResizable = true
        ed.horizontallyResizable = false
        ed.textContainer!.containerSize = NSSize(width: scrollView.bounds.size.width, height: CGFloat.max)
        ed.textContainer!.widthTracksTextView = true
        scrollView.documentView = ed
    }

    return TextView(rootView: scrollView, textView: ed, afterAdding: afterAdding)
}

class ButtonDelegate: NSObject {
    var callback: () -> ()
    init(_ callback: () -> ()) {
        self.callback = callback
    }
    @objc func buttonClicked() {
        callback()
    }
}

public func button(text: String, onClick: () -> ()) -> View {
    let button = NSButton(frame: CGRectZero)
    let delegate = ButtonDelegate(onClick)
    button.title = text
    button.target = delegate
    button.action = "buttonClicked"
    button.bezelStyle = .SmallSquareBezelStyle
    return SimpleView(rootView: button, delegate: delegate)
}

public func label(text: String) -> View {
    let field = NSTextField(frame: CGRectZero)
    field.bezeled = false
    field.drawsBackground = false
    field.editable = false
    field.selectable = false
    field.stringValue = text
    return SimpleView(rootView: field)
}

final class Box<A>: NSObject {
    var unbox: A
    init(_ value: A) { unbox = value }
}

public func stack(views: [View], orientation: NSUserInterfaceLayoutOrientation = .Vertical) -> View {
    let stackView = NSStackView(frame: CGRectZero)
    stackView.orientation = orientation
    stackView.autoresizingMask = NSAutoresizingMaskOptions([.ViewWidthSizable, .ViewHeightSizable])
    for view in views {
        stackView.addView(view.rootView, inGravity: .Top)
    }

    let afterAdding = {
        views.forEach { $0.afterAdding() }
    }
    return SimpleView(rootView: stackView, delegate: Box(views), afterAdding: afterAdding)
}

// TODO: left-hand side finder-like tree tructure
// TODO: toolbar at the top.
// Goal: build something like notes?

app("My app") { theApp in
    let text = Array(count: 3, repeatedValue: "Hello, world").joinWithSeparator("\n")
    let tv = textView(text, editable: true)
    let theButton = button("Hello") { tv.text += "\nHello!"}
    let buttons = stack([theButton, button("Exit", onClick: theApp.exit)], orientation: .Horizontal)
    return stack([label("Add some text"), tv, buttons])
}
