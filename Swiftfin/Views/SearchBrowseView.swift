//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import JellyfinAPI
import SwiftUI

// MARK: - SearchBrowseViewModel

/// Loads movie / series genres together with an artwork source for each,
/// used by the empty state of the iOS Search tab.
@MainActor
final class SearchBrowseViewModel: ObservableObject {

    struct Genre: Identifiable, Hashable {
        let id: String
        let name: String
        var image: ImageSource?
    }

    @Published
    private(set) var genres: [Genre] = []

    private var hasLoaded = false

    private static let genreLimit = 24
    private static let tileImageOptions = ImageSourceOptions(maxWidth: 600, quality: 90)

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true

        Task { [weak self] in
            await self?.load()
        }
    }

    private func load() async {
        guard let userSession = Container.shared.currentUserSession() else { return }

        let client = userSession.client
        let userID = userSession.user.id

        var parameters = Paths.GetGenresParameters()
        parameters.userID = userID
        parameters.includeItemTypes = [.movie, .series]
        parameters.enableImages = true
        parameters.imageTypeLimit = 1
        parameters.sortBy = [.sortName]
        parameters.sortOrder = [.ascending]
        parameters.limit = Self.genreLimit

        guard let response = try? await client.send(Paths.getGenres(parameters: parameters)) else { return }

        let items = (response.value.items ?? []).filter { $0.name?.isNotEmpty == true }

        var genres: [Genre] = items.map { item in
            Genre(
                id: item.id ?? item.name ?? UUID().uuidString,
                name: item.name ?? "",
                // Server genre images are auto-generated poster collages; use an item backdrop instead.
                image: nil
            )
        }

        guard !Task.isCancelled else { return }
        self.genres = genres

        // Give each genre the artwork of a random item from it.
        let missing = genres.enumerated().filter { $0.element.image == nil }
        guard missing.isNotEmpty else { return }

        let fallbacks: [Int: ImageSource] = await withTaskGroup(of: (Int, ImageSource?).self) { group in
            for (index, genre) in missing {
                group.addTask {
                    var itemParameters = Paths.GetItemsParameters()
                    itemParameters.userID = userID
                    itemParameters.genres = [genre.name]
                    itemParameters.includeItemTypes = [.movie, .series]
                    itemParameters.isRecursive = true
                    itemParameters.imageTypes = [.backdrop]
                    itemParameters.enableImageTypes = [.backdrop, .primary]
                    itemParameters.imageTypeLimit = 1
                    itemParameters.sortBy = [.random]
                    itemParameters.limit = 1

                    let item = try? await client.send(Paths.getItems(parameters: itemParameters)).value.items?.first

                    let source = await MainActor.run {
                        item.flatMap { item in
                            item.imageSource(.backdrop, itemID: item.id, environment: Self.tileImageOptions) ??
                                item.imageSource(.primary, itemID: item.id, environment: Self.tileImageOptions)
                        }
                    }

                    return (index, source)
                }
            }

            var result: [Int: ImageSource] = [:]
            for await (index, source) in group {
                if let source {
                    result[index] = source
                }
            }
            return result
        }

        guard !Task.isCancelled, fallbacks.isNotEmpty else { return }

        for (index, source) in fallbacks where genres.indices.contains(index) {
            genres[index].image = source
        }

        self.genres = genres
    }

}

// MARK: - SearchBrowseView

/// "Browse" section of genre tiles shown while the search query is empty.
struct SearchBrowseView: View {

    @ObservedObject
    var viewModel: SearchBrowseViewModel

    @Router
    private var router

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.genres.isNotEmpty {
                Text(L10n.browse)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.genres) { genre in
                        SearchBrowseGenreTile(genre: genre) { namespace in
                            route(to: genre, in: namespace)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .edgePadding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .animation(.easeInOut(duration: 0.25), value: viewModel.genres)
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }

    private func route(to genre: SearchBrowseViewModel.Genre, in namespace: Namespace.ID) {
        let staticFilters = ItemFilterCollection(
            genres: [ItemGenre(stringLiteral: genre.name)],
            itemTypes: [.movie, .series]
        )

        router.route(
            to: .library(
                library: ItemLibrary(
                    parent: BaseItemDto(name: genre.name),
                    staticFilters: staticFilters
                ),
                displayTitle: genre.name
            ),
            in: namespace
        )
    }
}

// MARK: - SearchBrowseGenreTile

private struct SearchBrowseGenreTile: View {

    @Namespace
    private var namespace

    let genre: SearchBrowseViewModel.Genre
    let action: (Namespace.ID) -> Void

    private var fallbackGradient: LinearGradient {
        // Stable, name-derived tint so image-less tiles still feel distinct.
        let hue = Double(abs(genre.name.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }) % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.55, brightness: 0.45),
                Color(hue: hue, saturation: 0.65, brightness: 0.22),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button {
            action(namespace)
        } label: {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(fallbackGradient)
                    .overlay {
                        if let image = genre.image {
                            ImageView(image)
                                .aspectRatio(contentMode: .fill)
                                .id(image.url)
                                .transition(.opacity)
                        }
                    }
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0.35),
                        .init(color: .black.opacity(0.75), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Text(genre.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
            .frame(height: 104)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SearchBrowseTileButtonStyle())
        .matchedTransitionSource(id: "item", in: namespace)
        .accessibilityLabel(genre.name)
    }
}

private struct SearchBrowseTileButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
