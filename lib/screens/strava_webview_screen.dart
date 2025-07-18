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
    super.initState();
    print('[StravaWebViewScreen] initState called');
    
    // Check if we have a code parameter from OAuth redirect
    final uri = Uri.parse(widget.initialUrl);
    final code = uri.queryParameters['code'];
    
    if (code != null) {
      print('[StravaWebViewScreen] Found code parameter: $code');
      _handleStravaRedirect(code);
    } else {
      print('[StravaWebViewScreen] No code parameter found checking for stored token');
      _checkForStoredToken();
    }
  }

  Future<void> _checkForStoredToken() async {
    print('[StravaWebViewScreen] _checkForStoredToken called');
    try {
      print('[StravaWebViewScreen] About to call _stravaService.getAccessToken()');
      final token = await _stravaService.getAccessToken();
      print('[StravaWebViewScreen] getAccessToken returned: ${token != null ? (token.length > 10 ? "${token.substring(0, 10)}..." : token) : "null"}');
      
      if (token != null && token.isNotEmpty && !token.startsWith('Error:')) {
        print('[StravaWebViewScreen] Found stored token, loading existing data');
        final runProvider = context.read<RunProvider>();
        print('[StravaWebViewScreen] About to call runProvider.loadRuns()');
        await runProvider.loadRuns(); // This should load from Supabase
        print('[StravaWebViewScreen] runProvider.loadRuns() completed');
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
        widget.onImportComplete(_total, gpsCount);
      } else {
        print('[StravaWebViewScreen] No stored token found, showing connect button');
        print('[StravaWebViewScreen] Token details: null=${token == null}, empty=${token?.isEmpty}, startsWithError=${token?.startsWith('Error:')}');
      }
    } catch (e) {
      print('[StravaWebViewScreen] Error checking for stored token: $e');
    }
  }

  Future<void> _handleStravaRedirect(String code) async {
    print('[StravaWebViewScreen] _handleStravaRedirect called with code: $code');
    try {
      final token = await _stravaService.exchangeCodeForToken(code);
      print('[StravaWebViewScreen] Token exchange result: ${token != null ? "SUCCESS" : "FAILED"}');
      
      if (token != null && !token.startsWith('Error:')) {
        print('[StravaWebViewScreen] Token exchange successful, loading runs...');
        final runProvider = Provider.of<RunProvider>(context, listen: false);
        
        // First load existing data from Supabase
        await runProvider.loadRuns();
        print('[StravaWebViewScreen] loadRuns completed');
        
        // Then sync new data from Strava
        await runProvider.smartSyncFromStrava(afterOAuth: true);
        print('[StravaWebViewScreen] smartSyncFromStrava completed');
        
        // Navigate back to home screen
        if (mounted) {
          Navigator.of(context).pop();
          if (widget.onImportComplete != null) {
            widget.onImportComplete!();
          }
        }
      } else {
        print('[StravaWebViewScreen] Token exchange failed: $token');
        // Show error message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Strava authentication failed: $token')),
          );
        }
      }
    } catch (e) {
      print('[StravaWebViewScreen] ERROR in _handleStravaRedirect: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during Strava authentication: $e')),
        );
      }
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