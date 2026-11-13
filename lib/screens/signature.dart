import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  /// Strokes drawn by the user; null separates strokes.
  final List<Offset?> _points = [];
  bool _signInvoices = true;
  bool _clientSign = true;
  bool _signReceipts = false;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;

    Widget toggleRow(String title, String sub, bool value, ValueChanged<bool> onChanged) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Fonts.sans(size: 14.5, weight: FontWeight.w600, color: dl.ink)),
                    Text(sub, style: Fonts.caption(dl.muted)),
                  ],
                ),
              ),
              DaylitToggle(value: value, onChanged: onChanged),
            ],
          ),
        );

    return ScreenScaffold(
      header: TopBar(
        title: 'Signature',
        trailing: [
          Pressable(
            onTap: () => setState(_points.clear),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text('Clear', style: Fonts.sans(size: 14, weight: FontWeight.w700, color: dl.rust)),
            ),
          ),
        ],
      ),
      bottom: [
        Expanded(
          child: DaylitButton('Save signature', onTap: () {
            Haptics.success();
            Navigator.of(context).pop();
            toast(context, _points.isEmpty ? 'No signature drawn' : 'Signature saved');
          }),
        ),
      ],
      children: stagger([
        DaylitCard(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 210,
                  decoration: BoxDecoration(
                    color: dl.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Palette.sand, width: 1.5),
                  ),
                  child: GestureDetector(
                    onPanStart: (d) => setState(() => _points.add(d.localPosition)),
                    onPanUpdate: (d) => setState(() => _points.add(d.localPosition)),
                    onPanEnd: (_) => setState(() => _points.add(null)),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _SignaturePainter(_points, ink: dl.ink, guide: Palette.sand),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 0, 10),
                          child: IgnorePointer(
                            child: Eyebrow(_points.isEmpty ? 'Draw with your finger' : 'Signed', size: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Your signature is embedded as an image on documents.', style: Fonts.caption(dl.muted)),
            ],
          ),
        ),
        const SectionLabel('Signed as'),
        const FieldTile(label: 'Name & title', value: 'Nora Lindqvist, Owner'),
        const SectionLabel('Where it appears'),
        ListCard(
          children: [
            toggleRow('Sign all invoices', 'Added to the footer automatically', _signInvoices, (v) => setState(() => _signInvoices = v)),
            toggleRow('Request client signature on estimates', 'Clients sign to accept', _clientSign, (v) => setState(() => _clientSign = v)),
            toggleRow('Sign receipts', _signReceipts ? 'On' : 'Off', _signReceipts, (v) => setState(() => _signReceipts = v)),
          ],
        ),
      ]),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points, {required this.ink, required this.guide});

  final List<Offset?> points;
  final Color ink;
  final Color guide;

  @override
  void paint(Canvas canvas, Size size) {
    // Dashed baseline.
    final y = size.height * 0.72;
    final dash = Paint()..color = guide..strokeWidth = 1;
    for (double x = 28; x < size.width - 28; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
    }

    final pen = Paint()
      ..color = ink
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    var drawing = false;
    for (final p in points) {
      if (p == null) {
        drawing = false;
        continue;
      }
      if (!drawing) {
        path.moveTo(p.dx, p.dy);
        drawing = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
