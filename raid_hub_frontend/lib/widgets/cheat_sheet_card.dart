import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cheat_sheet.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart'; // Add ApiService import

/// [CheatSheetCard]
/// 단일 컨닝페이퍼(CheatSheet) 정보를 표시하는 카드 위젯입니다.
/// 클릭 시 이미지를 전체 화면으로 보여주고, 관리자에게는 삭제 버튼을 제공합니다.
class CheatSheetCard extends StatelessWidget {
  final CheatSheet cheatSheet;
  final VoidCallback onDelete;

  const CheatSheetCard({
    super.key,
    required this.cheatSheet,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = ApiService(); // Add instance

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              // 클릭 로그 기록
              apiService.logActivity(
                activityType: 'CHEATSHEET_CLICK',
                targetTitle: '${cheatSheet.raidName} | ${cheatSheet.title}',
              );
              _showFullImage(context, cheatSheet);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.network(
                    cheatSheet.fullImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, _, __) =>
                        const Center(child: Icon(Icons.broken_image, size: 50)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cheatSheet.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${cheatSheet.raidName} | ${cheatSheet.gate}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (authService.isAdmin)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: onDelete,
              ),
            ),
        ],
      ),
    );
  }

  /// 이미지를 전체 화면으로 띄우는 다이얼로그
  void _showFullImage(BuildContext context, CheatSheet cs) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        panEnabled: true, // Enable panning
                        scaleEnabled: true, // Enable zooming
                        minScale: 0.5,
                        maxScale: 5.0, // Allow up to 5x zoom
                        child: Image.network(
                          cs.fullImageUrl,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                color: Colors.black87,
                child: Text(
                  '출처: ${cs.uploaderName}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
