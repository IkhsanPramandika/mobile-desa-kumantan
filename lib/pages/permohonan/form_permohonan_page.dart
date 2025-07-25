// Lokasi: lib/pages/permohonan/form_permohonan_page.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import 'dart:typed_data';

// Wrapper class to handle file data on web and mobile
class PlatformFileWrapper {
  final String? path;
  final Uint8List? bytes;
  final String name;
  PlatformFileWrapper({this.path, this.bytes, required this.name});
}

class FormPermohonanPage extends StatefulWidget {
  final String jenisSurat;
  final String pageTitle;
  final Map<String, dynamic>? initialData;
  final int? draftId;
  // [PERUBAHAN] Tambahkan parameter untuk revisi
  final int? revisiId;
  final String? catatanPenolakan;

  const FormPermohonanPage({
    super.key,
    required this.jenisSurat,
    required this.pageTitle,
    this.initialData,
    this.draftId,
    // [PERUBAHAN] Jadikan opsional di constructor
    this.revisiId,
    this.catatanPenolakan,
  });

  @override
  State<FormPermohonanPage> createState() => _FormPermohonanPageState();
}

class _FormPermohonanPageState extends State<FormPermohonanPage> {
  final _formKey = GlobalKey<FormState>();
  String _apiEndpoint = '';
  String _draftApiEndpoint = '';
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _isForSomeoneElse = false;
  int? _currentDraftId;
  // [PERUBAHAN] Tambahkan state untuk revisiId
  int? _currentRevisiId;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, PlatformFileWrapper?> _selectedFiles = {};
  final List<Map<String, TextEditingController>> _ahliWarisControllers = [];

  @override
  void initState() {
    super.initState();
    _currentDraftId = widget.draftId;
    // [PERUBAHAN] Inisialisasi revisiId
    _currentRevisiId = widget.revisiId;
    _setupPageInfo();

    // [PERUBAHAN] Logika populasi data sekarang juga menangani revisi
    if (widget.initialData != null) {
      _populateFormFromDraft(widget.initialData!);
    } else {
      _fetchProfileData();
    }

    if (widget.jenisSurat == 'permohonan-sk-ahli-waris') {
      if (_ahliWarisControllers.isEmpty) {
        _addAhliWarisField();
      }
    }
  }

