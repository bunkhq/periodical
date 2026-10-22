import Foundation

/// Parses loose, human-typed times into minutes since midnight.
///
/// Understands things like `9am`, `at 9:30`, `14:31`, `1431`, `noon`, `five past noon`,
/// `quarter to 3`, `in 30 minutes`, `in an hour and a half`, `2h 15m from now`.
/// Results are always whole minutes; relative times are rounded to the nearest minute.
///
/// When a `reference` time is given (the start of a block, while asking for its end), bare
/// durations count from it: `45 minutes after`, `after 45 minutes`, `an hour later`, `for 50 min`,
/// `1h 30m`, `+20`, or a bare number from 25 to 99 (`45`). `in …` still counts from now.
///
/// Bare hours from 1 to 6 with no am/pm (`2`, `3:15`) are read as afternoon, since a
/// school day rarely has anything at 3 in the morning. Use a leading zero (`03:15`) or
/// `am` to force the morning.
public enum TimeParser {
    public static func parse(
        _ input: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        reference: Int? = nil
    ) -> Int? {
        let s = normalize(input)
        guard !s.isEmpty else { return nil }

        if let reference, let offset = offsetFromReference(s) {
            let minutes = reference + Int((offset / 60).rounded())
            return (minutes % 1440 + 1440) % 1440
        }

        if s == "now" || s == "right now" {
            return minuteOfDay(roundedToMinute(now), calendar: calendar)
        }
        if let offset = relativeOffset(s) {
            return minuteOfDay(roundedToMinute(now.addingTimeInterval(offset)), calendar: calendar)
        }
        if let minutes = offsetFromTime(s) ?? absolute(s) {
            return minutes
        }
        return detectedTime(input, calendar: calendar)
    }

    /// Localized short time, e.g. `9:05 AM`.
    public static func format(minutes: Int, calendar: Calendar = .current) -> String {
        let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date())!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Normalization

    private static let phrases: [(String, String)] = [
        ("in the morning", "am"), ("this morning", "am"),
        ("in the afternoon", "pm"), ("this afternoon", "pm"),
        ("in the evening", "pm"), ("this evening", "pm"),
        ("at night", "pm"), ("tonight", "pm"),
        ("an hour and a half", "90 minutes"), ("a hour and a half", "90 minutes"),
        ("and a half hours?", "hours 30 minutes"),
        ("half an hour", "30 minutes"), ("half a hour", "30 minutes"), ("half hour", "30 minutes"),
        ("a couple of", "2"), ("a couple", "2"), ("a few", "3"),
        ("a quarter", "quarter"),
        ("an hour", "1 hour"), ("a hour", "1 hour"), ("a minute", "1 minute"),
        ("o'?clock", ""),
        ("noon", "12pm"), ("midday", "12pm"), ("midnight", "12am"),
        ("a\\.m\\.?", "am"), ("p\\.m\\.?", "pm"),
    ]

    private static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
        "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]
    private static let tens: [String: Int] = ["twenty": 20, "thirty": 30, "forty": 40, "fourty": 40, "fifty": 50]

