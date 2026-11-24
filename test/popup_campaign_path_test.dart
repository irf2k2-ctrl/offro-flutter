// The popup request carries the account's country code (never inferred from the city) when it is known.
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/screens/home/popup_campaign_overlay.dart' show popupCampaignsPath;

void main() {
  test('country code is added when known, upper-cased', () {
    expect(popupCampaignsPath('Riyadh', 'sa'), '/public/popup-campaigns?city=Riyadh&country=SA');
    expect(popupCampaignsPath('New Delhi', 'IN'), '/public/popup-campaigns?city=New%20Delhi&country=IN');
  });

  test('a guest / unknown country sends the city only (the old request)', () {
    expect(popupCampaignsPath('Mumbai', null), '/public/popup-campaigns?city=Mumbai');
    expect(popupCampaignsPath('Mumbai', ' '), '/public/popup-campaigns?city=Mumbai');
  });
}
