import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail_gdx_plus/video_thumbnail_gdx_plus.dart';

const Color _red = Color(0xFFDC2626);

String _fmt(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

// =====================================================================
// Thumbnails: a picture of the video, instead of a blank box
// =====================================================================

/// Makes (and remembers) a picture from a video, so lists don't redo the work.
class VideoThumbCache {
  static final Map<String, Future<Uint8List?>> _jobs = {};

  static Future<Uint8List?> get(String source) {
    final existing = _jobs[source];
    if (existing != null) return existing;
    final job = _make(source);
    _jobs[source] = job;
    job.then((bytes) {
      // A failed attempt is not remembered, so it can be tried again later.
      if (bytes == null) _jobs.remove(source);
    });
    return job;
  }

  static Future<Uint8List?> _make(String source) async {
    if (kIsWeb) return null;
    try {
      return await VideoThumbnail.thumbnailData(
        video: source,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 70,
        timeMs: 300,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A picture of the video with a play button on top.
/// Give it either a web [url] or a local [file]; set [width] and [height].
class VideoThumb extends StatefulWidget {
  final String? url;
  final File? file;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final bool showPlay;

  const VideoThumb({
    super.key,
    this.url,
    this.file,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.showPlay = true,
  });

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  Future<Uint8List?>? _future;

  String? get _source => widget.file?.path ?? widget.url;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant VideoThumb old) {
    super.didUpdateWidget(old);
    if ((old.file?.path ?? old.url) != _source) _start();
  }

  void _start() {
    final s = _source;
    _future = (s == null || s.isEmpty) ? Future<Uint8List?>.value(null) : VideoThumbCache.get(s);
  }

  Widget _placeholder(bool loading) {
    return Container(
      color: const Color(0xFF1F2937),
      child: Center(
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
            : const Icon(Icons.videocam_rounded, color: Colors.white38, size: 34),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (kIsWeb && widget.url != null)
              _WebFirstFrame(url: widget.url!)
            else
              FutureBuilder<Uint8List?>(
                future: _future,
                builder: (context, snap) {
                  final bytes = snap.data;
                  if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
                  return _placeholder(snap.connectionState != ConnectionState.done);
                },
              ),
            if (widget.showPlay)
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Web only: the browser can show a video's first frame by itself.
class _WebFirstFrame extends StatefulWidget {
  final String url;
  const _WebFirstFrame({required this.url});

  @override
  State<_WebFirstFrame> createState() => _WebFirstFrameState();
}

class _WebFirstFrameState extends State<_WebFirstFrame> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (!_ready || c == null) return Container(color: const Color(0xFF1F2937));
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
    );
  }
}

// =====================================================================
// The player: play / pause, back 5s, forward 5s, scrub bar, fullscreen
// =====================================================================

class VideoViewer extends StatefulWidget {
  final String url;
  final bool autoPlay;
  const VideoViewer({super.key, required this.url, this.autoPlay = true});

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late VideoPlayerController _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _c.initialize();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _failed = false;
      });
      if (widget.autoPlay) _c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _retry() async {
    await _c.dispose();
    if (!mounted) return;
    setState(() {
      _ready = false;
      _failed = false;
    });
    _init();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _openFullscreen() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => _FullscreenVideoPage(controller: _c)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_failed) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not play this video.', style: TextStyle(color: Colors.white70)),
            TextButton(onPressed: _retry, child: const Text('Try again')),
          ],
        ),
      );
    } else if (!_ready) {
      body = const Center(child: CircularProgressIndicator(color: Colors.white));
    } else {
      body = _VideoSurface(controller: _c, isFullscreen: false, onToggleFullscreen: _openFullscreen);
    }
    return ColoredBox(color: Colors.black, child: body);
  }
}

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenVideoPage({required this.controller});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Wide videos turn the phone sideways; tall videos stay upright.
    if (widget.controller.value.aspectRatio > 1) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _VideoSurface(
        controller: widget.controller,
        isFullscreen: true,
        onToggleFullscreen: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _VideoSurface extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const _VideoSurface({required this.controller, required this.isFullscreen, required this.onToggleFullscreen});

  @override
  State<_VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<_VideoSurface> {
  bool _show = true;
  bool _wasPlaying = false;
  Timer? _hideTimer;

  VideoPlayerController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _wasPlaying = _c.value.isPlaying;
    _c.addListener(_onValue);
    _scheduleHide();
  }

  @override
  void dispose() {
    _c.removeListener(_onValue);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onValue() {
    final playing = _c.value.isPlaying;
    if (playing != _wasPlaying) {
      _wasPlaying = playing;
      if (!mounted) return;
      if (playing) {
        _scheduleHide();
      } else {
        setState(() => _show = true);
      }
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_c.value.isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _c.value.isPlaying) setState(() => _show = false);
    });
  }

  void _toggleControls() {
    setState(() => _show = !_show);
    if (_show) _scheduleHide();
  }

  Future<void> _togglePlay() async {
    final v = _c.value;
    if (v.isPlaying) {
      await _c.pause();
    } else {
      final ended = v.duration > Duration.zero && v.position >= v.duration;
      if (ended) await _c.seekTo(Duration.zero);
      await _c.play();
    }
    if (mounted) setState(() => _show = true);
    _scheduleHide();
  }

  Future<void> _skip(int seconds) async {
    final v = _c.value;
    var target = v.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.duration) target = v.duration;
    await _c.seekTo(target);
    if (mounted) setState(() => _show = true);
    _scheduleHide();
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap, {double size = 36, String? tooltip}) {
    return IconButton(
      tooltip: tooltip,
      iconSize: size,
      color: Colors.white,
      style: IconButton.styleFrom(backgroundColor: Colors.black45),
      onPressed: onTap,
      icon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = _c.value.aspectRatio;
    final aspect = (ar.isFinite && ar > 0) ? ar : 16 / 9;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: AspectRatio(aspectRatio: aspect, child: VideoPlayer(_c))),
          AnimatedOpacity(
            opacity: _show ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_show,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _c,
                builder: (context, v, _) {
                  final ended = v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _roundIcon(Icons.replay_5_rounded, () => _skip(-5), tooltip: 'Back 5 seconds'),
                            const SizedBox(width: 22),
                            v.isBuffering && v.isPlaying
                                ? const SizedBox(width: 64, height: 64, child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white)))
                                : _roundIcon(
                                    v.isPlaying ? Icons.pause_rounded : (ended ? Icons.replay_rounded : Icons.play_arrow_rounded),
                                    _togglePlay,
                                    size: 48,
                                    tooltip: v.isPlaying ? 'Pause' : 'Play',
                                  ),
                            const SizedBox(width: 22),
                            _roundIcon(Icons.forward_5_rounded, () => _skip(5), tooltip: 'Forward 5 seconds'),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: widget.isFullscreen ? 18 : 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Text(_fmt(v.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: VideoProgressIndicator(
                                  _c,
                                  allowScrubbing: true,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  colors: const VideoProgressColors(playedColor: _red, bufferedColor: Colors.white38, backgroundColor: Colors.white24),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_fmt(v.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: widget.isFullscreen ? 'Exit full screen' : 'Full screen',
                                color: Colors.white,
                                onPressed: widget.onToggleFullscreen,
                                icon: Icon(widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}