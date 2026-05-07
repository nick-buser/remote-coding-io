import Foundation

// UserDefaults-backed persistence for `LocalProjectNote`. Stopgap until
// the contract exposes project-level docs. Notes are bucketed by
// projectID inside a single keyed payload so reads / writes are one
// JSON roundtrip per call.
struct LocalProjectNoteStore {
    static let userDefaultsKey = "LocalProjectNotes.v1"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func list(projectID: Int64) -> [LocalProjectNote] {
        readAll()[projectID] ?? []
    }

    @discardableResult
    func save(_ note: LocalProjectNote) -> LocalProjectNote {
        var saved = note
        saved.updatedAt = Date()
        var all = readAll()
        var bucket = all[saved.projectID] ?? []
        if let index = bucket.firstIndex(where: { $0.id == saved.id }) {
            bucket[index] = saved
        } else {
            bucket.append(saved)
        }
        all[saved.projectID] = bucket
        write(all)
        return saved
    }

    private func readAll() -> [Int64: [LocalProjectNote]] {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey) else {
            return [:]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([String: [LocalProjectNote]].self, from: data) else {
            return [:]
        }
        var byID: [Int64: [LocalProjectNote]] = [:]
        for (key, notes) in decoded {
            if let projectID = Int64(key) {
                byID[projectID] = notes
            }
        }
        return byID
    }

    private func write(_ all: [Int64: [LocalProjectNote]]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let stringKeyed = Dictionary(uniqueKeysWithValues: all.map { (String($0.key), $0.value) })
        guard let data = try? encoder.encode(stringKeyed) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }
}
