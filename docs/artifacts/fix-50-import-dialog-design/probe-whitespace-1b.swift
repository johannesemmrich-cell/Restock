import Foundation
// Adversary-Probe Paket 1b: welcher Leerraum wird von `.whitespaces` erfasst (Regel 10/11)?
let cases: [(String, String)] = [
 ("space U+0020", " "), ("tab U+0009", "\t"), ("newline U+000A", "\n"),
 ("nbsp U+00A0", "\u{00A0}"), ("enQuad U+2000", "\u{2000}"),
 ("narrowNBSP U+202F", "\u{202F}"), ("ideographic U+3000", "\u{3000}"),
 ("zeroWidth U+200B", "\u{200B}"), ("crlf", "\r\n"), ("vtab U+000B", "\u{000B}")
]
for (n, s) in cases {
  print("\(n): ws-leer=\(s.trimmingCharacters(in: .whitespaces).isEmpty)  wsn-leer=\(s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)")
}
func sanitize(_ text: String) -> String? {
  let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
  guard !trimmed.isEmpty, trimmed.count <= 60, !trimmed.contains("\n") else { return nil }
  return trimmed
}
print("sanitize(quote+space+quote) = \(String(describing: sanitize("\" \"")))")
print("sanitize(single space) = \(String(describing: sanitize(" ")))")
