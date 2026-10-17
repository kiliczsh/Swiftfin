//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct AboutItemGroup: ContentGroup {

    let displayTitle: String
    let id: String
    @SharedBaseItem
    var item: BaseItemDto

    func body(with viewModel: Empty) -> Body {
        Body(item: item)
    }

    struct Body: View {

        @Router
        private var router

        @SharedBaseItem
        var item: BaseItemDto

        private struct AboutCard<Content: View>: View {

            let title: String
            let subtitle: String?
            let action: () -> Void
            let content: Content

            init(
                title: String,
                subtitle: String? = nil,
                action: @escaping () -> Void,
                @ViewBuilder content: () -> Content
            ) {
                self.title = title
                self.subtitle = subtitle
                self.action = action
                self.content = content()
            }

            var body: some View {
                Button(action: action) {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .topLeading)

                            if let subtitle, subtitle.isNotEmpty {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .topLeading)

                        content
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .backport
                    .glassEffect(
                        in: .rect(
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )
                }
                .foregroundStyle(.primary, .secondary)
                .buttonStyle(.card)
                .buttonBorderShape(.roundedRectangle(radius: 20))
            }
        }

        @ViewBuilder
        private var descriptionCard: some View {
            let subtitle = item.taglines?.first ?? item.parentTitle
            let hasOverviewContent = item.taglines?.first?.isNotEmpty == true || item.overview?.isNotEmpty == true

            AboutCard(
                title: item.displayTitle,
                subtitle: subtitle
            ) {
                if hasOverviewContent {
                    router.route(to: .itemOverview(item: item))
                }
            } content: {
                if let overview = item.overview, overview.isNotEmpty {
                    SeeMoreText(overview)
                        .font(.footnote)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
            }
            .aspectRatio(cardAspectRatio, contentMode: .fit)
        }

        @ViewBuilder
        private func mediaSourceCard(for mediaSource: MediaSourceInfo, hasMultipleSources: Bool) -> some View {
            let subtitle = hasMultipleSources ? mediaSource.displayTitle : nil

            AboutCard(
                title: L10n.media,
                subtitle: subtitle
            ) {
                router.route(to: .mediaSourceInfo(source: mediaSource))
            } content: {
                if let mediaStreams = mediaSource.mediaStreams {
                    let text = mediaStreams.compactMap(\.displayTitle)
                        .joined(separator: ", ")

                    Text(text)
                        .font(.footnote)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
            }
            .aspectRatio(cardAspectRatio, contentMode: .fit)
        }

        private func ratingsCard(criticRating: Float, communityRating: Float) -> some View {
            AboutCard(
                title: L10n.ratings,
                action: {}
            ) {
                if criticRating > -1 {
                    HStack {
                        Group {
                            if criticRating >= 60 {
                                Image(.tomatoFresh)
                                    .symbolRenderingMode(.multicolor)
                                    .foregroundStyle(.green, .red)
                            } else {
                                Image(.tomatoRotten)
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.green)
                            }
                        }
                        .font(.largeTitle)

                        // swiftlint:disable:next hard_coded_display_string
                        Text("\(criticRating, specifier: "%.0f")")
                            .fontWeight(.semibold)
                    }
                }

                if communityRating > -1 {
                    HStack {
                        Image(systemName: "star.fill")
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(.yellow)
                            .font(.largeTitle)

                        // swiftlint:disable:next hard_coded_display_string
                        Text("\(communityRating, specifier: "%.1f")")
                            .fontWeight(.semibold)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }

        private var cardHeight: CGFloat {
            #if os(tvOS)
            400
            #else
            200
            #endif
        }

        private let cardAspectRatio: CGFloat = 1.77

        var body: some View {
            #if os(iOS)
            InformationGrid(item: item)
            #else
            cardsBody
            #endif
        }

        private var cardsBody: some View {
            ContentGroupSection {
                ScrollView(.horizontal) {
                    HStack(spacing: EdgeInsets.itemSpacing) {
                        descriptionCard

                        if let mediaSources = item.mediaSources {
                            ForEach(mediaSources) { source in
                                mediaSourceCard(for: source, hasMultipleSources: mediaSources.count > 1)
                            }
                        }

                        if item.criticRating != nil || item.communityRating != nil {
                            ratingsCard(
                                criticRating: item.criticRating ?? -1,
                                communityRating: item.communityRating ?? -1
                            )
                        }
                    }
                    .edgePadding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                #if os(tvOS)
                .withViewContext(.isOverComplexContent)
                #endif
                .frame(height: cardHeight)
                .frame(maxWidth: .infinity)
            } header: {
                Text(L10n.about)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                    .edgePadding(.horizontal)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.about)
        }
    }
}

#if os(iOS)

// MARK: - Information grid

extension AboutItemGroup {

    /// Two-column label/value grid describing the item: release, runtime,
    /// rating, genre, media streams and versions.
    struct InformationGrid: View {

        private struct Entry: Identifiable {

            let id: String
            let title: String
            let value: String
            var action: (() -> Void)?
        }

        @Router
        private var router

        @SharedBaseItem
        var item: BaseItemDto

        private var mediaSource: MediaSourceInfo? {
            item.mediaSources?.first
        }

        private func streams(_ type: MediaStreamType) -> [MediaStream] {
            (mediaSource?.mediaStreams ?? item.mediaStreams ?? [])
                .filter { $0.type == type }
        }

        private func joined(_ values: [String], limit: Int = 3) -> String? {
            var unique: [String] = []
            for value in values where value.isNotEmpty && !unique.contains(value) {
                unique.append(value)
            }

            guard unique.isNotEmpty else { return nil }

            let shown = unique.prefix(limit).joined(separator: " · ")
            return unique.count > limit ? "\(shown) +\(unique.count - limit)" : shown
        }

        private var released: String? {
            if item.type == .series {
                guard let start = item.productionYear ?? item.premiereDate.map({ Calendar.current.component(.year, from: $0) })
                else { return nil }

                if let end = item.endDate.map({ Calendar.current.component(.year, from: $0) }), end != start {
                    return "\(start)–\(end)"
                }

                return String(start)
            }

            return item.premiereDate?.formatted(date: .abbreviated, time: .omitted)
                ?? item.productionYear.map(String.init)
        }

        private var ratings: String? {
            var parts: [String] = []

            if let communityRating = item.communityRating {
                parts.append("★ \(communityRating.formatted(.number.precision(.fractionLength(1))))")
            }

            if let criticRating = item.criticRating {
                parts.append("\(Int(criticRating))%")
            }

            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }

        private var entries: [Entry] {
            var entries: [Entry] = []

            func add(_ id: String, _ title: String, _ value: String?, action: (() -> Void)? = nil) {
                guard let value, value.isNotEmpty else { return }

                entries.append(Entry(id: id, title: title, value: value, action: action))
            }

            let sourceAction: (() -> Void)? = mediaSource.map { source in
                { router.route(to: .mediaSourceInfo(source: source)) }
            }

            add("released", L10n.releaseDate, released)
            add("runtime", L10n.runtime, item.runtime?.formatted(.hourMinuteAbbreviated))
            add("rated", L10n.parentalRating, item.officialRating)
            add("ratings", L10n.ratings, ratings)
            // Genres and studios are shown as tappable pills below this section.
            add(
                "director",
                L10n.director,
                joined(item.people?.filter { $0.type == .director }.compactMap(\.name) ?? [], limit: 2)
            )
            add("video", L10n.video, joined(streams(.video).compactMap(\.displayTitle), limit: 1), action: sourceAction)
            add("audio", L10n.audio, joined(streams(.audio).compactMap { $0.language ?? $0.displayTitle }), action: sourceAction)
            add("subtitles", L10n.subtitles, joined(streams(.subtitle).compactMap { $0.language ?? $0.displayTitle }, limit: 4))

            if let mediaSources = item.mediaSources, mediaSources.count > 1 {
                add("versions", L10n.version, joined(mediaSources.compactMap(\.displayTitle), limit: 2))
            }

            return entries
        }

        @ViewBuilder
        private func cell(_ entry: Entry) -> some View {
            let content = VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(entry.value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)

            if let action = entry.action {
                Button(action: action) {
                    content
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }

        var body: some View {
            let items = entries

            if items.isNotEmpty {
                ContentGroupSection {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16, alignment: .topLeading),
                            GridItem(.flexible(), spacing: 16, alignment: .topLeading),
                        ],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(items) { entry in
                            cell(entry)
                        }
                    }
                    .edgePadding(.horizontal)
                } header: {
                    DetailSectionHeader(L10n.information)
                }
                .padding(.top, 8)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(L10n.information)
            }
        }
    }
}

#endif
