// import 'package:flutter/material.dart';
// import 'main_screen.dart';

// class OnboardingScreen extends StatefulWidget {
//   const OnboardingScreen({super.key});

//   @override
//   State<OnboardingScreen> createState() => _OnboardingScreenState();
// }

// class _OnboardingScreenState extends State<OnboardingScreen> {
//   final PageController _controller = PageController();
//   int _index = 0;

//   final List<_OnboardingPage> _pages = const [
//     _OnboardingPage(
//       title: 'Print in Seconds',
//       subtitle: 'Send documents and photos to your printer with one tap.',
//       image: 'assets/images/printer.png',
//       bgStart: Color(0xFFEAF2FF),
//       bgEnd: Color(0xFFBFDDF7),
//       accent: Color(0xFF2F80ED),
//     ),
//     _OnboardingPage(
//       title: 'Scan & Save',
//       subtitle: 'Turn paper into clean PDFs using smart scan tools.',
//       image: 'assets/images/scan.png',
//       bgStart: Color(0xFFFFFFFF),
//       bgEnd: Color(0xFFFFFFFF),
//       accent: Color(0xFF12AAA7),
//     ),
//     _OnboardingPage(
//       title: 'Smart Text',
//       subtitle: 'Extract text and edit instantly from any document.',
//       image: 'assets/images/text.png',
//       bgStart: Color(0xFFFFFFFF),
//       bgEnd: Color(0xFFFFFFFF),
//       accent: Color(0xFF007AFF),
//     ),
//   ];

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   void _next() {
//     if (_index == _pages.length - 1) {
//       Navigator.of(
//         context,
//       ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
//       return;
//     }
//     _controller.nextPage(
//       duration: const Duration(milliseconds: 320),
//       curve: Curves.easeOut,
//     );
//   }

//   void _skip() {
//     _controller.animateToPage(
//       _pages.length - 1,
//       duration: const Duration(milliseconds: 360),
//       curve: Curves.easeOut,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final page = _pages[_index];
//     return Scaffold(
//       body: AnimatedContainer(
//         duration: const Duration(milliseconds: 400),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [page.bgStart, page.bgEnd],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               const SizedBox(height: 12),
//               Expanded(
//                 child: PageView.builder(
//                   controller: _controller,
//                   onPageChanged: (value) => setState(() => _index = value),
//                   itemCount: _pages.length,
//                   itemBuilder: (context, i) {
//                     final p = _pages[i];
//                     return Padding(
//                       padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           AnimatedSwitcher(
//                             duration: const Duration(milliseconds: 350),
//                             child: Container(
//                               key: ValueKey(p.image),
//                               height: 240,
//                               width: 240,
//                               child: Image.asset(p.image, fit: BoxFit.contain),
//                             ),
//                           ),
//                           const SizedBox(height: 64),
//                           Text(
//                             p.title,
//                             textAlign: TextAlign.center,
//                             style: const TextStyle(
//                               fontSize: 26,
//                               fontWeight: FontWeight.w800,
//                               color: Color(0xFF0F172A),
//                               letterSpacing: -0.4,
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           Text(
//                             p.subtitle,
//                             textAlign: TextAlign.center,
//                             style: const TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w600,
//                               color: Color(0xFF334155),
//                               height: 1.35,
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: List.generate(_pages.length, (i) {
//                         final active = i == _index;
//                         return AnimatedContainer(
//                           duration: const Duration(milliseconds: 220),
//                           margin: const EdgeInsets.symmetric(horizontal: 4),
//                           height: 8,
//                           width: active ? 22 : 8,
//                           decoration: BoxDecoration(
//                             color: active ? page.accent : Colors.white,
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                         );
//                       }),
//                     ),
//                     const SizedBox(height: 18),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 48,
//                       child: DecoratedBox(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               page.accent,
//                               page.accent.withOpacity(0.75),
//                             ],
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                           ),
//                           borderRadius: BorderRadius.circular(14),
//                           boxShadow: [
//                             BoxShadow(
//                               color: page.accent.withOpacity(0.35),
//                               blurRadius: 16,
//                               offset: const Offset(0, 8),
//                             ),
//                           ],
//                         ),
//                         child: ElevatedButton(
//                           onPressed: _next,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.transparent,
//                             shadowColor: Colors.transparent,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(14),
//                             ),
//                           ),
//                           child: Text(
//                             _index == _pages.length - 1
//                                 ? 'Get Started'
//                                 : 'Next',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 15,
//                               fontWeight: FontWeight.w800,
//                               letterSpacing: 0.4,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     const Text(
//                       'You can change this anytime in Settings',
//                       style: TextStyle(
//                         fontSize: 11.5,
//                         fontWeight: FontWeight.w600,
//                         color: Color(0xFF64748B),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _OnboardingPage {
//   const _OnboardingPage({
//     required this.title,
//     required this.subtitle,
//     required this.image,
//     required this.bgStart,
//     required this.bgEnd,
//     required this.accent,
//   });

//   final String title;
//   final String subtitle;
//   final String image;
//   final Color bgStart;
//   final Color bgEnd;
//   final Color accent;
// }
