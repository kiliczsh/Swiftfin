//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

#if os(iOS)

extension ItemView {

    /// iPhone hero action row: a wide white Play/Resume capsule followed by
    /// a small number of glass circle buttons. Remaining bar buttons move into
    /// the navigation bar ellipsis menu (see `split(_:)`).
    struct CompactActionBar: View {

        static let maximumCircleButtons = 2

        @ObservedObject
        var provider: ItemContentGroupProvider

        private var buttonConfiguration = ItemActionButtons.Configuration()

        init(provider: ItemContentGroupProvider) {
            self.provider = provider
        }

        /// Moves bar buttons beyond `maximumCircleButtons` into the overflow menu.
        static func split(
            _ resolved: (visible: [ItemActionButton], overflow: [ItemActionButton], menu: [ItemActionButton])
        ) -> (visible: [ItemActionButton], overflow: [ItemActionButton], menu: [ItemActionButton]) {
            let visible = Array(resolved.visible.prefix(maximumCircleButtons))
            let overflow = Array(resolved.visible.dropFirst(visible.count)) + resolved.overflow

            return (visible: visible, overflow: overflow, menu: resolved.menu)
        }

        var body: some View {
            let (visible, _, _) = Self.split(buttonConfiguration.resolvedButtons(for: provider))

            HStack(spacing: 10) {
                if provider.item.presentPlayButton {
                    PlayButton(provider: provider, style: .prominent)
                        .frame(maxWidth: .infinity)
                }

                ForEach(visible) { button in
                    ItemActionButtons.view(for: button)
                        .labelStyle(CircleActionLabelStyle(activeColor: button.activeColor))
                }
            }
            .frame(height: 50)
            .environmentObject(provider)
            .buttonBorderShape(.circle)
            .buttonStyle(BasicHoverButtonStyle())
        }
    }

    struct CircleActionLabelStyle: LabelStyle {

        @Environment(\.isSelected)
        private var isSelected

        var activeColor: Color?

        private var isActive: Bool {
            isSelected && activeColor != nil
        }

        func makeBody(configuration: Configuration) -> some View {
            Label(configuration)
                .labelStyle(.iconOnly)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? Color.black : Color.white)
                .frame(width: 50, height: 50)
                .background {
                    if isActive {
                        Circle().fill(Color.white)
                    }
                }
                .backport
                .glassEffect(isActive ? .identity : .regular, in: .circle)
                .contentShape(.circle)
        }
    }
}

#endif
