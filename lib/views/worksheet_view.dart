import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:pdfx/pdfx.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../models/worksheet_model.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../utils/shared_prefs_helper.dart';
import 'dart:typed_data';

class WorksheetView extends StatefulWidget {
  final int workOrderId;
  final String workOrderName;

  const WorksheetView({
    Key? key,
    required this.workOrderId,
    required this.workOrderName,
  }) : super(key: key);

  @override
  State<WorksheetView> createState() => _WorksheetViewState();
}

class _WorksheetViewState extends State<WorksheetView> {
  final OdooService _odooService = OdooService();
  PdfController? pdfController;
  YoutubePlayerController? youtubeController;
  bool _isLoading = false;
  String? _error;
  bool _isLandscape = false;
  String _contentType = ''; // 'pdf', 'video', 'text'
  String _htmlContent = '';
  WorksheetModel? _worksheet;
  String? _pdfLocalPath;
  Uint8List? _pdfBytes; // Store PDF bytes for printing

  @override
  void initState() {
    super.initState();
    _loadWorksheet();
  }

  Future<void> _loadWorksheet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = SharedPrefsHelper.getUserData();
      final data = await _odooService.getWorkOrderInstructions(
        database: userData!['database'],
        userId: userData['userId'],
        password: userData['password'],
        workOrderId: widget.workOrderId,
      );

      if (data == null) {
        setState(() {
          _error = 'No instructions found';
          _isLoading = false;
        });
        return;
      }

      _worksheet = WorksheetModel.fromJson(data);

      if (!_worksheet!.hasContent) {
        setState(() {
          _error = 'No content available';
          _isLoading = false;
        });
        return;
      }

      await _setupContent();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _setupContent() async {
    if (_worksheet == null) return;

    // 1) PDF
    if (_worksheet!.worksheetType == 'pdf' && _worksheet!.worksheet != null) {
      try {
        final bytes = base64Decode(_worksheet!.worksheet!);
        _pdfBytes = Uint8List.fromList(bytes); // ⭐ Convertir en Uint8List

        setState(() {
          _contentType = 'pdf';
          pdfController = PdfController(
            document: PdfDocument.openData(bytes),
          );
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _error = 'PDF decode error: $e';
          _isLoading = false;
        });
      }
      return;
    }

    // 2) TEXT
    if (_worksheet!.worksheetType == 'text' && _worksheet!.operationNote != null) {
      final noteHtml = _worksheet!.operationNote!;

      // Check for YouTube URL
      final youtubeUrl = _extractYoutubeUrl(noteHtml);
      if (youtubeUrl != null) {
        final videoId = YoutubePlayer.convertUrlToId(youtubeUrl);
        if (videoId != null) {
          setState(() {
            _contentType = 'video';
            youtubeController = YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(
                autoPlay: false,
                mute: false,
                enableCaption: true,
              ),
            );
            _isLoading = false;
          });
          return;
        }
      }

      // HTML Text
      setState(() {
        _contentType = 'text';
        _htmlContent = noteHtml;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _error = 'Unsupported content type';
      _isLoading = false;
    });
  }

  String? _extractYoutubeUrl(String html) {
    final regExp = RegExp(
      r'https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)[\w-]+',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(html);
    return match?.group(0);
  }

  // ⭐ Save PDF locally
  Future<void> _savePdfLocally() async {
    if (_contentType != 'pdf' || _pdfBytes == null) {
      _showSnackBar('No PDF available', isError: true);
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'worksheet_${widget.workOrderId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(_pdfBytes!); // ✅ Uint8List fonctionne ici aussi
      setState(() {
        _pdfLocalPath = file.path;
      });

      _showSnackBar('PDF saved: $fileName');
    } catch (e) {
      _showSnackBar('Save error: $e', isError: true);
    }
  }


  // ⭐ Share PDF
  Future<void> _sharePdf() async {
    if (_pdfLocalPath != null) {
      await Share.shareXFiles(
        [XFile(_pdfLocalPath!)],
        text: 'Work Instructions - ${widget.workOrderName}',
      );
    } else {
      await _savePdfLocally();
      if (_pdfLocalPath != null) {
        await _sharePdf();
      }
    }
  }

  // ⭐ Print PDF
  Future<void> _printPdf() async {
    if (_contentType != 'pdf' || _pdfBytes == null) {
      _showSnackBar('No PDF available to print', isError: true);
      return;
    }

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _pdfBytes!,
        name: 'Work_Instructions_${widget.workOrderId}.pdf',
      );
    } catch (e) {
      _showSnackBar('Print error: $e', isError: true);
    }
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
  }

  @override
  void dispose() {
    pdfController?.dispose();
    youtubeController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    String title = localizations.translate('work_instructions');
    Color appBarColor = const Color(0xFF455A64);

    switch (_contentType) {
      case 'video':
        title = localizations.translate('video_instructions');
        appBarColor = Colors.red;
        break;
      case 'pdf':
        title = localizations.translate('pdf_worksheet');
        appBarColor = Colors.blue;
        break;
      case 'text':
        title = localizations.translate('text_instructions');
        appBarColor = Colors.green;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.workOrderName,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: !_isLoading && _error == null
            ? [
          // ⭐ Print Button (PDF only)
          if (_contentType == 'pdf')
            IconButton(
              icon: const Icon(Icons.print, size: 24, color: Colors.white),
              onPressed: _printPdf,
              tooltip: localizations.translate('print_pdf'),
            ),

          // ⭐ Download/Share Menu (PDF only)
          if (_contentType == 'pdf')
            PopupMenuButton<String>(
              icon: const Icon(Icons.download, size: 24, color: Colors.white),
              tooltip: localizations.translate('download_pdf'),
              onSelected: (value) {
                if (value == 'save') {
                  _savePdfLocally();
                } else if (value == 'share') {
                  _sharePdf();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      const Icon(Icons.save, color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Text(localizations.translate('save_pdf')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Text(localizations.translate('share_pdf')),
                    ],
                  ),
                ),
              ],
            ),

          // Landscape/Portrait Toggle
          if (_contentType == 'video' || _contentType == 'pdf')
            IconButton(
              icon: Icon(
                _isLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_landscape,
                size: 24,
                color: Colors.white,
              ),
              onPressed: _toggleOrientation,
              tooltip: _isLandscape ? 'Portrait' : 'Landscape',
            ),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            onPressed: _loadWorksheet,
            tooltip: localizations.translate('refresh'),
          ),
        ]
            : null,
      ),
      body: _buildContent(localizations),
    );
  }

  Widget _buildContent(AppLocalizations localizations) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading instructions...', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadWorksheet,
                icon: const Icon(Icons.refresh),
                label: Text(localizations.translate('retry')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (_contentType) {
      case 'video':
        return _buildVideoContent();
      case 'pdf':
        return _buildPdfContent();
      case 'text':
        return _buildTextContent();
      default:
        return Center(
          child: Text(localizations.translate('no_content')),
        );
    }
  }

  Widget _buildVideoContent() {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
        ),
      ),
      builder: (context, player) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            player,
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                youtubeController!.metadata.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPdfContent() {
    return PdfView(
      controller: pdfController!,
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description, size: 32, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate('instructions'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: HtmlWidget(
              _htmlContent,
              textStyle: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
