import 'package:flutter/material.dart';
import 'dart:ui';

class GlassCard extends StatelessWidget {
	final Widget? child;
	final double? height;
	final VoidCallback? onTap;

	const GlassCard({Key? key, this.child, this.height, this.onTap}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final borderRadius = BorderRadius.circular(16.0);

			return Container(
				height: height,
				decoration: BoxDecoration(
					borderRadius: borderRadius,
					// stronger border for crisper look
					border: Border.all(color: Colors.white.withAlpha((0.28 * 255).round())),
					// slightly darker interior so content pops
					color: Colors.white.withAlpha((0.12 * 255).round()),
				),
				child: ClipRRect(
					borderRadius: borderRadius,
					child: BackdropFilter(
						// much lower blur for HD appearance
						filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
						child: Material(
							color: Colors.transparent,
							child: InkWell(
								onTap: onTap,
								borderRadius: borderRadius,
								splashColor: Colors.white24,
								highlightColor: Colors.white10,
								child: Padding(
									padding: const EdgeInsets.all(16.0),
									child: child ?? const SizedBox.shrink(),
								),
							),
						),
					),
				),
			);
	}
}
