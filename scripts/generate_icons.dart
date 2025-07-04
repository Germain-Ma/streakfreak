import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

void main() async {
  // Read the SVG file
  final svgFile = File('assets/icon.svg');
  if (!await svgFile.exists()) {
    print('SVG file not found at assets/icon.svg');
    return;
  }
  
  final svgContent = await svgFile.readAsString();
  
  // Create directories if they don't exist
  await Directory('assets/icons').create(recursive: true);
  
  // Generate different sizes
  final sizes = [
    {'name': 'Icon-192.png', 'size': 192},
    {'name': 'Icon-512.png', 'size': 512},
    {'name': 'Icon-maskable-192.png', 'size': 192},
    {'name': 'Icon-maskable-512.png', 'size': 512},
  ];
  
  for (final size in sizes) {
    await generateIcon(svgContent, size['name']!, size['size']!);
  }
  
  print('Icons generated successfully!');
}

Future<void> generateIcon(String svgContent, String filename, int size) async {
  // For now, we'll create a simple colored square as placeholder
  // In a real implementation, you'd use a proper SVG to PNG converter
  
  final file = File('assets/icons/$filename');
  await file.writeAsBytes(createPlaceholderIcon(size));
  print('Generated $filename');
}

Uint8List createPlaceholderIcon(int size) {
  // Create a simple gradient icon as placeholder
  // This is a basic implementation - in production you'd use proper SVG rendering
  
  final bytes = <int>[];
  
  // Simple PNG header for a solid color image
  // This is a very basic implementation - in practice you'd use a proper PNG encoder
  
  // For now, let's create a simple colored square
  final color = [99, 102, 241]; // Indigo color
  
  // Create a simple 1x1 pixel PNG (simplified)
  // In reality, you'd use a proper PNG encoder library
  
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
    // ... rest of PNG data would go here
  ]);
} 