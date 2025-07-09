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
  const StravaWebViewScreen({super.key, required this.onImportComplete});

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
      if (code != null && !_isSuccess) {
        _handleStravaRedirect(html.window.location.href);
      }
    }
  }

  Future<void> _handleStravaRedirect(String url) async {
    setState(() => _isLoading = true);
    final code = Uri.parse(url).queryParameters['code'];
    if (code != null) {
      try {
        // Exchange code for token
        final token = await _stravaService.exchangeCodeForToken(code);
        if (token != null && !token.startsWith('Error:')) {
          // Import activities from Strava
          final runProvider = context.read<RunProvider>();
          await runProvider.importFromStrava();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect to Strava: ${token ?? "Unknown error"}')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing from Strava: $e')),
        );
      }
    }
  }

  void _startWebOAuth() {
    if (_oauthStarted) return;
    _oauthStarted = true;
    final url = 'https://www.strava.com/oauth/authorize?client_id=167512&response_type=code&redirect_uri=${Uri.base.origin}&approval_prompt=auto&scope=activity:read_all';
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
                      onPressed: _startWebOAuth,
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
                        _controller.loadRequest(Uri.parse('https://www.strava.com/oauth/authorize?client_id=167512&response_type=code&redirect_uri=http://localhost&approval_prompt=auto&scope=activity:read_all'));
                      },
                      child: const Text('Connect to Strava', style: TextStyle(fontSize: 18)),
                    ),
                if (_isLoading)
                  Column(
                    children: const [
                      SizedBox(height: 24),
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Syncing activities from Strava...', style: TextStyle(color: Colors.white)),
                    ],
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