/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

public class ParagraphNode: ElementNode {
  override public init() {
    super.init()
  }

  override required init(_ key: NodeKey?) {
    super.init(key)
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }

  override public class func getType() -> NodeType {
    return .paragraph
  }

  override public func clone() -> Self {
    Self(key)
  }

  override public func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    if let paragraph = theme.paragraph {
      return paragraph
    }

    return [:]
  }

  override public func getBlockLevelAttributes(theme: Theme) -> BlockLevelAttributes? {
    let attributes = theme.getBlockLevelAttributes(type)
    guard let centerParagraph = theme.centerParagraph else {
      return attributes
    }
    // Always give an alignment, never nil: the paragraph style is copied forward from the text storage,
    // so a paragraph that stops being centered has to be set back to natural explicitly.
    let base = attributes ?? BlockLevelAttributes(marginTop: 0, marginBottom: 0, paddingTop: 0, paddingBottom: 0)
    return base.withAlignment(centerParagraph(self) ? .center : .natural)
  }

  override open func insertNewAfter(selection: RangeSelection?) throws -> ParagraphNode? {
    let newElement = createParagraphNode()
    let direction = getDirection()
    do {
      try newElement.setDirection(direction: direction)
      try insertAfter(nodeToInsert: newElement)
    } catch {
      throw LexicalError.internal("Error in insertNewAfter: \(error.localizedDescription)")
    }
    return newElement
  }

  public func createParagraphNode() -> ParagraphNode {
    return ParagraphNode()
  }
}
