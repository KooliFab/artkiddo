import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// The drag handle at the top of a bottom sheet. One shape for every sheet,
/// so a sheet never has to redraw it.
class SheetHandle extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const SheetHandle({
    super.key,
    this.margin = const EdgeInsets.only(bottom: AppSpacing.s4),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: 36,
        height: 4,
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.borderStrong,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
      ),
    );
  }
}
