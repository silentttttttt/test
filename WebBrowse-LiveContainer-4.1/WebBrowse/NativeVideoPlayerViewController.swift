import AVKit
import AVFoundation
import UIKit

final class NativeVideoPlayerViewController: AVPlayerViewController {
    private let mediaURL: URL
    private let mediaTitle: String
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var didReportPlaybackStart = false
    private var didShowPlaybackError = false
    var onPlaybackStarted: (() -> Void)?

    init(url: URL, title: String, headers: [String: String] = [:], onPlaybackStarted: (() -> Void)? = nil) {
        self.mediaURL = url
        self.mediaTitle = title
        self.onPlaybackStarted = onPlaybackStarted
        super.init(nibName: nil, bundle: nil)
        // Do not forward browser cookies into AVPlayer request headers. AVURLAsset can
        // follow redirects, and a Cookie header attached to the asset could be exposed
        // to a redirected host. Authenticated media should use a scoped media URL/token.
        let asset = AVURLAsset(url: url, options: [:])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 4
        player = AVPlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = true
        allowsPictureInPicturePlayback = true
        title = mediaTitle
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mediaTitle
        if let player {
            timeControlObservation = player.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
                guard let self, !self.didReportPlaybackStart, player.timeControlStatus == .playing else { return }
                self.didReportPlaybackStart = true
                DispatchQueue.main.async { self.onPlaybackStarted?() }
            }
        }
        if let item = player?.currentItem {
            statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard let self, item.status == .failed else { return }
                DispatchQueue.main.async {
                    guard self.isViewLoaded, self.view.window != nil, self.presentedViewController == nil, !self.didShowPlaybackError else { return }
                    self.didShowPlaybackError = true
                    let alert = UIAlertController(title: "Playback failed", message: item.error?.localizedDescription ?? "The video could not be played by the native player.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player?.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player?.pause()
    }

    deinit {
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()
    }
}
