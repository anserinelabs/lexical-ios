/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

public class QuoteNode: ElementNode {
  override public init() {
    super.init()
  }

  override public required init(_ key: NodeKey?) {
    super.init(key)
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }

  override public class func getType() -> NodeType {
    return .quote
  }

  override public func clone() -> Self {
    Self(key)
  }

  override public func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    theme.quote ?? [:]
  }

  override public func getIndent() -> Int {
    1
  }

  // MARK: - Mutation

  override open func insertNewAfter(selection: RangeSelection?) throws -> Node? {
    let newBlock = createParagraphNode()
    let direction = getDirection()
    try newBlock.setDirection(direction: direction)

    try insertAfter(nodeToInsert: newBlock)

    return newBlock
  }

  override public func collapseAtStart(selection: RangeSelection) throws -> Bool {
    let paragraph = createParagraphNode()
    let children = getChildren()
    try children.forEach({ try paragraph.append([$0]) })
    try replace(replaceWith: paragraph)

    return true
  }
}

@objc public class QuoteCustomDrawingAttributes: NSObject {
  public init(barColor: UIColor, barWidth: CGFloat, rounded: Bool, barInsets: UIEdgeInsets) {
    self.barColor = barColor
    self.barWidth = barWidth
    self.rounded = rounded
    self.barInsets = barInsets
    self.allBarXPositions = []
  }

  /// Internal initialiser used when a paragraph is nested inside multiple QuoteNodes.
  /// `allBarXPositions` holds one x-offset (relative to `rect.minX`) per ancestor quote
  /// level, ordered outermost-first (e.g. `[0, 40, 80]` for three levels of nesting).
  /// When non-empty this replaces the single-bar behaviour driven by `barInsets.left`.
  internal init(barColor: UIColor, barWidth: CGFloat, rounded: Bool, barInsets: UIEdgeInsets, allBarXPositions: [CGFloat]) {
    self.barColor = barColor
    self.barWidth = barWidth
    self.rounded = rounded
    self.barInsets = barInsets
    self.allBarXPositions = allBarXPositions
  }

  let barColor: UIColor
  let barWidth: CGFloat
  let rounded: Bool
  let barInsets: UIEdgeInsets
  /// X-offsets for every bar that should be drawn (one per nesting level).
  /// Empty means "draw a single bar using `barInsets.left`" (backward-compatible default).
  internal let allBarXPositions: [CGFloat]

  override public func isEqual(_ object: Any?) -> Bool {
    let lhs = self
    guard let rhs = object as? QuoteCustomDrawingAttributes else {
      return false
    }
    return lhs.barColor == rhs.barColor && lhs.barWidth == rhs.barWidth && lhs.rounded == rhs.rounded && lhs.barInsets == rhs.barInsets && lhs.allBarXPositions == rhs.allBarXPositions
  }
}

public extension NSAttributedString.Key {
  static let quoteCustomDrawing: NSAttributedString.Key = .init(rawValue: "quoteCustomDrawing")
}

extension QuoteNode {
  internal static var quoteBackgroundDrawing: CustomDrawingHandler {
    get {
      return { attributeKey, attributeValue, layoutManager, attributeRunCharacterRange, granularityExpandedCharacterRange, glyphRange, rect, firstLineFragment in
        guard let attributeValue = attributeValue as? QuoteCustomDrawingAttributes else { return }

        // Build the list of x-positions at which to draw bars.
        // For a non-nested quote `allBarXPositions` is empty, so we fall back to the
        // original single-bar behaviour (barInsets.left relative to rect.minX).
        // For nested quotes each entry is an absolute offset from rect.minX, and
        // barInsets.left is added on top of it so the configurable gap is preserved.
        let barXPositions: [CGFloat] = attributeValue.allBarXPositions.isEmpty
          ? [attributeValue.barInsets.left]
          : attributeValue.allBarXPositions.map { $0 + attributeValue.barInsets.left }

        attributeValue.barColor.setFill()

        for xPos in barXPositions {
          let barRect = CGRect(
            x: rect.minX + xPos,
            y: rect.minY + attributeValue.barInsets.top,
            width: attributeValue.barWidth,
            height: rect.height - attributeValue.barInsets.top - attributeValue.barInsets.bottom)

          if attributeValue.rounded {
            let bezierPath = UIBezierPath(roundedRect: barRect, cornerRadius: attributeValue.barWidth / 2)
            bezierPath.fill()
          } else {
            UIRectFill(barRect)
          }
        }
      }
    }
  }
}
