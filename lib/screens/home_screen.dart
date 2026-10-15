import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pre_review_screens/doc_pre.dart';
import '../pre_review_screens/page_layout_screen.dart';
import '../pre_review_screens/photo_pre.dart';
import '../pre_review_screens/camera_print_screen.dart';
import '../pre_review_screens/doc_scan_screen.dart';
import '../pre_review_screens/split_pdf_screen.dart';
import '../pre_review_screens/merge_pdf_screen.dart';
import '../pre_review_screens/contacts_screen.dart';
import '../pre_review_screens/pdf_to_image_screen.dart';
import '../pre_review_screens/image_to_pdf_screen.dart';
import '../pre_review_screens/text_pre.dart';
import '../ads/ad_service.dart';
import '../config/pro_theme.dart';
import '../l10n/labels.dart';
import '../services/billing_service.dart';
import '../widgets/app_snack.dart';
import '../widgets/pro_crown_icon.dart';
import 'learn_more_screen.dart';
import 'pro_screen.dart';
import 'web_page.dart';

class PrinterHomeScreen extends StatelessWidget {
  const PrinterHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 28),
              child: Column(
                children: [
                  _WelcomeBanner(
                    onLearnMore: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LearnMoreScreen(),
                        ),
                      );
                    },
                  ),
                  _FeatureGrid(
                    actions: [
                      _HomeAction(
                        title: 'feat_smart_text'.tr(),
                        assetPath: 'assets/images/text.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TextPreScreen(),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_documents'.tr(),
                        assetPath: 'assets/images/doc.png',
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: false,
                            allowedExtensions: const [
                              'pdf',
                              'doc',
                              'docx',
                              'ppt',
                              'pptx',
                              'xls',
                              'xlsx',
                              'txt',
                            ],
                          );
                          if (result == null || result.files.isEmpty) {
                            return;
                          }
                          final picked = result.files.first;
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DocPreScreen(file: picked),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_photo'.tr(),
                        assetPath: 'assets/images/photo_print.png',
                        onTap: () async {
                          final picker = ImagePicker();
                          final pickedList = await picker.pickMultiImage(
                            imageQuality: 95,
                          );
                          if (pickedList.isEmpty) {
                            final single = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 95,
                            );
                            if (single == null) {
                              return;
                            }
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PhotoPreScreen(images: [single]),
                              ),
                            );
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PhotoPreScreen(images: pickedList),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_layout'.tr(),
                        assetPath: 'assets/images/images.png',
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: true,
                            allowedExtensions: const [
                              'pdf',
                              'jpg',
                              'jpeg',
                              'png',
                              'webp',
                            ],
                          );
                          if (result == null || result.files.isEmpty) {
                            return;
                          }
                          final files = result.files;
                          final pdfFiles = files
                              .where(
                                (file) =>
                                    file.extension?.toLowerCase() == 'pdf' &&
                                    (file.path?.isNotEmpty ?? false),
                              )
                              .toList();
                          final imageFiles = files
                              .where(
                                (file) =>
                                    _isImageExtension(file.extension) &&
                                    (file.path?.isNotEmpty ?? false),
                              )
                              .toList();

                          if (pdfFiles.isNotEmpty && imageFiles.isNotEmpty) {
                            if (!context.mounted) {
                              return;
                            }
                            AppSnack.show(
                              context,
                              t(context, 'select_pdf_or_images'),
                            );
                            return;
                          }

                          if (pdfFiles.length > 1) {
                            if (!context.mounted) {
                              return;
                            }
                            AppSnack.show(
                              context,
                              t(context, 'select_one_pdf'),
                            );
                            return;
                          }

                          if (!context.mounted) {
                            return;
                          }

                          if (pdfFiles.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PageLayoutScreen.pdf(
                                  pdfPath: pdfFiles.first.path!,
                                ),
                              ),
                            );
                            return;
                          }

                          if (imageFiles.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PageLayoutScreen.images(images: imageFiles),
                              ),
                            );
                          }
                        },
                      ),
                      _HomeAction(
                        title: 'feat_camera'.tr(),
                        assetPath: 'assets/images/camera.png',
                        onTap: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 95,
                          );
                          if (picked == null) {
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CameraPrintScreen(image: picked),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_scan'.tr(),
                        assetPath: 'assets/images/scan.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DocScanScreen(),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_split'.tr(),
                        assetPath: 'assets/images/split.png',
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: false,
                            allowedExtensions: const ['pdf'],
                          );
                          if (result == null || result.files.isEmpty) {
                            return;
                          }
                          final file = result.files.first;
                          if (file.path == null) {
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SplitPdfScreen(pdfPath: file.path!),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_merge'.tr(),
                        assetPath: 'assets/images/merge.png',
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: true,
                            allowedExtensions: const ['pdf'],
                          );
                          if (result == null || result.files.isEmpty) {
                            return;
                          }
                          final paths = result.files
                              .map((f) => f.path)
                              .whereType<String>()
                              .toList();
                          if (paths.isEmpty) {
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MergePdfScreen(pdfPaths: paths),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_pdf_to_image'.tr(),
                        assetPath: 'assets/images/pdf_to_image.png',
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: false,
                            allowedExtensions: const ['pdf'],
                          );
                          if (result == null || result.files.isEmpty) {
                            return;
                          }
                          final file = result.files.first;
                          if (file.path == null) {
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PdfToImageScreen(pdfPath: file.path!),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_image_to_pdf'.tr(),
                        assetPath: 'assets/images/image_to_pdf.png',
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: true,
                            allowedExtensions: const [
                              'jpg',
                              'jpeg',
                              'png',
                              'webp',
                            ],
                          );
                          if (result == null || result.files.isEmpty) {
                            return;
                          }
                          final files = result.files
                              .where((f) => f.path != null)
                              .toList();
                          if (files.isEmpty) {
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ImageToPdfScreen(images: files),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_contacts'.tr(),
                        assetPath: 'assets/images/contect.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ContactsScreen(),
                            ),
                          );
                        },
                      ),
                      _HomeAction(
                        title: 'feat_web'.tr(),
                        assetPath: 'assets/images/webpage.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WebPageScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkHeaderOverlay,
      child: Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.gradientBackground,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              const Icon(Icons.print_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      t(context, 'app_name'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: BillingService.instance,
                builder: (context, _) {
                  if (BillingService.instance.isPro) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProScreen()),
                      );
                    },
                    tooltip: 'go_pro'.tr(),
                    icon: const ProCrownIcon(size: 30),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// In-app purchase button UI disabled.
// class _ProButton extends StatefulWidget {
//   const _ProButton({required this.onTap});
//
//   final VoidCallback onTap;
//
//   @override
//   State<_ProButton> createState() => _ProButtonState();
// }
//
// class _ProButtonState extends State<_ProButton>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;
//   bool _pressed = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1600),
//     )..repeat(reverse: true);
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTapDown: (_) => setState(() => _pressed = true),
//       onTapUp: (_) {
//         setState(() => _pressed = false);
//         widget.onTap();
//       },
//       onTapCancel: () => setState(() => _pressed = false),
//       child: AnimatedScale(
//         scale: _pressed ? 0.95 : 1.0,
//         duration: const Duration(milliseconds: 120),
//         curve: Curves.easeOut,
//         child: AnimatedBuilder(
//           animation: _controller,
//           builder: (context, child) {
//             final t = _controller.value;
//             final begin = Alignment.lerp(
//               Alignment.topLeft,
//               Alignment.bottomRight,
//               t,
//             )!;
//             final end = Alignment.lerp(
//               Alignment.bottomRight,
//               Alignment.topLeft,
//               t,
//             )!;
//             final c1 =
//                 Color.lerp(AppTheme.actionColor, const Color(0xFF6FA8FF), t)!;
//             final c2 =
//                 Color.lerp(const Color(0xFF4D6FA6), AppTheme.actionColor, t)!;
//             final c3 =
//                 Color.lerp(const Color(0xFF5B86E5), const Color(0xFF4D6FA6), t)!;
//             final c4 =
//                 Color.lerp(const Color(0xFF36D1DC), const Color(0xFF5B86E5), t)!;
//             final c5 =
//                 Color.lerp(const Color(0xFF2BC0E4), const Color(0xFF36D1DC), t)!;
//             return Container(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 12,
//                 vertical: 8,
//               ),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [c1, c2, c3, c4, c5],
//                   begin: begin,
//                   end: end,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.white.withOpacity(0.65),
//                     blurRadius: 12,
//                     spreadRadius: 1,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: const [
//                   Image(
//                     image: AssetImage('assets/images/pro.png'),
//                     height: 16,
//                     width: 16,
//                   ),
//                   SizedBox(width: 6),
//                   Text(
//                     "Go Pro",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 0.2,
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

class _TopBarIcon extends StatelessWidget {
  const _TopBarIcon({
    required this.icon,
    required this.onTap,
    required this.showDot,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          if (showDot)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                height: 8,
                width: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF8A3C),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrinterStatusCard extends StatelessWidget {
  const _PrinterStatusCard({required this.onDropDownTap});

  final VoidCallback onDropDownTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "My Printer:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3A4C6D),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "HP LaserJet Pro",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B3A55),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDropDownTap,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF2B3A55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                height: 54,
                width: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/images/printer.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.circle, color: Color(0xFF64C466), size: 10),
                        SizedBox(width: 6),
                        Text(
                          "Online",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2B3A55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Ready to Print",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7A96),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EAF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.62,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6FA8FF), Color(0xFF4B7FDB)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.onLearnMore});

  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD8EEFF), Color(0xFFBFDDF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'welcome_title'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'welcome_sub'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF546585),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onLearnMore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E6FB5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'learn_more'.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 76,
            width: 96,
            child: Image.asset(
              'assets/images/printer.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.actions});

  final List<_HomeAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return GestureDetector(
          onTap: () {
            AdService.instance.showSelectInterstitialThen(() async {
              action.onTap();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(action.assetPath, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  action.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B3A55),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.title,
    required this.assetPath,
    required this.onTap,
  });

  final String title;
  final String assetPath;
  final VoidCallback onTap;
}

bool _isImageExtension(String? ext) {
  if (ext == null) {
    return false;
  }
  switch (ext.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'webp':
      return true;
    default:
      return false;
  }
}
