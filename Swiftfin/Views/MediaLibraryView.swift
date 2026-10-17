//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// The iOS Media tab: a plain list of the user's libraries followed by a
/// grid of recently added items.
struct MediaLibraryView: View {

    @StateObject
    private var userViewsViewModel = PagingLibraryViewModel(library: UserViewLibrary())
    @StateObject
    private var recentlyAddedViewModel = PagingLibraryViewModel(library: RecentlyAddedLibrary(), pageSize: 24)

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 3
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                librariesSection

                if recentlyAddedViewModel.elements.isNotEmpty {
                    recentlyAddedSection
                        .padding(.top, 36)
                }
            }
            .padding(.horizontal, EdgeInsets.edgePadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if userViewsViewModel.state == .initial || userViewsViewModel.state == .refreshing,
               userViewsViewModel.elements.isEmpty
            {
                ProgressView()
            } else if userViewsViewModel.state == .error, userViewsViewModel.elements.isEmpty {
                userViewsViewModel.error.map(ErrorView.init)
            }
        }
        .refreshable {
            await userViewsViewModel.background.refresh()
            await recentlyAddedViewModel.background.refresh()
        }
        .navigationTitle(L10n.media)
        .toolbarTitleDisplayMode(.large)
        .errorMessage($userViewsViewModel.error)
        .onFirstAppear {
            userViewsViewModel.refresh()
            recentlyAddedViewModel.refresh()
        }
    }

    // MARK: - Libraries

    @ViewBuilder
    private var librariesSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(userViewsViewModel.elements) { element in
                MediaLibraryRow(element: element)
            }
        }
    }

    // MARK: - Recently Added

    @ViewBuilder
    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.recentlyAdded.localizedCapitalized)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(recentlyAddedViewModel.elements) { entry in
                    MediaLibraryPosterCell(entry: entry)
                }
            }
        }
    }
}

// MARK: - Row

private struct MediaLibraryRow: View {

    @Namespace
    private var namespace

    @Router
    private var router

    let element: UserViewLibraryElement

    var body: some View {
        Button {
            element.libraryDidSelectElement(router: router, in: namespace)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(element.displayTitle)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 52)

                Divider()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: "item", in: namespace)
    }
}

// MARK: - Poster

private struct MediaLibraryPosterCell: View {

    @Namespace
    private var namespace

    @Router
    private var router

    let entry: ItemEntry

    private var imageSources: [ImageSource] {
        [entry.snapshot.imageSource(.primary, itemID: entry.itemID, environment: ImageSourceOptions(maxWidth: 240))]
            .compactMap(\.self)
    }

    var body: some View {
        Button {
            entry.libraryDidSelectElement(router: router, in: namespace)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Color.secondarySystemFill
                    .opacity(0.75)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay {
                        ImageView(imageSources)
                            .placeholder { imageSource in
                                DefaultPlaceholderView(blurHash: imageSource.blurHash)
                            }
                            .failure {
                                Image(systemName: entry.systemImage)
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .clipShape(.rect(cornerRadius: 8))
                    .matchedTransitionSource(id: "item", in: namespace)

                Text(entry.displayTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            entry.posterContextMenu
        }
    }
}
