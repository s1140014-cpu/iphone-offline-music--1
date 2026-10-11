import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import MediaPlayer

@MainActor
final class MusicPlayer: ObservableObject {
    @Published var tracks: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.8
    @Published var message = "請匯入音樂開始播放"

    private var player: AVAudioPlayer?
    private var timer: Timer?

    init() {
        configureAudioSession()
        loadSavedTracks()
        configureRemoteCommands()
    }

    var currentTrack: URL? {
        guard tracks.indices.contains(currentIndex) else { return nil }
        return tracks[currentIndex]
    }

    private var musicFolder: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            message = "音訊設定失敗：\(error.localizedDescription)"
        }
    }

    func importFiles(_ urls: [URL]) {
        var imported = 0
        for source in urls {
            let hasAccess = source.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { source.stopAccessingSecurityScopedResource() }
            }

            let destination = uniqueDestination(for: source.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                if !tracks.contains(where: { $0.lastPathComponent == destination.lastPathComponent }) {
                    tracks.append(destination)
                    imported += 1
                }
            } catch {
                message = "匯入失敗：\(source.lastPathComponent)（\(error.localizedDescription)）"
            }
        }
        if imported > 0 {
            message = "已匯入 \(imported) 首歌曲，可離線播放"
            if player == nil { play(index: 0) }
        } else if !urls.isEmpty {
            message = "沒有新增歌曲；可能已匯入或檔案無法讀取"
        }
    }

    private func uniqueDestination(for filename: String) -> URL {
        let ext = URL(fileURLWithPath: filename).pathExtension
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        var candidate = musicFolder.appendingPathComponent(filename)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(stem) \(number)" : "\(stem) \(number).\(ext)"
            candidate = musicFolder.appendingPathComponent(newName)
            number += 1
        }
        return candidate
    }

    private func loadSavedTracks() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: musicFolder,
                includingPropertiesForKeys: nil
            )
            tracks = urls.filter { url in
                ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf"].contains(url.pathExtension.lowercased())
            }.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            message = "讀取音樂資料夾失敗"
        }
    }

    func play(index: Int? = nil) {
        guard !tracks.isEmpty else {
            message = "請先按「匯入音樂」選取歌曲"
            return
        }
        if let index {
            currentIndex = max(0, min(index, tracks.count - 1))
        }
        guard let url = currentTrack else { return }

        do {
            player?.stop()
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = PlayerDelegate.shared
            player?.volume = volume
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            duration = player?.duration ?? 0
            currentTime = 0
            message = "正在播放：\(url.deletingPathExtension().lastPathComponent)"
            startTimer()
            updateNowPlayingInfo()
            PlayerDelegate.shared.onFinished = { [weak self] in
                Task { @MainActor in self?.next() }
            }
        } catch {
            isPlaying = false
            message = "無法播放此檔案：\(error.localizedDescription)"
        }
    }

    func togglePlayPause() {
        guard let player else {
            play(index: currentIndex)
            return
        }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            message = "已暫停"
        } else {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch { }
            player.play()
            isPlaying = true
            message = "繼續播放"
        }
        updateNowPlayingInfo()
    }

    func next() {
        guard !tracks.isEmpty else { return }
        play(index: (currentIndex + 1) % tracks.count)
    }

    func previous() {
        guard !tracks.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
        } else {
            play(index: (currentIndex - 1 + tracks.count) % tracks.count)
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
        updateNowPlayingInfo()
    }

    func setVolume(_ value: Float) {
        volume = value
        player?.volume = value
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                self.duration = player.duration
                self.updateNowPlayingInfo()
            }
        }
    }

    private func updateNowPlayingInfo() {
        guard let url = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: url.deletingPathExtension().lastPathComponent,
            MPMediaItemPropertyArtist: "本機音樂",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        info[MPMediaItemPropertyAlbumTitle] = "離線音樂播放器"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == true { self?.togglePlayPause() }
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }
}

final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = PlayerDelegate()
    var onFinished: (() -> Void)?
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinished?()
    }
}

struct ContentView: View {
    @StateObject private var music = MusicPlayer()
    @State private var showingImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.cyan)
                    Text("離線音樂播放器")
                        .font(.largeTitle.bold())
                    Text("匯入到手機後，無網路也能播放")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                Button {
                    showingImporter = true
                } label: {
                    Label("匯入音樂（MP3 等）", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("正在播放")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(music.currentTrack?.deletingPathExtension().lastPathComponent ?? "尚未選擇歌曲")
                        .font(.headline)
                        .lineLimit(2)
                    Slider(
                        value: Binding(
                            get: { music.currentTime },
                            set: { music.seek(to: $0) }
                        ),
                        in: 0...max(music.duration, 1)
                    )
                    HStack {
                        Text(timeString(music.currentTime))
                        Spacer()
                        Text(timeString(music.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                    HStack(spacing: 32) {
                        Button { music.previous() } label: {
                            Image(systemName: "backward.end.fill").font(.title2)
                        }
                        Button { music.togglePlayPause() } label: {
                            Image(systemName: music.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 58))
                        }
                        Button { music.next() } label: {
                            Image(systemName: "forward.end.fill").font(.title2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: Binding(
                            get: { Double(music.volume) },
                            set: { music.setVolume(Float($0)) }
                        ), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack {
                    Text("我的音樂")
                        .font(.title3.bold())
                    Spacer()
                    Text("\(music.tracks.count) 首")
                        .foregroundStyle(.secondary)
                }

                List {
                    ForEach(Array(music.tracks.enumerated()), id: \.element) { index, url in
                        Button {
                            music.play(index: index)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: index == music.currentIndex && music.isPlaying ? "waveform" : "music.note")
                                    .foregroundStyle(.cyan)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(url.pathExtension.uppercased())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if index == music.currentIndex {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                Text(music.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal)
            .background(Color(red: 0.035, green: 0.055, blue: 0.09))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("匯入音樂")
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.audio, .mp3, .wav],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    music.importFiles(urls)
                case .failure(let error):
                    music.message = "選取檔案失敗：\(error.localizedDescription)"
                }
            }
        }
        .tint(.cyan)
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let value = max(0, Int(seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
