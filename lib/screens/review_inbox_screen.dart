/// lib/screens/review_inbox_screen.dart
///
/// Review Inbox — the main human review interface for DataFactory candidates.
///
/// Replaces the need to manually hunt through POIs.
/// Shows DataFactory uncertainty in plain language.
/// Supports filters, grouping, search, pagination, and bulk actions.
library;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/lab_theme.dart';
import '../review/models/review_candidate.dart';
import '../review/models/inbox_decision.dart';
import '../review/services/review_reason_translator.dart';
import '../widgets/review/review_candidate_card.dart';
import '../widgets/review/review_detail_panel.dart';
import 'identity_conflicts_screen.dart';

class ReviewInboxScreen extends StatefulWidget {
  final AppState state;

  const ReviewInboxScreen({super.key, required this.state});

  @override
  State<ReviewInboxScreen> createState() => _ReviewInboxScreenState();
}

class _ReviewInboxScreenState extends State<ReviewInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _priorityTabController;

  // Filters
  String _searchQuery = '';
  String? _filterCategory;
  String? _filterReason;
  String? _filterTier;
  String? _filterSubcategory;
  String? _filterMissingField;
  String _grouping = 'reason';
  String? _filterStatus; // null = all, 'unresolved', 'resolved', 'changed'

  // Pagination
  static const _pageSize = 30;
  int _displayedCount = _pageSize;

  // Multi-select
  final Set<String> _selectedIds = {};
  bool _bulkMode = false;

  // Detail panel
  ReviewCandidate? _detailCandidate;

  // Group view
  bool _groupByReason = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _priorityTabController = TabController(length: 6, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _priorityTabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final filtered = _getFilteredCandidates();
      if (_displayedCount < filtered.length) {
        setState(() => _displayedCount += _pageSize);
      }
    }
  }

  String get _priorityFilter {
    switch (_priorityTabController.index) {
      case 1:
        return 'BLOCKING';
      case 2:
        return 'HIGH';
      case 3:
        return 'MEDIUM';
      case 4:
        return 'LOW';
      case 5:
        return 'ALL';
      default:
        return 'URGENT';
    }
  }

  List<ReviewCandidate> _getFilteredCandidates() {
    final state = widget.state;
    var list = List<ReviewCandidate>.from(state.reviewCandidates);

    // Priority tab filter
    if (_priorityFilter == 'URGENT') {
      list = list
          .where(
            (c) =>
                c.reviewPriority.sortOrder <= ReviewPriority.high.sortOrder &&
                !(state.inboxDecisions[c.canonicalId]?.isResolved ?? false),
          )
          .toList();
    } else if (_priorityFilter != 'ALL') {
      list = list
          .where((c) => c.reviewPriority.label == _priorityFilter)
          .toList();
    }

    if (_filterSubcategory != null) {
      list = list.where((c) => c.subcategory == _filterSubcategory).toList();
    }
    if (_filterMissingField != null) {
      list = list
          .where((c) => c.missingFields.contains(_filterMissingField))
          .toList();
    }
    if (_filterStatus == 'research') {
      list = list
          .where(
            (c) =>
                state.inboxDecisions[c.canonicalId]?.verdict ==
                InboxVerdict.needsResearch,
          )
          .toList();
    }
    // Category filter
    if (_filterCategory != null) {
      list = list.where((c) => c.category == _filterCategory).toList();
    }

    // Reason filter
    if (_filterReason != null) {
      list = list
          .where((c) => c.travelRelevanceReason == _filterReason)
          .toList();
    }

    // Tier filter
    if (_filterTier != null) {
      list = list.where((c) => c.tier == _filterTier).toList();
    }

    // Status filter
    if (_filterStatus == 'unresolved') {
      list = list
          .where(
            (c) => !(state.inboxDecisions[c.canonicalId]?.isResolved ?? false),
          )
          .toList();
    } else if (_filterStatus == 'resolved') {
      list = list
          .where(
            (c) => state.inboxDecisions[c.canonicalId]?.isResolved ?? false,
          )
          .toList();
    } else if (_filterStatus == 'changed') {
      list = list
          .where(
            (c) =>
                state.inboxDecisions[c.canonicalId]?.changedSinceReview ??
                false,
          )
          .toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.category.toLowerCase().contains(q) ||
            (c.subcategory?.toLowerCase().contains(q) ?? false) ||
            c.travelRelevanceReason.toLowerCase().contains(q) ||
            c.alternateNames.any((n) => n.toLowerCase().contains(q));
      }).toList();
    }

    return list;
  }

  Map<String, List<ReviewCandidate>> _groupByReasonCode(
    List<ReviewCandidate> candidates,
  ) {
    final groups = <String, List<ReviewCandidate>>{};
    for (final c in candidates) {
      final key = _grouping == 'category'
          ? c.category
          : _grouping == 'priority'
          ? c.reviewPriority.label
          : c.travelRelevanceReason;
      groups.putIfAbsent(key, () => []).add(c);
    }
    // Sort groups by count descending
    final sorted = Map.fromEntries(
      groups.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length)),
    );
    return sorted;
  }

  Future<bool> _confirmBulk(bool exclude) async {
    final selected = widget.state.reviewCandidates
        .where((c) => _selectedIds.contains(c.canonicalId))
        .toList();
    final reasons = <String, int>{};
    for (final c in selected) {
      reasons.update(c.travelRelevanceReason, (n) => n + 1, ifAbsent: () => 1);
    }
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${selected.length} places selected'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in reasons.entries)
                    Text(
                      '${e.value} ${ReviewReasonTranslator.translateReason(e.key).title}',
                    ),
                  if (reasons.length > 1 ||
                      selected.map((c) => c.category).toSet().length > 1)
                    const Text(
                      'This selection contains different kinds of places. Check each before applying one decision.',
                    ),
                  const Text('Only explicitly selected places will change.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  '${exclude ? 'Exclude' : 'Keep'} ${selected.length} Places',
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _bulkApprove() async {
    if (_selectedIds.isEmpty || !await _confirmBulk(false)) return;
    final state = widget.state;
    final pack = state.activePack;
    if (pack == null) return;

    final approvedCount = _selectedIds.length;
    for (final id in List<String>.of(_selectedIds)) {
      final candidate = state.reviewCandidates.firstWhere(
        (c) => c.canonicalId == id,
      );
      final decision = InboxDecision(
        canonicalId: id,
        cityId: pack.id,
        packVersion: pack.version,
        verdict: InboxVerdict.approved,
        verdictNote: 'Bulk approved',
        author: state.contributorName,
        decidedAt: DateTime.now().toIso8601String(),
        snapshot: state.snapshotOf(candidate),
      );
      await state.saveInboxDecision(decision);
    }

    setState(() {
      _selectedIds.clear();
      _bulkMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$approvedCount candidates approved.')),
      );
    }
  }

  Future<void> _bulkExclude() async {
    if (_selectedIds.isEmpty || !await _confirmBulk(true)) return;
    final state = widget.state;
    final pack = state.activePack;
    if (pack == null) return;

    for (final id in List<String>.of(_selectedIds)) {
      final candidate = state.reviewCandidates.firstWhere(
        (c) => c.canonicalId == id,
      );
      final decision = InboxDecision(
        canonicalId: id,
        cityId: pack.id,
        packVersion: pack.version,
        verdict: InboxVerdict.rejected,
        verdictNote: 'Bulk excluded',
        author: state.contributorName,
        decidedAt: DateTime.now().toIso8601String(),
        snapshot: state.snapshotOf(candidate),
      );
      await state.saveInboxDecision(decision);
    }

    setState(() {
      _selectedIds.clear();
      _bulkMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final total = state.reviewCandidates.length;
        final unresolved = state.unresolvedReviewCount;
        final highUnresolved = state.unresolvedHighPriorityCount;
        final changedCount = state.inboxDecisions.values
            .where((d) => d.changedSinceReview)
            .length;

        if (state.reviewManifestMissing) {
          return _MissingManifestState(cityId: state.activePack?.id ?? '');
        }

        if (total == 0 && state.reviewManifestWarning != null) {
          return _ErrorState(message: state.reviewManifestWarning!);
        }

        final filtered = _getFilteredCandidates();
        final displayed = filtered.take(_displayedCount).toList();

        return Row(
          children: [
            // ── Main content ────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  _InboxHeader(
                    total: total,
                    unresolved: unresolved,
                    highUnresolved: highUnresolved,
                    changedCount: changedCount,
                    filterStatus: _filterStatus,
                    onFilterStatus: (v) => setState(() => _filterStatus = v),
                  ),
                  if (state.identityConflicts.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.compare),
                        label: Text(
                          'Identity Conflicts (${state.identityConflicts.where((c) => !c.resolved).length} unresolved)',
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                IdentityConflictsScreen(state: state),
                          ),
                        ),
                      ),
                    ),
                  _SearchFilterBar(
                    controller: _searchController,
                    candidates: state.reviewCandidates,
                    filterCategory: _filterCategory,
                    filterReason: _filterReason,
                    filterTier: _filterTier,
                    groupByReason: _groupByReason,
                    bulkMode: _bulkMode,
                    selectedCount: _selectedIds.length,
                    onSearch: (q) => setState(() {
                      _searchQuery = q;
                      _displayedCount = _pageSize;
                    }),
                    onCategoryFilter: (v) =>
                        setState(() => _filterCategory = v),
                    onReasonFilter: (v) => setState(() => _filterReason = v),
                    onTierFilter: (v) => setState(() => _filterTier = v),
                    onGroupToggle: (v) => setState(() => _groupByReason = v),
                    onBulkModeToggle: () =>
                        setState(() => _bulkMode = !_bulkMode),
                    onBulkApprove: _bulkApprove,
                    onBulkExclude: _bulkExclude,
                    onClearSelection: () =>
                        setState(() => _selectedIds.clear()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 16,
                      children: [
                        _DropdownFilter(
                          label: 'Subcategory',
                          value: _filterSubcategory,
                          items:
                              state.reviewCandidates
                                  .map((c) => c.subcategory)
                                  .whereType<String>()
                                  .toSet()
                                  .toList()
                                ..sort(),
                          onChanged: (v) => setState(() {
                            _filterSubcategory = v;
                            _displayedCount = _pageSize;
                          }),
                        ),
                        _DropdownFilter(
                          label: 'Missing field',
                          value: _filterMissingField,
                          items:
                              state.reviewCandidates
                                  .expand((c) => c.missingFields)
                                  .toSet()
                                  .toList()
                                ..sort(),
                          onChanged: (v) => setState(() {
                            _filterMissingField = v;
                            _displayedCount = _pageSize;
                          }),
                        ),
                        _DropdownFilter(
                          label: 'Status',
                          value: _filterStatus,
                          items: const [
                            'unresolved',
                            'resolved',
                            'research',
                            'changed',
                          ],
                          displayMap: const {
                            'unresolved': 'Unresolved',
                            'resolved': 'Reviewed',
                            'research': 'Needs Research',
                            'changed': 'Changed since review',
                          },
                          onChanged: (v) => setState(() {
                            _filterStatus = v;
                            _displayedCount = _pageSize;
                          }),
                        ),
                        if (_groupByReason)
                          _DropdownFilter(
                            label: 'Group',
                            value: _grouping,
                            items: const ['reason', 'category', 'priority'],
                            onChanged: (v) =>
                                setState(() => _grouping = v ?? 'reason'),
                          ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear filters'),
                        ),
                        Text(
                          '${filtered.length} matching',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (state.reviewManifestWarning != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        state.reviewManifestWarning!,
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                  TabBar(
                    controller: _priorityTabController,
                    labelColor: LabPalette.saffron,
                    unselectedLabelColor: LabPalette.muted,
                    indicatorColor: LabPalette.saffron,
                    onTap: (_) => setState(() => _displayedCount = _pageSize),
                    tabs: [
                      Tab(text: 'Start here ($highUnresolved)'),
                      Tab(
                        text:
                            'Blocking (${state.reviewCandidates.where((c) => c.reviewPriority == ReviewPriority.blocking).length})',
                      ),
                      Tab(
                        text:
                            'High (${state.reviewCandidates.where((c) => c.reviewPriority == ReviewPriority.high).length})',
                      ),
                      Tab(
                        text:
                            'Medium (${state.reviewCandidates.where((c) => c.reviewPriority == ReviewPriority.medium).length})',
                      ),
                      Tab(
                        text:
                            'Low (${state.reviewCandidates.where((c) => c.reviewPriority == ReviewPriority.low).length})',
                      ),
                      Tab(text: 'All ($total)'),
                    ],
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyInboxState(
                            hasFilters:
                                _searchQuery.isNotEmpty ||
                                _filterCategory != null ||
                                _filterReason != null ||
                                _filterStatus != null ||
                                _filterTier != null ||
                                _filterSubcategory != null ||
                                _filterMissingField != null ||
                                _priorityFilter != 'ALL',
                            onClear: _clearFilters,
                          )
                        : _groupByReason
                        ? _GroupedView(
                            groups: _groupByReasonCode(filtered),
                            decisions: state.inboxDecisions,
                            selectedIds: _selectedIds,
                            bulkMode: _bulkMode,
                            onSelect: (id, sel) => setState(() {
                              if (sel) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            }),
                            onCardTap: (c) =>
                                setState(() => _detailCandidate = c),
                            onQuickDecision: _handleQuickDecision,
                            state: state,
                            groupByReason: _grouping == 'reason',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(LabSpacing.md),
                            itemCount:
                                displayed.length +
                                (displayed.length < filtered.length ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == displayed.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final candidate = displayed[index];
                              final decision =
                                  state.inboxDecisions[candidate.canonicalId];
                              return ReviewCandidateCard(
                                candidate: candidate,
                                decision: decision,
                                isSelected: _selectedIds.contains(
                                  candidate.canonicalId,
                                ),
                                bulkMode: _bulkMode,
                                onTap: () => setState(
                                  () => _detailCandidate = candidate,
                                ),
                                onSelect: (sel) => setState(() {
                                  if (sel) {
                                    _selectedIds.add(candidate.canonicalId);
                                  } else {
                                    _selectedIds.remove(candidate.canonicalId);
                                  }
                                }),
                                onQuickDecision: (verdict) =>
                                    _handleQuickDecision(candidate, verdict),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // ── Detail panel (side panel) ────────────────────────────
            if (_detailCandidate != null) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 420,
                child: ReviewDetailPanel(
                  candidate: _detailCandidate!,
                  decision: state.inboxDecisions[_detailCandidate!.canonicalId],
                  state: state,
                  onClose: () => setState(() => _detailCandidate = null),
                  onDecision: (decision) async {
                    await state.saveInboxDecision(decision);
                    setState(() {});
                  },
                  onUndo: () async {
                    await state.removeInboxDecision(
                      _detailCandidate!.canonicalId,
                    );
                    setState(() {});
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _filterCategory = null;
      _filterSubcategory = null;
      _filterReason = null;
      _filterTier = null;
      _filterStatus = null;
      _filterMissingField = null;
      _priorityTabController.index = 0;
      _displayedCount = _pageSize;
      _selectedIds.clear();
    });
  }

  Future<void> _handleQuickDecision(
    ReviewCandidate candidate,
    InboxVerdict verdict,
  ) async {
    final pack = widget.state.activePack;
    if (pack == null) return;
    final decision = InboxDecision(
      canonicalId: candidate.canonicalId,
      cityId: pack.id,
      packVersion: pack.version,
      verdict: verdict,
      author: widget.state.contributorName,
      decidedAt: DateTime.now().toIso8601String(),
      snapshot: widget.state.snapshotOf(candidate),
    );
    await widget.state.saveInboxDecision(decision);
    setState(() {});
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InboxHeader extends StatelessWidget {
  final int total;
  final int unresolved;
  final int highUnresolved;
  final int changedCount;
  final String? filterStatus;
  final ValueChanged<String?> onFilterStatus;

  const _InboxHeader({
    required this.total,
    required this.unresolved,
    required this.highUnresolved,
    required this.changedCount,
    required this.filterStatus,
    required this.onFilterStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
        horizontal: LabSpacing.lg,
        vertical: LabSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, size: 18),
          const SizedBox(width: 8),
          Text(
            'Review Inbox',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          _StatusChip(
            label: '$unresolved unresolved',
            color: unresolved > 0 ? Colors.orange : Colors.green,
            selected: filterStatus == 'unresolved',
            onTap: () => onFilterStatus(
              filterStatus == 'unresolved' ? null : 'unresolved',
            ),
          ),
          const SizedBox(width: 6),
          if (highUnresolved > 0) ...[
            _StatusChip(
              label: '$highUnresolved HIGH',
              color: Colors.red.shade700,
              selected: false,
              onTap: null,
            ),
            const SizedBox(width: 6),
          ],
          if (changedCount > 0) ...[
            _StatusChip(
              label: '$changedCount changed',
              color: Colors.purple,
              selected: filterStatus == 'changed',
              onTap: () =>
                  onFilterStatus(filterStatus == 'changed' ? null : 'changed'),
            ),
            const SizedBox(width: 6),
          ],
          _StatusChip(
            label: '${total - unresolved} resolved',
            color: Colors.teal,
            selected: filterStatus == 'resolved',
            onTap: () =>
                onFilterStatus(filterStatus == 'resolved' ? null : 'resolved'),
          ),
          const Spacer(),
          Text(
            '$total candidates',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: LabPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : color.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withAlpha(60),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final List<ReviewCandidate> candidates;
  final String? filterCategory;
  final String? filterReason;
  final String? filterTier;
  final bool groupByReason;
  final bool bulkMode;
  final int selectedCount;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCategoryFilter;
  final ValueChanged<String?> onReasonFilter;
  final ValueChanged<String?> onTierFilter;
  final ValueChanged<bool> onGroupToggle;
  final VoidCallback onBulkModeToggle;
  final VoidCallback onBulkApprove;
  final VoidCallback onBulkExclude;
  final VoidCallback onClearSelection;

  const _SearchFilterBar({
    required this.controller,
    required this.candidates,
    required this.filterCategory,
    required this.filterReason,
    required this.filterTier,
    required this.groupByReason,
    required this.bulkMode,
    required this.selectedCount,
    required this.onSearch,
    required this.onCategoryFilter,
    required this.onReasonFilter,
    required this.onTierFilter,
    required this.onGroupToggle,
    required this.onBulkModeToggle,
    required this.onBulkApprove,
    required this.onBulkExclude,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final categories = candidates.map((c) => c.category).toSet().toList()
      ..sort();
    final reasons =
        candidates.map((c) => c.travelRelevanceReason).toSet().toList()..sort();
    final tiers = candidates.map((c) => c.tier).toSet().toList()..sort();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LabSpacing.md,
        vertical: LabSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          SizedBox(
            height: 36,
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search by name, category, reason…',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Filter row
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DropdownFilter(
                label: 'Category',
                value: filterCategory,
                items: categories,
                onChanged: onCategoryFilter,
              ),
              const SizedBox(width: 8),
              _DropdownFilter(
                label: 'Reason',
                value: filterReason,
                items: reasons,
                displayMap: {
                  for (final r in reasons)
                    r: ReviewReasonTranslator.translateReason(r).title,
                },
                onChanged: onReasonFilter,
              ),
              const SizedBox(width: 8),
              _DropdownFilter(
                label: 'Tier',
                value: filterTier,
                items: tiers,
                onChanged: onTierFilter,
              ),
              const SizedBox(width: 8),
              // Group toggle
              FilterChip(
                label: const Text(
                  'Group by reason',
                  style: TextStyle(fontSize: 12),
                ),
                selected: groupByReason,
                onSelected: onGroupToggle,
                visualDensity: VisualDensity.compact,
              ),
              // Bulk mode
              if (bulkMode) ...[
                Text(
                  '$selectedCount selected',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: selectedCount > 0 ? onBulkApprove : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('Keep $selectedCount'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.teal,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: selectedCount > 0 ? onBulkExclude : null,
                  icon: const Icon(Icons.close, size: 16),
                  label: Text('Exclude $selectedCount'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton(
                  onPressed: onClearSelection,
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
              TextButton.icon(
                onPressed: onBulkModeToggle,
                icon: Icon(bulkMode ? Icons.close : Icons.checklist, size: 16),
                label: Text(
                  bulkMode ? 'Exit bulk' : 'Select',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Map<String, String>? displayMap;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    this.displayMap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      hint: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      value: value,
      isDense: true,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'All $label',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        ...items.map(
          (item) => DropdownMenuItem<String?>(
            value: item,
            child: Text(
              displayMap?[item] ?? item,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _GroupedView extends StatelessWidget {
  final bool groupByReason;
  final Map<String, List<ReviewCandidate>> groups;
  final Map<String, InboxDecision> decisions;
  final Set<String> selectedIds;
  final bool bulkMode;
  final Function(String, bool) onSelect;
  final ValueChanged<ReviewCandidate> onCardTap;
  final Function(ReviewCandidate, InboxVerdict) onQuickDecision;
  final AppState state;

  const _GroupedView({
    required this.groupByReason,
    required this.groups,
    required this.decisions,
    required this.selectedIds,
    required this.bulkMode,
    required this.onSelect,
    required this.onCardTap,
    required this.onQuickDecision,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(LabSpacing.md),
      children: groups.entries.map((entry) {
        final reason = entry.key;
        final candidates = entry.value;
        final translation = ReviewReasonTranslator.translateReason(reason);
        return _GroupSection(
          reasonCode: reason,
          reasonTitle: groupByReason ? translation.title : reason,
          candidates: candidates,
          decisions: decisions,
          selectedIds: selectedIds,
          bulkMode: bulkMode,
          onSelect: onSelect,
          onCardTap: onCardTap,
          onQuickDecision: onQuickDecision,
          isCritical: translation.isCritical,
        );
      }).toList(),
    );
  }
}

class _GroupSection extends StatefulWidget {
  final String reasonCode;
  final String reasonTitle;
  final List<ReviewCandidate> candidates;
  final Map<String, InboxDecision> decisions;
  final Set<String> selectedIds;
  final bool bulkMode;
  final Function(String, bool) onSelect;
  final ValueChanged<ReviewCandidate> onCardTap;
  final Function(ReviewCandidate, InboxVerdict) onQuickDecision;
  final bool isCritical;

  const _GroupSection({
    required this.reasonCode,
    required this.reasonTitle,
    required this.candidates,
    required this.decisions,
    required this.selectedIds,
    required this.bulkMode,
    required this.onSelect,
    required this.onCardTap,
    required this.onQuickDecision,
    required this.isCritical,
  });

  @override
  State<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<_GroupSection> {
  bool _expanded = false;
  int _visibleCount = 30;

  @override
  Widget build(BuildContext context) {
    final resolved = widget.candidates
        .where((c) => widget.decisions[c.canonicalId]?.isResolved ?? false)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isCritical
                  ? Colors.red.withAlpha(12)
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isCritical
                    ? Colors.red.withAlpha(60)
                    : Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                if (widget.isCritical)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                Expanded(
                  child: Text(
                    widget.reasonTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '$resolved / ${widget.candidates.length} resolved',
                  style: TextStyle(
                    fontSize: 11,
                    color: resolved == widget.candidates.length
                        ? Colors.teal
                        : LabPalette.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: LabPalette.saffronSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.candidates.length}',
                    style: TextStyle(
                      color: LabPalette.inkStrong,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: LabPalette.muted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.candidates.take(_visibleCount).map((candidate) {
            final decision = widget.decisions[candidate.canonicalId];
            return Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: ReviewCandidateCard(
                candidate: candidate,
                decision: decision,
                isSelected: widget.selectedIds.contains(candidate.canonicalId),
                bulkMode: widget.bulkMode,
                onTap: () => widget.onCardTap(candidate),
                onSelect: (sel) => widget.onSelect(candidate.canonicalId, sel),
                onQuickDecision: (v) => widget.onQuickDecision(candidate, v),
              ),
            );
          }),
        if (_expanded && _visibleCount < widget.candidates.length)
          TextButton(
            onPressed: () => setState(() => _visibleCount += 30),
            child: const Text('Load 30 more'),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _MissingManifestState extends StatelessWidget {
  final String cityId;

  const _MissingManifestState({required this.cityId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LabSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No review manifest found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Run the sync script to fetch DataFactory review candidates for $cityId.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                'Open Sync Latest City Packs in the workbench toolbar, verify the DataFactory repository, and refresh $cityId.',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LabSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Could not load review inbox',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;

  const _EmptyInboxState({required this.hasFilters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 56, color: Colors.teal),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No candidates match your filters.'
                : 'No items need review.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try clearing some filters.'
                : 'All review items have been resolved.',
            style: const TextStyle(color: Colors.grey),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ],
      ),
    );
  }
}
