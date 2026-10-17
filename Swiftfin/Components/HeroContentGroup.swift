//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import JellyfinAPI
import SwiftUI

// MARK: - Content Group

/// Full-bleed paging hero shown at the top of the iOS Home tab.
///
/// Shows resumable video items when available, otherwise recently added items.
struct HeroContentGroup: ContentGroup {

    let id = "hero-carousel"
    let viewModel: HeroContentGroupViewModel

    var _shouldBeResolved: Bool {
        viewModel.hasContent
    }

    init(
        resumeLibrary: ResumeItemsLibrary,
        recentlyAddedLibrary: RecentlyAddedLibrary
    ) {
        self.viewModel = HeroContentGroupViewModel(
            resumeLibrary: resumeLibrary,
            recentlyAddedLibrary: recentlyAddedLibrary
        )
    }

    func body(with viewModel: HeroContentGroupViewModel) -> some View {
        HeroCarouselView(viewModel: viewModel)
            .preference(
                key: ContentGroupCustomizationKey.self,
                value: .ignoreSafeAreaTop
            )
    }
}

/// Wraps a group so it only shows while the hero is showing resume items.
/// When there is nothing to resume the hero falls back to recently added items,
/// and the separate recently added row would just repeat them.
struct HeroDependentContentGroup<Base: ContentGroup>: ContentGroup {

    let base: Base
    let hero: HeroContentGroupViewModel

    var id: String {
        base.id
    }

    var viewModel: Base.ViewModel {
        base.viewModel
    }

    var _shouldBeResolved: Bool {
        base._shouldBeResolved && hero.hasResumeItems
    }

    func body(with viewModel: Base.ViewModel) -> Base.Body {
        base.body(with: viewModel)
    }
}

// MARK: - View Model

final class HeroContentGroupViewModel: ViewModel, WithRefresh {

    struct Background: WithRefresh {

        let viewModel: HeroContentGroupViewModel

        func refresh() {
            Task { await refresh() }
        }

        func refresh() async {
            async let resume: Void = viewModel.resumeViewModel.background.refresh()
            async let recentlyAdded: Void = viewModel.recentlyAddedViewModel.background.refresh()
            _ = await (resume, recentlyAdded)
        }
    }

    static let maxItems = 5

    let resumeViewModel: PagingLibraryViewModel<ResumeItemsLibrary>
    let recentlyAddedViewModel: PagingLibraryViewModel<RecentlyAddedLibrary>

    var background: Background {
        get { Background(viewModel: self) }
        set {}
    }

    var hasResumeItems: Bool {
        resumeViewModel.elements.isNotEmpty
    }

    var hasContent: Bool {
        hasResumeItems || recentlyAddedViewModel.elements.isNotEmpty
    }

    var entries: [ItemEntry] {
        let source = hasResumeItems ? resumeViewModel.elements.elements : recentlyAddedViewModel.elements.elements
        return Array(source.prefix(Self.maxItems))
    }

    init(
        resumeLibrary: ResumeItemsLibrary,
        recentlyAddedLibrary: RecentlyAddedLibrary
    ) {
        self.resumeViewModel = PagingLibraryViewModel(library: resumeLibrary, pageSize: Self.maxItems)
        self.recentlyAddedViewModel = PagingLibraryViewModel(library: recentlyAddedLibrary, pageSize: Self.maxItems)

        super.init()

        resumeViewModel.objectWillChange
            .merge(with: recentlyAddedViewModel.objectWillChange)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        Task {
            await refresh()
        }
    }

    func refresh() async {
        async let resume: Void = resumeViewModel.refresh()
        async let recentlyAdded: Void = recentlyAddedViewModel.refresh()

        _ = await (resume, recentlyAdded)
    }
}

// MARK: - Layout

private enum HeroLayout {

    static let height: CGFloat = 540
    static let logoMaxWidth: CGFloat = 300
    static let logoMaxHeight: CGFloat = 110
    static let buttonHeight: CGFloat = 50
    static let horizontalPadding: CGFloat = 32
}

// MARK: - Carousel

private struct HeroCarouselView: View {

    @ObservedObject
    var viewModel: HeroContentGroupViewModel

    @State
    private var selection: ItemEntry.ID?

    private var entries: [ItemEntry] {
        viewModel.entries
    }

    private var selectedIndex: Int {
        guard let selection else { return 0 }

        return entries.firstIndex { $0.id == selection } ?? 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(entries) { entry in
                        HeroPage(
                            item: entry.snapshot,
                            isResume: viewModel.hasResumeItems
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(entry.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selection)
            .scrollClipDisabled(false)

            if entries.count > 1 {
                HeroPageDots(
                    count: entries.count,
                    selectedIndex: selectedIndex
                )
                .padding(.bottom, 14)
            }
        }
        .frame(height: HeroLayout.height)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .onChange(of: entries.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) {
                self.selection = ids.first
            }
        }
    }
}

