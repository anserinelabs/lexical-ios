/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import Lexical
import XCTest

extension NodeType {
  static let testWideDecorator = NodeType(rawValue: "testWideDecorator")
}

/// A decorator as wide as the editor, so it can never share a line with text and
/// always wraps onto one of its own -- a GIF, in practice.
final class TestWideDecoratorNode: DecoratorNode {
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
    return CGSize(width: textViewWidth, height: 200)
  }
}

final class TextViewTests: XCTestCase {

  // MARK: - Caret line affinity

  /// Builds `paragraph["HELLO", <wide decorator>]` in a laid-out view. The
  /// decorator cannot fit after the text, so it wraps onto a line of its own and
  /// the caret at index 5 sits exactly on the boundary.
  private func makeViewWithTextThenWideDecorator() throws -> LexicalView {
    let view = LexicalView(
      editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    try view.editor.registerNode(nodeType: .testWideDecorator, class: TestWideDecoratorNode.self)
    view.frame = CGRect(x: 0, y: 0, width: 320, height: 600)

    try view.editor.update {
      guard let root = getRoot(), let paragraph = root.getFirstChild() as? ParagraphNode else {
        XCTFail("expected the initial empty paragraph")
        return
      }
      let text = TextNode()
      try text.setText("HELLO")
      try paragraph.append([text])
      try paragraph.append([TestWideDecoratorNode()])
    }

    view.setNeedsLayout()
    view.layoutIfNeeded()
    view.textView.layoutManager.ensureLayout(for: view.textView.textContainer)
    return view
  }

  /// The caret in front of a wrapped decorator belongs to the end of the text
  /// before it. Resolved forwards, it lands at the decorator's left edge -- for a
  /// GIF, a whole GIF height below the text being typed, which the text view then
  /// scrolls to.
  func testCaretInFrontOfAWrappedDecoratorBelongsToTheTextLine() throws {
    let textView = try makeViewWithTextThenWideDecorator().textView
    XCTAssertEqual(textView.textStorage.string, "HELLO\u{fffc}", "text then the decorator")

    let decoratorIndex = 5
    XCTAssertTrue(
      textView.caretBelongsToPreviousLine(at: decoratorIndex),
      "the caret in front of the wrapped decorator belongs to the text's line")

    // The decorator really is on a line of its own below the text.
    let decoratorGlyph = textView.layoutManager.glyphIndexForCharacter(at: decoratorIndex)
    let decoratorLine = textView.layoutManager.lineFragmentRect(
      forGlyphAt: decoratorGlyph, effectiveRange: nil)
    let textLine = textView.layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
    XCTAssertGreaterThan(decoratorLine.minY, textLine.minY, "the decorator should have wrapped")

    guard
      let caretPosition = textView.position(from: textView.beginningOfDocument, offset: decoratorIndex),
      let startPosition = textView.position(from: textView.beginningOfDocument, offset: 0)
    else {
      XCTFail("expected text positions")
      return
    }

    let caret = textView.caretRect(for: caretPosition)
    XCTAssertLessThan(caret.minY, decoratorLine.minY, "the caret should be drawn above the decorator")
    XCTAssertGreaterThan(
      caret.minX, textView.caretRect(for: startPosition).minX,
      "the caret should be at the end of the text, not the start of the decorator's line")
  }

  /// Only a decorator's line. Inside the text there is no ambiguity to resolve.
  func testCaretInsideTextDoesNotMoveLine() throws {
    let textView = try makeViewWithTextThenWideDecorator().textView
    XCTAssertFalse(textView.caretBelongsToPreviousLine(at: 2))
  }

  /// And not a wrap in ordinary prose: the caret belongs where it was put, and
  /// the two candidate positions are only a line apart.
  func testCaretAtAProseWrapDoesNotMoveLine() throws {
    let view = LexicalView(
      editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    view.frame = CGRect(x: 0, y: 0, width: 320, height: 600)

    try view.editor.update {
      guard let root = getRoot(), let paragraph = root.getFirstChild() as? ParagraphNode else {
        XCTFail("expected the initial empty paragraph")
        return
      }
      let text = TextNode()
      try text.setText(String(repeating: "wrapping words ", count: 12))
      try paragraph.append([text])
    }

    view.setNeedsLayout()
    view.layoutIfNeeded()
    let textView = view.textView
    textView.layoutManager.ensureLayout(for: textView.textContainer)

    var firstLineGlyphs = NSRange()
    _ = textView.layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: &firstLineGlyphs)
    XCTAssertLessThan(
      NSMaxRange(firstLineGlyphs), textView.textStorage.length, "the text should have wrapped")

    let secondLineStart = textView.layoutManager.characterIndexForGlyph(
      at: NSMaxRange(firstLineGlyphs))
    XCTAssertFalse(textView.caretBelongsToPreviousLine(at: secondLineStart))
  }

  func testInitialise() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView
    XCTAssertTrue(textView.textStorage is TextStorage)
    XCTAssertTrue(textView.layoutManager is LayoutManager)
    XCTAssertNotNil(textView.editor)
  }

