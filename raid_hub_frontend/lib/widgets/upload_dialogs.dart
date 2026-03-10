import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/raid_video.dart';

/// [VideoUploadDialog]
/// 관리자가 새로운 공략 영상의 유튜브 링크를 직접 등록할 때 사용하는 팝업 다이얼로그입니다.
class VideoUploadDialog extends StatefulWidget {
  final Map<String, List<String>> raidByCategory;
  final Function(RaidVideo) onUpload;
  
  const VideoUploadDialog({super.key, required this.raidByCategory, required this.onUpload});

  @override
  State<VideoUploadDialog> createState() => _VideoUploadDialogState();
}

class _VideoUploadDialogState extends State<VideoUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  String? _selectedRaidName;
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _uploaderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.raidByCategory.keys.first;
    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('공략 영상 등록'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: '레이드 분류'),
                items: widget.raidByCategory.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() {
                  _selectedCategory = val!;
                  _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
                }),
              ),
              DropdownButtonFormField<String>(
                value: _selectedRaidName,
                decoration: const InputDecoration(labelText: '레이드 이름'),
                items: widget.raidByCategory[_selectedCategory]?.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _selectedRaidName = val),
              ),
              TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: '영상 제목'), validator: (val) => val!.isEmpty ? '제목을 입력하세요' : null),
              TextFormField(controller: _urlController, decoration: const InputDecoration(labelText: '유튜브 URL'), validator: (val) => val!.isEmpty ? 'URL을 입력하세요' : null),
              TextFormField(controller: _uploaderController, decoration: const InputDecoration(labelText: '스트리머/유튜버 이름'), validator: (val) => val!.isEmpty ? '이름을 입력하세요' : null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onUpload(RaidVideo(
                title: _titleController.text,
                youtubeUrl: _urlController.text,
                uploaderName: _uploaderController.text,
                raidName: _selectedRaidName!,
                difficulty: '공략',
                gate: '전체',
              ));
            }
          },
          child: const Text('등록'),
        ),
      ],
    );
  }
}

/// [CheatSheetUploadDialog]
/// 관리자가 새로운 컨닝페이퍼(이미지)를 업로드할 때 사용하는 팝업 다이얼로그입니다.
/// FilePicker를 사용하여 로컬의 이미지를 선택할 수 있습니다.
class CheatSheetUploadDialog extends StatefulWidget {
  final Map<String, List<String>> raidByCategory;
  final Function(String, String, String, String, List<int>, String) onUpload;
  
  const CheatSheetUploadDialog({super.key, required this.raidByCategory, required this.onUpload});

  @override
  State<CheatSheetUploadDialog> createState() => _CheatSheetUploadDialogState();
}

class _CheatSheetUploadDialogState extends State<CheatSheetUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  String? _selectedRaidName;
  final _titleController = TextEditingController();
  final _gateController = TextEditingController(text: '전체');
  final _uploaderController = TextEditingController();
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.raidByCategory.keys.first;
    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null) setState(() => _pickedFile = result.files.first);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('컨닝 페이퍼 등록'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pickedFile != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Image.memory(_pickedFile!.bytes!, height: 150, fit: BoxFit.cover)),
              ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image), label: Text(_pickedFile == null ? '이미지 선택' : '이미지 변경')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: '레이드 분류'),
                items: widget.raidByCategory.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() {
                  _selectedCategory = val!;
                  _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
                }),
              ),
              DropdownButtonFormField<String>(
                value: _selectedRaidName,
                decoration: const InputDecoration(labelText: '레이드 이름'),
                items: widget.raidByCategory[_selectedCategory]?.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _selectedRaidName = val),
              ),
              TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: '공략 제목'), validator: (val) => val!.isEmpty ? '제목을 입력하세요' : null),
              TextFormField(controller: _gateController, decoration: const InputDecoration(labelText: '관문'), validator: (val) => val!.isEmpty ? '관문을 입력하세요' : null),
              TextFormField(controller: _uploaderController, decoration: const InputDecoration(labelText: '출처 (작성자/사이트명 등)')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _pickedFile != null) {
              widget.onUpload(_titleController.text, _selectedRaidName!, _gateController.text, _uploaderController.text, _pickedFile!.bytes!, _pickedFile!.name);
            } else if (_pickedFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지를 선택해주세요.')));
            }
          },
          child: const Text('업로드'),
        ),
      ],
    );
  }
}
