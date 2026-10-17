//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import Logging
import SwiftUI

struct PlayButton: View {

    enum Style {

        /// Accent-tinted glass capsule
        case standard
        /// Solid white capsule with black text and inline remaining time
        case prominent
    }

    @Default(.accentColor)
    private var accentColor

    @ObservedObject
    var provider: ItemContentGroupProvider

    @Router
    private var router

    var style: Style = .standard

    init(provider: ItemContentGroupProvider, style: Style = .standard) {
        self.provider = provider
        self.style = style
    }

    private var mediaSource: String? {
        guard provider.mediaPlayerItemProvider?.item.mediaSources?.count ?? 0 > 1 else { return nil }

        return provider.mediaPlayerItemProvider?.mediaSource?.displayTitle
    }

    private func play(fromBeginning: Bool = false) {
        let mediaPlayerItemProvider = if fromBeginning {
            provider.mediaPlayerItemProvider?.modifyingItem {
                $0.userData?.playbackPositionTicks = 0
            }
        } else {
            provider.mediaPlayerItemProvider
        }

        guard let mediaPlayerItemProvider else {
            provider.logger.error("Play selected with no playback item provider")
            return
        }

        let queue: any MediaPlayerQueue? = mediaPlayerItemProvider.item.type == .episode ?
            EpisodeMediaPlayerQueue(episode: mediaPlayerItemProvider.item) : nil

        router.route(
            to: .videoPlayer(
                provider: mediaPlayerItemProvider,
                queue: queue
            )
        )
    }

    // MARK: - Prominent

    private var playbackItem: BaseItemDto? {
        provider.mediaPlayerItemProvider?.item
    }

    /// "Resume" / "Play", prefixed episode locator for series and seasons.
    private var prominentTitle: String {
        guard let playbackItem else { return L10n.play }

        if playbackItem.isUnaired || playbackItem.hasAired || playbackItem.isMissing {
            return playbackItem.playButtonLabel
        }

        let hasProgress = (playbackItem.userData?.playbackPositionTicks ?? 0) > 0
        let base = hasProgress ? L10n.resume : L10n.play

        if provider.item.type == .series || provider.item.type == .season,
           let seasonEpisodeLabel = playbackItem.seasonEpisodeLabel
        {
            return "\(base) \(seasonEpisodeLabel)"
        }

        return base
    }

    private var prominentRemaining: String? {
        guard let playbackItem,
              !playbackItem.isUnaired, !playbackItem.hasAired, !playbackItem.isMissing,
              (playbackItem.userData?.playbackPositionTicks ?? 0) > 0,
              let progressLabel = playbackItem.progressLabel
        else { return nil }

        return L10n.posterAccessibilityRemaining(progressLabel)
    }

    private var prominentLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.fill")
                .font(.body)

            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(prominentTitle)
                        .font(.headline)
                        .lineLimit(1)

                    if let prominentRemaining {
                        Text(prominentRemaining)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(.black.opacity(0.65))
                            .lineLimit(1)
                    }
                }
                .minimumScaleFactor(0.8)

                if let mediaSource {
                    Text(mediaSource)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.black.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white, in: .capsule)
        .contentShape(.capsule)
    }

    var body: some View {
        switch style {
        case .standard:
            standardBody
        case .prominent:
            prominentBody
        }
    }

    private var prominentBody: some View {
        Button {
            play()
        } label: {
            prominentLabel
        }
        .buttonStyle(BasicHoverButtonStyle())
        .contextMenu {
            if provider.mediaPlayerItemProvider?.item.userData?.playbackPositionTicks != 0 {
                Button(L10n.playFromBeginning, systemImage: "gobackward") {
                    play(fromBeginning: true)
                }
            }
        }
        .disabled(provider.mediaPlayerItemProvider == nil)
        .opacity(provider.mediaPlayerItemProvider == nil ? 0.5 : 1)
        .accessibilityLabel([prominentTitle, prominentRemaining, mediaSource].compactMap(\.self).joined(separator: ", "))
    }

    // MARK: - Standard

    private var standardBody: some View {
        Button {
            play()
        } label: {
            HStack {
                Image(systemName: "play.fill")

                VStack(spacing: 2) {
                    Text(provider.mediaPlayerItemProvider?.item.playButtonLabel ?? L10n.play)

                    if let mediaSource {
                        Marquee(mediaSource, speed: 40, delay: 3, fade: 5)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .font(.callout)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .backport
            .glassEffect(
                .regular.selection(
                    tint: accentColor,
                    foregroundColor: accentColor.overlayColor
                ),
                in: .capsule
            )
        }
        .buttonBorderShape(.capsule)
        .buttonStyle(BasicHoverButtonStyle())
        .contextMenu {
            if provider.mediaPlayerItemProvider?.item.userData?.playbackPositionTicks != 0 {
                Button(L10n.playFromBeginning, systemImage: "gobackward") {
                    play(fromBeginning: true)
                }
            }
        }
        .disabled(provider.mediaPlayerItemProvider == nil)
    }
}