  void _populateFormFromDraft(Map<String, dynamic> data) {
    setState(() => _isLoadingProfile = true);
    data.forEach((key, value) {
      if (value != null) {
        if (key == 'daftar_ahli_waris' && value is List) {
          _ahliWarisControllers.clear();
          for (var item in value) {
            _ahliWarisControllers.add({
              'nama':
                  TextEditingController(text: item['nama']?.toString() ?? ''),
              'nik': TextEditingController(text: item['nik']?.toString() ?? ''),
              'hubungan': TextEditingController(
                  text: item['hubungan']?.toString() ?? ''),
              'alamat':
                  TextEditingController(text: item['alamat']?.toString() ?? ''),
            });
          }
        } else {
          _getController(key).text = value.toString();
        }
      }
    });
    setState(() => _isLoadingProfile = false);
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var map in _ahliWarisControllers) {
      for (var controller in map.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    if (_isForSomeoneElse) {
      setState(() => _isLoadingProfile = false);
      return;
    }

    setState(() => _isLoadingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception("Token tidak ditemukan");

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/masyarakat/profil'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updatePemohonControllers(data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal memuat data profil: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _updatePemohonControllers(Map<String, dynamic> data) {
    _getController('nama_pemohon').text = data['nama_lengkap'] ?? '';
    _getController('nik_pemohon').text = data['nik'] ?? '';
    _getController('jenis_kelamin').text = data['jenis_kelamin'] ?? '';
    _getController('tempat_lahir').text = data['tempat_lahir'] ?? '';
    _getController('tanggal_lahir').text = data['tanggal_lahir'] ?? '';
    _getController('warganegara_agama').text =
        '${data['kewarganegaraan'] ?? 'WNI'} / ${data['agama'] ?? ''}';
    _getController('pekerjaan').text = data['pekerjaan'] ?? '';
    _getController('alamat_pemohon').text = data['alamat_lengkap'] ?? '';
    _getController('agama').text = data['agama'] ?? '';
  }

  void _clearPemohonControllers() {
    final keysToClear = [
      'nama_pemohon',
      'nik_pemohon',
      'jenis_kelamin',
      'tempat_lahir',
      'tanggal_lahir',
      'warganegara_agama',
      'pekerjaan',
      'alamat_pemohon',
      'agama'
    ];
    for (var key in keysToClear) {
      _getController(key).clear();
    }
  }

  TextEditingController _getController(String key) {
    return _controllers[key] ??= TextEditingController();
  }

  void _setupPageInfo() {
    const String prefix = '/masyarakat';
    _apiEndpoint = '$prefix/${widget.jenisSurat}';
    _draftApiEndpoint = '$prefix/draft/${widget.jenisSurat}';
  }

  void _addAhliWarisField() {
    setState(() {
      _ahliWarisControllers.add({
        'nama': TextEditingController(),
        'nik': TextEditingController(),
        'hubungan': TextEditingController(),
        'alamat': TextEditingController(),
      });
    });
  }

  Future<void> _pickFile(String key) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: kIsWeb,
    );
    if (!mounted) return;
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      setState(() {
        _selectedFiles[key] = PlatformFileWrapper(
          path: kIsWeb ? null : file.path,
          bytes: kIsWeb ? file.bytes : null,
          name: file.name,
        );
      });
    }
  }

  bool _validateRequiredFiles() {
    // Jika sedang revisi, file tidak wajib diisi ulang
    if (_currentRevisiId != null) return true;

    Map<String, List<String>> requiredFilesMap = {
      'permohonan-kk-baru': ['file_kk', 'file_ktp', 'buku_nikah_akta_cerai'],
      'permohonan-kk-hilang': ['surat_keterangan_hilang_kepolisian', 'file_kk_lama', 'file_ktp_pemohon'],
      'permohonan-kk-perubahan-data': [
        'file_kk',
        'file_ktp',
        'surat_keterangan_pendukung'
      ],
      'permohonan-sk-ahli-waris': [
        'file_ktp_pemohon',
        'file_kk_pemohon',
        'file_ktp_ahli_waris',
        'file_kk_ahli_waris',
        'surat_keterangan_kematian'
      ],
      'permohonan-sk-domisili': ['file_kk', 'file_ktp'],
      'permohonan-sk-kelahiran': [
        'file_kk',
        'file_ktp',
        'surat_nikah_orangtua',
        'surat_keterangan_kelahiran'
      ],
      'permohonan-sk-perkawinan': [
        'file_kk',
        'file_ktp_mempelai',
        'surat_nikah_orang_tua',
        'kartu_imunisasi_catin',
        'sertifikat_elsimil'
      ],
      'permohonan-sk-tidak-mampu': ['file_kk', 'file_ktp'],
      'permohonan-sk-usaha': ['file_kk', 'file_ktp'],
    };

    List<String> requiredFields = requiredFilesMap[widget.jenisSurat] ?? [];
    if (requiredFields.isEmpty) return true;

    for (String fieldKey in requiredFields) {
      if (_selectedFiles[fieldKey] == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _kirimPermohonan() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Harap isi semua field yang wajib diisi.'),
          backgroundColor: Colors.red));
      return;
    }

    if (!_validateRequiredFiles()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Harap lengkapi semua lampiran dokumen yang wajib diisi.'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    var request = http.MultipartRequest(
        'POST', Uri.parse('${AppConfig.apiBaseUrl}$_apiEndpoint'));
    request.headers.addAll(
        {'Accept': 'application/json', 'Authorization': 'Bearer $token'});

    _controllers.forEach((key, controller) {
      request.fields[key] = controller.text;
    });

    if (_currentDraftId != null) {
      request.fields['draft_id'] = _currentDraftId.toString();
    }

    // [PERUBAHAN] Tambahkan revisi_id ke request jika ada
    if (_currentRevisiId != null) {
      request.fields['revisi_id'] = _currentRevisiId.toString();
    }

    if (widget.jenisSurat == 'permohonan-sk-ahli-waris') {
      List<Map<String, String>> daftarAhliWaris = [];
      for (var controllerMap in _ahliWarisControllers) {
        daftarAhliWaris.add({
          'nama': controllerMap['nama']!.text,
          'nik': controllerMap['nik']!.text,
          'hubungan': controllerMap['hubungan']!.text,
          'alamat': controllerMap['alamat']!.text,
        });
      }
      request.fields['daftar_ahli_waris'] = jsonEncode(daftarAhliWaris);
    }

    for (var entry in _selectedFiles.entries) {
      final String key = entry.key;
      final PlatformFileWrapper? file = entry.value;
      if (file != null) {
        if (kIsWeb && file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(key, file.bytes!,
              filename: file.name));
        } else if (!kIsWeb && file.path != null) {
          request.files.add(await http.MultipartFile.fromPath(key, file.path!));
        }
      }
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        // [PERUBAHAN] Pesan sukses yang lebih dinamis
        final message = _currentRevisiId != null
            ? 'Revisi permohonan berhasil dikirim!'
            : 'Permohonan berhasil diajukan!';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      } else {
        final errors = jsonDecode(responseBody);
        String errorMessage = errors['message'] ?? 'Terjadi kesalahan.';
        if (errors['errors'] != null) {
          errorMessage += '\n';
          (errors['errors'] as Map).forEach((key, value) {
            errorMessage += '${value[0]}\n';
          });
        }
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Gagal Mengajukan'),
                    content: Text(errorMessage),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'))
                    ]));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _simpanDraft() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final Map<String, String> fields = {};
    _controllers.forEach((key, controller) {
      fields[key] = controller.text;
    });

    if (widget.jenisSurat == 'permohonan-sk-ahli-waris') {
      List<Map<String, String>> daftarAhliWaris = [];
      for (var controllerMap in _ahliWarisControllers) {
        daftarAhliWaris.add({
          'nama': controllerMap['nama']!.text,
          'nik': controllerMap['nik']!.text,
          'hubungan': controllerMap['hubungan']!.text,
          'alamat': controllerMap['alamat']!.text,
        });
      }
      fields['daftar_ahli_waris'] = jsonEncode(daftarAhliWaris);
    }

    final Uri uri;
    final String method;

    if (_currentDraftId != null) {
      uri = Uri.parse(
          '${AppConfig.apiBaseUrl}$_draftApiEndpoint/$_currentDraftId');
      method = 'PUT';
    } else {
      uri = Uri.parse('${AppConfig.apiBaseUrl}$_draftApiEndpoint');
      method = 'POST';
    }

    try {
      final request = http.Request(method, uri);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      });
      request.body = jsonEncode(fields);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permohonan berhasil disimpan sebagai draft.'),
            backgroundColor: Colors.blueAccent));
        Navigator.of(context).pop(true);
      } else {
        final errors = jsonDecode(responseBody);
        String errorMessage = errors['message'] ?? 'Terjadi kesalahan.';
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Gagal Menyimpan Draft'),
                    content: Text(errorMessage),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'))
                    ]));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle, style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF5F8FA),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // [PERUBAHAN] Tampilkan catatan penolakan jika ini adalah form revisi
                  if (widget.catatanPenolakan != null)
                    _buildCatatanRevisiCard(widget.catatanPenolakan!),

                  ..._buildFormWidgets(),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _kirimPermohonan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          // [PERUBAHAN] Teks tombol dinamis
                          label: Text(_currentRevisiId != null
                              ? "KIRIM ULANG REVISI"
                              : (_currentDraftId != null
                                  ? "AJUKAN PERMOHONAN FINAL"
                                  : "AJUKAN PERMOHONAN")),
                        ),
                        const SizedBox(height: 12),
                        // [PERUBAHAN] Sembunyikan tombol draft jika sedang merevisi
                        if (_currentRevisiId == null)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.drafts_outlined),
                            label: const Text("SIMPAN SEBAGAI DRAFT"),
                            onPressed: _simpanDraft,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          )
                      ],
                    )
                ],
              ),
            ),
    );
  }

  List<Widget> _buildFormWidgets() {
    List<Widget> formContent = [];

    if (![
      'permohonan-kk-baru',
      'permohonan-kk-hilang',
      'permohonan-kk-perubahan-data'
    ].contains(widget.jenisSurat)) {
      formContent.add(_buildPemohonSectionCard());
    }

    switch (widget.jenisSurat) {
      case 'permohonan-kk-baru':
        formContent.add(_buildKKBaruFormCard());
        break;
      case 'permohonan-kk-hilang':
        formContent.add(_buildKKHilangFormCard());
        break;
      case 'permohonan-kk-perubahan-data':
        formContent.add(_buildKKPerubahanFormCard());
        break;
      case 'permohonan-sk-ahli-waris':
        formContent.add(_buildSKAhliWarisFormCard());
        break;
      case 'permohonan-sk-domisili':
        formContent.add(_buildSKDomisiliFormCard());
        break;
      case 'permohonan-sk-kelahiran':
        formContent.add(_buildSKKelahiranFormCard());
        break;
      case 'permohonan-sk-perkawinan':
        formContent.add(_buildSKPerkawinanFormCard());
        break;
      case 'permohonan-sk-tidak-mampu':
        formContent.add(_buildSKTidakMampuFormCard());
        break;
      case 'permohonan-sk-usaha':
        formContent.add(_buildSKUsahaFormCard());
        break;
      default:
        formContent.add(const Card(
            child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Jenis surat tidak valid.'))));
    }
    return formContent;
  }

  // [PERUBAHAN] Widget baru untuk menampilkan catatan revisi
  Widget _buildCatatanRevisiCard(String catatan) {
    return Card(
      elevation: 2,
      color: Colors.yellow.shade50,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.orange.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Text('Catatan Perbaikan dari Petugas',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900)),
              ],
            ),
            const Divider(height: 16),
            Text(
              catatan,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPemohonSectionCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data Pemohon',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Ajukan untuk orang lain'),
              value: _isForSomeoneElse,
              onChanged: (bool? value) {
                setState(() {
                  _isForSomeoneElse = value ?? false;
                  if (_isForSomeoneElse) {
                    _clearPemohonControllers();
                  } else {
                    _fetchProfileData();
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            _buildTextField('nama_pemohon', 'Nama Lengkap Pemohon',
                enabled: _isForSomeoneElse),
            _buildTextField('nik_pemohon', 'NIK',
                keyboardType: TextInputType.number, enabled: _isForSomeoneElse),
            _buildDropdownField(
                'jenis_kelamin', 'Jenis Kelamin', ['Laki-laki', 'Perempuan'],
                enabled: _isForSomeoneElse),
            _buildTextField('tempat_lahir', 'Tempat Lahir',
                enabled: _isForSomeoneElse),
            _buildDatePickerField('tanggal_lahir', 'Tanggal Lahir',
                enabled: _isForSomeoneElse),
            _buildTextField('pekerjaan', 'Pekerjaan',
                enabled: _isForSomeoneElse),
            _buildTextField('alamat_pemohon', 'Alamat Lengkap Pemohon',
                enabled: _isForSomeoneElse),
          ],
        ),
      ),
    );
  }

  Widget _buildKKBaruFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField('file_kk', 'File Kartu Keluarga (Lama/Ortu)'),
            _buildFilePickerField('file_ktp', 'File KTP Pemohon'),
            _buildFilePickerField(
                'buku_nikah_akta_cerai', 'Buku Nikah / Akta Cerai'),
            _buildFilePickerField(
                'surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
                isRequired: false),
            _buildFilePickerField('surat_pindah_datang', 'Surat Pindah Datang',
                isRequired: false),
            _buildFilePickerField('ijazah_terakhir', 'Ijazah Terakhir',
                isRequired: false),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildKKHilangFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField('surat_keterangan_hilang_kepolisian',
                'Surat Kehilangan dari Kepolisian'),
            _buildFilePickerField('file_kk_lama', 'File Kartu Keluarga Lama'),
            _buildFilePickerField('file_ktp_pemohon', 'File KTP Pemohon'),
            _buildFilePickerField(
                'surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
                isRequired: false),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildKKPerubahanFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField('file_kk', 'File Kartu Keluarga (Lama)'),
            _buildFilePickerField('file_ktp', 'File KTP Pemohon'),
            _buildFilePickerField(
                'surat_keterangan_pendukung', 'Dokumen Pendukung Perubahan'),
            _buildFilePickerField(
                'surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
                isRequired: false),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSKAhliWarisFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Data Pewaris (Almarhum/Almarhumah)'),
            _buildTextField('nama_pewaris', 'Nama Lengkap Pewaris'),
            _buildTextField('nik_pewaris', 'NIK Pewaris',
                keyboardType: TextInputType.number),
            _buildTextField('tempat_lahir_pewaris', 'Tempat Lahir Pewaris'),
            _buildDatePickerField(
                'tanggal_lahir_pewaris', 'Tanggal Lahir Pewaris'),
            _buildDatePickerField(
                'tanggal_meninggal_pewaris', 'Tanggal Meninggal Pewaris'),
            _buildTextField('alamat_pewaris', 'Alamat Terakhir Pewaris'),
            _buildSectionHeader('Daftar Ahli Waris'),
            ..._buildAhliWarisFields(),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Tambah Ahli Waris"),
              onPressed: _addAhliWarisField,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField(
                'file_ktp_pemohon', 'File KTP Pemohon (yang mengajukan)'),
            _buildFilePickerField(
                'file_kk_pemohon', 'File KK Pemohon (yang mengajukan)'),
            _buildFilePickerField(
                'file_ktp_ahli_waris', 'Semua KTP Ahli Waris (Jadikan 1 File)'),
            _buildFilePickerField(
                'file_kk_ahli_waris', 'Semua KK Ahli Waris (Jadikan 1 File)'),
            _buildFilePickerField(
                'surat_keterangan_kematian', 'Surat Kematian Pewaris'),
            _buildFilePickerField(
                'surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
                isRequired: false),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSKDomisiliFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Data Pemohon/Lembaga'),
            _buildTextField(
                'nama_pemohon_atau_lembaga', 'Nama Pemohon atau Lembaga'),
            _buildTextField('nik_pemohon', 'NIK Pemohon (jika perorangan)',
                keyboardType: TextInputType.number),
            _buildTextField(
                'alamat_lengkap_domisili', 'Alamat Lengkap Domisili',
                maxLines: 3),
            _buildTextField('rt_domisili', 'RT Domisili'),
            _buildTextField('rw_domisili', 'RW Domisili'),
            _buildSectionHeader('Keperluan'),
            _buildTextField(
                'keperluan_domisili', 'Digunakan untuk keperluan apa?',
                maxLines: 3),
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField('file_kk', 'File Kartu Keluarga'),
            _buildFilePickerField('file_ktp', 'File KTP'),
            _buildFilePickerField(
                'file_surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
                isRequired: false),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSKKelahiranFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Data Anak'),
            _buildTextField('nama_anak', 'Nama Lengkap Anak'),
            _buildTextField('tempat_lahir_anak', 'Tempat Lahir Anak'),
            _buildDatePickerField('tanggal_lahir_anak', 'Tanggal Lahir Anak'),
            _buildDropdownField('jenis_kelamin_anak', 'Jenis Kelamin Anak',
                ['Laki-laki', 'Perempuan']),
            _buildDropdownField('agama_anak', 'Agama Anak', [
              'Islam',
              'Kristen Protestan',
              'Katolik',
              'Hindu',
              'Buddha',
              'Konghucu'
            ]),
            _buildTextField('alamat_anak', 'Alamat'),
            _buildSectionHeader('Data Orang Tua'),
            _buildTextField('nama_ayah', 'Nama Ayah'),
            _buildTextField('nik_ayah', 'NIK Ayah',
                keyboardType: TextInputType.number),
            _buildTextField('nama_ibu', 'Nama Ibu'),
            _buildTextField('nik_ibu', 'NIK Ibu',
                keyboardType: TextInputType.number),
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField('file_kk', 'File Kartu Keluarga'),
            _buildFilePickerField(
                'file_ktp', 'File KTP (Ayah & Ibu jadi 1 file)'),
            _buildFilePickerField(
                'surat_nikah_orangtua', 'Surat Nikah Orang Tua'),
            _buildFilePickerField(
                'surat_keterangan_kelahiran', 'Surat Kelahiran dari Bidan/RS'),
            _buildFilePickerField(
                'surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
                isRequired: false),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSKPerkawinanFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Data Calon Mempelai Pria'),
            _buildTextField('nama_pria', 'Nama Lengkap Pria'),
            _buildTextField('nik_pria', 'NIK Pria',
                keyboardType: TextInputType.number),
            _buildTextField('tempat_lahir_pria', 'Tempat Lahir Pria'),
            _buildDatePickerField('tanggal_lahir_pria', 'Tanggal Lahir Pria'),
            _buildTextField('alamat_pria', 'Alamat Lengkap Pria'),
            _buildSectionHeader('Data Calon Mempelai Wanita'),
            _buildTextField('nama_wanita', 'Nama Lengkap Wanita'),
            _buildTextField('nik_wanita', 'NIK Wanita',
                keyboardType: TextInputType.number),
            _buildTextField('tempat_lahir_wanita', 'Tempat Lahir Wanita'),
            _buildDatePickerField(
                'tanggal_lahir_wanita', 'Tanggal Lahir Wanita'),
            _buildTextField('alamat_wanita', 'Alamat Lengkap Wanita'),
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField(
                'file_kk', 'File KK kedua calon (Jadikan 1 File)'),
            _buildFilePickerField(
                'file_ktp_mempelai', 'File KTP kedua calon (Jadikan 1 File)'),
            _buildFilePickerField(
                'surat_nikah_orang_tua', 'Surat Nikah Orang Tua'),
            _buildFilePickerField(
                'kartu_imunisasi_catin', 'Kartu Imunisasi Catin'),
            _buildFilePickerField('sertifikat_elsimil', 'Sertifikat Elsimil'),
            _buildFilePickerField(
                'akta_penceraian', 'Akta Perceraian (Jika Ada)',
                isRequired: false),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk Petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSKTidakMampuFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Data Pihak Terkait (Opsional)'),
            _buildTextField('nama_terkait', 'Nama Terkait (Anak/Orang Tua)',
                isRequired: false),
            _buildTextField('nik_terkait', 'NIK Terkait',
                isRequired: false, keyboardType: TextInputType.number),
            _buildTextField('tempat_lahir_terkait', 'Tempat Lahir Terkait',
                isRequired: false),
            _buildDatePickerField(
                'tanggal_lahir_terkait', 'Tanggal Lahir Terkait',
                isRequired: false),
            _buildDropdownField('jenis_kelamin_terkait',
                'Jenis Kelamin Terkait', ['Laki-laki', 'Perempuan'],
                isRequired: false),
            _buildDropdownField(
                'agama_terkait',
                'Agama Terkait',
                [
                  'Islam',
                  'Kristen Protestan',
                  'Katolik',
                  'Hindu',
                  'Buddha',
                  'Konghucu'
                ],
                isRequired: false),
            _buildTextField(
                'pekerjaan_atau_sekolah_terkait', 'Pekerjaan/Sekolah Terkait',
                isRequired: false),
            _buildTextField('alamat_terkait', 'Alamat Terkait',
                isRequired: false),
            _buildSectionHeader('Keperluan'),
            _buildTextField('keperluan_surat', 'Digunakan untuk keperluan apa?',
                maxLines: 3),
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField('file_kk', 'File Kartu Keluarga'),
            _buildFilePickerField('file_ktp', 'File KTP'),
            _buildFilePickerField(
                'file_pendukung_lain', 'File Pendukung Lainnya',
                isRequired: false),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSKUsahaFormCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Data Usaha'),
            _buildTextField('nama_usaha', 'Nama Usaha'),
            _buildTextField('alamat_usaha', 'Alamat Usaha'),
            _buildTextField('keperluan_surat', 'Keperluan Surat'),
            _buildSectionHeader('Lampiran Dokumen'),
            _buildFilePickerField('file_kk', 'File Kartu Keluarga'),
            _buildFilePickerField('file_ktp', 'File KTP'),
            _buildSectionHeader('Catatan Tambahan'),
            _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
                isRequired: false, maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900)),
    );
  }

  Widget _buildTextField(String fieldKey, String label,
      {bool isRequired = true,
      int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      TextEditingController? controller,
      bool enabled = true}) {
    final fieldController = controller ?? _getController(fieldKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: fieldController,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Masukkan $label...',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade200,
          suffix: isRequired
              ? null
              : Text('(Opsional)',
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return '$label tidak boleh kosong';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePickerField(String fieldKey, String label,
      {bool isRequired = true,
      TextEditingController? controller,
      bool enabled = true}) {
    final fieldController = controller ?? _getController(fieldKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: fieldController,
        readOnly: true,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Pilih Tanggal',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade200,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffix: isRequired
              ? null
              : Text('(Opsional)',
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
        ),
        onTap: !enabled
            ? null
            : () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  String formattedDate =
                      DateFormat('yyyy-MM-dd').format(pickedDate);
                  setState(() {
                    fieldController.text = formattedDate;
                  });
                }
              },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return '$label tidak boleh kosong';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(String fieldKey, String label, List<String> items,
      {bool isRequired = true,
      TextEditingController? controller,
      bool enabled = true}) {
    final fieldController = controller ?? _getController(fieldKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: fieldController.text.isNotEmpty ? fieldController.text : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade200,
          prefixIcon: const Icon(Icons.arrow_drop_down_circle_outlined),
          suffix: isRequired
              ? null
              : Text('(Opsional)',
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
        ),
        hint: Text('Pilih $label...'),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: !enabled
            ? null
            : (String? newValue) {
                setState(() {
                  fieldController.text = newValue ?? '';
                });
              },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return '$label tidak boleh kosong';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFilePickerField(String key, String label,
      {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ${isRequired ? '' : '(Opsional)'}',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pickFile(key),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFiles[key]?.name ??
                              'Pilih file (PDF, JPG, PNG)...',
                          style: GoogleFonts.poppins(
                              color: _selectedFiles[key] != null
                                  ? Colors.black87
                                  : Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedFiles[key] != null)
                        Icon(Icons.check_circle, color: Colors.green.shade600),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAhliWarisFields() {
    List<Widget> fields = [];
    for (int i = 0; i < _ahliWarisControllers.length; i++) {
      fields.add(Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Data Ahli Waris ${i + 1}",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  if (i > 0)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () =>
                          setState(() => _ahliWarisControllers.removeAt(i)),
                    ),
                ],
              ),
              const Divider(),
              _buildTextField('ahli_waris_${i}_nama', 'Nama Lengkap',
                  controller: _ahliWarisControllers[i]['nama']!),
              _buildTextField('ahli_waris_${i}_nik', 'NIK',
                  controller: _ahliWarisControllers[i]['nik']!,
                  keyboardType: TextInputType.number),
              _buildTextField('ahli_waris_${i}_hubungan', 'Hubungan Keluarga',
                  controller: _ahliWarisControllers[i]['hubungan']!),
              _buildTextField('ahli_waris_${i}_alamat', 'Alamat',
                  controller: _ahliWarisControllers[i]['alamat']!),
            ],
          ),
        ),
      ));
    }
    return fields;
  }
}
