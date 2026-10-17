//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension SeriesEpisodeContentGroup {

    struct SeasonSelector: PlatformView {

        let seasons: [PagingLibraryViewModel<EpisodeLibrary>]

        @Binding
        var selection: PagingLibraryViewModel<EpisodeLibrary>.ID?

        let preferredSelection: PagingLibraryViewModel<EpisodeLibrary>.ID?

        @FocusState
        private var focusedSeason: PagingLibraryViewModel<EpisodeLibrary>.ID?

        private var selectedSeason: PagingLibraryViewModel<EpisodeLibrary>? {
            seasons.first { $0.id == selection }
        }

        @ViewBuilder
        private func title(_ value: String) -> some View {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .edgePadding(.horizontal)
        }

        var tvOSView: some View {
            if seasons.isEmpty {
                title(L10n.episodes)
            } else {
                ScrollView(.horizontal) {
                    SelectionTrack(
                        seasons,
                        selection: selection,
                        focus: $focusedSeason
                    ) { season in
                        selection = season.id
                    }
                    .controlSize(.large)
                    .edgePadding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .focusSection()
                .defaultFocus(
                    $focusedSeason,
                    preferredSelection,
                    priority: .userInitiated
                )
                .task(id: focusedSeason) {
                    await selectSeasonAfterFocusDebounce(focusedSeason)
                }
            }
        }

        @MainActor
        private func selectSeasonAfterFocusDebounce(
            _ seasonID: PagingLibraryViewModel<EpisodeLibrary>.ID?
        ) async {
            guard let seasonID, seasonID != selection else { return }

            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

            guard seasonID == focusedSeason,
                  seasonID != selection,
                  seasons.contains(where: { $0.id == seasonID })
            else { return }

            selection = seasonID
        }

        var iOSView: some View {
            if seasons.count <= 1 {
                title(selectedSeason?.library.parent.displayTitle ?? L10n.episodes)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(seasons) { season in
                                SeasonPill(
                                    title: season.library.parent.displayTitle,
                                    isSelected: season.id == selection
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selection = season.id
                                    }
                                }
                                .id(season.id)
                            }
                        }
                        .edgePadding(.horizontal)
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .onAppear {
                        if let selection {
                            proxy.scrollTo(selection, anchor: .center)
                        }
                    }
                }
                .accessibilityLabel(L10n.seasons)
            }
        }
    }
}

extension SeriesEpisodeContentGroup {

    /// Season capsule: inverted (white/black in dark mode) when selected, grey (#1C1C1E in dark mode) otherwise.
    struct SeasonPill: View {

        let title: String
        let isSelected: Bool
        let action: () -> Void

        private var unselectedColor: Color {
            #if os(iOS)
            Color(uiColor: .secondarySystemBackground)
            #else
            Color.secondary.opacity(0.3)
            #endif
        }

        private var selectedForegroundColor: Color {
            #if os(iOS)
            Color(uiColor: .systemBackground)
            #else
            Color.black
            #endif
        }

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? selectedForegroundColor : Color.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(
                        isSelected ? Color.primary : unselectedColor,
                        in: .capsule
                    )
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}
