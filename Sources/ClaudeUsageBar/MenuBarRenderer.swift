import AppKit

enum MenuBarRenderer {
    // Bar colors
    private static let greenColor = NSColor(red: 0.35, green: 0.78, blue: 0.24, alpha: 1.0)
    private static let yellowColor = NSColor(red: 0.92, green: 0.75, blue: 0.15, alpha: 1.0)
    private static let grayColor = NSColor(white: 0.55, alpha: 1.0)
    private static let dimColor = NSColor(white: 0.25, alpha: 1.0)

    // Layout constants (in points)
    private static let imageWidth: CGFloat = 80
    private static let imageHeight: CGFloat = 18
    private static let barHeight: CGFloat = 7
    private static let barGap: CGFloat = 1
    private static let barCornerRadius: CGFloat = 2

    static func render(usage: UsageData) -> NSImage {
        let size = NSSize(width: imageWidth, height: imageHeight)
        let image = NSImage(size: size, flipped: false) { rect in
            // Bottom bar: 7-day weekly (y=0)
            drawBar(
                in: NSRect(x: 0, y: 0, width: rect.width, height: barHeight),
                timePercent: usage.sevenDay.timeElapsedPercent,
                usagePercent: usage.sevenDay.utilization
            )

            // Top bar: 5-hour session (y = barHeight + gap)
            drawBar(
                in: NSRect(x: 0, y: barHeight + barGap, width: rect.width, height: barHeight),
                timePercent: usage.fiveHour.timeElapsedPercent,
                usagePercent: usage.fiveHour.utilization
            )

            return true
        }
        image.isTemplate = false
        return image
    }

    static func renderError() -> NSImage {
        let size = NSSize(width: imageWidth, height: imageHeight)
        let image = NSImage(size: size, flipped: false) { rect in
            let errorColor = NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.6)

            let bottomRect = NSRect(x: 0, y: 0, width: rect.width, height: barHeight)
            let bottomPath = NSBezierPath(roundedRect: bottomRect, xRadius: barCornerRadius, yRadius: barCornerRadius)
            errorColor.setFill()
            bottomPath.fill()

            let topRect = NSRect(x: 0, y: barHeight + barGap, width: rect.width, height: barHeight)
            let topPath = NSBezierPath(roundedRect: topRect, xRadius: barCornerRadius, yRadius: barCornerRadius)
            errorColor.setFill()
            topPath.fill()

            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawBar(in rect: NSRect, timePercent: Double, usagePercent: Double) {
        let timeFraction = min(max(timePercent / 100.0, 0), 1.0)
        let usageFraction = min(max(usagePercent / 100.0, 0), 1.0)

        // Full background (dim) with rounded corners
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: barCornerRadius, yRadius: barCornerRadius)
        dimColor.setFill()
        bgPath.fill()

        // Clip to rounded rect for inner fills
        NSGraphicsContext.current?.saveGraphicsState()
        bgPath.addClip()

        if usageFraction <= timeFraction {
            // On track: gray for time elapsed, green for usage consumed
            if timeFraction > 0 {
                let timeRect = NSRect(x: rect.origin.x, y: rect.origin.y,
                                      width: rect.width * timeFraction, height: rect.height)
                grayColor.setFill()
                NSBezierPath(rect: timeRect).fill()
            }
            if usageFraction > 0 {
                let usageRect = NSRect(x: rect.origin.x, y: rect.origin.y,
                                       width: rect.width * usageFraction, height: rect.height)
                greenColor.setFill()
                NSBezierPath(rect: usageRect).fill()
            }
        } else {
            // Over budget: yellow for usage consumed
            if usageFraction > 0 {
                let usageRect = NSRect(x: rect.origin.x, y: rect.origin.y,
                                       width: rect.width * usageFraction, height: rect.height)
                yellowColor.setFill()
                NSBezierPath(rect: usageRect).fill()
            }
        }

        NSGraphicsContext.current?.restoreGraphicsState()
    }
}
