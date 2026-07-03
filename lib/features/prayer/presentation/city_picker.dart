/// Searchable worldwide city picker for prayer times.
library;

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/features/prayer/data/prayer_cities.dart';

Future<PrayerCity?> showCityPicker(BuildContext context) {
  return showModalBottomSheet<PrayerCity>(
    context: context,
    backgroundColor: AppColors.surfaceBlack,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
    ),
    builder: (_) => const _CityPickerSheet(),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = _query.isEmpty
        ? kPrayerCities
        : kPrayerCities
            .where((c) =>
                c.label.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              autofocus: true,
              style: AppTypography.body,
              cursorColor: AppColors.shinyWhite,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search your city…',
                hintStyle: const TextStyle(color: AppColors.mutedWhite),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.mutedWhite),
                filled: true,
                fillColor: AppColors.glassTint,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusButton),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                        'City not listed — pick the nearest big city.',
                        style: AppTypography.caption))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: const Icon(Icons.location_city_outlined,
                          color: AppColors.mutedWhite, size: 20),
                      title:
                          Text(visible[i].label, style: AppTypography.body),
                      onTap: () => Navigator.pop(context, visible[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
