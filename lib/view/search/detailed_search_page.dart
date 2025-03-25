import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DetailedSearchPage extends StatefulWidget {
  final String? initialUserId;
  final bool? movingFlag;

  DetailedSearchPage({this.initialUserId, this.movingFlag});

  @override
  _DetailedSearchPageState createState() => _DetailedSearchPageState();
}

class _DetailedSearchPageState extends State<DetailedSearchPage> {
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  bool _isFollowing = false;
  bool _star = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool movingFlag = false;
  bool _isExactMatch = false;
  String? _imageUrl;

  final List<String> categories = [
    '動物',
    'AI',
    '漫画',
    'イラスト',
    '写真',
    '俳句・短歌',
    '改修要望/バグ',
    '憲章宣誓',
  ];

  final storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    if (widget.initialUserId != null) {
      _userIdController.text = widget.initialUserId!;
    }
    _loadSearchFilters();
    _getImageUrl();
  }

  Future<void> _loadSearchFilters() async {
    _searchController.text = await storage.read(key: 'query') ?? '';
    _selectedCategory = await storage.read(key: 'selectedCategory');
    _userIdController.text = await storage.read(key: 'searchUserId') ?? '';
    _isExactMatch = (await storage.read(key: 'isExactMatch')) == 'true';
    _isFollowing = (await storage.read(key: 'isFollowing')) == 'true';
    _star = (await storage.read(key: 'star')) == 'true';
    String? startDateString = await storage.read(key: 'startDate');
    _startDate =
        startDateString != null ? DateTime.tryParse(startDateString) : null;

    String? endDateString = await storage.read(key: 'endDate');
    _endDate = endDateString != null ? DateTime.tryParse(endDateString) : null;

    setState(() {});
  }

  Future<void> _saveSearchFilters() async {
    await storage.write(key: 'query', value: _searchController.text);
    await storage.write(
        key: 'selectedCategory', value: _selectedCategory ?? '');
    await storage.write(key: 'searchUserId', value: _userIdController.text);
    await storage.write(key: 'isExactMatch', value: _isExactMatch.toString());
    await storage.write(key: 'isFollowing', value: _isFollowing.toString());
    await storage.write(key: 'star', value: _star.toString());
    await storage.write(
        key: 'startDate', value: _startDate?.toIso8601String() ?? '');
    await storage.write(
        key: 'endDate', value: _endDate?.toIso8601String() ?? '');
  }

  Future<void> _clearSearchFilters() async {
    await storage.delete(key: 'query');
    await storage.delete(key: 'selectedCategory');
    await storage.delete(key: 'searchUserId');
    await storage.delete(key: 'isExactMatch');
    await storage.delete(key: 'isFollowing');
    await storage.delete(key: 'star');
    await storage.delete(key: 'startDate');
    await storage.delete(key: 'endDate');
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _applySearchFilters() async {
    await _clearSearchFilters();
    await _saveSearchFilters();
    Navigator.pop(context, {
      'query': _searchController.text,
      'selectedCategory': _selectedCategory,
      'searchUserId': _userIdController.text,
      'isExactMatch': _isExactMatch,
      'isFollowing': _isFollowing,
      'star': _star,
      'startDate': _startDate,
      'endDate': _endDate,
    });
  }

  void _clearFilters() async {
    await _clearSearchFilters();
    setState(() {
      _selectedCategory = null;
      _searchController.clear();
      _userIdController.clear();
      _isExactMatch = false;
      _isFollowing = false;
      _star = false;
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _getImageUrl() async {
    // FirestoreからURLを取得
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('setting')
        .doc('AppBarIMG')
        .get();
    String? imageUrl = doc.data()?['DetailedSearchPage'];
    if (imageUrl != null &&
        (imageUrl.startsWith('gs://') || imageUrl.startsWith('https://'))) {
      // Firebase StorageからダウンロードURLを取得
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      String downloadUrl = await ref.getDownloadURL();
      setState(() {
        _imageUrl = downloadUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _imageUrl == null
            ? const Text('詳しい検索条件', style: TextStyle(color: Colors.black))
            : Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                height: kToolbarHeight,
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          TextButton.icon(
            label: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text('clear'),
            ),
            onPressed: _clearFilters,
            style: TextButton.styleFrom(
              side: BorderSide(
                  color: const Color.fromARGB(255, 168, 201, 221),
                  width: 2), // 枠線の色と幅を設定
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4), // 角を丸める
              ),
            ),
          ),
          SizedBox(width: 12.0), // 右側に空間を追加
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('カテゴリー',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 28, 22, 209))),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2列に設定
                  childAspectRatio: 3, // アスペクト比を設定して高さを調整
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.lightBlueAccent.withValues()
                            : Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: '検索内容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'ユーザーID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      const Text('完全一致'),
                      Checkbox(
                        value: _isExactMatch,
                        onChanged: (bool? value) {
                          setState(() {
                            _isExactMatch = value ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('フォローユーザー',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 28, 22, 209))),
                  Switch(
                    value: _isFollowing,
                    onChanged: (value) {
                      setState(() {
                        _isFollowing = value;
                        // if (value) {
                        //   _star = false;
                        // }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('スター',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 28, 22, 209))),
                  Switch(
                    value: _star,
                    onChanged: (value) {
                      setState(() {
                        _star = value;
                        // if (value) {
                        //   _isFollowing = false;
                        // }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('開始日',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 28, 22, 209))),
                  TextButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(_startDate == null
                        ? '選択してください'
                        : '${_startDate!.toLocal()}'.split(' ')[0]),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('終了日',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 28, 22, 209))),
                  TextButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(_endDate == null
                        ? '選択してください'
                        : '${_endDate!.toLocal()}'.split(' ')[0]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _applySearchFilters,
                  child: Text(
                    '検索',
                    style: TextStyle(
                      color: Colors.white, // 文字の色を白に設定
                      fontWeight: FontWeight.bold, // 文字を太く設定
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 153, 204, 224),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0), // 角を四角くする
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
