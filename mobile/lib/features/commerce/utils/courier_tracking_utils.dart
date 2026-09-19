import 'package:url_launcher/url_launcher.dart';

/// Resolves standard Indian and international courier tracking portal URLs.
String? resolveCourierTrackingUrl(String carrier, String trackingNumber) {
  if (trackingNumber.trim().isEmpty) return null;
  final c = carrier.toLowerCase().trim();
  final t = trackingNumber.trim();
  if (c.contains('delhivery')) {
    return 'https://www.delhivery.com/track/package/$t';
  } else if (c.contains('blue dart') || c.contains('bluedart')) {
    return 'https://www.bluedart.com/tracking?track=$t';
  } else if (c.contains('dtdc')) {
    return 'https://www.dtdc.in/tracking/shipment-tracking.asp?strCnno=$t';
  } else if (c.contains('india post') || c.contains('speed post')) {
    return 'https://www.indiapost.gov.in/_layouts/15/dop.portal.tracking/trackconsignment.aspx';
  } else if (c.contains('ekart')) {
    return 'https://ekartlogistics.com/shipmenttrack/$t';
  } else if (c.contains('trackon')) {
    return 'https://trackon.in/track/$t';
  } else if (c.contains('fedex')) {
    return 'https://www.fedex.com/fedextrack/?trknbr=$t';
  } else if (c.contains('shadowfax')) {
    return 'https://tracker.shadowfax.in/track/$t';
  } else if (c.contains('xpressbees') || c.contains('xpress')) {
    return 'https://www.xpressbees.com/track?tracking_id=$t';
  }
  return 'https://www.google.com/search?q=${Uri.encodeComponent('$carrier tracking $t')}';
}

/// Opens the courier tracking web page in external browser or in-app view.
Future<bool> launchCourierTracking(String carrier, String trackingNumber) async {
  final urlStr = resolveCourierTrackingUrl(carrier, trackingNumber);
  if (urlStr == null) return false;
  final uri = Uri.parse(urlStr);
  return await launchUrl(uri, mode: LaunchMode.externalApplication);
}
