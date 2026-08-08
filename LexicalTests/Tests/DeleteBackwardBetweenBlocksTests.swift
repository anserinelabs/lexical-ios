/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import Lexical
import XCTest

extension NodeType {
  static let testBlockDecorator = NodeType(rawValue: "testBlockDecorator")
}

/// A decorator that lives as a direct child of root, rather than inline inside a paragraph. The
/// caret either side of one is an element point on root, which is the position these tests are
/// about.
final class TestBlockDecoratorNode: DecoratorNode {
  override init() {
    super.init(nil)
  }

  public required init(_ key: NodeKey?) {
    super.init(key)
  }

  required init(from decoder: Decoder) throws {
    fatalError("init(from:) has not been implemented")
  }

  override public func clone() -> Self {
    Self(key)
  }

  override public func createView() -> UIImageView {
    return UIImageView()
  }

  override public func decorate(view: UIView) {}

  override public func sizeForDecoratorView(textViewWidth: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGSize {
    return CGSize(width: 100, height: 100)
  }
}

final class DeleteBackwardBetweenBlocksTests: XCTestCase {

  /// Backspacing with the caret between an empty paragraph and a block decorator should take the
  /// empty paragraph out, and nothing else. Because there is no text node at the caret, this used
  /// to go through removeText(), which resolves the end of the selection to the whole previous
  /// block and removes it -- along with a selection left pointing into it.
  func testBackspaceBetweenEmptyBlockAndDecoratorRemovesTheEmptyBlock() throws {
    let view = try makeViewWithBlockDecorator()
    let editor = view.editor
    let textView = view.textView

    try insertDecoratorAsOwnBlock(editor)
    XCTAssertEqual(editor.textStorage?.string, "\n\u{fffc}\n", "an empty paragraph, the decorator, and a trailing paragraph")

    // Caret between the empty paragraph and the decorator.
    textView.selectedRange = NSRange(location: 1, length: 0)
    textView.deleteBackward()

    XCTAssertEqual(editor.textStorage?.string, "\u{fffc}\n", "the empty paragraph should be gone")
    try editor.read {
      XCTAssertEqual(getRoot()?.getChildrenSize(), 2, "the decorator and the trailing paragraph should remain")
      XCTAssertTrue(getRoot()?.getFirstChild() is TestBlockDecoratorNode, "the decorator should now be first")
    }
    assertEditorIsConsistent(editor)
  }

  /// The same caret position, but with text in the block before the decorator: backspace should
  /// delete one character of it, not the whole block.
  func testBackspaceBetweenTextBlockAndDecoratorDeletesOneCharacter() throws {
    let view = try makeViewWithBlockDecorator()
    let editor = view.editor
    let textView = view.textView

    textView.insertText("abc")
    try insertDecoratorAsOwnBlock(editor)
    XCTAssertEqual(editor.textStorage?.string, "abc\n\u{fffc}\n")

    // Caret between the paragraph and the decorator.
    textView.selectedRange = NSRange(location: 4, length: 0)
    textView.deleteBackward()

    XCTAssertEqual(editor.textStorage?.string, "ab\n\u{fffc}\n", "only the last character should be gone")
    try editor.read {
      XCTAssertEqual(getRoot()?.getChildrenSize(), 3, "all three blocks should remain")
    }
    assertEditorIsConsistent(editor)
  }

  /// A blank line between two paragraphs of text, with no decorator anywhere. The caret is an
  /// element point here too -- an empty paragraph has no text node to sit in -- but it is inside
  /// the blank paragraph rather than between blocks, so backspace should merge: the blank line
  /// goes, the caret lands at the end of the text above it.
  func testBackspaceOnABlankLineBetweenTwoParagraphsRemovesTheBlankLine() throws {
    let view = try makeViewWithBlockDecorator()
    let editor = view.editor
    let textView = view.textView

    textView.insertText("ABC")
    try editor.update {
      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("expected a range selection")
        return
      }
      try selection.insertParagraph()
      try selection.insertParagraph()
      try selection.insertText("DEF")
    }
    XCTAssertEqual(editor.textStorage?.string, "ABC\n\nDEF")

    // Caret on the blank line.
    textView.selectedRange = NSRange(location: 4, length: 0)
    textView.deleteBackward()

    XCTAssertEqual(editor.textStorage?.string, "ABC\nDEF", "only the blank line should be gone")
    try editor.read {
      let selection = try getSelection() as? RangeSelection
      XCTAssertEqual(selection?.anchor.offset, 3, "the caret should be after the C")
    }
    assertEditorIsConsistent(editor)
  }

  // MARK: - Helpers

  private func makeViewWithBlockDecorator() throws -> LexicalView {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    try view.editor.registerNode(nodeType: .testBlockDecorator, class: TestBlockDecoratorNode.self)
    return view
  }

  /// Inserts the decorator as a direct child of root, after the block the caret is in, with a
  /// trailing paragraph for the caret to land in.
  private func insertDecoratorAsOwnBlock(_ editor: Editor) throws {
    try editor.update {
      guard let selection = try getSelection() as? RangeSelection,
        let anchorNode = try? selection.anchor.getNode(),
        let rootNode = getRoot()
      else {
        XCTFail("expected a range selection")
        return
      }

      var targetBlock = anchorNode
      while let parent = targetBlock.getParent(), parent !== rootNode {
        targetBlock = parent
      }

      let decorator = TestBlockDecoratorNode()
      try targetBlock.insertAfter(nodeToInsert: decorator)

      let trailing = ParagraphNode()
      try decorator.insertAfter(nodeToInsert: trailing)
      _ = try trailing.selectEnd()
    }
  }

  private func assertEditorIsConsistent(
    _ editor: Editor, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertNil(editor.testing_getPendingEditorState(), "the update should have committed", file: file, line: line)
    XCTAssertTrue(editor.dirtyNodes.isEmpty, "the update should have cleared its dirty nodes", file: file, line: line)
    XCTAssertEqual(editor.dirtyType, .noDirtyNodes, "the update should have cleared its dirty type", file: file, line: line)

    guard let textStorage = editor.textStorage else {
      XCTFail("no text storage", file: file, line: line)
      return
    }
    try? editor.read {
      for (key, item) in editor.rangeCache {
        guard let node = getNodeByKey(key: key), node.isAttached() else { continue }
        XCTAssertLessThanOrEqual(
          item.entireRange().upperBound, textStorage.length,
          "cached range for \(key) runs past the end of the text storage",
          file: file, line: line)
      }
      XCTAssertEqual(
        editor.rangeCache[kRootNodeKey]?.entireRange().length, textStorage.length,
        "root's cached range should span the text storage",
        file: file, line: line)

      if let selection = try getSelection() as? RangeSelection {
        XCTAssertNotNil(try? selection.anchor.getNode(), "the caret should be on a node that still exists", file: file, line: line)
      }
    }
  }
}
