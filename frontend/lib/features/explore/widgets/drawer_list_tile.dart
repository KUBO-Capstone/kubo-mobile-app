// Helper widget for List titles in explore page, drawer
import 'package:flutter/material.dart';
import '../../../core/widgets/app_svg_icon.dart';

class DrawerListTile extends StatelessWidget {
  final String title;
  final String iconPath;
  final int? tabIndex;

  const DrawerListTile({
    super.key,
    required this.title,
    required this.iconPath,
    this.tabIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 8),
      leading: AppSvgIcon(assetPath: iconPath, size: 20, color: Colors.black),
      title: Text(title),
      onTap: () { 
        // route to corresponding page
      },
    );
  }
} 