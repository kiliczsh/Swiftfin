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

extension SelectUserView {

    struct Toolbar: View {

        @Default(.selectUserDisplayType)
        private var userListDisplayType

        @Environment(\.horizontalSizeClass)
        private var horizontalSizeClass

        @Binding
        private var isEditing: Bool
        @Binding
        private var selectedUsers: Set<UserState>

        @FocusState
        private var isCenterButtonFocused: Bool

        private let servers: OrderedSet<ServerState>
        private let allUsers: [UserItem]
        private let onDelete: () -> Void

        private func toggleUsers() {
            if selectedUsers.count == allUsers.count {
                selectedUsers.removeAll()
            } else {
                selectedUsers = Set(allUsers.map(\.user))
            }
        }

        private let buttonHeight: CGFloat = UIDevice.isTV ? 75 : 44

        /// On iOS the profile grid carries its own "Add" cell, so the
        /// separate add button is only needed for the list layout.
        private var showsAddUserButton: Bool {
            #if os(iOS)
            return allUsers.isNotEmpty && userListDisplayType == .list
            #else
            return true
            #endif
        }

        init(
            servers: OrderedSet<ServerState>,
            allUsers: [UserItem],
            isEditing: Binding<Bool>,
            selectedUsers: Binding<Set<UserState>>,
            onDelete: @escaping () -> Void
        ) {
            self.servers = servers
            self.allUsers = allUsers
            self._isEditing = isEditing
            self._selectedUsers = selectedUsers
            self.onDelete = onDelete
        }

        var body: some View {
            if horizontalSizeClass == .compact {
                compactView
            } else {
                regularView
            }
        }

        @ViewBuilder
        private var compactView: some View {
            if !isEditing {
                HStack(spacing: 10) {
                    ServerMenu(servers: servers)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)

                    if showsAddUserButton {
                        AddUserMenu(servers: servers)
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }

        private var regularView: some View {
            HStack(alignment: .top, spacing: UIDevice.isTV ? 32 : nil) {
                if isEditing {
                    editView
                } else {
                    regularContentView
                }
            }
            .animation(.linear(duration: 0.1), value: selectedUsers.isNotEmpty)
            .frame(height: buttonHeight)
            .frame(maxWidth: .infinity)
            .focusSection()
            .edgePadding([.bottom, .horizontal])
            .defaultFocus(
                $isCenterButtonFocused,
                true,
                priority: .userInitiated
            )
        }

        @ViewBuilder
        private var editView: some View {
            Button(action: toggleUsers) {
                Text(selectedUsers.count == allUsers.count ? L10n.removeAll : L10n.selectAll)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 100, maxWidth: 300)

            Button {
                isEditing = false
            } label: {
                Text(L10n.cancel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 100, maxWidth: 300)
            .focused($isCenterButtonFocused)

            Button(role: .destructive, action: onDelete) {
                Text(L10n.delete)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 100, maxWidth: 300)
            .disabled(selectedUsers.isEmpty)
        }

        @ViewBuilder
        private var regularContentView: some View {
            Menu {
                AdvancedMenuContent(
                    hasUsers: allUsers.isNotEmpty,
                    isEditing: $isEditing
                )
            } label: {
                Label(L10n.advanced, systemImage: "gearshape.fill")
                    .labelStyle(.iconOnly)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .foregroundStyle(.primary, .secondary)
            .menuOrder(.fixed)
            .symbolRenderingMode(.monochrome)
            .frame(width: buttonHeight, height: buttonHeight)
            .buttonBorderShape(.circle)
            .backport
            .glassEffect(in: .circle)

            ServerMenu(servers: servers)
                .frame(maxWidth: UIDevice.isTV ? 600 : 400)
                .frame(height: buttonHeight)
                .focused($isCenterButtonFocused)

            AddUserMenu(servers: servers)
                .frame(width: buttonHeight, height: buttonHeight)
                .hidden(!showsAddUserButton || allUsers.isEmpty)
        }
    }
}
