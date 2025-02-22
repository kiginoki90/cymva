import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TimelineHeader extends StatefulWidget {
  final PageController pageController;

  const TimelineHeader({super.key, required this.pageController});

  @override
  State<TimelineHeader> createState() => _TimelineHeaderState();
}

class _TimelineHeaderState extends State<TimelineHeader> {
  int currentPage = 0;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeCurrentPage();
    widget.pageController.addListener(_pageListener);
  }

  Future<void> _initializeCurrentPage() async {
    final pageIndexString = await storage.read(key: 'TimeLine') ?? '0';
    final initialPageIndex = int.tryParse(pageIndexString) ?? 0;
    setState(() {
      currentPage = initialPageIndex;
    });
    widget.pageController.jumpToPage(initialPageIndex);
  }

  void _pageListener() async {
    if (mounted) {
      final pageIndex = widget.pageController.page?.round() ?? 0;
      await storage.write(
        key: 'TimeLine',
        value: pageIndex.toString(),
      );
      final pageIndexString = await storage.read(key: 'TimeLine') ?? '0';
      final initialPageIndex = int.tryParse(pageIndexString) ?? 0;
      setState(() {
        currentPage = initialPageIndex;
      });
    }
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_pageListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIconButton('タイムライン', 0),
              _buildIconButton('ランキング', 1),
              _buildIconButton('フォロー', 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(String label, int pageIndex) {
    return IconButton(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Container(
            margin: const EdgeInsets.only(top: 2),
            height: 2,
            width: 60,
            color: currentPage == pageIndex ? Colors.blue : Colors.transparent,
          ),
        ],
      ),
      onPressed: () async {
        widget.pageController.jumpToPage(pageIndex);
        await storage.write(
          key: 'TimeLine',
          value: pageIndex.toString(),
        );
        final pageIndexString = await storage.read(key: 'TimeLine') ?? '0';
        final initialPageIndex = int.tryParse(pageIndexString) ?? 0;
        setState(() {
          currentPage = initialPageIndex;
        });
      },
    );
  }
}