// MARK: - Page Dots

private struct HeroPageDots: View {

    let count: Int
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< count, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index == selectedIndex ? 1 : 0.35))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        .accessibilityHidden(true)
    }
}

// MARK: - Page

private struct HeroPage: View {

    @Router
    private var router

    let item: BaseItemDto
    let isResume: Bool

    private var displayTitle: String {
        if item.type == .episode, let seriesName = item.seriesName {
            return seriesName
        }
        return item.displayTitle
    }

    private var backdropSources: [ImageSource] {
        item.imageSources(
            for: .landscape,
            environment: .init(viewContext: .isBackdrop)
        )
    }

    private var logoSource: ImageSource? {
        let options = ImageSourceOptions(
            maxWidth: HeroLayout.logoMaxWidth,
            maxHeight: HeroLayout.logoMaxHeight
        )

        if item.type == .episode {
            return item.imageSource(
                .logo,
                itemID: item.parentLogoItemID,
                tag: item.parentLogoImageTag,
                environment: options
            )
        } else {
            return item.imageSource(
                .logo,
                itemID: item.id,
                environment: options
            )
        }
    }

    private var hasProgress: Bool {
        (item.userData?.playbackPositionTicks ?? 0) > 0
    }

    private var canPlayDirectly: Bool {
        switch item.type {
        case .episode, .movie, .video, .musicVideo:
            true
        default:
            false
        }
    }

    // MARK: Actions

    private func routeToItem() {
        router.route(to: .item(item: item))
    }

    private func play() {
        guard canPlayDirectly,
              let provider = item.getPlaybackItemProvider(userSession: nil)
        else {
            routeToItem()
            return
        }

        let queue: any MediaPlayerQueue? = item.type == .episode ?
            EpisodeMediaPlayerQueue(episode: item) : nil

        router.route(
            to: .videoPlayer(
                provider: provider,
                queue: queue
            )
        )
    }

    // MARK: Views

    private var backdrop: some View {
        ImageView(backdropSources)
            .failure {
                Color.black
            }
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .top) {
                // Status bar legibility
                LinearGradient(
                    colors: [.black.opacity(0.55), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.55), location: 0.6),
                        .init(color: .black.opacity(0.92), location: 0.85),
                        .init(color: .black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: routeToItem)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(displayTitle)
            .accessibilityAction(named: Text(displayTitle), routeToItem)
    }

    private var titleFallback: some View {
        Text(displayTitle.uppercased())
            .font(.system(size: 40, weight: .heavy))
            .tracking(-0.5)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
    }

    private var logo: some View {
        ImageView(logoSource)
            .placeholder { _ in
                titleFallback
            }
            .failure {
                titleFallback
            }
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: HeroLayout.logoMaxWidth, maxHeight: HeroLayout.logoMaxHeight)
            .accessibilityLabel(displayTitle)
    }

    @ViewBuilder
    private var kicker: some View {
        if isResume, hasProgress {
            DotHStack {
                Text(L10n.continue)

                if let progressLabel = item.progressLabel {
                    Text(L10n.timeLeftFormat(progressLabel))
                }
            }
        } else if isResume {
            Text(L10n.continue)
        } else {
            Text(L10n.recentlyAdded.localizedCapitalized)
        }
    }

    private var metadata: some View {
        DotHStack {
            if item.type == .episode {
                if let seasonEpisodeLabel = item.seasonEpisodeLabel {
                    Text(seasonEpisodeLabel)
                }

                if let name = item.name, name != displayTitle {
                    Text(name)
                        .lineLimit(1)
                }
            } else {
                if let genre = item.genres?.first {
                    Text(genre)
                }

                if let year = item.premiereDateYear {
                    Text(year)
                }
            }

            if let runtime = item.runtime {
                Text(runtime, format: .runtime)
            }
        }
        .lineLimit(1)
    }

    private var playButtonTitle: String {
        if isResume, hasProgress {
            return L10n.resume
        }
        return L10n.play
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button(action: play) {
                Label(playButtonTitle, systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: HeroLayout.buttonHeight)
                    .background(.white, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(action: routeToItem) {
                Image(systemName: "info")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: HeroLayout.buttonHeight, height: HeroLayout.buttonHeight)
                    .backport
                    .glassEffect(.regular, in: .circle)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(displayTitle))
        }
        .frame(maxWidth: 320)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            backdrop

            VStack(spacing: 10) {
                kicker
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))

                logo

                metadata
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                buttons
                    .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, HeroLayout.horizontalPadding)
            .padding(.bottom, 44)
        }
        .frame(height: HeroLayout.height)
        .clipped()
    }
}
