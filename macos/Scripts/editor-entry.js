// Entry point for esbuild — bundles CodeMirror 6 into a single IIFE.
// Run: npx esbuild Scripts/editor-entry.js --bundle --format=iife --global-name=CM --outfile=Sources/Gloss/Resources/codemirror-bundle.js --minify

import {
    EditorView, ViewPlugin, Decoration, WidgetType,
    lineNumbers, highlightActiveLineGutter, highlightActiveLine,
    drawSelection, dropCursor, rectangularSelection, crosshairCursor,
    highlightSpecialChars, keymap
} from '@codemirror/view';
import {EditorState} from '@codemirror/state';
import {
    syntaxTree, defaultHighlightStyle, syntaxHighlighting,
    indentOnInput, bracketMatching, foldGutter, foldKeymap
} from '@codemirror/language';
import {markdown, markdownLanguage} from '@codemirror/lang-markdown';
import {defaultKeymap, history, historyKeymap} from '@codemirror/commands';
import {closeBrackets, closeBracketsKeymap} from '@codemirror/autocomplete';
import {searchKeymap, highlightSelectionMatches} from '@codemirror/search';

export {
    EditorView, ViewPlugin, Decoration, WidgetType,
    lineNumbers, highlightActiveLineGutter, highlightActiveLine,
    drawSelection, dropCursor, rectangularSelection, crosshairCursor,
    highlightSpecialChars, keymap,
    EditorState,
    syntaxTree, defaultHighlightStyle, syntaxHighlighting,
    indentOnInput, bracketMatching, foldGutter, foldKeymap,
    markdown, markdownLanguage,
    defaultKeymap, history, historyKeymap,
    closeBrackets, closeBracketsKeymap,
    searchKeymap, highlightSelectionMatches
};
