import 'package:flutter/material.dart';

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
  DateTime? _startDate;
  DateTime? _endDate;
  bool movingFlag = false;

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

  @override
  void initState() {
    super.initState();
    if (widget.initialUserId != null) {
      _userIdController.text = widget.initialUserId!;
    }
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

  void _applySearchFilters() {
    // 検索条件を適用する処理をここに追加
    Navigator.pop(context, {
      'query': _searchController.text,
      'selectedCategory': _selectedCategory,
      'searchUserId': _userIdController.text,
      'isFollowing': _isFollowing,
      'startDate': _startDate,
      'endDate': _endDate,
    }); // モーダルを閉じると同時に検索条件を渡す
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _searchController.clear();
      _userIdController.clear();
      _isFollowing = false;
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('詳しい検索条件'),
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
              Text('カテゴリー',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Column(
                children: categories.map((category) {
                  return RadioListTile<String>(
                    title: Text(category),
                    value: category,
                    groupValue: _selectedCategory,
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 0.0, horizontal: 16.0), // パディングを調整
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '検索内容',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(
                  labelText: 'ユーザーID',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('フォローユーザー', style: TextStyle(fontSize: 16)),
                  Switch(
                    value: _isFollowing,
                    onChanged: (value) {
                      setState(() {
                        _isFollowing = value;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('開始日', style: TextStyle(fontSize: 16)),
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
                  Text('終了日', style: TextStyle(fontSize: 16)),
                  TextButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(_endDate == null
                        ? '選択してください'
                        : '${_endDate!.toLocal()}'.split(' ')[0]),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _applySearchFilters,
                  child: Text('完了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
