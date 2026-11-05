import 'package:flutter/material.dart';

/// A built-in sticker: a big emoji with a short caption. The chat and the
/// comments only store the sticker's key (for example "safe"); every phone
/// draws it from this list.
class StickerDef {
  final String key;
  final String emoji;
  final String caption;
  final Color color;
  const StickerDef(this.key, this.emoji, this.caption, this.color);
}

const List<StickerDef> kStickers = [
  StickerDef('help', '🆘', 'I need help', Color(0xFFDC2626)),
  StickerDef('safe', '✅', "I'm safe", Color(0xFF16A34A)),
  StickerDef('home', '🏠', 'Home safe', Color(0xFF16A34A)),
  StickerDef('otw', '🚗', 'On my way', Color(0xFF2563EB)),
  StickerDef('late', '⏰', 'Running late', Color(0xFFD97706)),
  StickerDef('call', '📞', 'Call me', Color(0xFF2563EB)),
  StickerDef('where', '📍', 'Where are you?', Color(0xFFDC2626)),
  StickerDef('watch', '👀', 'Watch out', Color(0xFFD97706)),
  StickerDef('thanks', '🙏', 'Thank you', Color(0xFF7C3AED)),
  StickerDef('ok', '👍', 'OK', Color(0xFF2563EB)),
  StickerDef('love', '❤️', 'Stay safe', Color(0xFFDB2777)),
  StickerDef('laugh', '😂', 'Haha', Color(0xFFD97706)),
  StickerDef('sad', '😢', 'Sorry', Color(0xFF0891B2)),
  StickerDef('wow', '😮', 'Wow', Color(0xFFD97706)),
  StickerDef('well', '🎉', 'Well done', Color(0xFF7C3AED)),
  StickerDef('fire', '🔥', 'Hot!', Color(0xFFDC2626)),
];

/// Plain big-emoji stickers (the key is the emoji itself).
const List<String> kEmojiStickers = ['😍', '🥳', '😎', '🤝', '💪', '🤗', '🙌', '💯'];

StickerDef? stickerByKey(String key) {
  for (final s in kStickers) {
    if (s.key == key) return s;
  }
  return null;
}

/// Draws one sticker at the given size.
class StickerView extends StatelessWidget {
  final String stickerKey;
  final double size;
  const StickerView({super.key, required this.stickerKey, this.size = 130});

  @override
  Widget build(BuildContext context) {
    final def = stickerByKey(stickerKey);
    if (def == null) {
      // Unknown key or a plain emoji sticker: just draw it big.
      return SizedBox(
        width: size,
        height: size * 0.8,
        child: FittedBox(child: Text(stickerKey, style: TextStyle(fontSize: size * 0.6))),
      );
    }
    return Container(
      width: size,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: def.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: def.color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(def.emoji, style: TextStyle(fontSize: size * 0.42)),
          const SizedBox(height: 4),
          Text(
            def.caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size * 0.105 + 3, fontWeight: FontWeight.w700, color: def.color),
          ),
        ],
      ),
    );
  }
}

/// Opens the sticker tray. Returns the sticker key, or null if dismissed.
Future<String?> showStickerPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      expand: false,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text('Stickers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in kStickers)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(sheetContext, s.key),
                  child: StickerView(stickerKey: s.key, size: 96),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Big emoji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in kEmojiStickers)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(sheetContext, e),
                  child: Padding(padding: const EdgeInsets.all(8), child: Text(e, style: const TextStyle(fontSize: 38))),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}