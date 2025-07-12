import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import '../providers/location_provider.dart';
import '../services/strava_service.dart';
import 'dart:async';
import 'dart:html' as html;

class StravaWebViewScreen extends StatefulWidget {
  final void Function(int total, int gps) onImportComplete;
  StravaWebViewScreen({super.key, required this.onImportComplete}) {
    print('[StravaWebViewScreen] constructor called');
  }

  @override
  State<StravaWebViewScreen> createState() => _StravaWebViewScreenState();
}

class _StravaWebViewScreenState extends State<StravaWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = false;
  bool _isSuccess = false;
  int _total = 0;
  int _gps = 0;
  bool _oauthStarted = false;
  final StravaService _stravaService = StravaService();
  int _importProgress = 0;
  int _importTotal = 0;
  Duration _estimatedRemaining = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int total, int progress) {
    _timer?.cancel();
    setState(() {
      _importTotal = total;
      _importProgress = progress;
      _estimatedRemaining = Duration(seconds: ((total - progress) / 2).ceil());
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_estimatedRemaining.inSeconds > 0) {
          _estimatedRemaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void initState() {
    print('[StravaWebViewScreen] initState called');
    super.initState();
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (url) {
            if (url.contains('code=')) {
              _handleStravaRedirect(url);
            }
          },
        ));
    } else {
      // On web, check for code in URL
      final code = Uri.base.queryParameters['code'];
      final state = Uri.base.queryParameters['state'];
      print('[StravaWebViewScreen] initState code param: $code, state param: $state');
      if (code == null || code.isEmpty) {
        print('[StravaWebViewScreen] ERROR: code param is missing or empty. Uri.base:  [33m${Uri.base} [0m, query params: ${Uri.base.queryParameters}');
        // Optionally show a user-friendly error here
        return;
      }
      if (!_isSuccess) {
        _handleStravaRedirect(html.window.location.href);
      }
    }
  }

  Future<void> _handleStravaRedirect(String url) async {
    print('[StravaWebViewScreen] _handleStravaRedirect called with url: $url');
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    print('[StravaWebViewScreen] code param: $code, state param: $state');
    setState(() => _isLoading = true);
    if (code == null || code.isEmpty) {
      print('[StravaWebViewScreen] ERROR: code param is missing or empty in _handleStravaRedirect. Uri: $uri, query params: ${uri.queryParameters}');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Missing code parameter in Strava redirect. Please try again.')),
      );
      return;
    }
    try {
      // Exchange code for token
      final token = await _stravaService.exchangeCodeForToken(code);
      if (token != null && !token.startsWith('Error:')) {
        // Import activities from Strava
        final runProvider = context.read<RunProvider>();
        final stravaId = await runProvider.stravaService.getAthleteId();
        print('[StravaWebViewScreen] Athlete ID: ' + (stravaId ?? 'null'));
        if (stravaId == null) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not determine Strava athlete ID.')),
          );
          return;
        }
        final supabaseActivities = await runProvider.fetchSupabaseActivities(stravaId);
        print('[StravaWebViewScreen] Supabase activities count: ' + supabaseActivities.length.toString());
        if (supabaseActivities.isNotEmpty) {
          // Find latest activity date
          DateTime? latestDate;
          for (final a in supabaseActivities) {
            final dateStr = a.fields['Date'];
            if (dateStr != null && dateStr.isNotEmpty) {
              final d = DateTime.tryParse(dateStr);
              if (d != null && (latestDate == null || d.isAfter(latestDate))) {
                latestDate = d;
              }
            }
          }
          print('[StravaWebViewScreen] Latest activity date in Supabase: ' + (latestDate?.toIso8601String() ?? 'null'));
          // Only fetch new activities from Strava
          await runProvider.importFromStrava(after: latestDate, existingActivities: supabaseActivities);
        } else {
          print('[StravaWebViewScreen] No activities in Supabase, doing full import.');
          await runProvider.importFromStrava();
        }
        // Wait for GPS extraction
        final locationProvider = context.read<LocationProvider>();
        await locationProvider.refresh();
        // Count total and GPS activities
        final activities = runProvider.activities;
        final runs = runProvider.runs;
        int gpsCount = 0;
        for (final run in runs) {
          if (run.lat != 0.0 || run.lon != 0.0) {
            gpsCount++;
          }
        }
        setState(() {
          _isSuccess = true;
          _isLoading = false;
          _total = activities.length;
          _gps = gpsCount;
        });
        widget.onImportComplete(_total, _gps);
      } else {
        // Handle error
        setState(() => _isLoading = false);
        print('[StravaWebViewScreen] ERROR: Failed to connect to Strava: ${token ?? "Unknown error"}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to Strava: ${token ?? "Unknown error"}')),
        );
      }
    } catch (e, stack) {
      setState(() => _isLoading = false);
      print('[StravaWebViewScreen] Error importing from Strava: $e');
      print('[StravaWebViewScreen] Stack trace: $stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing from Strava: $e')),
      );
    }
  }

  void _startWebOAuth() {
    if (_oauthStarted) return;
    _oauthStarted = true;
    final url = 'https://www.strava.com/oauth/authorize?client_id=167512&response_type=code&redirect_uri=https://germain-ma.github.io/streakfreak&approval_prompt=auto&scope=activity:read_all';
    html.window.open(url, '_self');
  }

  @override
  Widget build(BuildContext context) {
    print('[StravaWebViewScreen] build called (import screen)');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2980), Color(0xFFFF512F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 48),
                Image.asset('assets/logo.png', height: 100),
                const SizedBox(height: 24),
                Text('StreakFreak', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 8, color: Colors.black26)])),
                const SizedBox(height: 32),
                if (!_isLoading && !_isSuccess)
                  if (kIsWeb)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFfc4c02),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                      onPressed: () {
                        print('[StravaWebViewScreen] Strava sync button pressed');
                        _startWebOAuth();
                      },
                      child: const Text('Connect to Strava', style: TextStyle(fontSize: 18)),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFfc4c02),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                      onPressed: () {
                        _controller.loadRequest(Uri.parse('https://www.strava.com/oauth/authorize?client_id=167512&response_type=code&redirect_uri=https://germain-ma.github.io/streakfreak&approval_prompt=auto&scope=activity:read_all'));
                      },
                      child: const Text('Connect to Strava', style: TextStyle(fontSize: 18)),
                    ),
                if (_isLoading)
                  Consumer<RunProvider>(
                    builder: (context, runProvider, child) {
                      // Start timer if not already started
                      if (_timer == null && runProvider.importTotal > 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _startTimer(runProvider.importTotal, runProvider.importProgress);
                        });
                      }
                      // Update timer progress
                      if (_importProgress != runProvider.importProgress) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _importProgress = runProvider.importProgress;
                            _estimatedRemaining = Duration(seconds: ((_importTotal - _importProgress) / 2).ceil());
                          });
                        });
                      }
                      String formatDuration(Duration d) {
                        String twoDigits(int n) => n.toString().padLeft(2, '0');
                        final h = d.inHours;
                        final m = d.inMinutes % 60;
                        final s = d.inSeconds % 60;
                        if (h > 0) {
                          return '${twoDigits(h)}:${twoDigits(m)}:${twoDigits(s)}';
                        } else {
                          return '${twoDigits(m)}:${twoDigits(s)}';
                        }
                      }
                      // --- NEW: Show 'Calculating estimated time...' if import started but total is 0 ---
                      if (runProvider.isImporting && runProvider.importTotal == 0) {
                        return Column(
                          children: [
                            const SizedBox(height: 24),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            const Text(
                              'Calculating estimated time...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        );
                      }
                      // --- END NEW ---
                      return Column(
                        children: [
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            runProvider.isImporting && runProvider.importTotal > 0
                              ? 'Syncing activities from Strava... (${runProvider.importProgress}/${runProvider.importTotal})'
                              : 'Syncing activities from Strava...',
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (_estimatedRemaining.inSeconds > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Estimated time remaining: ${formatDuration(_estimatedRemaining)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if (_isSuccess)
                  Column(
                    children: [
                      const SizedBox(height: 24),
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 12),
                      Text('Import successful!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Total activities imported: $_total', style: TextStyle(color: Colors.white)),
                      Text('Activities with GPS: $_gps', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                if (!kIsWeb && !_isLoading && !_isSuccess)
                  SizedBox(
                    height: 400,
                    child: WebViewWidget(controller: _controller),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 