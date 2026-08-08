/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import Lexical
import XCTest

final class UpdateCommitTests: XCTestCase {

  /// An update whose block leaves the selection on a node it removed is a bug in that block, and
  /// the editor reports it and rolls the update back. What it must not do is apply the update to
  /// the text storage first: the reconciler also writes the range cache, so a half applied update
  /// leaves the text storage and range cache describing the pending state while the editor state,
  /// pending state and dirty nodes still describe the old one. The next update then reconciles the
  /// same change a second time, deleting ranges that have already gone, until one of them runs off
  /// the end of the string.
  func testUpdateThatLosesItsSelectionRollsBackInsteadOfHalfApplying() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor
    let textView = view.textView

    textView.insertText("hello")
    textView.insertText("\n")
    textView.insertText("world")
    XCTAssertEqual(editor.textStorage?.string, "hello\nworld")

    var reportedErrors: [Error] = []
    let removeErrorListener = editor.registerErrorListener { _, _, error in
      reportedErrors.append(error)
    }
    defer { removeErrorListener() }

    // Remove the block the caret is in without moving the caret out of it first. `restoreSelection:
    // false` is what an update block that forgets to reposition the selection amounts to.
    try editor.update {
      guard let lastChild = getRoot()?.getLastChild() else {
        XCTFail("expected a last child")
        return
      }
      try Node.removeNode(nodeToRemove: lastChild, restoreSelection: false)
    }

    XCTAssertEqual(reportedErrors.count, 1, "the lost selection should have been reported")

    XCTAssertEqual(editor.textStorage?.string, "hello\nworld", "the update should have been rolled back")
    XCTAssertNil(editor.testing_getPendingEditorState(), "no pending editor state should be left behind")
    XCTAssertTrue(editor.dirtyNodes.isEmpty, "no dirty nodes should be left behind")
    XCTAssertEqual(editor.dirtyType, .noDirtyNodes, "no dirty type should be left behind")
    assertRangeCacheMatchesTextStorage(editor)

    // The crash this guards against happens on the *next* update, which is usually just a caret
    // move: it reconciles the rolled back change again against a range cache that already has it.
    textView.selectedRange = NSRange(location: 0, length: 0)

    XCTAssertEqual(editor.textStorage?.string, "hello\nworld", "a later update should not reapply the rolled back change")
    assertRangeCacheMatchesTextStorage(editor)
  }

  /// The range cache is the reconciler's map of the text storage, so every attached node's cached
  /// range has to fit inside the string, and root's has to span all of it.
  private func assertRangeCacheMatchesTextStorage(
    _ editor: Editor, file: StaticString = #filePath, line: UInt = #line
  ) {
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
    }
  }
}
