import 'package:flutter/material.dart';
import 'store_design.dart';

/// Reserves the page's content shape while its first request is in flight.
/// Static placeholders avoid a blank screen without adding a perpetual shimmer.
class StoreLoadingLayout extends StatelessWidget {
  const StoreLoadingLayout({super.key, this.checkout = false});

  final bool checkout;

  @override
  Widget build(BuildContext context) => Semantics(
        label: checkout ? 'Loading checkout' : 'Loading content',
        liveRegion: true,
        child: ExcludeSemantics(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < StoreLayout.tablet;
            final main = Column(
              children: [
                _panel(checkout ? 190 : 210),
                const SizedBox(height: 20),
                _panel(160),
              ],
            );
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 12 : 24),
                    child: checkout && constraints.maxWidth >= 960
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: main),
                              const SizedBox(width: 28),
                              SizedBox(width: 320, child: _panel(270)),
                            ],
                          )
                        : Column(
                            children: [
                              if (checkout) ...[
                                _panel(220),
                                const SizedBox(height: 16),
                              ],
                              main,
                            ],
                          ),
                  ),
                ),
              ),
            );
          }),
        ),
      );

  Widget _panel(double height) => Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: storeWhite,
          border: Border.all(color: storeBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(0.45, 22),
            const SizedBox(height: 24),
            _line(0.85, 14),
            const SizedBox(height: 12),
            _line(0.65, 14),
          ],
        ),
      );

  Widget _line(double fraction, double height) => FractionallySizedBox(
        widthFactor: fraction,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: storeBorder.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}
