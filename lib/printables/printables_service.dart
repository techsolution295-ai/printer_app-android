import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'printable_item.dart';

/// Loads printables from a remote JSON catalog, then a curated open-source
/// fallback. Images stay on the network — nothing is bundled as an asset.
class PrintablesService {
  PrintablesService._();

  static final PrintablesService instance = PrintablesService._();

  static const catalogUrl =
      'https://raw.githubusercontent.com/cursor-printables/catalog/main/catalog.json';

  static const _catalogTimeout = Duration(seconds: 4);
  static const _downloadTimeout = Duration(seconds: 20);

  static const _headers = {
    'User-Agent': 'SmartPrinter/1.0',
    'Accept': 'image/*,application/pdf,*/*;q=0.8',
  };

  PrintablesCatalog? _cache;

  Future<PrintablesCatalog> loadCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    try {
      final response = await http
          .get(Uri.parse(catalogUrl))
          .timeout(_catalogTimeout);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final catalog = PrintablesCatalog.fromJson(json);
        if (catalog.categories.isNotEmpty) {
          _cache = catalog;
          return catalog;
        }
      }
    } catch (_) {
      // Remote catalog is optional. The curated fallback still uses remote URLs.
    }

    _cache = _openSourceFallback();
    return _cache!;
  }

  Future<Uint8List> downloadBytes(String url) async {
    final response = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(_downloadTimeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('Download failed (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  /// Downloads the printable and returns print-ready PDF bytes.
  Future<Uint8List> buildPrintablePdf(PrintableItem item) async {
    final bytes = await downloadBytes(item.fileUrl);
    if (item.isPdf) return bytes;
    return _imageToPdf(bytes);
  }

  Future<Uint8List> _imageToPdf(Uint8List imageBytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    return doc.save();
  }

  PrintablesCatalog _openSourceFallback() {
    String unsplash(String id) =>
        'https://images.unsplash.com/photo-$id?auto=format&fit=crop&w=900&q=80';
    String pexels(String path) =>
        'https://images.pexels.com/photos/$path?auto=compress&cs=tinysrgb&w=800';

    return PrintablesCatalog(
      version: 2,
      categories: [
        PrintableCategory(
          id: 'birthday',
          title: 'Birthday cards',
          items: [
            _img('bd1', 'Happy Birthday Balloons', unsplash('1530103862676-de8c9debad1d'), 'Unsplash'),
            _img('bd2', 'Cake Celebration', unsplash('1464349095431-e9a21285b5f3'), 'Unsplash'),
            _img('bd3', 'Party Confetti', unsplash('1513151233558-d860c5398176'), 'Unsplash'),
            _img('bd4', 'Colorful Gifts', unsplash('1513885535751-8b9238bd345a'), 'Unsplash'),
            _img('bd5', 'Birthday Cupcakes', unsplash('1578985545062-69928b1d9587'), 'Unsplash'),
            _img('bd6', 'Festive Decor', unsplash('1464349153735-7db50ed83c84'), 'Unsplash'),
            _img('bd7', 'Party Lights', pexels('1729797/pexels-photo-1729797.jpeg'), 'Pexels'),
            _img('bd8', 'Celebration Cake', pexels('1055272/pexels-photo-1055272.jpeg'), 'Pexels'),
            _img('bd9', 'Sparkle Party', unsplash('1492684223066-81342ee5ff30'), 'Unsplash'),
            _img('bd10', 'Balloon Party', pexels('1793035/pexels-photo-1793035.jpeg'), 'Pexels'),
            _img('bd11', 'Birthday Table', pexels('1857157/pexels-photo-1857157.jpeg'), 'Pexels'),
            _img('bd12', 'Gift Box Card', unsplash('1549465220-1a8b9238cd48'), 'Unsplash'),
            _img('bd13', 'Kids Birthday Fun', unsplash('1602631985686-1bb0e6a8696e'), 'Unsplash'),
            _img('bd14', 'Golden Birthday', unsplash('1511795409834-ef04bbd61622'), 'Unsplash'),
            _img('bd15', 'Floral Birthday', unsplash('1487530811176-3780de880c2d'), 'Unsplash'),
          ],
        ),
        PrintableCategory(
          id: 'calendars',
          title: 'Calendars',
          items: [
            _img('cal1', 'Minimal Desk Calendar', unsplash('1506784983877-45594efa4cbe'), 'Unsplash'),
            _img('cal2', 'Wall Calendar Grid', unsplash('1611224923853-80b023f02d71'), 'Unsplash'),
            _img('cal3', 'Planner Calendar', pexels('5712136/pexels-photo-5712136.jpeg'), 'Pexels'),
            _pdf(
              'cal4',
              'Sample Calendar PDF',
              'https://mozilla.github.io/pdf.js/web/compressed.tracemonkey-pldi-09.pdf',
              unsplash('1506784365847-bbad939e9335'),
              'GitHub · Mozilla PDF.js',
            ),
            _img('cal5', 'Monthly Overview', unsplash('1484480974693-6ca0a78fb36b'), 'Unsplash'),
            _img('cal6', 'Vintage Calendar Page', unsplash('1506784365847-bbad939e9335'), 'Unsplash'),
            _img('cal7', 'Year Planner Look', unsplash('1454165804606-c3d57bc86b40'), 'Unsplash'),
            _img('cal8', 'Clean Schedule', pexels('5712137/pexels-photo-5712137.jpeg'), 'Pexels'),
            _img('cal9', 'Office Calendar', pexels('669610/pexels-photo-669610.jpeg'), 'Pexels'),
            _img('cal10', 'Date Grid Style', unsplash('1517842645767-c639042777db'), 'Unsplash'),
          ],
        ),
        PrintableCategory(
          id: 'planners',
          title: 'Planners',
          items: [
            _img('pl1', 'Daily Appointment Book', unsplash('1484480974693-6ca0a78fb36b'), 'Unsplash'),
            _img('pl2', 'Daily Planner', unsplash('1517842645767-c639042777db'), 'Unsplash'),
            _img('pl3', 'Weekly Work Planner', unsplash('1454165804606-c3d57bc86b40'), 'Unsplash'),
            _img('pl4', 'Notebook Goals', unsplash('1516414447565-b14be0adf13e'), 'Unsplash'),
            _img('pl5', 'To-Do Checklist', pexels('5905700/pexels-photo-5905700.jpeg'), 'Pexels'),
            _img('pl6', 'Habit Tracker Style', unsplash('1606326608606-aa0b62935f2b'), 'Unsplash'),
            _img('pl7', 'Meeting Notes', unsplash('1434030216411-0b793f4b4173'), 'Unsplash'),
            _img('pl8', 'Study Planner', pexels('4145153/pexels-photo-4145153.jpeg'), 'Pexels'),
            _img('pl9', 'Bullet Journal Page', unsplash('1544396821-4dd40b938ad3'), 'Unsplash'),
            _img('pl10', 'Weekly Spread', pexels('3184465/pexels-photo-3184465.jpeg'), 'Pexels'),
          ],
        ),
        PrintableCategory(
          id: 'games',
          title: 'Games & Puzzles',
          items: [
            _img('gm1', 'Classic Puzzle Fun', pexels('207983/pexels-photo-207983.jpeg'), 'Pexels'),
            _img('gm2', 'Valentine Maze Style', unsplash('1518199266791-5375a83190b7'), 'Unsplash'),
            _img('gm3', 'Spring Activity Page', unsplash('1490750967868-88aa4486c946'), 'Unsplash'),
            _img('gm4', 'Summer Fun Sheet', unsplash('1507525428034-b723cf961d3e'), 'Unsplash'),
            _img('gm5', 'Board Game Night', pexels('163036/mario-luigi-yoschi-figures-163036.jpeg'), 'Pexels'),
            _img('gm6', 'Kids Coloring Scene', unsplash('1513364776144-60967b0f800f'), 'Unsplash'),
            _img('gm7', 'Word Play Theme', unsplash('1588196749597-9ff075ee6b5b'), 'Unsplash'),
            _img('gm8', 'Family Game Night', unsplash('1611996575749-79a3a250f948'), 'Unsplash'),
            _img('gm9', 'Puzzle Pieces', unsplash('1587654780291-39c9404d746b'), 'Unsplash'),
            _img('gm10', 'Brain Teaser Card', pexels('1337380/pexels-photo-1337380.jpeg'), 'Pexels'),
          ],
        ),
        PrintableCategory(
          id: 'nature',
          title: 'Nature',
          items: [
            _img('na1', 'Forest Path', unsplash('1441974231531-c6227db76b6e'), 'Unsplash'),
            _img('na2', 'Foggy Peaks', unsplash('1470071459604-3b5ec3a7fe05'), 'Unsplash'),
            _img('na3', 'Desert Road', unsplash('1500530855697-b586d89ba3ee'), 'Unsplash'),
            _img('na4', 'Mountain Sunrise', unsplash('1469474968028-56623f02e42e'), 'Unsplash'),
            _img('na5', 'Green Hills', unsplash('1472214103451-9374bd1c798e'), 'Unsplash'),
            _img('na6', 'Lake View', unsplash('1426604966848-d7adac402bff'), 'Unsplash'),
            _img('na7', 'Waterfall', unsplash('1433086966358-54859d0ed716'), 'Unsplash'),
            _img('na8', 'Ocean Sunset', unsplash('1475924156734-496f6cac6ec1'), 'Unsplash'),
            _img('na9', 'Moss Forest', unsplash('1447752875215-b2761acb3c5d'), 'Unsplash'),
          ],
        ),
        PrintableCategory(
          id: 'flowers',
          title: 'Flowers',
          items: [
            _img('fl1', 'Tulip Field', unsplash('1462275646964-a0e3386b89fa'), 'Unsplash'),
            _img('fl2', 'Red Roses', unsplash('1496062031456-07b8f162a322'), 'Unsplash'),
            _img('fl3', 'Flower Bouquet', unsplash('1526047932273-341f2a7631f9'), 'Unsplash'),
            _img('fl4', 'Spring Bloom', unsplash('1457089328109-e5d9bd499191'), 'Unsplash'),
            _img('fl5', 'Rose Garden', unsplash('1468327768560-75b778cbb551'), 'Unsplash'),
            _img('fl6', 'Green Leaves', unsplash('1501004318641-b39e6451bec6'), 'Unsplash'),
            _img('fl7', 'Succulents', unsplash('1416879595882-3373a0480b5b'), 'Unsplash'),
            _img('fl8', 'Wildflowers', unsplash('1508610048659-a06b669e3321'), 'Unsplash'),
          ],
        ),
        PrintableCategory(
          id: 'animals',
          title: 'Animals',
          items: [
            _img('an1', 'Puppy Portrait', unsplash('1517849845537-4d257902454a'), 'Unsplash'),
            _img('an2', 'Cat Close-up', unsplash('1514888286974-6c03e2ca1dba'), 'Unsplash'),
            _img('an3', 'Red Fox', unsplash('1474511320723-9a56873867b5'), 'Unsplash'),
            _img('an4', 'Leopard', unsplash('1456926631375-92c8ce872def'), 'Unsplash'),
            _img('an5', 'Panda', unsplash('1564349683136-77e08dba1ef7'), 'Unsplash'),
            _img('an6', 'Songbird', unsplash('1444464666168-49d633b86797'), 'Unsplash'),
            _img('an7', 'Butterfly', unsplash('1475809913362-28a064062ccd'), 'Unsplash'),
            _img('an8', 'Happy Dog', unsplash('1548767797-d8c844163c4c'), 'Unsplash'),
            _img('an9', 'Kitten', unsplash('1583337130417-3346a1be7dee'), 'Unsplash'),
          ],
        ),
        PrintableCategory(
          id: 'school',
          title: 'School',
          items: [
            _img('sc1', 'Classroom', unsplash('1503676260728-1c00da094a0b'), 'Unsplash'),
            _img('sc2', 'Open Books', unsplash('1497633762265-9d179a990aa6'), 'Unsplash'),
            _img('sc3', 'Book Stack', unsplash('1481627834876-b7833e8f5570'), 'Unsplash'),
            _img('sc4', 'Study Desk', unsplash('1456513080510-7bf3a84b82f8'), 'Unsplash'),
            _img('sc5', 'School Hall', unsplash('1509062522246-3755977927d7'), 'Unsplash'),
            _img('sc6', 'Library Shelf', unsplash('1524995997946-a1c2e315a42f'), 'Unsplash'),
            _img('sc7', 'Writing Notes', unsplash('1488190211105-8b0e65b80b4e'), 'Unsplash'),
            _img('sc8', 'School Supplies', unsplash('1513542789411-b6a5d4f31634'), 'Unsplash'),
          ],
        ),
        PrintableCategory(
          id: 'food',
          title: 'Food',
          items: [
            _img('fd1', 'Dinner Plate', unsplash('1504674900247-0877df9cc836'), 'Unsplash'),
            _img('fd2', 'Fresh Bowl', unsplash('1498837167922-ddd27525d352'), 'Unsplash'),
            _img('fd3', 'Fruit Spread', unsplash('1495521821757-a1efb6729352'), 'Unsplash'),
            _img('fd4', 'Pasta Plate', unsplash('1467003909585-2f8a72700288'), 'Unsplash'),
            _img('fd5', 'Breakfast Eggs', unsplash('1482049016688-2d3e1b311543'), 'Unsplash'),
            _img('fd6', 'Garden Salad', unsplash('1512621776951-a57141f2eefd'), 'Unsplash'),
            _img('fd7', 'Pancake Stack', unsplash('1567620905732-2d1ec7ab7445'), 'Unsplash'),
            _img('fd8', 'Grill Night', unsplash('1555939594-58d7cb561ad1'), 'Unsplash'),
            _img('fd9', 'Morning Table', unsplash('1493770348161-369560ae357d'), 'Unsplash'),
          ],
        ),
        PrintableCategory(
          id: 'travel',
          title: 'Travel',
          items: [
            _img('tr1', 'Travel Flatlay', unsplash('1488646953014-85cb44e25828'), 'Unsplash'),
            _img('tr2', 'Open Road', unsplash('1469854523086-cc02fe5d8800'), 'Unsplash'),
            _img('tr3', 'Lake House', unsplash('1476514525535-07fb3b4ae5f1'), 'Unsplash'),
            _img('tr4', 'Paris Streets', unsplash('1502602898657-3e91760cbb34'), 'Unsplash'),
            _img('tr5', 'Island View', unsplash('1533105079780-92b9be482077'), 'Unsplash'),
            _img('tr6', 'Coastal Town', unsplash('1516483638261-f4dbaf036963'), 'Unsplash'),
            _img('tr7', 'Canal City', unsplash('1523906834658-6e24ef2386f9'), 'Unsplash'),
            _img('tr8', 'City Skyline', unsplash('1506973035872-a4ec16b8e8d9'), 'Unsplash'),
            _img('tr9', 'Old Town', unsplash('1467269204594-9661b134dd2b'), 'Unsplash'),
            _img('tr10', 'Night Lights', unsplash('1528183429752-a97d0bf99b5a'), 'Unsplash'),
          ],
        ),
        PrintableCategory(
          id: 'holidays',
          title: 'Holidays',
          items: [
            _img('ho1', 'Christmas Tree', unsplash('1512389142860-9c449e58a543'), 'Unsplash'),
            _img('ho2', 'Holiday Decor', unsplash('1543589077-47d81606c1bf'), 'Unsplash'),
            _img('ho3', 'String Lights', unsplash('1482517967863-00e15c9b44be'), 'Unsplash'),
            _img('ho4', 'Wrapped Gifts', unsplash('1512909006721-3d6018887383'), 'Unsplash'),
            _img('ho5', 'Fireworks', unsplash('1467810563316-b5476525c0f9'), 'Unsplash'),
          ],
        ),
      ],
    );
  }

  PrintableItem _img(String id, String title, String url, String source) {
    return PrintableItem(
      id: id,
      title: title,
      previewUrl: url,
      fileUrl: url,
      fileType: 'image',
      source: source,
    );
  }

  PrintableItem _pdf(
    String id,
    String title,
    String fileUrl,
    String previewUrl,
    String source,
  ) {
    return PrintableItem(
      id: id,
      title: title,
      previewUrl: previewUrl,
      fileUrl: fileUrl,
      fileType: 'pdf',
      source: source,
    );
  }
}