  func testGetNativeSelection() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor
    let textView = view.textView

    // Note that modifying the text view like this will break the reconciler. That's OK in this test
    // as it doesn't run the reconciler!

    textView.text = "Hello world"
    textView.isUpdatingNativeSelection = true // disable the selection feeding back to Lexical -- in this case we _just_ want a native selection
    textView.selectedRange = NSRange(location: 1, length: 4)
    textView.isUpdatingNativeSelection = false
    XCTAssertEqual(textView.selectedRange.location, 1, "Selection range should be 1")
    XCTAssertEqual(textView.selectedRange.length, 4, "Selection length should be 4")

    let selection = editor.getNativeSelection()
    guard let range = selection.range else {
      XCTFail("selection should have range")
      return
    }
    XCTAssertEqual(range.location, 1, "Fetched native selection range should be 1")
    XCTAssertEqual(range.length, 4, "Fetched native selection length should be 4")
    XCTAssertNotNil(selection.opaqueRange)
  }

  func testMoveNativeSelection() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor
    let textView = view.textView

    textView.text = "Hello world"
    textView.isUpdatingNativeSelection = true
    textView.selectedRange = NSRange(location: 1, length: 4)
    textView.isUpdatingNativeSelection = false

    let selection = editor.getNativeSelection()
    guard let range = selection.range else {
      XCTFail("selection should have range")
      return
    }
    XCTAssertEqual(range.location, 1)
    XCTAssertEqual(range.length, 4)

    editor.moveNativeSelection(type: .extend, direction: .backward, granularity: .character)

    let modifiedSelection = editor.getNativeSelection()
    guard let modifiedRange = modifiedSelection.range else {
      XCTFail("selection should have range")
      return
    }
    XCTAssertEqual(modifiedRange.location, 0)
    XCTAssertEqual(modifiedRange.length, 5)
  }

  func testUpdateNativeSelection() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView

    try textView.editor.update {
      createExampleNodeTree()
    }

    try textView.editor.getEditorState().read {
      let selection = RangeSelection(
        anchor: Point(key: "1", offset: 1, type: .text),
        focus: Point(key: "2", offset: 3, type: .text),
        format: TextFormat())

      try textView.updateNativeSelection(from: selection)
      XCTAssertEqual(textView.selectedRange.location, 1)
      XCTAssertEqual(textView.selectedRange.length, 8)

      let selection2 = RangeSelection(
        anchor: Point(key: "7", offset: 0, type: .element),
        focus: Point(key: "7", offset: 1, type: .element),
        format: TextFormat())

      try textView.updateNativeSelection(from: selection2)
      XCTAssertEqual(textView.selectedRange.location, 52)
      XCTAssertEqual(textView.selectedRange.length, 11)
    }
  }

  func testInsertTextUITextInputMethodWithNewLine() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView

    try textView.editor.update {
      guard let rootNode = getActiveEditorState()?.getRootNode(), let paragraphNode = rootNode.getFirstChild() as? ParagraphNode else {
        XCTFail("No root node")
        return
      }
      let textNode = TextNode()
      try textNode.setText("Hello world")
      try paragraphNode.append([textNode])
      let anchor = createPoint(key: "1", offset: 11, type: .text)
      let focus = createPoint(key: "1", offset: 11, type: .text)
      textView.editor.getEditorState().selection = RangeSelection(anchor: anchor, focus: focus, format: TextFormat())
    }

    textView.selectedRange = NSRange(location: 11, length: 0)

    textView.insertText("\n")
    XCTAssertEqual(textView.text, "Hello world\n", "Should have inserted character in non-controlled mode")
    if let newParagraphNode = getNodeByKey(key: "2") as? ParagraphNode {
      XCTAssertEqual(newParagraphNode.key, "2")
      XCTAssertEqual(newParagraphNode.parent, kRootNodeKey)
      XCTAssertEqual(newParagraphNode.getChildren(), [])
    }

    textView.insertText("Hey")
    XCTAssertEqual(textView.text, "Hello world\nHey", "Should have inserted character in controller mode")
    if let newTextNode = getNodeByKey(key: "3") as? TextNode {
      XCTAssertEqual(newTextNode.key, "3")
      XCTAssertEqual(newTextNode.parent, "2")
      XCTAssertEqual(newTextNode.getTextPart(), "Hey")
    }

    guard let selection = textView.editor.getEditorState().selection as? RangeSelection else {
      XCTFail("Expected range selection")
      return
    }
    XCTAssertEqual(selection.anchor.key, "3")
    XCTAssertEqual(selection.focus.key, "3")
    XCTAssertEqual(selection.anchor.offset, 3)
    XCTAssertEqual(selection.focus.offset, 3)
    XCTAssertEqual(selection.anchor.type, .text)
  }

  // Test disabled due to iOS 16 UIPasteboard restrictions. I can't figure out a workaround right now. @amyworrall
  //  func testCut() throws {
  //    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  //    let textView = view.textView
  //
  //    textView.insertText("Hello world")
  //    let anchor = createPoint(key: "1", offset: 6, type: .text)
  //    let focus = createPoint(key: "1", offset: 11, type: .text)
  //    textView.editor.getEditorState().selection = RangeSelection(anchor: anchor, focus: focus, format: TextFormat())
  //
  //    textView.cut(nil)
  //
  //    try textView.editor.update {
  //      let itemSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["x-lexical-nodes"])
  //      guard let data = UIPasteboard.general.data(forPasteboardType: "x-lexical-nodes", inItemSet: itemSet)?.last else {
  //        print("No data on pasteboard")
  //        return
  //      }
  //
  //      let json = try JSONDecoder().decode(SerializedNodeArray.self, from: data)
  //      if let node = json.nodeArray.first as? TextNode {
  //        let text = node.getText_dangerousPropertyAccess()
  //        XCTAssertEqual(String(describing: text), "world")
  //      } else {
  //        XCTFail("First (only) node in nodeArray was not TextNode")
  //      }
  //    }
  //  }

  // Test disabled due to iOS 16 UIPasteboard restrictions. I can't figure out a workaround right now. @amyworrall
  //  func testCopy() throws {
  //    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  //    let textView = view.textView
  //
  //    textView.insertText("Hello world")
  //    let anchor = createPoint(key: "1", offset: 6, type: .text)
  //    let focus = createPoint(key: "1", offset: 11, type: .text)
  //    textView.editor.getEditorState().selection = RangeSelection(anchor: anchor, focus: focus, format: TextFormat())
  //
  //    textView.copy(nil)
  //
  //    try textView.editor.update {
  //      let itemSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["x-lexical-nodes"])
  //      guard let data = UIPasteboard.general.data(forPasteboardType: "x-lexical-nodes", inItemSet: itemSet)?.last else {
  //        print("No data on pasteboard")
  //        return
  //      }
  //
  //      let json = try JSONDecoder().decode(SerializedNodeArray.self, from: data)
  //      if let node = json.nodeArray.first as? TextNode {
  //        let text = node.getText_dangerousPropertyAccess()
  //        XCTAssertEqual(String(describing: text), "world")
  //      } else {
  //        XCTFail("First (only) node in nodeArray was not TextNode")
  //      }
  //    }
  //  }

  func testInsertPlainText() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView

    textView.insertText("Hello world")
    let anchor = createPoint(key: "1", offset: 11, type: .text)
    let focus = createPoint(key: "1", offset: 11, type: .text)
    textView.editor.getEditorState().selection = RangeSelection(anchor: anchor, focus: focus, format: TextFormat())

    guard let selection = textView.editor.getEditorState().selection as? RangeSelection else {
      XCTFail("Need selection")
      return
    }

    try textView.editor.update {
      let text = "Text\nText"

      try insertPlainText(selection: selection, text: text)
    }

    try textView.editor.update {
      let nodemap = textView.editor.getEditorState().nodeMap
      print(nodemap)
      XCTAssertTrue((nodemap["0"] as? ParagraphNode)?.children.count == 1)
      XCTAssertTrue((nodemap["1"] as? TextNode)?.getTextPart() == "Hello worldText")
      XCTAssertTrue((nodemap["3"] as? TextNode)?.getTextPart() == "Text")
      XCTAssertTrue((nodemap["4"] as? ParagraphNode)?.children.count == 1)
    }
  }

  func testInsertPlainTextWithinternalNewlines() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView

    textView.insertText("Hello world")
    let anchor = createPoint(key: "1", offset: 11, type: .text)
    let focus = createPoint(key: "1", offset: 11, type: .text)
    textView.editor.getEditorState().selection = RangeSelection(anchor: anchor, focus: focus, format: TextFormat())

    guard let selection = textView.editor.getEditorState().selection as? RangeSelection else {
      XCTFail("Need selection")
      return
    }

    try textView.editor.update {
      let text = "Text\n\n\n\nText"

      try insertPlainText(selection: selection, text: text)
    }

    try textView.editor.update {
      let nodemap = textView.editor.getEditorState().nodeMap
      print(nodemap)
      XCTAssertTrue((nodemap["0"] as? ParagraphNode)?.children.count == 1)
      XCTAssertTrue((nodemap["1"] as? TextNode)?.getTextPart() == "Hello worldText")
      XCTAssertTrue((nodemap["4"] as? ParagraphNode)?.children.isEmpty ?? false)
      XCTAssertTrue((nodemap["6"] as? ParagraphNode)?.children.isEmpty ?? false)
      XCTAssertTrue((nodemap["8"] as? ParagraphNode)?.children.isEmpty ?? false)
      XCTAssertTrue((nodemap["10"] as? ParagraphNode)?.children.count == 1)
      XCTAssertTrue((nodemap["9"] as? TextNode)?.getTextPart() == "Text")
    }
  }

  func testInsertRTF() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView

    textView.insertText("Hello world")
    let anchor = createPoint(key: "1", offset: 11, type: .text)
    let focus = createPoint(key: "1", offset: 11, type: .text)
    textView.editor.getEditorState().selection = RangeSelection(anchor: anchor, focus: focus, format: TextFormat())

    guard let selection = textView.editor.getEditorState().selection as? RangeSelection else {
      XCTFail("Need selection")
      return
    }

    try textView.editor.update {
      let text = NSMutableAttributedString(string: "Test\nText")
      text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single, range: NSRange(location: 0, length: text.length))

      try insertRTF(selection: selection, attributedString: text)
    }

    try textView.editor.update {
      let nodemap = textView.editor.getEditorState().nodeMap
      print(nodemap)
      XCTAssertTrue((nodemap["0"] as? ParagraphNode)?.children.count == 2)
      XCTAssertTrue((nodemap["1"] as? TextNode)?.getTextPart() == "Hello world")
      XCTAssertTrue((nodemap["2"] as? TextNode)?.getTextPart() == "Test")
      XCTAssertTrue((nodemap["2"] as? TextNode)?.format.underline ?? false)
      XCTAssertTrue((nodemap["3"] as? TextNode)?.getTextPart() == "Text")
      XCTAssertTrue((nodemap["3"] as? TextNode)?.format.underline ?? false)
      XCTAssertTrue((nodemap["4"] as? ParagraphNode)?.children.count == 1)
    }
  }

  func testShowPlaceholderTextWithPlaceholderLabel() {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView
    textView.setPlaceholderText("Enter Text", textColor: .lightGray, font: .systemFont(ofSize: 8))

    if let label = textView.subviews.first(where: { $0 is UILabel }) as? UILabel {
      XCTAssertTrue(!label.isHidden)
    }
  }

  func testShowPlaceholderTextWithPlaceholderLabelHidden() {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView

    textView.setPlaceholderText("Enter Text", textColor: .lightGray, font: .systemFont(ofSize: 8))
    textView.insertText("hello")
    textView.showPlaceholderText()

    if let label = textView.subviews.first(where: { $0 is UILabel }) as? UILabel {
      XCTAssertTrue(label.isHidden, "\(label)")
    }
  }

  func testShowPlaceholderLabelOnDeletion() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView
    textView.setPlaceholderText("Aa", textColor: .lightGray, font: .systemFont(ofSize: 8))

    textView.insertText("H")
    textView.showPlaceholderText()
    if let label = textView.subviews.first(where: { $0 is UILabel }) as? UILabel {
      XCTAssertTrue(label.isHidden)
    }

    try textView.editor.update {
      try onDeleteBackwardsFromUITextView(editor: textView.editor)
    }
    if let label = textView.subviews.first(where: { $0 is UILabel }) as? UILabel {
      XCTAssertTrue(!label.isHidden)
    }
  }

  func testBasicInsertStrategy() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView
    textView.insertText("hello")
    textView.insertText("\n")
    textView.insertText("world")
    let nodeMap = textView.editor.getEditorState().nodeMap

    guard let selection = textView.editor.getEditorState().selection as? RangeSelection else {
      XCTFail("Need selection")
      return
    }

    try textView.editor.update {
      let nodes = nodeMap.compactMap({ $0.value }).filter({ isElementNode(node: $0) })
      _ = try insertGeneratedNodes(editor: textView.editor, nodes: nodes, selection: selection)
      XCTAssertTrue(nodes.count == 3)
      XCTAssertTrue((nodeMap["0"] as? ParagraphNode)?.children.count == 1)
    }
  }

  func testInsertEllipsis() throws {
    // iOS handles an ellipsis autocorrection by calling replaceCharacters(in:with:) on the text storage twice, each
    // time replacing one of the previous dots with empty string, then finally calling insertText on the text view
    // to insert the ellipsis. Let's simulate this.

    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let textView = view.textView
    guard let textStorage = textView.textStorage as? TextStorage else {
      XCTFail()
      return
    }

    textView.insertText("He..")
    textStorage.replaceCharacters(in: NSRange(location: 3, length: 1), with: NSAttributedString(string: ""))
    textStorage.replaceCharacters(in: NSRange(location: 2, length: 1), with: NSAttributedString(string: ""))
    textView.insertText("…")
    XCTAssertEqual(textView.text, "He…")
  }
}
