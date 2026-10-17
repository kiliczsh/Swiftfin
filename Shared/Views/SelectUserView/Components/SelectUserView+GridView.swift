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

// TODO: remember last focused user for tvOS focus

extension SelectUserView {

    struct GridView: PlatformView {

        @Binding
        private var isEditing: Bool
        @Binding
        private var selectedUsers: Set<UserState>

        private let onDelete: (UserState) -> Void
        private let action: (UserState) -> Void
        private let serverSelection: SelectUserServerSelection
        private let servers: OrderedSet<ServerState>
        private let userItems: [UserItem]

        init(
            userItems: [UserItem],
            isEditing: Binding<Bool>,
            selectedUsers: Binding<Set<UserState>>,
            serverSelection: SelectUserServerSelection,
            servers: OrderedSet<ServerState> = [],
            action: @escaping (UserState) -> Void,
            onDelete: @escaping (UserState) -> Void
        ) {
            self.userItems = userItems
            self._isEditing = isEditing
            self._selectedUsers = selectedUsers
            self.serverSelection = serverSelection
            self.servers = servers
            self.action = action
            self.onDelete = onDelete
        }

        @ViewBuilder
        private func userGridButton(for item: UserItem) -> some View {
            UserButton(
                user: item.user,
                server: item.server,
                showServer: serverSelection == .all
            ) {
                if isEditing {
                    selectedUsers.toggle(value: item.user)
                } else {
                    action(item.user)
                }
            } onDelete: {
                onDelete(item.user)
            }
            .isSelected(selectedUsers.contains(item.user))
        }

        // MARK: - iOS: "Who's Watching?"

        @ViewBuilder
        private func profileButton(for item: UserItem) -> some View {
            ProfileAvatarButton(
                user: item.user,
                server: item.server,
                showServer: serverSelection == .all
            ) {
                if isEditing {
                    UIDevice.impact(.light)
                    selectedUsers.toggle(value: item.user)
                } else {
                    action(item.user)
                }
            } onDelete: {
                onDelete(item.user)
            }
            .isSelected(selectedUsers.contains(item.user))
        }

        private var profileColumnCount: Int {
            UIDevice.isPhone ? 2 : 4
        }

        private var showsAddProfile: Bool {
            !isEditing && servers.isNotEmpty
        }

        /// Cell indices split into rows; the last index is the "Add" cell when shown.
        private var profileRows: [[Int]] {
            let count = userItems.count + (showsAddProfile ? 1 : 0)
            return stride(from: 0, to: count, by: profileColumnCount).map { start in
                Array(start ..< min(start + profileColumnCount, count))
            }
        }

        @ViewBuilder
        private func profileCell(at index: Int) -> some View {
            if index < userItems.count {
                profileButton(for: userItems[index])
            } else {
                AddProfileButton(servers: servers)
            }
        }

        var iOSView: some View {
            VStack(spacing: 36) {
                Text(L10n.whosWatching)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 16)

                // Rows are centered individually so a short last row (or a lone
                // "Add" cell) sits in the middle instead of hugging the leading edge.
                VStack(spacing: ProfileMetrics.rowSpacing) {
                    ForEach(profileRows, id: \.self) { row in
                        HStack(alignment: .top, spacing: ProfileMetrics.columnSpacing) {
                            ForEach(row, id: \.self) { index in
                                profileCell(at: index)
                            }
                        }
                    }
                }
                .animation(.snappy(duration: 0.25), value: isEditing)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .scrollIfLargerThanContainer(axes: .vertical, padding: 100)
        }

        var tvOSView: some View {
            HStack(spacing: EdgeInsets.itemSpacing) {
                ForEach(userItems, id: \.user.id) { item in
                    userGridButton(for: item)
                        .frame(width: 300)
                }
            }
            .edgePadding(.horizontal)
            .focusSection()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollIfLargerThanContainer(axes: .horizontal)
            #if os(tvOS)
            .scrollClipDisabled()
            #endif
        }
    }
}
