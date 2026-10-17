//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

extension ItemView {

    /// iPhone hero header: full-bleed key art that runs under the status bar,
    /// a centered logo (or heavy uppercase title), metadata, outlined badges,
    /// a white Play/Resume capsule with glass circle actions and the description.
    struct CompactEnhancedHeaderContentGroup: ContentGroup {

        let id: String = ItemView.Component.header
        let provider: ItemContentGroupProvider

        func body(with viewModel: Empty) -> Body {
            Body(provider: provider)
        }

        struct Body: View {

            @ObservedObject
            var provider: ItemContentGroupProvider

            @StoredValue(.User.itemViewAttributes)
            private var attributes

            /// Height of the hero area in content coordinates (below the navigation bar).
            /// The background is stretched to also cover the bar and status bar.
            private let heroHeight: CGFloat = 440

            /// How far the art extends above the content's top edge, under the status bar.
            private static let underStatusBarExtent: CGFloat = 120

            // MARK: - Title

            @ViewBuilder
            private var fallbackTitle: some View {
                Text(provider.item.displayTitle.localizedUppercase)
                    .font(.system(size: 44, weight: .black))
                    .tracking(-1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            @ViewBuilder
            private var logo: some View {
                ImageView(
                    provider.item.imageSource(
                        .logo,
                        itemID: provider.item.id,
                        environment: ImageSourceOptions(maxHeight: 200)
                    )
                )
                .placeholder { _ in
                    Color.clear
                        .frame(height: 90)
                }
                .failure {
                    fallbackTitle
                }
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 100, alignment: .bottom)
                .shadow(color: .black.opacity(0.3), radius: 10)
                .accessibilityLabel(provider.item.displayTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityRemoveTraits(.isImage)
            }

            // MARK: - Hero content

            @ViewBuilder
            private var heroContent: some View {
                VStack(alignment: .center, spacing: 10) {
                    logo

                    MetadataHStack(item: provider.item, font: .subheadline)
                        .foregroundStyle(.white.opacity(0.75))

                    ItemView.AttributesHStack(
                        attributes: attributes,
                        item: provider.item,
                        selectedMediaSource: provider.mediaPlayerItemProvider?.mediaSource,
                        alignment: .center,
                        prefersOutlineBadges: true
                    )
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight, alignment: .bottom)
            }

            // MARK: - Background

            @ViewBuilder
            private var heroBackground: some View {
                VStack(spacing: 0) {
                    Color.black
                        .frame(height: heroHeight + 60 + Self.underStatusBarExtent)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            ImageView(provider.item.imageSource(
                                .backdrop,
                                itemID: provider.item.id,
                                environment: ImageSourceOptions(maxWidth: 1320)
                            ))
                            .image { (image: Image) in
                                image
                                    .aspectRatio(contentMode: .fill)
                            }
                            .placeholder { _ in
                                Color.black
                            }
                        }
                        .clipped()
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [.black.opacity(0.55), .black.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 140)
                        }
                        .overlay(alignment: .bottom) {
                            // Fade fully to black so the art never ends in a hard edge.
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0), location: 0),
                                    .init(color: .black.opacity(0.6), location: 0.5),
                                    .init(color: .black, location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 300)
                        }
                        // Run the art up under the status bar instead of leaving a black band.
                        .padding(.top, -Self.underStatusBarExtent)

                    // Actions and description sit on plain black below the art.
                    Color.black
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .accessibilityHidden(true)
            }

            // MARK: - Body

            var body: some View {
                VStack(alignment: .leading, spacing: 20) {
                    heroContent

                    #if os(iOS)
                    ItemView.CompactActionBar(provider: provider)
                    #else
                    ItemView.ActionBar(provider: provider)
                    #endif

                    ItemView.Description(item: provider.item, isInline: true)
                }
                .edgePadding(.horizontal)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .colorScheme(.dark)
                .backgroundParallaxHeader(multiplier: 0.85) {
                    heroBackground
                }
            }
        }
    }
}
