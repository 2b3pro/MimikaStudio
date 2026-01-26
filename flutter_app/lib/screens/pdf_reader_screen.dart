import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import '../services/api_service.dart';

class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final ApiService _api = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  // Library state
  List<Map<String, String>> _pdfLibrary = [];
  String? _selectedPdfPath;
  String? _selectedPdfName;
  bool _isInitialized = false;

  // Reading state
  bool _isReading = false;
  bool _isPaused = false;
  int _currentPage = 1;
  int _totalPages = 0;
  String? _selectedText;
  List<String> _sentences = [];
  int _currentSentenceIndex = -1;
  String _currentReadingText = '';

  // TTS settings
  String _selectedVoice = 'af_heart';
  double _speed = 1.0;

  // Kokoro voices (subset)
  final List<Map<String, String>> _voices = [
    {'id': 'af_heart', 'name': 'Heart (Female)'},
    {'id': 'af_bella', 'name': 'Bella (Female)'},
    {'id': 'af_sarah', 'name': 'Sarah (Female)'},
    {'id': 'am_michael', 'name': 'Michael (Male)'},
    {'id': 'am_adam', 'name': 'Adam (Male)'},
    {'id': 'bf_emma', 'name': 'Emma (British F)'},
    {'id': 'bm_george', 'name': 'George (British M)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSamplePdfs();
  }

  Future<void> _loadSamplePdfs() async {
    final previousCount = _pdfLibrary.length;
    final wasInitialized = _isInitialized;

    // Look for PDFs in the project pdf directory
    // Try multiple possible locations
    final sampleDirs = <String>[];

    // 1. Hardcoded development path
    sampleDirs.add('/Volumes/SSD4tb/Dropbox/DSS/artifacts/code/TSSUi/pdf');

    // 2. Try to find pdf folder relative to executable (for packaged app)
    try {
      final execPath = Platform.resolvedExecutable;
      // In macOS app bundle: .../MimikaStudio.app/Contents/MacOS/MimikaStudio
      // Go up to project root: .../MimikaStudio.app -> ../../.. -> flutter_app -> .. -> project
      final execDir = Directory(execPath).parent;
      // Try various relative paths from executable
      sampleDirs.add(p.join(execDir.path, '..', '..', '..', '..', '..', 'pdf'));
      sampleDirs.add(p.join(execDir.path, '..', '..', '..', 'pdf'));
      sampleDirs.add(p.join(execDir.path, 'pdf'));
    } catch (_) {}

    // 3. Current directory and parent
    sampleDirs.add('${Directory.current.path}/pdf');
    sampleDirs.add('${Directory.current.path}/../pdf');

    // Debug: print paths being checked
    debugPrint('PDF search paths:');
    for (final path in sampleDirs) {
      final exists = await Directory(path).exists();
      debugPrint('  $path -> exists: $exists');
    }

    for (final dirPath in sampleDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          final files = await dir.list().toList();
          for (final file in files) {
            if (file is File && file.path.toLowerCase().endsWith('.pdf')) {
              final name = p.basename(file.path);
              final absolutePath = file.absolute.path;
              if (!_pdfLibrary.any((p) => p['path'] == absolutePath)) {
                _pdfLibrary.add({'path': absolutePath, 'name': name});
                debugPrint('Found PDF: $name at $absolutePath');
              }
            }
          }
        } catch (e) {
          debugPrint('Error listing directory $dirPath: $e');
        }
      }
    }

    // Auto-select first PDF if any found and nothing selected
    if (_pdfLibrary.isNotEmpty && _selectedPdfPath == null) {
      _selectPdf(_pdfLibrary.first['path']!, _pdfLibrary.first['name']!);
    }

    setState(() => _isInitialized = true);

    // Show feedback on refresh (only after initial load or on explicit refresh)
    if (wasInitialized && mounted) {
      final newCount = _pdfLibrary.length - previousCount;
      if (newCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found $newCount new PDF(s)')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No new PDFs found (checked ${sampleDirs.length} locations)')),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _openPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = p.basename(path);

      // Add to library if not exists
      if (!_pdfLibrary.any((p) => p['path'] == path)) {
        setState(() {
          _pdfLibrary.add({'path': path, 'name': name});
        });
      }

      _selectPdf(path, name);
    }
  }

  void _selectPdf(String path, String name) {
    setState(() {
      _selectedPdfPath = path;
      _selectedPdfName = name;
      _currentPage = 1;
      _totalPages = 0;
      _stopReading();
    });
  }

  void _removePdf(String path) {
    setState(() {
      _pdfLibrary.removeWhere((p) => p['path'] == path);
      if (_selectedPdfPath == path) {
        _selectedPdfPath = null;
        _selectedPdfName = null;
        _stopReading();
      }
    });
  }

  Future<void> _startReading() async {
    if (_selectedPdfPath == null) return;

    // Get text from current page selection or extract full page
    String textToRead = _selectedText ?? '';

    if (textToRead.isEmpty) {
      // Try to get text from the viewer
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select text in the PDF to read aloud, or use the text input below'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Split into sentences
    _sentences = _splitIntoSentences(textToRead);
    if (_sentences.isEmpty) return;

    setState(() {
      _isReading = true;
      _isPaused = false;
      _currentSentenceIndex = 0;
    });

    await _readNextSentence();
  }

  List<String> _splitIntoSentences(String text) {
    // Split by sentence endings
    final sentences = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);

      if (text[i] == '.' || text[i] == '!' || text[i] == '?') {
        // Check if followed by space or end
        if (i + 1 >= text.length || text[i + 1] == ' ' || text[i + 1] == '\n') {
          final sentence = buffer.toString().trim();
          if (sentence.isNotEmpty && sentence.length > 1) {
            sentences.add(sentence);
          }
          buffer.clear();
        }
      }
    }

    // Add remaining text as last sentence
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }

    return sentences;
  }

  Future<void> _readNextSentence() async {
    if (!_isReading || _isPaused) return;
    if (_currentSentenceIndex >= _sentences.length) {
      _stopReading();
      return;
    }

    final sentence = _sentences[_currentSentenceIndex];
    setState(() {
      _currentReadingText = sentence;
    });

    try {
      // Generate TTS audio
      final audioUrl = await _api.generateKokoro(
        text: sentence,
        voice: _selectedVoice,
        speed: _speed,
      );

      if (!_isReading) return; // Check if stopped while generating

      // Play audio
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();

      // Wait for audio to complete
      await _audioPlayer.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );

      if (!_isReading || _isPaused) return;

      // Move to next sentence
      setState(() {
        _currentSentenceIndex++;
      });

      // Small pause between sentences
      await Future.delayed(const Duration(milliseconds: 300));

      _readNextSentence();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS Error: $e')),
        );
      }
      _stopReading();
    }
  }

  void _pauseReading() {
    setState(() {
      _isPaused = true;
    });
    _audioPlayer.pause();
  }

  void _resumeReading() {
    setState(() {
      _isPaused = false;
    });
    _audioPlayer.play();

    // If audio finished while paused, continue to next
    if (_audioPlayer.processingState == ProcessingState.completed) {
      setState(() {
        _currentSentenceIndex++;
      });
      _readNextSentence();
    }
  }

  void _stopReading() {
    setState(() {
      _isReading = false;
      _isPaused = false;
      _currentSentenceIndex = -1;
      _currentReadingText = '';
      _sentences = [];
    });
    _audioPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sidebar
        _buildSidebar(),
        // Main content
        Expanded(
          child: _selectedPdfPath != null
              ? _buildPdfViewer()
              : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.library_books, size: 20),
                const SizedBox(width: 8),
                const Text('PDF Library', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadSamplePdfs,
                  tooltip: 'Refresh PDFs',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: _openPdf,
                  tooltip: 'Open PDF',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Library list
          Expanded(
            child: _pdfLibrary.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No PDFs',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _openPdf,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Open PDF'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _pdfLibrary.length,
                    itemBuilder: (context, index) {
                      final pdf = _pdfLibrary[index];
                      final isSelected = pdf['path'] == _selectedPdfPath;

                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                        leading: Icon(
                          Icons.picture_as_pdf,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          size: 20,
                        ),
                        title: Text(
                          pdf['name']!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _removePdf(pdf['path']!),
                          visualDensity: VisualDensity.compact,
                        ),
                        onTap: () => _selectPdf(pdf['path']!, pdf['name']!),
                      );
                    },
                  ),
          ),
          // TTS Settings
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TTS Voice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedVoice,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  items: _voices.map((v) {
                    return DropdownMenuItem(
                      value: v['id'],
                      child: Text(v['name']!, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedVoice = value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Speed:', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _speed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label: '${_speed.toStringAsFixed(1)}x',
                        onChanged: (v) => setState(() => _speed = v),
                      ),
                    ),
                    Text('${_speed.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Open a PDF to get started',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openPdf,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    final file = File(_selectedPdfPath!);
    if (!file.existsSync()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('File not found:\n$_selectedPdfPath', textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toolbar
        _buildToolbar(),
        // Reading indicator
        if (_isReading) _buildReadingIndicator(),
        // PDF Viewer
        Expanded(
          child: SfPdfViewer.file(
            file,
            key: _pdfViewerKey,
            controller: _pdfController,
            onDocumentLoaded: (details) {
              setState(() {
                _totalPages = details.document.pages.count;
              });
            },
            onPageChanged: (details) {
              setState(() {
                _currentPage = details.newPageNumber;
              });
            },
            onTextSelectionChanged: (details) {
              setState(() {
                _selectedText = details.selectedText;
              });
            },
          ),
        ),
        // Page indicator
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Zoom controls
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _pdfController.zoomLevel -= 0.25,
            tooltip: 'Zoom out',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _pdfController.zoomLevel += 0.25,
            tooltip: 'Zoom in',
          ),
          const VerticalDivider(),
          // Navigation
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: () => _pdfController.previousPage(),
            tooltip: 'Previous page',
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: () => _pdfController.nextPage(),
            tooltip: 'Next page',
          ),
          const Spacer(),
          // TTS controls
          if (_selectedText != null && _selectedText!.isNotEmpty && !_isReading)
            Chip(
              avatar: const Icon(Icons.text_fields, size: 16),
              label: Text(
                '${_selectedText!.length} chars selected',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(width: 8),
          if (!_isReading)
            FilledButton.icon(
              onPressed: (_selectedText != null && _selectedText!.isNotEmpty)
                  ? _startReading
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Read Aloud'),
            )
          else
            Row(
              children: [
                if (_isPaused)
                  FilledButton.icon(
                    onPressed: _resumeReading,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: _pauseReading,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _stopReading,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReadingIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPaused ? Icons.pause_circle : Icons.volume_up,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isPaused
                    ? 'Paused'
                    : 'Reading sentence ${_currentSentenceIndex + 1} of ${_sentences.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          if (_currentReadingText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currentReadingText,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Page $_currentPage of $_totalPages'),
        ],
      ),
    );
  }
}
