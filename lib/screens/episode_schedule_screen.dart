import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../core/app_state.dart';
import '../models/anime.dart';
import '../repositories/anime_repository.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../screens/anime_details_screen.dart';
import '../widgets/cached_anime_image.dart';
import '../widgets/ui_states.dart';

class EpisodeScheduleScreen extends StatefulWidget {
  final AppState state;
  final AnalyticsService analytics;

  const EpisodeScheduleScreen({
    super.key,
    required this.state,
    required this.analytics,
  });

  @override
  State<EpisodeScheduleScreen> createState() => _EpisodeScheduleScreenState();
}

class _EpisodeScheduleScreenState extends State<EpisodeScheduleScreen> {
  final repository = AnimeRepository();
  final List<String> days = const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  late String selectedDay;
  List<EpisodeScheduleItem> items = const [];
  bool loading = true;
  String? error;
  int requestToken = 0;

  @override
  void initState() {
    super.initState();
    selectedDay = days[DateTime.now().weekday - 1];
    _load(selectedDay);
  }

  Future<void> _load(String day, {bool force = false}) async {
    final token = ++requestToken;
    setState(() {
      selectedDay = day;
      loading = true;
      error = null;
    });

    try {
      if (force) {
        // The repository cache is intentionally short-lived; changing the
        // day or pulling to refresh is enough to obtain the live schedule.
      }
      final result = await repository.getEpisodeSchedule(day: day);
      if (!mounted || token != requestToken) return;
      setState(() {
        items = [...result]..sort((a, b) => _timeMinutes(a.time).compareTo(_timeMinutes(b.time)));
        loading = false;
      });
    } catch (e) {
      if (!mounted || token != requestToken) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  int _timeMinutes(String? value) {
    if (value == null || !value.contains(':')) return 24 * 60;
    final parts = value.split(':');
    final h = int.tryParse(parts.first) ?? 23;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 59;
    return h * 60 + m;
  }

  String _dayLabel(String day) {
    const ar = {
      'monday': 'الإثنين',
      'tuesday': 'الثلاثاء',
      'wednesday': 'الأربعاء',
      'thursday': 'الخميس',
      'friday': 'الجمعة',
      'saturday': 'السبت',
      'sunday': 'الأحد',
    };
    const en = {
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
    };
    return AppLanguage.instance.text(ar[day] ?? day, en[day] ?? day);
  }

  String _status(EpisodeScheduleItem item) {
    if (!item.airing) return AppLanguage.instance.text('متوقف', 'Not airing');
    return AppLanguage.instance.text('موعد بث الحلقة القادمة', 'Next episode broadcast');
  }

  void _openAnime(Anime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeDetailsScreen(
          anime: anime,
          state: widget.state,
          remoteConfig: RemoteConfig.disabled,
          analytics: widget.analytics,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = days[DateTime.now().weekday - 1];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLanguage.instance.text('جدول الحلقات', 'Episode Schedule')),
        actions: [
          IconButton(
            tooltip: AppLanguage.instance.text('تحديث', 'Refresh'),
            onPressed: () => _load(selectedDay, force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(selectedDay, force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLanguage.instance.text('مواعيد البث', 'Broadcast schedule'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLanguage.instance.text(
                        'تابع الأنميات التي لديها حلقة جديدة حسب سجل البث.',
                        'Track anime with a new episode according to the broadcast schedule.',
                      ),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: days.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final day = days[index];
                          final selected = day == selectedDay;
                          return ChoiceChip(
                            selected: selected,
                            label: Text('${_dayLabel(day)}${day == today ? ' • ${AppLanguage.instance.text('اليوم', 'Today')}' : ''}'),
                            onSelected: (_) => _load(day),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (loading && items.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: LoadingGrid())
            else if (error != null && items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: UiStateCard(
                  icon: Icons.cloud_off_outlined,
                  title: AppLanguage.instance.text('تعذر تحميل جدول البث', 'Couldn\'t load the schedule'),
                  message: error!,
                  actionLabel: AppLanguage.instance.text('إعادة المحاولة', 'Retry'),
                  onAction: () => _load(selectedDay, force: true),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: UiStateCard(
                  icon: Icons.event_busy_outlined,
                  title: AppLanguage.instance.text('لا توجد حلقات مجدولة', 'No scheduled episodes'),
                  message: AppLanguage.instance.text(
                    'لا توجد بيانات بث متاحة لهذا اليوم حاليًا.',
                    'There is no broadcast data available for this day right now.',
                  ),
                  compact: true,
                ),
              )
            else ...[
              if (error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: InlineNotice(
                      warning: true,
                      icon: Icons.cloud_off_outlined,
                      text: AppLanguage.instance.text(
                        'تعذر تحديث البيانات؛ يتم عرض آخر بيانات متاحة.',
                        'Refresh failed; showing the latest available data.',
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => _ScheduleCard(item: items[index], onTap: () => _openAnime(items[index].anime), status: _status(items[index])),
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final EpisodeScheduleItem item;
  final VoidCallback onTap;
  final String status;

  const _ScheduleCard({required this.item, required this.onTap, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 126,
          child: Row(
            children: [
              SizedBox(
                width: 92,
                child: CachedAnimeImage(
                  url: item.anime.image,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.schedule_outlined, size: 18, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            item.time?.isNotEmpty == true ? item.time! : '—',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'الحلقة القادمة',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(Icons.radio_outlined, size: 15, color: cs.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
