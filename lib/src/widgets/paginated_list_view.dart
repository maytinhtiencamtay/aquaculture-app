import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A generic paginated list wrapper.
/// Wraps a list of items and provides page-based navigation controls at the bottom.
class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int itemsPerPage;
  final EdgeInsetsGeometry padding;
  final Widget? emptyWidget;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.itemsPerPage = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.emptyWidget,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant PaginatedListView<T> old) {
    super.didUpdateWidget(old);
    // Reset page if list changes significantly
    if (widget.items.length != old.items.length) {
      final maxPage = _maxPage;
      if (_currentPage > maxPage) {
        _currentPage = maxPage;
      }
    }
  }

  int get _maxPage => widget.items.isEmpty ? 0 : ((widget.items.length - 1) ~/ widget.itemsPerPage);
  int get _totalPages => _maxPage + 1;

  List<T> get _pageItems {
    final start = _currentPage * widget.itemsPerPage;
    final end = (start + widget.itemsPerPage).clamp(0, widget.items.length);
    return widget.items.sublist(start, end);
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page.clamp(0, _maxPage));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const SizedBox.shrink();
    }

    final pageItems = _pageItems;
    final showPagination = widget.items.length > widget.itemsPerPage;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: widget.padding,
            itemCount: pageItems.length,
            itemBuilder: (ctx, i) => widget.itemBuilder(ctx, pageItems[i], _currentPage * widget.itemsPerPage + i),
          ),
        ),
        if (showPagination) _buildPaginationBar(),
      ],
    );
  }

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Info text
          Text(
            '${_currentPage * widget.itemsPerPage + 1}–${(_currentPage * widget.itemsPerPage + _pageItems.length)} / ${widget.items.length}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          // Previous
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
            visualDensity: VisualDensity.compact,
            tooltip: 'Trang trước',
          ),
          // Page buttons
          ..._buildPageButtons(),
          // Next
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: _currentPage < _maxPage ? () => _goToPage(_currentPage + 1) : null,
            visualDensity: VisualDensity.compact,
            tooltip: 'Trang sau',
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageButtons() {
    final pages = <Widget>[];
    const maxVisible = 5;

    int start = (_currentPage - maxVisible ~/ 2).clamp(0, _totalPages - 1);
    int end = (start + maxVisible).clamp(0, _totalPages);
    if (end - start < maxVisible) {
      start = (end - maxVisible).clamp(0, _totalPages - 1);
    }

    if (start > 0) {
      pages.add(_pageBtn(0));
      if (start > 1) pages.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text('…', style: TextStyle(color: AppColors.textHint))));
    }

    for (int i = start; i < end; i++) {
      pages.add(_pageBtn(i));
    }

    if (end < _totalPages) {
      if (end < _totalPages - 1) pages.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text('…', style: TextStyle(color: AppColors.textHint))));
      pages.add(_pageBtn(_totalPages - 1));
    }

    return pages;
  }

  Widget _pageBtn(int page) {
    final isActive = page == _currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: isActive ? null : () => _goToPage(page),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${page + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
