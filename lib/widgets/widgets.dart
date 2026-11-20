import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/tokens.dart';

/// Figma: "Button" component set (Type=Primary | Secondary | Ghost).
enum AppButtonType { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  const AppButton(this.label, {super.key, this.onPressed, this.type = AppButtonType.primary});

  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    final (bg, fg, side) = switch (type) {
      AppButtonType.primary => (c.accent, c.onAccent, BorderSide.none),
      AppButtonType.secondary => (c.accentTint, c.accent, BorderSide.none),
      AppButtonType.ghost => (Colors.transparent, c.textPrimary, BorderSide(color: c.border)),
    };
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: StadiumBorder(side: side),
          textStyle: context.text.labelLarge,
        ),
        child: Text(label),
      ),
    );
  }
}

/// Figma: "Chip" component set (State=Default | Selected).
class DndChip extends StatelessWidget {
  const DndChip(this.label, {super.key, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return Material(
      color: selected ? c.accentTint : c.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? c.accent : c.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: Space.s16),
          alignment: Alignment.center,
          child: Text(label,
              style: context.text.labelLarge!.copyWith(color: selected ? c.accent : c.textPrimary)),
        ),
      ),
    );
  }
}

class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.labels, required this.selected, this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: Space.s8,
        runSpacing: Space.s8,
        children: [
          for (var i = 0; i < labels.length; i++)
            DndChip(labels[i], selected: i == selected, onTap: () => onSelected?.call(i)),
        ],
      );
}

/// Bordered surface used for every grouped list in the design.
class DndCard extends StatelessWidget {
  const DndCard({super.key, required this.child, this.borderColor, this.borderWidth = 1, this.color});

  final Widget child;
  final Color? borderColor;
  final double borderWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: borderColor ?? c.border, width: borderWidth),
      ),
      child: child,
    );
  }
}

class DndDivider extends StatelessWidget {
  const DndDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s16),
        child: Divider(height: 1, thickness: 1, color: context.dnd.border),
      );
}

/// A card containing rows separated by dividers.
class DndGroup extends StatelessWidget {
  const DndGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DndCard(
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const DndDivider(),
            children[i],
          ],
        ]),
      );
}

/// Figma: "Setting Row" component set (Icon=...).
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 14),
        child: Row(children: [
          IconTile(icon: icon, size: 40, iconSize: 20),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.text.labelLarge),
              if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
            ]),
          ),
          if (value != null) ...[
            Text(value!, style: context.text.bodyMedium!.copyWith(color: c.textSecondary)),
            const SizedBox(width: Space.s4),
          ],
          Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
        ]),
      ),
    );
  }
}

/// Rounded square holding an icon (icon-tile in Figma).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 48,
    this.iconSize = 24,
    this.filled = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? c.accent : c.accentTint,
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: Icon(icon, size: iconSize, color: filled ? c.onAccent : c.accent),
    );
  }
}

/// Figma: "Profile Card" component set (Icon=..., State=Active | Idle).
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.profile, this.onChanged, this.onTap});

  final DndProfile profile;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return DndCard(
      borderColor: profile.active ? c.accent : c.border,
      borderWidth: profile.active ? 2 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.s16),
          child: Row(children: [
            IconTile(icon: profile.icon, filled: profile.active),
            const SizedBox(width: Space.s16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(profile.name, style: context.text.titleMedium),
                Text(profile.meta, style: context.text.bodySmall),
              ]),
            ),
            Switch(value: profile.active, onChanged: onChanged),
          ]),
        ),
      ),
    );
  }
}

/// Uppercase section label (Overline text style).
class OverlineText extends StatelessWidget {
  const OverlineText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: context.text.labelSmall);
}

/// Big screen title with optional round add button (tab screens).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, required this.subtitle, this.onAdd});

  final String title;
  final String subtitle;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: context.text.displayLarge),
          Text(subtitle, style: context.text.bodyMedium!.copyWith(color: c.textSecondary)),
        ]),
      ),
      if (onAdd != null)
        Material(
          color: c.accent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAdd,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.add, color: c.onAccent),
            ),
          ),
        ),
    ]);
  }
}

/// Amber conflict / warning banner.
class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.title, required this.message, this.action, this.onAction});

  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: Space.s12),
      decoration: BoxDecoration(
        color: c.warningTint,
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: Row(children: [
        Icon(DndIcons.warning, size: 20, color: c.warning),
        const SizedBox(width: Space.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.text.labelLarge),
            Text(message, style: context.text.bodySmall),
          ]),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: context.text.labelLarge!.copyWith(color: c.accent)),
          ),
      ]),
    );
  }
}
