//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension ItemView {

    struct Description: View {

        @Router
        private var router

        @SharedBaseItem
        var item: BaseItemDto

        /// Tagline and overview flow as a single paragraph: bold primary tagline
        /// followed by the secondary overview.
        var isInline: Bool = false

        private var tagline: String? {
            item.taglines?.first(where: \.isNotEmpty)
        }

        private var overview: String? {
            item.overview.flatMap { $0.isNotEmpty ? $0 : nil }
        }

        private var inlineText: Text {
            var text = Text(verbatim: "")

            if let tagline {
                text = Text(tagline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            if let overview {
                let overviewText = Text(overview)
                    .foregroundStyle(.secondary)

                // Joins two styled texts with a space; nothing here is user-facing copy to localize.
                // swiftlint:disable:next hard_coded_display_string
                text = tagline == nil ? overviewText : Text("\(text) \(overviewText)")
            }

            return text
        }

        @ViewBuilder
        private var inlineBody: some View {
            Button {
                router.route(to: .itemOverview(item: item))
            } label: {
                SeeMoreText(inlineText)
                    .font(.callout)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .disabled(overview == nil)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var isPresented: Bool {
            item.taglines?.contains(where: \.isNotEmpty) == true ||
                item.overview?.isNotEmpty == true
        }

        var body: some View {
            if isPresented, isInline {
                inlineBody
            } else if isPresented {
                VStack(alignment: .leading, spacing: 5) {
                    if let firstTagline = item.taglines?.first(where: \.isNotEmpty) {
                        Text(firstTagline)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    if let itemOverview = item.overview, itemOverview.isNotEmpty {
                        InlinePlatformView {
                            Button {
                                router.route(to: .itemOverview(item: item))
                            } label: {
                                SeeMoreText(itemOverview)
                                    .font(.footnote)
                                    .lineLimit(3)
                            }
                            .buttonStyle(.plain)
                        } tvOSView: {
                            Text(itemOverview)
                                .font(.footnote)
                                .lineLimit(3)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
