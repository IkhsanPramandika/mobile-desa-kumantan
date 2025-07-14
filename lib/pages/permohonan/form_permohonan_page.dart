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

  const FormPermohonanPage({
    super.key,
    required this.jenisSurat,
    required this.pageTitle,
    this.initialData,
    this.draftId,
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

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, PlatformFileWrapper?> _selectedFiles = {};
  final List<Map<String, TextEditingController>> _ahliWarisControllers = [];

  @override
  void initState() {
    super.initState();
    _currentDraftId = widget.draftId;
    _setupPageInfo();

    if (widget.initialData != null) {
      _populateFormFromDraft(widget.initialData!);
    } else {
      _fetchProfileData();
    }

    if (widget.jenisSurat == 'sk-ahli-waris') {
      if (_ahliWarisControllers.isEmpty) {
        _addAhliWarisField();
      }
    }
  }

  void _populateFormFromDraft(Map<String, dynamic> data) {
    setState(() {
      _isLoadingProfile = true;
    });
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
    setState(() {
      _isLoadingProfile = false;
    });
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

  Future<void> _kirimPermohonan() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Harap isi semua field yang wajib diisi.'),
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

    if (widget.jenisSurat == 'sk-ahli-waris') {
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permohonan berhasil diajukan!'),
            backgroundColor: Colors.green));
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

    if (widget.jenisSurat == 'sk-ahli-waris') {
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                            label: Text(_currentDraftId != null
                                ? "AJUKAN PERMOHONAN FINAL"
                                : "AJUKAN PERMOHONAN"),
                          ),
                          const SizedBox(height: 12),
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
            ),
    );
  }

  List<Widget> _buildFormWidgets() {
    switch (widget.jenisSurat) {
      case 'permohonan-kk-baru':
        return _buildKKBaruForm();
      case 'permohonan-kk-hilang':
        return _buildKKHilangForm();
      case 'permohonan-kk-perubahan-data':
        return _buildKKPerubahanForm();
      case 'permohonan-sk-ahli-waris':
        return _buildSKAhliWarisForm();
      case 'permohonan-sk-domisili':
        return _buildSKDomisiliForm();
      case 'permohonan-sk-kelahiran':
        return _buildSKKelahiranForm();
      case 'permohonan-sk-perkawinan':
        return _buildSKPerkawinanForm();
      case 'permohonan-sk-tidak-mampu':
        return _buildSKTidakMampuForm();
      case 'permohonan-sk-usaha':
        return _buildSKUsahaForm();
      default:
        return [const Text('Jenis surat tidak valid.')];
    }
  }

  List<Widget> _buildPemohonSection() {
    return [
      _buildSectionHeader('Data Pemohon'),
      CheckboxListTile(
        title: const Text("Ajukan untuk orang lain"),
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
        controlAffinity: ListTileControlAffinity.leading,
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
      _buildTextField('pekerjaan', 'Pekerjaan', enabled: _isForSomeoneElse),
      _buildTextField('alamat_pemohon', 'Alamat Lengkap Pemohon',
          enabled: _isForSomeoneElse),
    ];
  }

  List<Widget> _buildKKBaruForm() {
    return [
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField('file_kk', 'File Kartu Keluarga (Lama/Ortu)',
          isRequired: false),
      _buildFilePickerField('file_ktp', 'File KTP Pemohon', isRequired: false),
      _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
          isRequired: false),
      _buildFilePickerField('buku_nikah_akta_cerai', 'Buku Nikah / Akta Cerai',
          isRequired: false),
      _buildFilePickerField('surat_pindah_datang', 'Surat Pindah Datang',
          isRequired: false),
      _buildFilePickerField('ijazah_terakhir', 'Ijazah Terakhir',
          isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
    ];
  }

  List<Widget> _buildKKHilangForm() {
    return [
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
          isRequired: false),
      _buildFilePickerField('surat_keterangan_hilang_kepolisian',
          'Surat Kehilangan dari Kepolisian',
          isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
    ];
  }

  List<Widget> _buildKKPerubahanForm() {
    return [
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField('file_kk', 'File Kartu Keluarga (Lama)',
          isRequired: false),
      _buildFilePickerField('file_ktp', 'File KTP Pemohon', isRequired: false),
      _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
          isRequired: false),
      _buildFilePickerField(
          'surat_keterangan_pendukung', 'Dokumen Pendukung Perubahan',
          isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
    ];
  }

  List<Widget> _buildSKAhliWarisForm() {
    return [
      _buildSectionHeader('Data Pewaris (Almarhum/Almarhumah)'),
      _buildTextField('nama_pewaris', 'Nama Lengkap Pewaris',
          isRequired: false),
      _buildTextField('nik_pewaris', 'NIK Pewaris',
          keyboardType: TextInputType.number, isRequired: false),
      _buildTextField('tempat_lahir_pewaris', 'Tempat Lahir Pewaris',
          isRequired: false),
      _buildDatePickerField('tanggal_lahir_pewaris', 'Tanggal Lahir Pewaris',
          isRequired: false),
      _buildDatePickerField(
          'tanggal_meninggal_pewaris', 'Tanggal Meninggal Pewaris',
          isRequired: false),
      _buildTextField('alamat_pewaris', 'Alamat Terakhir Pewaris',
          isRequired: false),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField(
          'file_ktp_pemohon', 'File KTP Pemohon (yang mengajukan)',
          isRequired: false),
      _buildFilePickerField(
          'file_kk_pemohon', 'File KK Pemohon (yang mengajukan)',
          isRequired: false),
      _buildFilePickerField(
          'file_ktp_ahli_waris', 'Semua KTP Ahli Waris (jadikan 1 file)',
          isRequired: false),
      _buildFilePickerField(
          'file_kk_ahli_waris', 'Semua KK Ahli Waris (jadikan 1 file)',
          isRequired: false),
      _buildFilePickerField(
          'surat_keterangan_kematian', 'Surat Kematian Pewaris',
          isRequired: false),
      _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
          isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
    ];
  }

  List<Widget> _buildSKDomisiliForm() {
    return [
      _buildSectionHeader('Data Pemohon/Lembaga'),
      _buildTextField('nama_pemohon_atau_lembaga', 'Nama Pemohon atau Lembaga',
          isRequired: false),
      _buildTextField('nik_pemohon', 'NIK Pemohon (jika perorangan)',
          isRequired: false, keyboardType: TextInputType.number),
      _buildTextField('alamat_lengkap_domisili', 'Alamat Lengkap Domisili',
          maxLines: 3, isRequired: false),
      _buildTextField('rt_domisili', 'RT Domisili', isRequired: false),
      _buildTextField('rw_domisili', 'RW Domisili', isRequired: false),
      _buildSectionHeader('Keperluan'),
      _buildTextField('keperluan_domisili', 'Digunakan untuk keperluan apa?',
          maxLines: 3, isRequired: false),
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField('file_kk', 'File Kartu Keluarga',
          isRequired: false),
      _buildFilePickerField('file_ktp', 'File KTP', isRequired: false),
      _buildFilePickerField(
          'file_surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
          isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
    ];
  }

  List<Widget> _buildSKKelahiranForm() {
    return [
      _buildSectionHeader('Data Anak'),
      _buildTextField('nama_anak', 'Nama Lengkap Anak', isRequired: false),
      _buildTextField('tempat_lahir_anak', 'Tempat Lahir Anak',
          isRequired: false),
      _buildDatePickerField('tanggal_lahir_anak', 'Tanggal Lahir Anak',
          isRequired: false),
      _buildDropdownField('jenis_kelamin_anak', 'Jenis Kelamin Anak',
          ['Laki-laki', 'Perempuan'],
          isRequired: false),
      _buildDropdownField(
          'agama_anak',
          'Agama Anak',
          [
            'Islam',
            'Kristen Protestan',
            'Katolik',
            'Hindu',
            'Buddha',
            'Konghucu'
          ],
          isRequired: false),
      _buildTextField('alamat_anak', 'Alamat', isRequired: false),
      _buildSectionHeader('Data Orang Tua'),
      _buildTextField('nama_ayah', 'Nama Ayah', isRequired: false),
      _buildTextField('nik_ayah', 'NIK Ayah',
          isRequired: false, keyboardType: TextInputType.number),
      _buildTextField('nama_ibu', 'Nama Ibu', isRequired: false),
      _buildTextField('nik_ibu', 'NIK Ibu',
          isRequired: false, keyboardType: TextInputType.number),
      _buildTextField('no_buku_nikah', 'Nomor Buku Nikah', isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField('file_kk', 'File Kartu Keluarga',
          isRequired: false),
      _buildFilePickerField('file_ktp', 'File KTP (Ayah & Ibu jadi 1 file)',
          isRequired: false),
      _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW',
          isRequired: false),
      _buildFilePickerField('surat_nikah_orangtua', 'Surat Nikah Orang Tua',
          isRequired: false),
      _buildFilePickerField(
          'surat_keterangan_kelahiran', 'Surat Kelahiran dari Bidan/RS',
          isRequired: false),
    ];
  }

  List<Widget> _buildSKPerkawinanForm() {
    return [
      _buildSectionHeader('Data Calon Mempelai Pria'),
      _buildTextField('nama_pria', 'Nama Lengkap Pria', isRequired: false),
      _buildTextField('nik_pria', 'NIK Pria',
          keyboardType: TextInputType.number, isRequired: false),
      _buildTextField('tempat_lahir_pria', 'Tempat Lahir Pria',
          isRequired: false),
      _buildDatePickerField('tanggal_lahir_pria', 'Tanggal Lahir Pria',
          isRequired: false),
      _buildTextField('alamat_pria', 'Alamat Lengkap Pria', isRequired: false),
      _buildSectionHeader('Data Calon Mempelai Wanita'),
      _buildTextField('nama_wanita', 'Nama Lengkap Wanita', isRequired: false),
      _buildTextField('nik_wanita', 'NIK Wanita',
          keyboardType: TextInputType.number, isRequired: false),
      _buildTextField('tempat_lahir_wanita', 'Tempat Lahir Wanita',
          isRequired: false),
      _buildDatePickerField('tanggal_lahir_wanita', 'Tanggal Lahir Wanita',
          isRequired: false),
      _buildTextField('alamat_wanita', 'Alamat Lengkap Wanita',
          isRequired: false),
      _buildSectionHeader('Detail Akad Nikah'),
      _buildDatePickerField('tanggal_akad', 'Rencana Tanggal Akad',
          isRequired: false),
      _buildTextField('tempat_akad', 'Rencana Tempat Akad', isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField('file_kk', 'File KK kedua calon (jadikan 1 file)',
          isRequired: false),
      _buildFilePickerField(
          'file_ktp_mempelai', 'File KTP kedua calon (jadikan 1 file)',
          isRequired: false),
      _buildFilePickerField('surat_nikah_orang_tua', 'Surat Nikah Orang Tua',
          isRequired: false),
      _buildFilePickerField('kartu_imunisasi_catin', 'Kartu Imunisasi Catin',
          isRequired: false),
      _buildFilePickerField('sertifikat_elsimil', 'Sertifikat Elsimil',
          isRequired: false),
      _buildFilePickerField('akta_penceraian', 'Akta Perceraian (jika ada)',
          isRequired: false),
    ];
  }

  List<Widget> _buildSKTidakMampuForm() {
    return [
      ..._buildPemohonSection(),
      _buildSectionHeader('Data Pihak Terkait (Opsional)'),
      _buildTextField('nama_terkait', 'Nama Terkait (Anak/Orang Tua)',
          isRequired: false),
      _buildTextField('nik_terkait', 'NIK Terkait',
          isRequired: false, keyboardType: TextInputType.number),
      _buildTextField('tempat_lahir_terkait', 'Tempat Lahir Terkait',
          isRequired: false),
      _buildDatePickerField('tanggal_lahir_terkait', 'Tanggal Lahir Terkait',
          isRequired: false),
      _buildDropdownField('jenis_kelamin_terkait', 'Jenis Kelamin Terkait',
          ['Laki-laki', 'Perempuan'],
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
      _buildTextField('alamat_terkait', 'Alamat Terkait', isRequired: false),
      _buildSectionHeader('Keperluan'),
      _buildTextField('keperluan_surat', 'Digunakan untuk keperluan apa?',
          maxLines: 3, isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField('file_kk', 'File Kartu Keluarga',
          isRequired: false),
      _buildFilePickerField('file_ktp', 'File KTP', isRequired: false),
      _buildFilePickerField('file_pendukung_lain', 'File Pendukung Lainnya',
          isRequired: false),
    ];
  }

  List<Widget> _buildSKUsahaForm() {
    return [
      ..._buildPemohonSection(),
      _buildSectionHeader('Data Usaha'),
      _buildTextField('nama_usaha', 'Nama Usaha', isRequired: false),
      _buildTextField('alamat_usaha', 'Alamat Usaha', isRequired: false),
      _buildSectionHeader('Catatan Tambahan'),
      _buildTextField('catatan_pemohon', 'Catatan untuk petugas',
          isRequired: false, maxLines: 4),
      _buildSectionHeader('Lampiran Dokumen'),
      _buildFilePickerField('file_kk', 'File Kartu Keluarga',
          isRequired: false),
      _buildFilePickerField('file_ktp', 'File KTP', isRequired: false),
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
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
