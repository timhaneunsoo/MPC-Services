import Foundation

struct ChordTransposer {
    static func formatAndTransposeSongSheet(text: String, steps: Int) -> String {
        let orderMarker = "[Order]"
        
        // Normalize line endings and remove BOM
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n")
                                 .replacingOccurrences(of: "\r", with: "\n")
                                 .replacingOccurrences(of: "\u{FEFF}", with: "")
                                 .trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = normalizedText.split(separator: "\n", omittingEmptySubsequences: false)
        
        print("Split Lines:")
        for line in lines {
            print("Line: '\(line)'")
        }
        
        var beforeOrder: [String] = []
        var orderSection: [String] = []
        var afterOrder: [String] = []
        
        var isOrderSection = false
        var isAfterOrderSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine == orderMarker {
                isOrderSection = true
                isAfterOrderSection = false
                orderSection.append(String(line)) // Include `[Order]` header
                continue
            }
            
            if isOrderSection && trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                isOrderSection = false
                isAfterOrderSection = true
            }
            
            if isOrderSection {
                orderSection.append(String(line))
            } else if isAfterOrderSection {
                afterOrder.append(String(line))
            } else {
                beforeOrder.append(String(line))
            }
        }
        
        // Debugging output
        print("Before Order:\n\(beforeOrder.joined(separator: "\n"))")
        print("Order Section:\n\(orderSection.joined(separator: "\n"))")
        print("After Order:\n\(afterOrder.joined(separator: "\n"))")
        
        // Transpose editable sections
        let transposedBeforeOrder = transposeText(text: beforeOrder.joined(separator: "\n"), steps: steps)
        let transposedAfterOrder = transposeText(text: afterOrder.joined(separator: "\n"), steps: steps)
        
        // Combine into two columns
        return formatAsTwoColumns(
            beforeOrder: transposedBeforeOrder,
            orderSection: orderSection.joined(separator: "\n"),
            afterOrder: transposedAfterOrder
        )
    }

    static func transposeText(text: String, steps: Int) -> String {
        // Regular expression to match individual chords
        let chordRegex = try! NSRegularExpression(pattern: "^[A-G](#|b)?(m|min|maj|dim|aug|sus|add|2|4|6|7|9|11|13|6/9|7-5|7-9|7#5|7#9|7\\+5|7\\+9|b5|#5|#9|7b5|7b9|7sus2|7sus4|add2|add4|add9|aug|dim|dim7|m/maj7|m6|m7|m7b5|m9|m11|m13|M7|M9|M11|M13|mb5|m|sus|sus2|sus4)*(\\/[A-G](#|b)?)?$")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var result = [String]()

        for line in lines {
            let words = line.split(separator: " ", omittingEmptySubsequences: false)
            var transposedLine = ""

            for word in words {
                let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
                let range = NSRange(trimmedWord.startIndex..<trimmedWord.endIndex, in: trimmedWord)

                if chordRegex.firstMatch(in: trimmedWord, options: [], range: range) != nil {
                    // If the word is a chord, transpose it
                    let transposedChord = transposeChord(chord: trimmedWord, steps: steps)
                    transposedLine.append(transposedChord + " ")
                } else {
                    // Otherwise, keep the word as is
                    transposedLine.append(word + " ")
                }
            }

            result.append(transposedLine.trimmingCharacters(in: .whitespaces))
        }

        return result.joined(separator: "\n")
    }

    static func transposeChord(chord: String, steps: Int) -> String {
        let sharpNotes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let flatNotes = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

        func transposeNote(note: String, steps: Int) -> String {
            if let index = sharpNotes.firstIndex(of: note) {
                return sharpNotes[(index + steps + sharpNotes.count) % sharpNotes.count]
            } else if let index = flatNotes.firstIndex(of: note) {
                return sharpNotes[(index + steps + flatNotes.count) % sharpNotes.count]
            }
            return note // Return as-is if not found
        }

        if chord.contains("/") {
            let parts = chord.split(separator: "/")
            guard parts.count == 2 else { return chord }
            let mainChord = String(parts[0])
            let bassNote = String(parts[1])
            let transposedMainChord = transposeChord(chord: mainChord, steps: steps)
            let transposedBassNote = transposeNote(note: bassNote, steps: steps)
            return "\(transposedMainChord)/\(transposedBassNote)"
        }

        let regex = try! NSRegularExpression(pattern: "^[A-G](#|b)?")
        guard let match = regex.firstMatch(in: chord, range: NSRange(chord.startIndex..<chord.endIndex, in: chord)),
              let range = Range(match.range, in: chord) else {
            return chord
        }

        let baseNote = String(chord[range])
        let suffix = String(chord[range.upperBound...])
        let transposedBaseNote = transposeNote(note: baseNote, steps: steps)
        return "\(transposedBaseNote)\(suffix)"
    }

    static func formatAsTwoColumns(beforeOrder: String, orderSection: String, afterOrder: String) -> String {
        // Ensure all parts are trimmed and clean
        let firstColumn = beforeOrder.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondColumn = ([orderSection, afterOrder]
            .filter { !$0.isEmpty } // Avoid adding empty sections
            .joined(separator: "\n\n")) // Add spacing between sections

        // Return columns with a clear separator
        return "\(firstColumn) || \(secondColumn)"
    }
}
