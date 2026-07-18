#if os(iOS)
import Foundation
import SwiftUI
import UIKit

/// iOS: UITextView wrapper with attributed string highlighting inline chords + drag-to-move + loupe
struct ChordTextEditorWrapper: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let fontSize: CGFloat
    @Binding var caretRect: CGRect

    func makeUIView(context: Context) -> ChordTextView {
        let tv = ChordTextView()
        tv.delegate = context.coordinator
        tv.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        tv.textColor = .label
        tv.backgroundColor = .clear
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.spellCheckingType = .no
        tv.smartQuotesType = .no
        tv.smartDashesType = .no
        tv.smartInsertDeleteType = .no
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.text = text

        // Add chord drag gesture recognizer
        let dragGesture = ChordDragGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleChordDrag(_:)))
        dragGesture.delegate = context.coordinator
        tv.addGestureRecognizer(dragGesture)

        // Initial attributed string
        tv.attributedText = highlightChords(in: text, fontSize: fontSize)
        return tv
    }

    func updateUIView(_ uiView: ChordTextView, context: Context) {
        // Update attributed string if text changed
        if uiView.text != text {
            uiView.attributedText = highlightChords(in: text, fontSize: fontSize)
        }
        // Sync selection
        let ns = text as NSString
        if selection.location + selection.length <= ns.length {
            if uiView.selectedRange != selection {
                uiView.selectedRange = selection
            }
        }
        context.coordinator.publishCaret(uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Highlight all `[chord]` tags in the text.
    func highlightChords(in text: String, fontSize: CGFloat) -> NSAttributedString {
        let attr = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        attr.addAttributes(baseAttrs, range: fullRange)

        let open = "[", close = "]"
        let ns = text as NSString
        let len = ns.length
        var i = 0
        let chordAttrs: [NSAttributedString.Key: Any] = [
            .backgroundColor: UIColor.systemBlue.withAlphaComponent(0.15),
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.systemBlue.withAlphaComponent(0.4)
        ]
        while i < len {
            if ns.character(at: i) == UInt16(open.utf16.first!) {
                var j = i + 1
                var closeIdx = -1
                let newline = UInt16("\n".utf16.first!)
                while j < len {
                    let c = ns.character(at: j)
                    if c == UInt16(close.utf16.first!) { closeIdx = j; break }
                    if c == newline { break }
                    j += 1
                }
                if closeIdx >= 0 {
                    let range = NSRange(location: i, length: closeIdx - i + 1)
                    attr.addAttributes(chordAttrs, range: range)
                    i = closeIdx + 1
                    continue
                }
            }
            i += 1
        }
        return attr
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        let parent: ChordTextEditorWrapper
        var isProgrammatic = false
        var dragState: DragState?
        weak var loupeView: ChordLoupeView?

        init(_ parent: ChordTextEditorWrapper) { self.parent = parent }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            parent.selection = textView.selectedRange
            // Restore chord highlighting after gesture
            if let chordTextView = textView as? ChordTextView {
                chordTextView.attributedText = parent.highlightChords(in: textView.text ?? "", fontSize: parent.fontSize)
            }
            publishCaret(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            publishCaret(textView)
            guard !isProgrammatic else { return }
            if parent.selection != textView.selectedRange {
                parent.selection = textView.selectedRange
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if let tv = scrollView as? UITextView {
                publishCaret(tv)
                // Update loupe position on scroll
                updateLoupePosition(in: tv as? ChordTextView)
            }
        }

        func publishCaret(_ tv: UITextView) {
            var rect = CGRect.null
            if let start = tv.selectedTextRange?.start {
                let r = tv.caretRect(for: start)
                if !r.isNull, !r.isInfinite, !r.origin.x.isNaN, !r.origin.y.isNaN {
                    rect = r.offsetBy(dx: -tv.contentOffset.x, dy: -tv.contentOffset.y)
                }
            }
            let newRect = rect
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.parent.caretRect != newRect { self.parent.caretRect = newRect }
            }
        }

        // MARK: - Chord Drag Gesture

        @objc func handleChordDrag(_ gesture: ChordDragGestureRecognizer) {
            guard let textView = gesture.view as? ChordTextView else { return }
            let location = gesture.location(in: textView)

            switch gesture.state {
            case .possible, .began:
                if let chordInfo = findChord(at: location, in: textView) {
                    dragState = DragState(chordInfo: chordInfo, initialLocation: location, fontSize: parent.fontSize, currentLocation: location)
                    showLoupe(at: location, in: textView)
                }
            case .changed:
                guard var state = dragState else { return }
                state.currentLocation = location
                dragState = state
                moveChord(state, in: textView)
                updateLoupe(at: location, in: textView)
            case .ended, .cancelled, .failed:
                if var state = dragState {
                    finalizeDrag(state, in: textView)
                }
                hideLoupe()
                dragState = nil
            @unknown default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        private func findChord(at point: CGPoint, in textView: ChordTextView) -> ChordInfo? {
            let textPos = textView.closestPosition(to: point)
            guard let pos = textPos else { return nil }

            let offset = textView.offset(from: textView.beginningOfDocument, to: pos)
            let ns = (textView.text ?? "") as NSString

            let open = UInt16("[".utf16.first!)
            let close = UInt16("]".utf16.first!)
            let newline = UInt16("\n".utf16.first!)
            var i = 0
            var occurrence = 0
            var lineOccurrence = 0
            var currentLineStart = 0
            let len = ns.length
            while i < len {
                if ns.character(at: i) == newline {
                    currentLineStart = i + 1
                    lineOccurrence = 0
                }
                if ns.character(at: i) == open {
                    var j = i + 1
                    var closeIdx = -1
                    while j < len {
                        let c = ns.character(at: j)
                        if c == close { closeIdx = j; break }
                        if c == newline { break }
                        j += 1
                    }
                    if closeIdx >= 0 {
                        if offset >= i && offset <= closeIdx + 1 {
                            let chordText = ns.substring(with: NSRange(location: i + 1, length: closeIdx - i - 1))
                            return ChordInfo(
                                occurrence: occurrence,
                                lineOccurrence: lineOccurrence,
                                range: NSRange(location: i, length: closeIdx - i + 1),
                                name: chordText,
                                lineStart: lineStartOffset(at: i, in: ns),
                                lineEnd: lineEndOffset(at: closeIdx, in: ns)
                            )
                        }
                        occurrence += 1
                        lineOccurrence += 1
                        i = closeIdx + 1
                        continue
                    }
                }
                i += 1
            }
            return nil
        }

        private func lineStartOffset(at offset: Int, in ns: NSString) -> Int {
            var i = offset
            let newline = UInt16("\n".utf16.first!)
            while i > 0 && ns.character(at: i - 1) != newline { i -= 1 }
            return i
        }

        private func lineEndOffset(at offset: Int, in ns: NSString) -> Int {
            var i = offset
            let newline = UInt16("\n".utf16.first!)
            while i < ns.length && ns.character(at: i) != newline { i += 1 }
            return i
        }

        private func moveChord(_ state: DragState, in textView: ChordTextView) {
            let oldText = textView.text ?? ""
            let ns = oldText as NSString
            let lineRange = NSRange(location: state.chordInfo.lineStart, length: state.chordInfo.lineEnd - state.chordInfo.lineStart)
            var lineText = ns.substring(with: lineRange)

            // Find and remove the chord by both name AND lineOccurrence (to handle duplicate chord names in same line)
            let open = "[", close = "]"
            let lineNs = lineText as NSString
            var foundRange: NSRange?
            var searchIdx = 0
            var lineChordIndex = 0
            while searchIdx < lineNs.length {
                if lineNs.character(at: searchIdx) == UInt16(open.utf16.first!) {
                    var j = searchIdx + 1
                    var closeIdx = -1
                    let newline = UInt16("\n".utf16.first!)
                    while j < lineNs.length {
                        let c = lineNs.character(at: j)
                        if c == UInt16(close.utf16.first!) { closeIdx = j; break }
                        if c == newline { break }
                        j += 1
                    }
                    if closeIdx >= 0 {
                        let chordName = lineNs.substring(with: NSRange(location: searchIdx + 1, length: closeIdx - searchIdx - 1))
                        if chordName == state.chordInfo.name && lineChordIndex == state.chordInfo.lineOccurrence {
                            foundRange = NSRange(location: searchIdx, length: closeIdx - searchIdx + 1)
                            break
                        }
                        lineChordIndex += 1
                        searchIdx = closeIdx + 1
                        continue
                    }
                }
                searchIdx += 1
            }

            if let rangeToRemove = foundRange {
                lineText = (lineText as NSString).replacingCharacters(in: rangeToRemove, with: "")
            }

            // Calculate new insert position based on horizontal drag distance
            let dragDeltaX = state.currentLocation.x - state.initialLocation.x
            let charWidth = state.fontSize * 0.6
            let charDelta = Int(round(dragDeltaX / charWidth))
            // Base insert location is original chord position in line
            let originalChordPosInLine = state.chordInfo.range.location - state.chordInfo.lineStart
            var insertLoc = max(0, min((lineText as NSString).length, originalChordPosInLine + charDelta))

            // Insert chord at new position
            let insertText = "[\(state.chordInfo.name)]"
            lineText = (lineText as NSString).replacingCharacters(in: NSRange(location: insertLoc, length: 0), with: insertText)

            // Replace line in full text
            let newText = (oldText as NSString).replacingCharacters(in: lineRange, with: lineText)
            textView.attributedText = parent.highlightChords(in: newText, fontSize: state.fontSize)
            textView.text = newText

            // Update parent binding
            parent.text = newText
        }

        private func finalizeDrag(_ state: DragState, in textView: ChordTextView) {
            let newText = textView.text ?? ""
            let ns = newText as NSString
            let searchRange = NSRange(location: state.chordInfo.lineStart, length: state.chordInfo.lineEnd - state.chordInfo.lineStart)
            let open = UInt16("[".utf16.first!)
            let close = UInt16("]".utf16.first!)
            var i = searchRange.location
            while i < searchRange.location + searchRange.length {
                if ns.character(at: i) == open {
                    var j = i + 1
                    var closeIdx = -1
                    while j < searchRange.location + searchRange.length {
                        let c = ns.character(at: j)
                        if c == close { closeIdx = j; break }
                        j += 1
                    }
                    if closeIdx >= 0 {
                        let chordName = ns.substring(with: NSRange(location: i + 1, length: closeIdx - i - 1))
                        if chordName == state.chordInfo.name {
                            parent.selection = NSRange(location: closeIdx + 1, length: 0)
                            return
                        }
                        i = closeIdx + 1
                        continue
                    }
                }
                i += 1
            }
            parent.selection = NSRange(location: state.chordInfo.lineEnd, length: 0)
        }

        private func showLoupe(at point: CGPoint, in textView: ChordTextView) {
            let loupe = ChordLoupeView()
            loupe.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
            loupe.center = textView.convert(point, to: textView.superview)
            loupe.magnify(textView, at: point)
            textView.superview?.addSubview(loupe)
            loupeView = loupe
        }

        private func updateLoupe(at point: CGPoint, in textView: ChordTextView) {
            loupeView?.center = textView.convert(point, to: textView.superview)
            loupeView?.magnify(textView, at: point)
        }

        private func updateLoupePosition(in textView: ChordTextView?) {
            guard let textView, let state = dragState else { return }
            loupeView?.center = textView.convert(state.currentLocation, to: textView.superview)
        }

        private func hideLoupe() {
            loupeView?.removeFromSuperview()
            loupeView = nil
        }
    }
}

// MARK: - Supporting Types (public within file)

struct DragState {
    let chordInfo: ChordInfo
    let initialLocation: CGPoint
    let fontSize: CGFloat
    var currentLocation: CGPoint
}

struct ChordInfo {
    let occurrence: Int
    let lineOccurrence: Int  // 0-based index of this chord within its line
    let range: NSRange
    let name: String
    let lineStart: Int
    let lineEnd: Int
}

// MARK: - Custom UITextView for drag interaction

class ChordTextView: UITextView {
    /// Currently tapped chord range (for visual feedback)
    var tappedChordRange: NSRange? {
        didSet { setNeedsDisplay() }
    }
    
    override func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
        super.touchesShouldBegin(touches, with: event, in: view)
        return true
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        // Draw highlight for tapped chord
        if let range = tappedChordRange {
            let layoutManager = self.layoutManager
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rects = (0..<layoutManager.numberOfGlyphs).compactMap { glyphIndex -> CGRect? in
                guard NSLocationInRange(glyphIndex, glyphRange) else { return nil }
                var glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                glyphRect.origin.x += textContainerInset.left
                glyphRect.origin.y += textContainerInset.top - contentOffset.y
                return glyphRect
            }
            let highlightColor = UIColor.systemBlue.withAlphaComponent(0.3)
            let context = UIGraphicsGetCurrentContext()
            context?.setFillColor(highlightColor.cgColor)
            for r in rects {
                context?.fill(r.insetBy(dx: -2, dy: -1))
            }
        }
    }
}

// MARK: - Custom Drag Gesture Recognizer

class ChordDragGestureRecognizer: UIGestureRecognizer {
    var initialTouchLocation: CGPoint = .zero
    var minimumDragDistance: CGFloat = 5
    var touchBeganChordRange: NSRange?
    weak var textView: ChordTextView?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view = view as? ChordTextView else { return }
        textView = view
        initialTouchLocation = touch.location(in: view)
        state = .possible
        
        // Immediately highlight the chord under finger
        if let chordInfo = findChordAt(point: initialTouchLocation, in: view) {
            touchBeganChordRange = chordInfo.range
            highlightChord(range: chordInfo.range, in: view)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view = view else { return }
        let location = touch.location(in: view)
        let distance = hypot(location.x - initialTouchLocation.x, location.y - initialTouchLocation.y)
        if distance > minimumDragDistance {
            if state == .possible { state = .began }
            else { state = .changed }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        clearHighlight()
        if state == .began || state == .changed { state = .ended }
        else { state = .cancelled }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        clearHighlight()
        state = .cancelled
    }
    
    private func findChordAt(point: CGPoint, in textView: ChordTextView) -> ChordInfo? {
        let textPos = textView.closestPosition(to: point)
        guard let pos = textPos else { return nil }
        
        let offset = textView.offset(from: textView.beginningOfDocument, to: pos)
        let ns = (textView.text ?? "") as NSString
        
        let open = UInt16("[".utf16.first!)
        let close = UInt16("]".utf16.first!)
        let newline = UInt16("\n".utf16.first!)
        var i = 0
        var occurrence = 0
        var lineOccurrence = 0
        var currentLineStart = 0
        let len = ns.length
        
        while i < len {
            if ns.character(at: i) == newline {
                currentLineStart = i + 1
                lineOccurrence = 0
            }
            if ns.character(at: i) == open {
                var j = i + 1
                var closeIdx = -1
                while j < len {
                    let c = ns.character(at: j)
                    if c == close { closeIdx = j; break }
                    if c == newline { break }
                    j += 1
                }
                if closeIdx >= 0 {
                    if offset >= i && offset <= closeIdx + 1 {
                        let chordText = ns.substring(with: NSRange(location: i + 1, length: closeIdx - i - 1))
                        return ChordInfo(
                            occurrence: occurrence,
                            lineOccurrence: lineOccurrence,
                            range: NSRange(location: i, length: closeIdx - i + 1),
                            name: chordText,
                            lineStart: lineStartOffset(at: i, in: ns),
                            lineEnd: lineEndOffset(at: closeIdx, in: ns)
                        )
                    }
                    occurrence += 1
                    lineOccurrence += 1
                    i = closeIdx + 1
                    continue
                }
            }
            i += 1
        }
        return nil
    }
    
    private func lineStartOffset(at offset: Int, in ns: NSString) -> Int {
        var i = offset
        let newline = UInt16("\n".utf16.first!)
        while i > 0 && ns.character(at: i - 1) != newline { i -= 1 }
        return i
    }
    
    private func lineEndOffset(at offset: Int, in ns: NSString) -> Int {
        var i = offset
        let newline = UInt16("\n".utf16.first!)
        while i < ns.length && ns.character(at: i) != newline { i += 1 }
        return i
    }
    
    private func highlightChord(range: NSRange, in textView: ChordTextView) {
        let attr = textView.attributedText.mutableCopy() as! NSMutableAttributedString
        let highlightAttrs: [NSAttributedString.Key: Any] = [
            .backgroundColor: UIColor.systemBlue.withAlphaComponent(0.4),
            .foregroundColor: UIColor.white,
            .font: UIFont.monospacedSystemFont(ofSize: textView.font!.pointSize, weight: .bold)
        ]
        attr.addAttributes(highlightAttrs, range: range)
        textView.attributedText = attr
    }
    
    private func clearHighlight() {
        touchBeganChordRange = nil
        // The coordinator's textViewDidChange will restore proper highlighting
    }
}

// MARK: - Loupe / Magnifier View

class ChordLoupeView: UIView {
    private let magnification: CGFloat = 2.0
    private let loupeSize: CGFloat = 80
    private var snapshotView: UIImageView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        bounds = CGRect(x: 0, y: 0, width: loupeSize, height: loupeSize)
        layer.cornerRadius = loupeSize / 2
        layer.borderWidth = 2
        layer.borderColor = UIColor.systemBlue.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)
        clipsToBounds = true
        backgroundColor = .clear

        let snapshot = UIImageView(frame: bounds)
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true
        addSubview(snapshot)
        snapshotView = snapshot
    }

    func magnify(_ sourceView: UIView, at point: CGPoint) {
        let sourceRect = CGRect(
            x: point.x - loupeSize / (2 * magnification),
            y: point.y - loupeSize / (2 * magnification),
            width: loupeSize / magnification,
            height: loupeSize / magnification
        )

        let renderer = UIGraphicsImageRenderer(bounds: sourceRect)
        let image = renderer.image { ctx in
            sourceView.layer.render(in: ctx.cgContext)
        }
        snapshotView?.image = image
    }
}
#endif