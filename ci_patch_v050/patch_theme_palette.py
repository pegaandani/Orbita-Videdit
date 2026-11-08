from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else "videdit_project")
appearance = root / "lib/features/editor/widgets/appearance_panel.dart"
visual = root / "lib/core/models/visual_settings.dart"
editor = root / "lib/features/editor/editor_screen.dart"

def replace_once(path: Path, before: str, after: str) -> None:
    source = path.read_text(encoding="utf-8")
    if after in source:
        print("Already patched:", path)
        return
    if source.count(before) != 1:
        raise SystemExit(f"Expected one exact theme marker in {path}, found {source.count(before)}")
    path.write_text(source.replace(before, after, 1), encoding="utf-8")
    print("Patched:", path)

original_palette = """  static const colors = <Color>[
    Color(0xFF6F1831), Color(0xFF8A1E2F), Color(0xFF163C2D), Color(0xFF4D5A2E),
    Color(0xFF162A4B), Color(0xFF79A8D8), Color(0xFF2C8E91), Color(0xFF6B3A82),
    Color(0xFFF0C94A), Color(0xFFE17A37), Color(0xFFE8DCC4), Color(0xFFFFEAC7),
    Color(0xFFFFFFFF), Color(0xFFD7D7D7), Color(0xFF777777), Color(0xFF29272D),
    Color(0xFF161519), Color(0xFF000000),
  ];"""
# Exactly 30 newly added colors: 10 recognizable pastels, 10 saturated,
# and 10 muted/dark. Mixed order, not category-separated.
new_palette = """  // Shared by all three independent layers. Thirty new colors are deliberately
  // interleaved rather than grouped by brightness or saturation.
  static const colors = <Color>[
    Color(0xFFEFA3B5), Color(0xFF15365A), Color(0xFFFF3434),
    Color(0xFF789283), Color(0xFF8AC9E8), Color(0xFFEA2DA5),
    Color(0xFF80394A), Color(0xFFD6A177), Color(0xFF11B8CD),
    Color(0xFFA78CD8), Color(0xFF354868), Color(0xFF29CC63),
    Color(0xFFB7C976), Color(0xFFFF7518), Color(0xFF4C256A),
    Color(0xFFF1C47A), Color(0xFF315E58), Color(0xFF3E56FF),
    Color(0xFFB5A3E6), Color(0xFF9A735B), Color(0xFFFFD600),
    Color(0xFF79D3BF), Color(0xFF6B728C), Color(0xFF852DE0),
    Color(0xFFF4A6A0), Color(0xFF802E30), Color(0xFF00C88B),
    Color(0xFFDEB1D7), Color(0xFF57587E), Color(0xFFEA174B),
    // Preserve the original colors and neutral whites, blacks, greys and creams.
    Color(0xFF6F1831), Color(0xFF8A1E2F), Color(0xFF163C2D), Color(0xFF4D5A2E),
    Color(0xFF162A4B), Color(0xFF79A8D8), Color(0xFF2C8E91), Color(0xFF6B3A82),
    Color(0xFFF0C94A), Color(0xFFE17A37), Color(0xFFE8DCC4), Color(0xFFFFEAC7),
    Color(0xFFFFFFFF), Color(0xFFD7D7D7), Color(0xFF777777), Color(0xFF29272D),
    Color(0xFF161519), Color(0xFF000000),
  ];"""
replace_once(appearance, original_palette, new_palette)

old_contrast = """  Color contrastOn(Color background) => background.computeLuminance() > .46
      ? const Color(0xFF17151A)
      : const Color(0xFFF7F4EE);"""
new_contrast = """  // Pick the higher WCAG contrast instead of relying on a fixed luminance
  // cutoff. The white/black pair provides at least 4.5:1 on opaque colors.
  Color contrastOn(Color background) {
    const light = Color(0xFFFFFFFF);
    const dark = Color(0xFF000000);
    final luminance = background.computeLuminance();
    final contrastLight = 1.05 / (luminance + .05);
    final contrastDark = (luminance + .05) / .05;
    return contrastLight >= contrastDark ? light : dark;
  }

  // Account for translucent panel surfaces over the user-selected background.
  Color effectivePanelBackground() {
    return Color.alphaBlend(layer2.withValues(alpha: panelOpacity), layer1);
  }"""
replace_once(visual, old_contrast, new_contrast)

old_theme = """    final panelText = _v.contrastOn(_v.layer2);
    final accentText = _v.contrastOn(_v.layer3);
    final scheme = Theme.of(context).colorScheme.copyWith(
          primary: _v.layer3,
          onPrimary: accentText,
          surface: _v.layer2,
          onSurface: panelText,
        );

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),"""
new_theme = """    final panelText = _v.contrastOn(_v.effectivePanelBackground());
    final accentText = _v.contrastOn(_v.layer3);
    final scheme = Theme.of(context).colorScheme.copyWith(
          primary: _v.layer3,
          onPrimary: accentText,
          surface: _v.effectivePanelBackground(),
          onSurface: panelText,
        );
    final existingTheme = Theme.of(context);

    return Theme(
      data: existingTheme.copyWith(
        colorScheme: scheme,
        textTheme: existingTheme.textTheme.apply(
          bodyColor: panelText,
          displayColor: panelText,
        ),
        iconTheme: existingTheme.iconTheme.copyWith(color: panelText),
      ),"""
replace_once(editor, old_theme, new_theme)
print("Three-layer mixed palette, preserved original colors, and dynamic contrast ready.")
