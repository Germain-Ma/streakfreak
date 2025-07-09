import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  // Replace these URLs with real Strava activity links if available
  static const String longestRunUrl = 'https://www.strava.com/activities/LONGEST_RUN_ID';
  static const String mostElevationUrl = 'https://www.strava.com/activities/MOST_ELEVATION_ID';
  static const String bestRunUrl = 'https://www.strava.com/activities/BEST_RUN_ID';
  static const String maxTilesRunUrl = 'https://www.strava.com/activities/MAX_TILES_RUN_ID';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your overall personal best',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Text('Total activities 2840 with total of 23193.7km', style: TextStyle(fontSize: 18)),
              Text('2019 was the best year with 4046km', style: TextStyle(fontSize: 18)),
              Text('July of 2018 was the best month with 397km', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              _linkText(
                context,
                "'Angermünde Ultra Running' was your longest Run with 50km",
                longestRunUrl,
              ),
              _linkText(
                context,
                "'Evening Run' was the Run with the most elevation gain of 1910.0 m",
                mostElevationUrl,
              ),
              _linkText(
                context,
                "'Alt-Treptow' was your best Run with a average of 21.24 km/h (02:49 /km)",
                bestRunUrl,
              ),
              _linkText(
                context,
                "'Angermünde Ultra Running' was your max tiles Run with 33 tiles",
                maxTilesRunUrl,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkText(BuildContext context, String text, String url) {
    return InkWell(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
} 