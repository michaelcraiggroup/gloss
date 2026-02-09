import Testing
import Foundation
import SwiftData
@testable import Gloss

@Suite("Favorites")
struct FavoritesTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: RecentDocument.self, configurations: config)
    }

    @Test("Default isFavorite is false")
    func defaultIsFavorite() {
        let doc = RecentDocument(path: "/tmp/test.md", title: "Test")
        #expect(doc.isFavorite == false)
    }

    @Test("Creating with isFavorite true works")
    func createWithFavorite() {
        let doc = RecentDocument(path: "/tmp/test.md", title: "Test", isFavorite: true)
        #expect(doc.isFavorite == true)
    }

    @Test("Toggling isFavorite persists in SwiftData")
    @MainActor
    func toggleFavoritePersists() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let doc = RecentDocument(path: "/tmp/fav.md", title: "Favorite Test")
        context.insert(doc)
        #expect(doc.isFavorite == false)

        doc.isFavorite = true
        try context.save()

        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.isFavorite }
        )
        let favorites = try context.fetch(descriptor)
        #expect(favorites.count == 1)
        #expect(favorites.first?.title == "Favorite Test")
    }

    @Test("Favorites sorted by title")
    @MainActor
    func favoritesSortedByTitle() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let docs = [
            RecentDocument(path: "/tmp/zebra.md", title: "Zebra", isFavorite: true),
            RecentDocument(path: "/tmp/apple.md", title: "Apple", isFavorite: true),
            RecentDocument(path: "/tmp/mango.md", title: "Mango", isFavorite: true),
            RecentDocument(path: "/tmp/notfav.md", title: "Not Fav"),
        ]
        for doc in docs { context.insert(doc) }
        try context.save()

        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.isFavorite },
            sortBy: [SortDescriptor(\RecentDocument.title)]
        )
        let favorites = try context.fetch(descriptor)
        #expect(favorites.count == 3)
        #expect(favorites[0].title == "Apple")
        #expect(favorites[1].title == "Mango")
        #expect(favorites[2].title == "Zebra")
    }

    @Test("Unfavoriting removes from favorites query")
    @MainActor
    func unfavoriteRemoves() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let doc = RecentDocument(path: "/tmp/test.md", title: "Test", isFavorite: true)
        context.insert(doc)
        try context.save()

        doc.isFavorite = false
        try context.save()

        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.isFavorite }
        )
        let favorites = try context.fetch(descriptor)
        #expect(favorites.isEmpty)
    }

    @Test("URL property returns correct path")
    func urlProperty() {
        let doc = RecentDocument(path: "/Users/test/notes.md", title: "Notes")
        #expect(doc.url.path == "/Users/test/notes.md")
    }
}
