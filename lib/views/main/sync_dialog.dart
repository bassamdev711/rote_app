import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/sync_service.dart';
import '../../providers/work_day_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/broadcast_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../providers/global_refresh_provider.dart';

class SyncDialog extends ConsumerStatefulWidget {
  final bool isPush;
  const SyncDialog({Key? key, required this.isPush}) : super(key: key);

  @override
  ConsumerState<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends ConsumerState<SyncDialog> {
  final SyncService _syncService = SyncService();
  String _status = 'جاري الإعداد...';
  bool _isSyncing = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    final onProgress = (msg) {
      if (mounted) {
        setState(() {
          _status = msg;
          if (msg.startsWith('خطأ')) {
            _hasError = true;
          }
        });
      }
    };

    if (widget.isPush) {
      await _syncService.pushData(onProgress: onProgress);
    } else {
      await _syncService.pullData(onProgress: onProgress);
    }

    if (mounted) {
      setState(() {
        _isSyncing = false;
        if (!_hasError) {
          _status = widget.isPush ? 'تمت عملية الرفع بنجاح!' : 'تمت عملية التنزيل بنجاح!';
          ref.invalidate(currentWorkDayProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(broadcastProvider);
          ref.invalidate(distributorNameProvider);
          ref.read(globalRefreshProvider.notifier).refresh();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isSyncing ? (widget.isPush ? Icons.cloud_upload : Icons.cloud_download) : (_hasError ? Icons.error_outline : Icons.check_circle_outline),
            color: _isSyncing ? (widget.isPush ? Colors.blue : Colors.green) : (_hasError ? Colors.red : Colors.green),
          ),
          const SizedBox(width: 10),
          Text(widget.isPush ? 'تصدير للسحابة' : 'استيراد من السحابة'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSyncing) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
        ],
      ),
      actions: [
        if (!_isSyncing)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
      ],
    );
  }
}
