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

    struct ServerMenu: View {

        @Default(.selectUserServerSelection)
        private var serverSelection

        @Environment(\.horizontalSizeClass)
        private var horizontalSizeClass

        @Router
        private var router

        let servers: OrderedSet<ServerState>

        var body: some View {
            Menu {
                Section {
                    Button(L10n.addServer, systemImage: "plus") {
                        router.route(to: .connectToServer)
                    }

                    if let selectedServer = serverSelection.server(from: servers) {
                        Button(L10n.editServer, systemImage: "server.rack") {
                            router.route(
                                to: .editLocalServer(server: selectedServer, isEditing: true),
                                style: .sheet
                            )
                        }
                    }
                }

                Picker(L10n.servers, selection: $serverSelection) {

                    if servers.count > 1 {
                        Label(L10n.allServers, systemImage: "person.2.fill")
                            .tag(SelectUserServerSelection.all)
                    }

                    ForEach(servers) { server in
                        Button {} label: {
                            Text(server.name)
                            Text(server.effectiveServerURL.absoluteString)
                        }
                        .tag(SelectUserServerSelection.server(id: server.id))
                    }
                }
            } label: {
                #if os(iOS)
                iOSLabel
                #else
                defaultLabel
                #endif
            }
            .foregroundStyle(.primary, .secondary)
            .menuOrder(.fixed)
            .symbolRenderingMode(.monochrome)
            .backport
            .glassEffect(in: .capsule)
        }

        private var selectedServerName: String {
            switch serverSelection {
            case .all:
                L10n.allServers
            case let .server(id):
                servers.first(where: { $0.id == id })?.name ?? L10n.unknown
            }
        }

        /// tvOS-style capsule label: server name + chevron, no icon.
        private var iOSLabel: some View {
            HStack(spacing: 6) {
                Text(selectedServerName)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.capsule)
        }

        private var defaultLabel: some View {
            HStack(spacing: horizontalSizeClass == .compact ? nil : 16) {
                switch serverSelection {
                case .all:
                    Label(L10n.allServers, systemImage: "person.2.fill")
                case let .server(id):
                    if let server = servers.first(where: { $0.id == id }) {
                        Label(server.name, systemImage: "server.rack")
                    } else {
                        Label(L10n.unknown, systemImage: "server.rack")
                    }
                }

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
