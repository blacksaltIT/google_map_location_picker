import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_map_location_picker/generated/i18n.dart';
import 'package:google_map_location_picker/src/providers/location_provider.dart';
import 'model/location_result.dart';

/// Custom Search input field, showing the search and clear icons.
class SearchInput extends StatefulWidget {
  final ValueChanged<String> onSearchInput;
  final Key searchInputKey;

  SearchInput(this.onSearchInput, {Key key, this.searchInputKey})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return SearchInputState(onSearchInput);
  }
}

class SearchInputState extends State {
  final ValueChanged<String> onSearchInput;
  final FocusNode focusNode = FocusNode();
  TextEditingController editController = TextEditingController();

  Timer debouncer;

  bool hasSearchEntry = false;

  SearchInputState(this.onSearchInput);

  @override
  void initState() {
    super.initState();
    editController.addListener(onSearchInputChange);
  }

  @override
  void dispose() {
    editController.removeListener(onSearchInputChange);
    editController.dispose();

    super.dispose();
  }

  List<Shadow> textShadows = [
    Shadow(offset: Offset(2, 2), color: Colors.black54, blurRadius: 3),
    Shadow(
        offset: Offset(-0.5, -0.5),
        color: Colors.white.withOpacity(0.85),
        blurRadius: 2)
  ];

  Text getTextIconOf(BuildContext context, IconData iconData,
      {double fontSize = 30, Color color, bool shadow = true}) {
    return Text(String.fromCharCode(iconData.codePoint),
        style: TextStyle(
            fontSize: fontSize,
            color: color ?? Theme.of(context).accentColor,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            shadows: shadow ? textShadows : []));
  }

  void onSearchInputChange() {
    if (!focusNode.hasFocus) return;

    if (editController.text.isEmpty) {
      debouncer?.cancel();
      onSearchInput(editController.text);
      return;
    }

    if (debouncer?.isActive ?? false) {
      debouncer.cancel();
    }

    debouncer = Timer(Duration(milliseconds: 500), () {
      onSearchInput(editController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.only(
          top:8,bottom:8
        ),
        child: Row(
          children: <Widget>[
            FlatButton(
                shape: CircleBorder(),
                padding: EdgeInsets.all(0),
                child: Center(
                    child: getTextIconOf(context, Icons.arrow_back_ios,
                        fontSize: 15)),
                onPressed: () {
                  Navigator.pop(context);
                }),
            Expanded(
              child: TextField(
                style: TextStyle(color: Theme.of(context).accentColor),
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: S.of(context)?.search_place ?? 'Search place',
                  border: InputBorder.none,
                  suffixIcon: hasSearchEntry
                      ? GestureDetector(
                          child: getTextIconOf(context, Icons.clear),
                          onTap: () {
                            editController.clear();
                            LocationResult location =
                                LocationProvider.of(context).lastIdleLocation;
                            LocationResult clearedLocation =
                                new LocationResult();
                            clearedLocation.latLng = location.latLng;
                            LocationProvider.of(context)
                                .setLastIdleLocation(clearedLocation);
                            setState(() {
                              hasSearchEntry = false;
                            });
                          },
                        )
                      : null,
                ),
                controller: editController,
                onChanged: (value) {
                  setState(() {
                    hasSearchEntry = value.isNotEmpty;
                  });
                },
              ),
            ),
            SizedBox(
              width: 8,
            ),
          ],
        ));
  }
}
