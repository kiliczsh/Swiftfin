//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// Section header for item detail rows: bold title with an optional trailing chevron.
struct DetailSectionHeader: View {

    let title: String
    let action: (() -> Void)?

    init(_ title: String, action: (() -> Void)? = nil) {
        self.title = title
        self.action = action
    }

    @ViewBuilder
    private var titleView: some View {
        #if os(tvOS)
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
        #else
        Text(title)
            .font(.title2.bold())
            .lineLimit(1)
        #endif
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        titleView

                        Image(systemName: "chevron.forward")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary, .secondary)
            } else {
                titleView
            }
        }
        .accessibilityAddTraits(.isHeader)
        .edgePadding(.horizontal)
    }
}
