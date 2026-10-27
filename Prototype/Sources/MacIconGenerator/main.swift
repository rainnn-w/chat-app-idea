import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
enum MacIconGenerator {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write("Usage: MacIconGenerator <output.png>\n".data(using: .utf8)!)
            exit(2)
        }

        let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let size = 1024
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        drawIcon(in: context, size: CGFloat(size))

        guard let image = context.makeImage() else {
            throw NSError(domain: "MacIconGenerator", code: 1)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "MacIconGenerator", code: 2)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "MacIconGenerator", code: 3)
        }
    }

    private static func drawIcon(in context: CGContext, size: CGFloat) {
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))

        let background = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let radius = size * 0.225
        let backgroundPath = CGPath(
            roundedRect: background,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        context.saveGState()
        context.addPath(backgroundPath)
        context.clip()

        drawLinearGradient(
            in: context,
            rect: background,
            colors: [
                CGColor(red: 0.98, green: 0.46, blue: 0.54, alpha: 1),
                CGColor(red: 0.66, green: 0.38, blue: 0.94, alpha: 1),
                CGColor(red: 0.24, green: 0.56, blue: 0.98, alpha: 1)
            ],
            startPoint: CGPoint(x: 0, y: size),
            endPoint: CGPoint(x: size, y: 0)
        )

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
        context.fillEllipse(in: CGRect(x: size * 0.45, y: size * 0.55, width: size * 0.70, height: size * 0.70))
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
        context.setLineWidth(size * 0.012)
        context.strokeEllipse(in: CGRect(x: size * 0.56, y: size * 0.58, width: size * 0.48, height: size * 0.48))

        drawChatBubble(
            in: context,
            rect: CGRect(x: size * 0.14, y: size * 0.55, width: size * 0.48, height: size * 0.27),
            fill: CGColor(red: 1, green: 1, blue: 1, alpha: 0.22)
        )

        drawChatBubble(
            in: context,
            rect: CGRect(x: size * 0.33, y: size * 0.68, width: size * 0.52, height: size * 0.23),
            fill: CGColor(red: 1, green: 1, blue: 1, alpha: 0.30)
        )

        drawHeart(in: context, center: CGPoint(x: size * 0.50, y: size * 0.43), scale: size * 0.00095)
        context.restoreGState()
    }

    private static func drawLinearGradient(
        in context: CGContext,
        rect: CGRect,
        colors: [CGColor],
        startPoint: CGPoint,
        endPoint: CGPoint
    ) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            colors: colors as CFArray,
            locations: [0, 0.52, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
    }

    private static func drawChatBubble(in context: CGContext, rect: CGRect, fill: CGColor) {
        let path = CGMutablePath()
        let corner = rect.height * 0.35
        path.addRoundedRect(
            in: rect,
            cornerWidth: corner,
            cornerHeight: corner
        )
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY))
        path.closeSubpath()

        context.setFillColor(fill)
        context.addPath(path)
        context.fillPath()
    }

    private static func drawHeart(in context: CGContext, center: CGPoint, scale: CGFloat) {
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 0.96)
        context.setFillColor(white)

        let circleRadius: CGFloat = 86 * scale
        context.fillEllipse(in: CGRect(
            x: center.x - 88 * scale - circleRadius,
            y: center.y - 20 * scale - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        ))
        context.fillEllipse(in: CGRect(
            x: center.x + 88 * scale - circleRadius,
            y: center.y - 20 * scale - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        ))

        context.beginPath()
        context.move(to: CGPoint(x: center.x - 172 * scale, y: center.y - 10 * scale))
        context.addLine(to: CGPoint(x: center.x + 172 * scale, y: center.y - 10 * scale))
        context.addLine(to: CGPoint(x: center.x, y: center.y - 212 * scale))
        context.closePath()
        context.fillPath()
    }
}

