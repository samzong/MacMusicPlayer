import Foundation
import Combine

class LibraryManager: ObservableObject {
    @Published var libraries: [MusicLibrary] = []
    @Published var currentLibrary: MusicLibrary?

    init() {
        loadLibraries()

        if libraries.isEmpty {
            migrateExistingSingleLibrary()
        }

        if let lastUsedId = UserDefaults.standard.string(forKey: "LastUsedLibraryID"),
           let uuid = UUID(uuidString: lastUsedId),
           let library = libraries.first(where: { $0.id == uuid }) {
            currentLibrary = library
        } else {
            currentLibrary = libraries.first
        }
    }

    func addLibrary(name: String, path: String) {
        let newLibrary = MusicLibrary(
            name: name,
            path: path
        )

        libraries.append(newLibrary)
        saveLibraries()

        switchLibrary(id: newLibrary.id)
    }

    func removeLibrary(id: UUID) {
        guard libraries.count > 1 else { return }

        libraries.removeAll { $0.id == id }

        if currentLibrary?.id == id {
            currentLibrary = libraries.first
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
        }

        saveLibraries()
    }

    func switchLibrary(id: UUID) {
        guard currentLibrary?.id != id,
              let newLibrary = libraries.first(where: { $0.id == id }) else {
            return
        }

        var updatedLibrary = newLibrary
        updatedLibrary.lastAccessed = Date()

        if let index = libraries.firstIndex(where: { $0.id == id }) {
            libraries[index] = updatedLibrary
        }

        currentLibrary = updatedLibrary

        UserDefaults.standard.set(id.uuidString, forKey: "LastUsedLibraryID")
        saveLibraries()

        NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
    }

    func renameLibrary(id: UUID, newName: String) {
        guard let index = libraries.firstIndex(where: { $0.id == id }) else {
            return
        }

        var updatedLibrary = libraries[index]
        updatedLibrary.name = newName
        libraries[index] = updatedLibrary

        if currentLibrary?.id == id {
            currentLibrary = updatedLibrary
        }

        saveLibraries()
    }

    func saveLibraries() {
        do {
            let data = try JSONEncoder().encode(libraries)
            UserDefaults.standard.set(data, forKey: "MusicLibraries")
        } catch {
            print("Failed to save libraries: \(error)")
        }
    }

    func loadLibraries() {
        guard let data = UserDefaults.standard.data(forKey: "MusicLibraries") else {
            return
        }

        do {
            libraries = try JSONDecoder().decode([MusicLibrary].self, from: data)
        } catch {
            print("Failed to load libraries: \(error)")
        }
    }

    private func migrateExistingSingleLibrary() {
        if let savedPath = UserDefaults.standard.string(forKey: "MusicFolderPath") {
            let defaultLibrary = MusicLibrary(
                id: UUID(),
                name: NSLocalizedString("My Music", comment: "Default music library name"),
                path: savedPath,
                createdAt: Date(),
                lastAccessed: Date()
            )

            libraries.append(defaultLibrary)
            currentLibrary = defaultLibrary
            saveLibraries()
        }
    }
}
