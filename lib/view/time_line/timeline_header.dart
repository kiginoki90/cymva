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
  late VoidCallback _pageListener;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeCurrentPage();
    _pageListener = () {
      if (mounted) {
        setState(() {
          currentPage = widget.pageController.page?.round() ?? 0;
        });
      }
    };
    widget.pageController.addListener(_pageListener);
  }

  Future<void> _initializeCurrentPage() async {
    final pageIndexString = await storage.read(key: 'TimeLine') ?? '0';
    final initialPageIndex = int.tryParse(pageIndexString) ?? 0;
    setState(() {
      currentPage = initialPageIndex;
    });
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
              IconButton(
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('タイムライン'),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      height: 2,
                      width: 60,
                      color:
                          currentPage == 0 ? Colors.blue : Colors.transparent,
                    ),
                  ],
                ),
                onPressed: () {
                  widget.pageController.jumpToPage(0);
                },
              ),
              IconButton(
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ランキング'),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      height: 2,
                      width: 60,
                      color:
                          currentPage == 1 ? Colors.blue : Colors.transparent,
                    ),
                  ],
                ),
                onPressed: () {
                  widget.pageController.jumpToPage(1);
                },
              ),
              IconButton(
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('フォロー'),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      height: 2,
                      width: 60,
                      color:
                          currentPage == 2 ? Colors.blue : Colors.transparent,
                    ),
                  ],
                ),
                onPressed: () {
                  widget.pageController.jumpToPage(2);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
