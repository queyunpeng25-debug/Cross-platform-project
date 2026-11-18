# Building Map

Interactive map of the CS building (Map tab).

## Features
- Floor plans for 1F, 2F and 3F with zoom and pan
- "You are here" from station QR codes and map QR stickers
- Puzzle piece locations on the stations
- Call pods highlighted on 2F and 3F
- Lift, stairs, toilet, entrances and parking

## Files
- `default_map_slot.dart` - connects the map to the app
- `building_map_screen.dart` - map screen
- `cs_building_map_data.dart` - floor plans and positions (in metres)
- `floor_plan_painter.dart` - draws the floors
- `map_pins.dart`, `map_panels.dart` - pins, legend and controls
- `map_positioning.dart` - QR codes and user position
- `locate_scanner_screen.dart` - QR scanner

## QR stickers
Run `python tools/generate_map_qr_codes.py` to create them in `demo_qr/map/`.

## Tests
Run `flutter test test/map_feature_test.dart`.

Building outline: © OpenStreetMap contributors.
