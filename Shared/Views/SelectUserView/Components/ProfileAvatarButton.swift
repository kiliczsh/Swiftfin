//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import OrderedCollections
import SwiftUI

// MARK: - Avatar sizing

extension SelectUserView {

    /// "Who's Watching?" avatar metrics.
    enum ProfileMetrics {
        static let avatarSize: CGFloat = 120
        static let columnSpacing: CGFloat = 40
        static let rowSpacing: CGFloat = 28
        static let nameSpacing: CGFloat = 10

        static let fallbackGradient = LinearGradient(
            colors: [
                Color(red: 0x8E / 255, green: 0x8E / 255, blue: 0x93 / 255),
                Color(red: 0x63 / 255, green: 0x63 / 255, blue: 0x66 / 255),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - ProfileAvatarButton

extension SelectUserView {

    /// A circular, tvOS-style profile avatar with the user's name beneath it.
    struct ProfileAvatarButton: View {

        @Default(.accentColor)
        private var accentColor

        @Environment(\.isEditing)
        private var isEditing
        @Environment(\.isSelected)
        private var isSelected

        let user: UserState
        let server: ServerState
        let showServer: Bool
        let action: () -> Void
        let onDelete: () -> Void

        private var isDimmed: Bool {
            isEditing && !isSelected
        }

        private var initial: String {
            user.username.first.map { String($0).uppercased() } ?? .empty
        }

        var body: some View {
            Button(action: action) {
                VStack(spacing: ProfileMetrics.nameSpacing) {
                    avatar

                    VStack(spacing: 2) {
                        Text(user.username)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if showServer {
                            Text(server.name)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                    .frame(width: ProfileMetrics.avatarSize + ProfileMetrics.columnSpacing - 8)
                }
                .opacity(isDimmed ? 0.5 : 1)
                .contentShape(.rect)
            }
            .buttonStyle(ProfilePressStyle())
            .contextMenu {
                if !isEditing {
                    Button(
                        L10n.delete,
                        systemImage: "trash",
                        role: .destructive,
                        action: onDelete
                    )
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isEditing && isSelected ? .isSelected : [])
        }

        @ViewBuilder
        private var avatar: some View {
            RedrawOnNotificationView(
                .didChangeUserProfile,
                filter: { $0 == user.id }
            ) {
                ImageView(user.profileImageSource(client: server.client))
                    .pipeline(.Swiftfin.local)
                    .image { image in
                        image
                            .aspectRatio(contentMode: .fill)
                    }
                    .placeholder { _ in
                        fallbackAvatar
                    }
                    .failure {
                        fallbackAvatar
                    }
            }
            .frame(width: ProfileMetrics.avatarSize, height: ProfileMetrics.avatarSize)
            .clipShape(.circle)
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
            .overlay(alignment: .bottomTrailing) {
                if isEditing, isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34, height: 34)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(accentColor.overlayColor, accentColor)
                        .background(Circle().fill(.black).padding(2))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.2), value: isSelected)
        }

        private var fallbackAvatar: some View {
            ZStack {
                ProfileMetrics.fallbackGradient

                Text(initial)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - AddProfileButton

extension SelectUserView {

    /// The trailing "Add" cell of the profile grid. Behaves like `AddUserMenu`:
    /// a direct action when a single server is selected, otherwise a server menu.
    struct AddProfileButton: View {

        @Default(.selectUserServerSelection)
        private var serverSelection

        @Router
        private var router

        let servers: OrderedSet<ServerState>

        private func addUser(server: ServerState) {
            UIDevice.impact(.light)
            router.route(to: .userSignIn(server: server))
        }

        var body: some View {
            ConditionalMenu(tracking: serverSelection.server(from: servers)) { server in
                addUser(server: server)
            } menuContent: {
                Text(L10n.selectServer)

                ForEach(servers) { server in
                    Button {
                        addUser(server: server)
                    } label: {
                        Text(server.name)
                        Text(server.effectiveServerURL.absoluteString)
                    }
                }
            } label: {
                VStack(spacing: ProfileMetrics.nameSpacing) {
                    ZStack {
                        Circle()
                            .fill(ProfileMetrics.fallbackGradient)

                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: ProfileMetrics.avatarSize, height: ProfileMetrics.avatarSize)

                    Text(L10n.addUser)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: ProfileMetrics.avatarSize + ProfileMetrics.columnSpacing - 8)
                }
                .contentShape(.rect)
            }
            .menuOrder(.fixed)
            .buttonStyle(ProfilePressStyle())
        }
    }
}

// MARK: - ProfilePressStyle

extension SelectUserView {

    struct ProfilePressStyle: ButtonStyle {

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        }
    }
}
