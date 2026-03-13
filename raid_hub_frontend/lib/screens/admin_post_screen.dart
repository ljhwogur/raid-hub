import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/admin_post.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';

class AdminPostScreen extends StatefulWidget {
  const AdminPostScreen({super.key});

  @override
  State<AdminPostScreen> createState() => _AdminPostScreenState();
}

class _AdminPostScreenState extends State<AdminPostScreen> {
  final ApiService _apiService = ApiService();
  List<AdminPost> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _apiService.getAdminPosts();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('소식을 불러오지 못했습니다: $e')));
    }
  }

  Widget _buildCenteredContent(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900), // 게시판에 적절한 최대 너비
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📢 관리자 소식',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (authService.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: '새 글 작성',
              onPressed: () => _showEditPostDialog(),
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF1A1C20), const Color(0xFF0F1012)]
              : [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)],
          ),
        ),
        child: _buildCenteredContent(
          _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty 
              ? Center(child: Text('등록된 소식이 없습니다.', style: TextStyle(color: textColor.withOpacity(0.5))))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return _buildPostCard(post, authService.isAdmin);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildPostCard(AdminPost post, bool isAdmin) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), 
          width: 1
        ),
      ),
      child: InkWell(
        onTap: () => _showPostDetail(post, isAdmin),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(24), // 패딩을 조금 더 늘림
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white : const Color(0xFF2D3436)
                      ),
                    ),
                  ),
                  if (isAdmin)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.blueAccent),
                          onPressed: () => _showEditPostDialog(post: post),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(post.id!),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.createdAt != null 
                  ? "${post.createdAt!.year}년 ${post.createdAt!.month}월 ${post.createdAt!.day}일"
                  : "",
                style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
              ),
              const Divider(height: 30, thickness: 0.5), // 구분선 추가
              Text(
                post.content,
                maxLines: 3, // 2줄에서 3줄로 늘림
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPostDetail(AdminPost post, bool isAdmin) {
    if (kIsWeb) {
      // 웹(PC) 환경: 화면 중앙에 다이얼로그로 표시
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1C20) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1),
              ),
              child: _buildDetailContent(post, isAdmin, isDialog: true),
            ),
          ),
        ),
      );
    } else {
      // 모바일 환경: 기존대로 바텀 시트 유지
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1C20) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: _buildDetailContent(post, isAdmin, controller: controller),
          ),
        ),
      );
    }
  }

  Widget _buildDetailContent(AdminPost post, bool isAdmin, {ScrollController? controller, bool isDialog = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.all(isDialog ? 32 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  post.title, 
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF2D3436), 
                    fontSize: isDialog ? 28 : 22, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54), 
                onPressed: () => Navigator.pop(context)
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.createdAt != null 
              ? "${post.createdAt!.year}년 ${post.createdAt!.month}월 ${post.createdAt!.day}일 작성됨"
              : "",
            style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), fontSize: 13),
          ),
          const Divider(height: 40, thickness: 1),
          Expanded(
            child: SelectionArea(
              child: Markdown(
                controller: controller,
                data: post.content,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF2D3436), 
                    fontSize: 16, 
                    height: 1.6
                  ),
                  h1: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                  h2: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                  strong: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(color: Colors.blueAccent),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), width: 1)),
                  ),
                ),
                onTapLink: (text, href, title) async {
                  if (href != null && href.startsWith('http')) {
                    await launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog({AdminPost? post}) {
    final titleController = TextEditingController(text: post?.title ?? '');
    final contentController = TextEditingController(text: post?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C20),
        title: Text(post == null ? '새 소식 작성' : '소식 수정', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: '제목', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 10,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '내용 (마크다운 지원)',
                  labelStyle: TextStyle(color: Colors.white54),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final newPost = AdminPost(title: titleController.text, content: contentController.text);
              try {
                if (post == null) {
                  await _apiService.createAdminPost(newPost);
                } else {
                  await _apiService.updateAdminPost(post.id!, newPost);
                }
                if (mounted) {
                  Navigator.pop(context);
                  _loadPosts();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 게시글을 정말로 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              try {
                await _apiService.deleteAdminPost(id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadPosts();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
