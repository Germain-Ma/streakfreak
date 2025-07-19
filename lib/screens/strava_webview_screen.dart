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
  final void Function()? onImportComplete;
  
  StravaWebViewScreen({super.key, this.onImportComplete});

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
      if (code != null && code.isNotEmpty) {
        if (!_isSuccess) {
          _handleStravaRedirect(html.window.location.href);
        }
      } else {
        // No code parameter - check if we have a stored token
        _checkForStoredToken();
      }
    }
  }

  Future<void> _checkForStoredToken() async {
    final token = await _stravaService.getAccessToken();
    
    if (token != null && token.isNotEmpty && !token.startsWith('Error:')) {
      setState(() => _isLoading = true);
      try {
        final runProvider = Provider.of<RunProvider>(context, listen: false);
        await runProvider.importFromStrava();
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        await locationProvider.refresh();
        
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
        
        if (widget.onImportComplete != null) {
          widget.onImportComplete!();
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing activities: $e')),
        );
      }
    } else {
    }
  }

  Future<void> _handleStravaRedirect(String url) async {
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    setState(() => _isLoading = true);
    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Missing code parameter in Strava redirect. Please try again.')),
      );
      return;
    }
    try {
      // Exchange code for token
      final token = await _stravaService.exchangeCodeForToken(code);
      if (token != null && !token.startsWith('Error:')) {
        try {
          final runProvider = Provider.of<RunProvider>(context, listen: false);
          await runProvider.loadRuns(); // Always fetch from Supabase first
          await runProvider.importFromStrava(); // Then sync with Strava
          // Wait for GPS extraction
          final locationProvider = Provider.of<LocationProvider>(context, listen: false);
          await locationProvider.refresh();
          // Count total and GPS activities
          int gpsCount = 0;
          int total = 0;
          try {
            final activities = runProvider.activities;
            final runs = runProvider.runs;
            total = activities.length;
            for (final run in runs) {
              if (run.lat != 0.0 || run.lon != 0.0) {
                gpsCount++;
              }
            }
          } catch (e) {
          }
          setState(() {
            _isSuccess = true;
            _isLoading = false;
            _total = total;
            _gps = gpsCount;
          });
          if (widget.onImportComplete != null) {
            widget.onImportComplete!();
          }
        } catch (e, stack) {
          throw e; // Re-throw to be caught by outer try-catch
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to Strava: ${token ?? "Unknown error"}')),
        );
      }
    } catch (e, stack) {
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