import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

String t(BuildContext context, String key, {Map<String, String>? namedArgs}) {
  return key.tr(context: context, namedArgs: namedArgs);
}

const _categoryKeys = <String, String>{
  'Birthday cards': 'cat_birthday',
  'Calendars': 'cat_calendars',
  'Planners': 'cat_planners',
  'Games & Puzzles': 'cat_games',
  'Nature': 'cat_nature',
  'Flowers': 'cat_flowers',
  'Animals': 'cat_animals',
  'School': 'cat_school',
  'Food': 'cat_food',
  'Travel': 'cat_travel',
  'Holidays': 'cat_holidays',
};

const _historyKeys = <String, String>{
  'Smart Text': 'feat_smart_text',
  'Photo Print': 'feat_photo',
  'Camera Print': 'camera_print',
  'Web Print': 'feat_web',
  'Contacts': 'feat_contacts',
  'Split PDF': 'feat_split',
  'Merge PDF': 'feat_merge',
  'PDF to Image': 'feat_pdf_to_image',
  'PDF to Image (Print)': 'pdf_to_image_print',
  'Image to PDF': 'feat_image_to_pdf',
  'Image to PDF (Print)': 'image_to_pdf_print',
  'Page Layout': 'feat_layout',
  'Doc Scan': 'doc_scan',
  'Doc Scanner': 'feat_scan',
};

String localizedCategory(BuildContext context, String title) {
  final key = _categoryKeys[title];
  if (key == null) return title;
  return key.tr(context: context);
}

String localizedHistoryTitle(BuildContext context, String title) {
  final key = _historyKeys[title];
  if (key == null) return title;
  return key.tr(context: context);
}