    static func normalize(_ input: String) -> String {
        var s = input.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
        for (pattern, replacement) in phrases {
            s = s.replacingOccurrences(of: "\\b\(pattern)(?=\\s|$)", with: replacement, options: .regularExpression)
        }

        // Number words to digits: "twenty five" -> "25", "nine oh five" -> "9 05".
        let words = s.split(whereSeparator: \.isWhitespace).map(String.init)
        var out: [String] = []
        var i = 0
        while i < words.count {
            let word = words[i]
            let next = i + 1 < words.count ? words[i + 1] : nil
            if let t = tens[word] {
                if let next, let u = units[next], (1...9).contains(u) {
                    out.append(String(t + u)); i += 2; continue
                }
                out.append(String(t))
            } else if (word == "oh" || word == "o"), let next, let u = units[next], u < 10 {
                out.append(String(format: "%02d", u)); i += 2; continue
            } else if let u = units[word] {
                out.append(String(u))
            } else {
                out.append(word)
            }
            i += 1
        }
        s = out.joined(separator: " ")

        for prefix in ["at ", "by ", "@"] where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Relative ("in 30 minutes")

    static func relativeOffset(_ s: String) -> TimeInterval? {
        let body: String
        if s.hasPrefix("in ") {
            body = String(s.dropFirst(3))
        } else if s.hasSuffix(" from now") {
            body = String(s.dropLast(" from now".count))
        } else if s.hasPrefix("+") {
            body = String(s.dropFirst())
        } else {
            return nil
        }
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        if let minutes = Double(trimmed) { return minutes * 60 }
        return duration(trimmed)
    }

    // MARK: - Relative to a reference ("45 minutes after", "an hour later", "45")

    static func offsetFromReference(_ s: String) -> TimeInterval? {
        var body = s
        var hadAffix = false
        for prefix in ["after ", "for ", "+"] where body.hasPrefix(prefix) {
            body = String(body.dropFirst(prefix.count))
            hadAffix = true
            break
        }
        for suffix in [" after it starts", " after start", " after", " later", " long"] where body.hasSuffix(suffix) {
            body = String(body.dropLast(suffix.count))
            hadAffix = true
            break
        }
        body = body.trimmingCharacters(in: .whitespaces)

        if let minutes = Int(body) {
            // Without "after"/"later", only numbers that can't be an hour count as minutes.
            return hadAffix || (25...99).contains(minutes) ? TimeInterval(minutes * 60) : nil
        }
        return duration(body)
    }

    /// Sum of `<number><unit>` pairs, e.g. `1h 30m`, `2 hours and 5 minutes`. Nil if anything else is left over.
    static func duration(_ body: String) -> TimeInterval? {
        let regex = try! NSRegularExpression(
            pattern: #"(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)(?=\d|\s|$)"#
        )
        let ns = body as NSString
        var total: TimeInterval = 0
        var leftover = body
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return nil }
        for match in matches {
            let value = Double(ns.substring(with: match.range(at: 1)))!
            let unit = ns.substring(with: match.range(at: 2))
            switch unit.first {
            case "h": total += value * 3600
            case "m": total += value * 60
            default: total += value
            }
            leftover = leftover.replacingOccurrences(of: ns.substring(with: match.range), with: " ")
        }
        let rest = leftover.split(whereSeparator: \.isWhitespace).filter { $0 != "and" }
        return rest.isEmpty ? total : nil
    }

    // MARK: - Offsets from a time ("five past noon", "quarter to 3")

    static func offsetFromTime(_ s: String) -> Int? {
        let regex = try! NSRegularExpression(
            pattern: #"^(\d+|quarter|half)\s*(?:minutes?|mins?|m)?\s+(past|after|to|before|till|til|until)\s+(.+)$"#
        )
        let ns = s as NSString
        guard let match = regex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let amountText = ns.substring(with: match.range(at: 1))
        let amount: Int
        switch amountText {
        case "quarter": amount = 15
        case "half": amount = 30
        default: amount = Int(amountText)!
        }
        guard amount < 60, let base = absolute(ns.substring(with: match.range(at: 3))) else { return nil }
        let direction = ns.substring(with: match.range(at: 2))
        let sign = (direction == "past" || direction == "after") ? 1 : -1
        return ((base + sign * amount) % 1440 + 1440) % 1440
    }

    // MARK: - Absolute ("9am", "14:31", "930")

    static func absolute(_ s: String) -> Int? {
        let separated = try! NSRegularExpression(
            pattern: #"^(\d{1,2})(?:\s*[:.h]\s*(\d{2})|\s+(\d{2}))?\s*(am|pm|a|p)?$"#
        )
        let compact = try! NSRegularExpression(pattern: #"^(\d{3,4})\s*(am|pm|a|p)?$"#)
        let ns = s as NSString
        let range = NSRange(location: 0, length: ns.length)

        func group(_ m: NSTextCheckingResult, _ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }

        let hourText: String
        let minute: Int
        let meridiem: String?
        if let m = separated.firstMatch(in: s, range: range) {
            hourText = group(m, 1)!
            minute = Int(group(m, 2) ?? group(m, 3) ?? "0")!
            meridiem = group(m, 4)
        } else if let m = compact.firstMatch(in: s, range: range) {
            let digits = group(m, 1)!
            hourText = String(digits.dropLast(2))
            minute = Int(digits.suffix(2))!
            meridiem = group(m, 2)
        } else {
            return nil
        }

        guard var hour = Int(hourText), minute < 60 else { return nil }
        switch meridiem?.first {
        case "a":
            guard (1...12).contains(hour) else { return nil }
            if hour == 12 { hour = 0 }
        case "p":
            guard (1...12).contains(hour) else { return nil }
            if hour != 12 { hour += 12 }
        default:
            guard hour < 24 else { return nil }
            let explicit24h = hourText.count == 2 && hourText.hasPrefix("0")
            if (1...6).contains(hour) && !explicit24h { hour += 12 }
        }
        return hour * 60 + minute
    }

    // MARK: - Fallback

    private static func detectedTime(_ input: String, calendar: Calendar) -> Int? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
              let match = detector.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let date = match.date
        else { return nil }
        return minuteOfDay(roundedToMinute(date), calendar: calendar)
    }

    // MARK: - Helpers

    static func roundedToMinute(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded() * 60)
    }

    static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return c.hour! * 60 + c.minute!
    }
}
