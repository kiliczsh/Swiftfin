//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

/// Horizontal row of circular cast & crew portraits with the name and role
/// centered below each one.
struct CastAndCrewGroup: ContentGroup {

    let displayTitle: String
    let id: String
    let people: [BaseItemPerson]

    func body(with viewModel: Empty) -> Body {
        Body(displayTitle: displayTitle, people: people)
    }

    struct Body: View {

        @Namespace
        private var namespace

        @Router
        private var router

        let displayTitle: String
        let people: [BaseItemPerson]

        private var portraitSize: CGFloat {
            UIDevice.isTV ? 160 : 76
        }

        private var cellWidth: CGFloat {
            UIDevice.isTV ? 200 : 92
        }

        private func routeToAll() {
            router.route(
                to: .library(
                    library: StaticLibrary(
                        title: displayTitle,
                        id: "cast-and-crew",
                        elements: people
                    ),
                    displayTitle: displayTitle
                )
            )
        }

        var body: some View {
            ContentGroupSection {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: UIDevice.isTV ? 40 : 12) {
                        ForEach(Array(people.enumerated()), id: \.offset) { _, person in
                            PersonCell(
                                person: person,
                                portraitSize: portraitSize,
                                namespace: namespace
                            )
                            .frame(width: cellWidth)
                        }
                    }
                    .edgePadding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            } header: {
                DetailSectionHeader(displayTitle, action: routeToAll)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(displayTitle)
        }
    }

    private struct PersonCell: View {

        @Router
        private var router

        let person: BaseItemPerson
        let portraitSize: CGFloat
        let namespace: Namespace.ID

        private var initials: String {
            let parts = (person.name ?? "")
                .split(separator: " ")
                .compactMap(\.first)
                .prefix(2)

            return String(parts).localizedUppercase
        }

        var body: some View {
            Button {
                person.libraryDidSelectElement(router: router, in: namespace)
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.17))

                        Text(initials)
                            .font(.system(size: portraitSize * 0.3, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ImageView(
                            person.imageSources(for: .portrait, size: .small)
                        )
                        .image { (image: Image) in
                            image
                                .aspectRatio(contentMode: .fill)
                        }
                        .placeholder { _ in
                            Color.clear
                        }
                        .failure {
                            Color.clear
                        }
                        .accessibilityHidden(true)
                    }
                    .frame(width: portraitSize, height: portraitSize)
                    .clipShape(.circle)
                    .matchedTransitionSource(id: "item", in: namespace)

                    VStack(spacing: 2) {
                        Text(person.displayTitle)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if let role = person.displayRole, role.isNotEmpty {
                            Text(role)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .contextMenu {
                person.posterContextMenu
            }
            .accessibilityElement(children: .combine)
        }
    }
}
