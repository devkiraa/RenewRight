// lib/screens/image_viewer_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart'; // UPDATED: Import the new package
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ImageViewerScreen extends StatefulWidget {
  final String base64Image;
  final String title;

  const ImageViewerScreen({
    super.key,
    required this.base64Image,
    this.title = 'Document Viewer',
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late Uint8List _imageBytes;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _imageBytes = base64Decode(widget.base64Image);
  }

  Future<void> _shareImage() async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; });

    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/${widget.title.replaceAll(' ', '_')}.jpg';
      await File(path).writeAsBytes(_imageBytes);
      
      final xfile = XFile(path);
      await Share.shareXFiles([xfile], text: 'Sharing document: ${widget.title}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing image: $e')));
    } finally {
      if(mounted) setState(() { _isProcessing = false; });
    }
  }

  // UPDATED: Function to handle downloading with the 'gal' package
  Future<void> _downloadImage() async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; });

    try {
      // The 'gal' package handles its own permissions.
      // It saves the image directly from the byte array.
      await Gal.putImageBytes(_imageBytes, name: widget.title);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved to Gallery!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving image: $e')));
    } finally {
      if(mounted) setState(() { _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.share), tooltip: 'Share', onPressed: _shareImage),
          IconButton(icon: const Icon(Icons.download), tooltip: 'Download', onPressed: _downloadImage),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(_imageBytes),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}