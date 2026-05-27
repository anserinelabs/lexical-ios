/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import Lexical
import XCTest

final class AttributesUtilsTests: XCTestCase {
  func testGetLexicalAttributes() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])

      let attributes = AttributeUtils.getLexicalAttributes(
        from: textNode,
        state: editorState,
        theme: editor.getTheme()
      )

      for attributeDict in attributes {
        if let font = attributeDict[.font] as? UIFont {
          XCTAssertTrue(font.familyName == "Helvetica", "Node font attribute is incorrect")
        }
      }
    }
  }

  private func firstFontInAttributedString(attrStr: NSAttributedString) -> UIFont {
    let font = attrStr.attribute(.font, at: 0, effectiveRange: nil)
    return font as? UIFont ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
  }

  func testattributedStringByAddingStyles() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])

      let attributedString = NSMutableAttributedString(string: textNode.getTextPart())

      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertTrue(font.familyName == "Helvetica", "TextNode's attributes should take priority over all parent node's attributes")
    }
  }

  func testApplyBoldStyles() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")
      textNode.format.bold = true

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])
      let attributedString = NSMutableAttributedString(string: textNode.getTextPart())
      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should contain the bold trait")

      textNode.format.bold = false
      // let attributedString = NSMutableAttributedString(string: textNode.getTextPart())
      let newStyledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let newFont = firstFontInAttributedString(attrStr: newStyledAttrStr)

      XCTAssertFalse(newFont.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should not contain the bold trait")
    }
  }

  func testApplyItalicStyles() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")
      textNode.format.italic = true

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])
      let attributedString = NSMutableAttributedString(string: textNode.getTextPart())
      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic), "Font should contain the italic trait")

      textNode.format.italic = false
      let newStyledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let newFont = firstFontInAttributedString(attrStr: newStyledAttrStr)

      XCTAssertFalse(newFont.fontDescriptor.symbolicTraits.contains(.traitItalic), "Font should not contain the italic trait")
    }
  }

  func testApplyBoldAndItalicStyles() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")
      textNode.format.bold = true
      textNode.format.italic = true

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])
      let attributedString = NSMutableAttributedString(string: textNode.getTextPart())
      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should contain the bold trait")
      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic), "Font should contain the italic trait")

      textNode.format.bold = false
      let newStyledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let newFont = firstFontInAttributedString(attrStr: newStyledAttrStr)

      XCTAssertFalse(newFont.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should not contain the bold trait")
      XCTAssertTrue(newFont.fontDescriptor.symbolicTraits.contains(.traitItalic), "Font should contain the italic trait")
    }
  }

  func testFontUpdate() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor
    try editor.update {
      let testAttributeNode = TestAttributesNode()

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([testAttributeNode])

      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])

      let attributedString = NSMutableAttributedString(string: "Hello World")
      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: testAttributeNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertEqual(font.familyName, "Arial", "Font attribute is incorrect")
      XCTAssertTrue(font.pointSize == 10, "Font size is incorrect")
      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should not contain the bold trait")
    }
  }

  func testThemeForRootNode() throws {
    let rootAttributes: [NSAttributedString.Key: Any] = [
      .fontFamily: "Arial",
      .fontSize: 18 as Float,
    ]

    let theme = Theme()
    theme.root = rootAttributes
    let view = LexicalView(editorConfig: EditorConfig(theme: theme, plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let paragraphNode = ParagraphNode()
      let textNode = TextNode()
      try textNode.setText("Testing Theme!")

      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])
    }

    let attributedString = view.textView.attributedText
    if let attribute = attributedString?.attribute(.font, at: 1, effectiveRange: nil) as? UIFont {
      XCTAssertEqual(attribute.familyName, "Arial")
      XCTAssertEqual(attribute.pointSize, 18)
    }
  }

  func testThemeForHeadingNode() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let headingNode = HeadingNode(tag: .h1)
      let textNode = TextNode()
      try textNode.setText("Testing HeadingNode!")

      try headingNode.append([textNode])
      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([headingNode])
    }

    let attributedString = view.textView.attributedText
    if let attribute = attributedString?.attribute(.font, at: 1, effectiveRange: nil) as? UIFont {
      XCTAssertEqual(attribute.familyName, "Helvetica")
      XCTAssertEqual(attribute.pointSize, 36)
    }
  }

  private func themeForBlockTests() -> Theme {
    let theme = Theme()
    theme.setBlockLevelAttributes(.code, value: BlockLevelAttributes(marginTop: 5, marginBottom: 3, paddingTop: 6, paddingBottom: 4))
    return theme
  }

  func testBlockLevelAttributesSimpleCase() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: themeForBlockTests(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let paragraphNode = ParagraphNode()
      let textNode = TextNode()
      try textNode.setText("Para1")
      try paragraphNode.append([textNode])

      let codeLine1 = TextNode(text: "line1")
      let lineBreak = LineBreakNode()
      let codeLine2 = TextNode(text: "line2")
      let codeNode = CodeNode()
      try codeNode.append([codeLine1, lineBreak, codeLine2])

      guard let rootNode = getRoot() else {
        XCTFail("should have root node")
        return
      }

      try rootNode.getChildren().forEach { node in
        try node.remove()
      }

      try rootNode.append([paragraphNode, codeNode])
    }

    guard let attributedString = view.textView.attributedText else {
      XCTFail("No attr string")
      return
    }
    XCTAssertEqual(attributedString.string, "Para1\nline1\nline2")

    // test that line1 gets the spacing before
    if let attribute = attributedString.attribute(.paragraphStyle, at: 6, effectiveRange: nil) as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 11, "Expected combination of paddingtop and margintop")
      XCTAssertEqual(attribute.paragraphSpacing, 0, "Expected no spacing after")
    } else {
      XCTFail("no para style")
    }
    // this is the first character of line2
    if let attribute = attributedString.attribute(.paragraphStyle, at: 12, effectiveRange: nil) as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 0, "Expected no spacing before")
      XCTAssertEqual(attribute.paragraphSpacing, 7, "Expected spacing after")
    } else {
      XCTFail("no para style")
    }
  }

  func testBlockLevelAttributesEmptyLineEndOfBlock() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: themeForBlockTests(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let paragraphNode = ParagraphNode()
      let textNode = TextNode()
      try textNode.setText("Para1")
      try paragraphNode.append([textNode])

      let codeLine1 = TextNode(text: "line1")
      let lineBreak = LineBreakNode()
      let codeNode = CodeNode()
      try codeNode.append([codeLine1, lineBreak])

      let paraNode2 = ParagraphNode()
      let textNode2 = TextNode(text: "text2")
      try paraNode2.append([textNode2])

      guard let rootNode = getRoot() else {
        XCTFail("should have root node")
        return
      }

      try rootNode.getChildren().forEach { node in
        try node.remove()
      }

      try rootNode.append([paragraphNode, codeNode, paraNode2])
    }

    guard let attributedString = view.textView.attributedText else {
      XCTFail("No attr string")
      return
    }
    XCTAssertEqual(attributedString.string, "Para1\nline1\n\ntext2")

    // test that line1 gets the spacing before
    if let attribute = attributedString.attribute(.paragraphStyle, at: 6, effectiveRange: nil) as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 11, "Expected combination of paddingtop and margintop")
      XCTAssertEqual(attribute.paragraphSpacing, 0, "Expected no spacing after")
    } else {
      XCTFail("no para style")
    }
    // this is a newline character that should contain the styling for the end of the code block
    if let attribute = attributedString.attribute(.paragraphStyle, at: 12, effectiveRange: nil) as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 0, "Expected no spacing before")
      XCTAssertEqual(attribute.paragraphSpacing, 7, "Expected spacing after")
    } else {
      XCTFail("no para style")
    }

    XCTAssertNil(view.textStorage.extraLineFragmentAttributes, "Should have no extra line fragment attributes due to not ending in newline")
  }

  func testBlockLevelAttributesEmptyLineEndOfDocument() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: themeForBlockTests(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let paragraphNode = ParagraphNode()
      let textNode = TextNode()
      try textNode.setText("Para1")
      try paragraphNode.append([textNode])

      let codeLine1 = TextNode(text: "line1")
      let lineBreak = LineBreakNode()
      let codeNode = CodeNode()
      try codeNode.append([codeLine1, lineBreak])

      guard let rootNode = getRoot() else {
        XCTFail("should have root node")
        return
      }

      try rootNode.getChildren().forEach { node in
        try node.remove()
      }

      try rootNode.append([paragraphNode, codeNode])
    }

    guard let attributedString = view.textView.attributedText else {
      XCTFail("No attr string")
      return
    }
    XCTAssertEqual(attributedString.string, "Para1\nline1\n")

    // test that line1 gets the spacing before
    if let attribute = attributedString.attribute(.paragraphStyle, at: 6, effectiveRange: nil) as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 11, "Expected combination of paddingtop and margintop")
      XCTAssertEqual(attribute.paragraphSpacing, 0, "Expected no spacing after")
    } else {
      XCTFail("no para style")
    }
    // this is a newline character that the LineBreakNode corresponds to.
    if let attribute = attributedString.attribute(.paragraphStyle, at: 11, effectiveRange: nil) as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 11, "Expected spacing before, since this line break is the same paragraph as line1")
      XCTAssertEqual(attribute.paragraphSpacing, 0, "Expected no spacing after, since that's handled by the extra line fragment attributes")
    } else {
      XCTFail("no para style")
    }

    XCTAssertNotNil(view.textStorage.extraLineFragmentAttributes, "Should have extra line fragment attributes")
    if let attribute = view.textStorage.extraLineFragmentAttributes?[.paragraphStyle] as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 0, "Expected no spacing before")
      XCTAssertEqual(attribute.paragraphSpacing, 7, "Expected spacing after")
    } else {
      XCTFail("no para style in extra line fragment attribs")
    }
  }

  func testParagraphInsideQuoteRetainsIndent() throws {
    // Regression test: a ParagraphNode inside a QuoteNode should inherit the
    // quote's indent (getIndent() == 1) so that text is offset from the quote
    // bar. Previously, ParagraphNode's indent value of 0 overwrote QuoteNode's
    // indent of 1 during attribute merging, leaving headIndent at zero.
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("quoted text")

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      let quoteNode = QuoteNode()
      try quoteNode.append([paragraphNode])

      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.getChildren().forEach { try $0.remove() }
      try rootNode.append([quoteNode])

      let combinedAttributes = AttributeUtils.attributedStringStyles(
        from: textNode,
        state: editorState,
        theme: editor.getTheme()
      )

      let paragraphStyle = combinedAttributes[.paragraphStyle] as? NSParagraphStyle
      XCTAssertNotNil(paragraphStyle, "Expected a paragraph style to be present")
      XCTAssertEqual(
        paragraphStyle?.headIndent,
        CGFloat(editor.getTheme().indentSize),
        "ParagraphNode inside QuoteNode should have headIndent equal to indentSize"
      )
      XCTAssertEqual(
        paragraphStyle?.firstLineHeadIndent,
        CGFloat(editor.getTheme().indentSize),
        "ParagraphNode inside QuoteNode should have firstLineHeadIndent equal to indentSize"
      )
    }
  }

  func testNestedQuoteProducesStackedBars() throws {
    // A QuoteNode inside another QuoteNode should produce a `quoteCustomDrawing`
    // attribute whose `allBarXPositions` contains one entry per nesting level.
    // The outer paragraph (depth 1) should still get the plain single-bar attribute.
    var theme = Theme()
    let barAttr = QuoteCustomDrawingAttributes(
      barColor: .gray,
      barWidth: 4,
      rounded: false,
      barInsets: UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0))
    theme.quote = [.quoteCustomDrawing: barAttr]

    let view = LexicalView(editorConfig: EditorConfig(theme: theme, plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }
      try rootNode.getChildren().forEach { try $0.remove() }

      // Build: root > outerQuote > [outerPara, innerQuote > innerPara]
      let outerTextNode = TextNode()
      try outerTextNode.setText("outer text")
      let outerPara = ParagraphNode()
      try outerPara.append([outerTextNode])

      let innerTextNode = TextNode()
      try innerTextNode.setText("inner text")
      let innerPara = ParagraphNode()
      try innerPara.append([innerTextNode])
      let innerQuote = QuoteNode()
      try innerQuote.append([innerPara])

      let outerQuote = QuoteNode()
      try outerQuote.append([outerPara, innerQuote])
      try rootNode.append([outerQuote])

      let indentSize = CGFloat(editor.getTheme().indentSize)

      // The outer paragraph (inside only one QuoteNode) should NOT get a multi-bar
      // attribute — its `allBarXPositions` should be empty.
      let outerAttrs = AttributeUtils.attributedStringStyles(
        from: outerTextNode,
        state: editorState,
        theme: editor.getTheme()
      )
      if let outerQuoteDrawing = outerAttrs[.quoteCustomDrawing] as? QuoteCustomDrawingAttributes {
        XCTAssertEqual(
          outerQuoteDrawing.allBarXPositions, [],
          "Single-level quote should not populate allBarXPositions"
        )
      } else {
        XCTFail("Expected quoteCustomDrawing attribute on outer paragraph")
      }

      // The inner paragraph (inside two QuoteNodes) should get a multi-bar attribute
      // with two positions: 0 for the outer bar, indentSize for the inner bar.
      let innerAttrs = AttributeUtils.attributedStringStyles(
        from: innerTextNode,
        state: editorState,
        theme: editor.getTheme()
      )
      if let innerQuoteDrawing = innerAttrs[.quoteCustomDrawing] as? QuoteCustomDrawingAttributes {
        XCTAssertEqual(
          innerQuoteDrawing.allBarXPositions,
          [0, indentSize],
          "Double-nested quote should have two bar x-positions"
        )
      } else {
        XCTFail("Expected quoteCustomDrawing attribute on inner paragraph")
      }
    }
  }

  func testTripleNestedQuoteProducesThreeBars() throws {
    // Three levels of QuoteNode nesting should produce three bar x-positions.
    var theme = Theme()
    let barAttr = QuoteCustomDrawingAttributes(
      barColor: .gray,
      barWidth: 4,
      rounded: false,
      barInsets: UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0))
    theme.quote = [.quoteCustomDrawing: barAttr]

    let view = LexicalView(editorConfig: EditorConfig(theme: theme, plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      guard let editorState = getActiveEditorState(),
        let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }
      try rootNode.getChildren().forEach { try $0.remove() }

      let textNode = TextNode()
      try textNode.setText("deeply nested")
      let para = ParagraphNode()
      try para.append([textNode])
      let innermost = QuoteNode()
      try innermost.append([para])
      let middle = QuoteNode()
      try middle.append([innermost])
      let outer = QuoteNode()
      try outer.append([middle])
      try rootNode.append([outer])

      let indentSize = CGFloat(editor.getTheme().indentSize)

      let attrs = AttributeUtils.attributedStringStyles(
        from: textNode,
        state: editorState,
        theme: editor.getTheme()
      )
      if let quoteDrawing = attrs[.quoteCustomDrawing] as? QuoteCustomDrawingAttributes {
        XCTAssertEqual(
          quoteDrawing.allBarXPositions,
          [0, indentSize, 2 * indentSize],
          "Triple-nested quote should have three bar x-positions"
        )
      } else {
        XCTFail("Expected quoteCustomDrawing attribute on triply-nested paragraph")
      }
    }
  }

  func testBlockLevelAttributesEmptyParagraphEndOfDocument() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: themeForBlockTests(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let paragraphNode = ParagraphNode()
      let textNode = TextNode()
      try textNode.setText("Para1")
      try paragraphNode.append([textNode])

      let codeLine1 = TextNode(text: "line1")
      let lineBreak = LineBreakNode()
      let codeNode = CodeNode()
      try codeNode.append([codeLine1, lineBreak])

      let paraNode2 = ParagraphNode()
      let textNode2 = TextNode(text: "")
      try paraNode2.append([textNode2])

      guard let rootNode = getRoot() else {
        XCTFail("should have root node")
        return
      }

      try rootNode.getChildren().forEach { node in
        try node.remove()
      }

      try rootNode.append([paragraphNode, codeNode, paraNode2])
    }

    guard let attributedString = view.textView.attributedText else {
      XCTFail("No attr string")
      return
    }
    XCTAssertEqual(attributedString.string, "Para1\nline1\n\n")

    // test that line1 gets the spacing before
    if let attribute = attributedString.attribute(.paragraphStyle, at: 6, effectiveRange: nil) as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 11, "Expected combination of paddingtop and margintop")
      XCTAssertEqual(attribute.paragraphSpacing, 0, "Expected no spacing after")
    } else {
      XCTFail("no para style")
    }
    // this is a newline character that should contain the styling for the end of the code block
    if let attribute = attributedString.attribute(.paragraphStyle, at: 12, effectiveRange: nil) as? NSParagraphStyle {
      XCTAssertEqual(attribute.paragraphSpacingBefore, 0, "Expected no spacing before")
      XCTAssertEqual(attribute.paragraphSpacing, 7, "Expected spacing after")
    } else {
      XCTFail("no para style")
    }

    XCTAssertNotNil(view.textStorage.extraLineFragmentAttributes, "Should have extra line fragment attributes")
  }
}
