import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
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

  const FormPermohonanPage({
    super.key,
    required this.jenisSurat,
    required this.pageTitle,
  });

  @override
  State<FormPermohonanPage> createState() => _FormPermohonanPageState();
}

class _FormPermohonanPageState extends State<FormPermohonanPage> {
  final _formKey = GlobalKey<FormState>();
  String _apiEndpoint = '';
  bool _isLoading = false;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, PlatformFileWrapper?> _selectedFiles = {};
  final List<Map<String, TextEditingController>> _ahliWarisControllers = [];

  @override
  void initState() {
    super.initState();
    if (widget.jenisSurat == 'sk_ahli_waris') {
      _addAhliWarisField();
    }
    _setupPageInfo();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var controllerMap in _ahliWarisControllers) {
      for (var controller in controllerMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _setupPageInfo() {
    switch (widget.jenisSurat) {
      case 'kk_baru': _apiEndpoint = '/permohonan-kk-baru'; break;
      case 'kk_hilang': _apiEndpoint = '/permohonan-kk-hilang'; break;
      case 'kk_perubahan': _apiEndpoint = '/permohonan-kk-perubahan-data'; break;
      case 'sk_ahli_waris': _apiEndpoint = '/permohonan-sk-ahli-waris'; break;
      case 'sk_tidak_mampu': _apiEndpoint = '/permohonan-sk-tidak-mampu'; break;
      case 'sk_domisili': _apiEndpoint = '/permohonan-sk-domisili'; break;
      case 'sk_kelahiran': _apiEndpoint = '/permohonan-sk-kelahiran'; break;
      case 'sk_perkawinan': _apiEndpoint = '/permohonan-sk-perkawinan'; break;
      case 'sk_usaha': _apiEndpoint = '/permohonan-sk-usaha'; break;
      default: _apiEndpoint = '';
    }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap isi semua field yang wajib diisi.'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isLoading = true; });
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      setState(() { _isLoading = false; });
      return;
    }

    var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}$_apiEndpoint'));
    request.headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $token'});

    _controllers.forEach((key, controller) {
      request.fields[key] = controller.text;
    });

    if (widget.jenisSurat == 'sk_ahli_waris') {
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
          request.files.add(http.MultipartFile.fromBytes(key, file.bytes!, filename: file.name));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permohonan berhasil diajukan!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      } else {
        final errors = jsonDecode(responseBody);
        String errorMessage = errors['message'] ?? 'Terjadi kesalahan.';
        showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Gagal Mengajukan'), content: Text(errorMessage), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._buildFormWidgets(),
              const SizedBox(height: 32),
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _kirimPermohonan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    label: const Text("AJUKAN PERMOHONAN"),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormWidgets() {
    switch (widget.jenisSurat) {
      case 'kk_baru':
        return [
          _buildSectionHeader('Lampiran Dokumen'),
          _buildFilePickerField('file_kk', 'File Kartu Keluarga (Lama/Ortu)'),
          _buildFilePickerField('file_ktp', 'File KTP Pemohon'),
          _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW'),
          _buildFilePickerField('buku_nikah_akta_cerai', 'Buku Nikah / Akta Cerai', isRequired: false),
          _buildFilePickerField('surat_pindah_datang', 'Surat Pindah Datang', isRequired: false),
          _buildFilePickerField('ijazah_terakhir', 'Ijazah Terakhir', isRequired: false),
          _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan_pemohon', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
        ];
      case 'kk_hilang':
        return [
          _buildSectionHeader('Lampiran Dokumen'),
          _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW'),
          _buildFilePickerField('surat_keterangan_hilang_kepolisian', 'Surat Kehilangan dari Kepolisian'),
          _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan_pemohon', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
        ];
      case 'kk_perubahan':
        return [
          _buildSectionHeader('Lampiran Dokumen'),
          _buildFilePickerField('file_kk', 'File Kartu Keluarga (Lama)'),
          _buildFilePickerField('file_ktp', 'File KTP Pemohon'),
          _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW'),
          _buildFilePickerField('surat_keterangan_pendukung', 'Dokumen Pendukung Perubahan'),
          _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan_pemohon', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
        ];
      case 'sk_ahli_waris':
        return [
          _buildSectionHeader('Data Pewaris (Almarhum/Almarhumah)'),
          _buildTextField('nama_pewaris', 'Nama Lengkap Pewaris'),
          _buildTextField('nik_pewaris', 'NIK Pewaris', keyboardType: TextInputType.number),
          _buildTextField('tempat_lahir_pewaris', 'Tempat Lahir Pewaris'),
          _buildTextField('tanggal_lahir_pewaris', 'Tanggal Lahir Pewaris (YYYY-MM-DD)'),
          _buildTextField('tanggal_meninggal_pewaris', 'Tanggal Meninggal Pewaris (YYYY-MM-DD)'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          _buildSectionHeader('Lampiran Dokumen'),
          _buildFilePickerField('file_ktp_pemohon', 'File KTP Pemohon (yang mengajukan)'),
          _buildFilePickerField('file_kk_pemohon', 'File KK Pemohon (yang mengajukan)'),
          _buildFilePickerField('file_ktp_ahli_waris', 'Semua KTP Ahli Waris (jadikan 1 file)'),
          _buildFilePickerField('file_kk_ahli_waris', 'Semua KK Ahli Waris (jadikan 1 file)'),
          _buildFilePickerField('surat_keterangan_kematian', 'Surat Kematian Pewaris'),
          _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW'),
          _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan_pemohon', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
        ];
      case 'sk_domisili':
        return [
          _buildSectionHeader('Data Pemohon'),
          _buildTextField('nama_pemohon_atau_lembaga', 'Nama Pemohon / Lembaga'),
          _buildTextField('nik_pemohon', 'NIK Pemohon', keyboardType: TextInputType.number),
          _buildTextField('jenis_kelamin_pemohon', 'Jenis Kelamin'),
          _buildTextField('tempat_lahir_pemohon', 'Tempat Lahir'),
          _buildTextField('tanggal_lahir_pemohon', 'Tanggal Lahir (YYYY-MM-DD)'),
          _buildTextField('pekerjaan_pemohon', 'Pekerjaan'),
          _buildTextField('alamat_lengkap_domisili', 'Alamat Domisili Sekarang'),
          _buildTextField('rt_domisili', 'RT Domisili'),
          _buildTextField('rw_domisili', 'RW Domisili'),
          _buildTextField('dusun_domisili', 'Dusun Domisili'),
          _buildSectionHeader('Keperluan'),
          _buildTextField('keperluan_domisili', 'Digunakan untuk keperluan apa?', maxLines: 3),
          _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan_pemohon', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
          _buildSectionHeader('Lampiran Dokumen'),
          _buildFilePickerField('file_kk', 'File Kartu Keluarga'),
          _buildFilePickerField('file_ktp', 'File KTP'),
          _buildFilePickerField('file_surat_pengantar_rt_rw', 'Surat Pengantar RT/RW'),
        ];
      case 'sk_kelahiran':
        return [
           _buildSectionHeader('Data Anak'),
          _buildTextField('nama_anak', 'Nama Lengkap Anak'),
          _buildTextField('tempat_lahir_anak', 'Tempat Lahir Anak'),
          _buildTextField('tanggal_lahir_anak', 'Tanggal Lahir Anak (YYYY-MM-DD)'),
          _buildTextField('jenis_kelamin_anak', 'Jenis Kelamin Anak'),
          _buildTextField('agama_anak', 'Agama Anak'),
          _buildTextField('alamat_anak', 'Alamat'),
          _buildSectionHeader('Data Orang Tua'),
          _buildTextField('nama_ayah', 'Nama Ayah'),
          _buildTextField('nik_ayah', 'NIK Ayah', isRequired: false, keyboardType: TextInputType.number),
          _buildTextField('nama_ibu', 'Nama Ibu'),
          _buildTextField('nik_ibu', 'NIK Ibu', isRequired: false, keyboardType: TextInputType.number),
          _buildTextField('no_buku_nikah', 'Nomor Buku Nikah', isRequired: false),
          _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
          _buildSectionHeader('Lampiran Dokumen'),
          _buildFilePickerField('file_kk', 'File Kartu Keluarga'),
          _buildFilePickerField('file_ktp', 'File KTP (Ayah & Ibu jadi 1 file)'),
          _buildFilePickerField('surat_pengantar_rt_rw', 'Surat Pengantar RT/RW'),
          _buildFilePickerField('surat_nikah_orangtua', 'Surat Nikah Orang Tua'),
          _buildFilePickerField('surat_keterangan_kelahiran', 'Surat Kelahiran dari Bidan/RS'),
        ];
      case 'sk_perkawinan':
        return [
          _buildSectionHeader('Data Calon Mempelai Pria'),
          _buildTextField('nama_pria', 'Nama Lengkap Pria'),
          _buildTextField('nik_pria', 'NIK Pria', keyboardType: TextInputType.number),
          _buildTextField('tempat_lahir_pria', 'Tempat Lahir Pria'),
          _buildTextField('tanggal_lahir_pria', 'Tanggal Lahir Pria (YYYY-MM-DD)'),
          _buildTextField('alamat_pria', 'Alamat Lengkap Pria'),
           _buildSectionHeader('Data Calon Mempelai Wanita'),
          _buildTextField('nama_wanita', 'Nama Lengkap Wanita'),
          _buildTextField('nik_wanita', 'NIK Wanita', keyboardType: TextInputType.number),
          _buildTextField('tempat_lahir_wanita', 'Tempat Lahir Wanita'),
          _buildTextField('tanggal_lahir_wanita', 'Tanggal Lahir Wanita (YYYY-MM-DD)'),
          _buildTextField('alamat_wanita', 'Alamat Lengkap Wanita'),
           _buildSectionHeader('Detail Akad Nikah'),
           _buildTextField('tanggal_akad_nikah', 'Rencana Tanggal Akad (YYYY-MM-DD)'),
           _buildTextField('tempat_akad_nikah', 'Rencana Tempat Akad'),
           _buildTextField('pemohon_surat', 'Surat dibuat atas nama (pria/wanita)'),
           _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan_pemohon', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
           _buildSectionHeader('Lampiran Dokumen'),
           _buildFilePickerField('file_kk', 'File KK kedua calon (jadikan 1 file)'),
           _buildFilePickerField('file_ktp_mempelai', 'File KTP kedua calon (jadikan 1 file)'),
           _buildFilePickerField('surat_nikah_orang_tua', 'Surat Nikah Orang Tua', isRequired: false),
           _buildFilePickerField('kartu_imunisasi_catin', 'Kartu Imunisasi Catin', isRequired: false),
           _buildFilePickerField('sertifikat_elsimil', 'Sertifikat Elsimil', isRequired: false),
           _buildFilePickerField('akta_penceraian', 'Akta Perceraian (jika ada)', isRequired: false),
        ];
      case 'sk_tidak_mampu':
        return [
          _buildSectionHeader('Data Pemohon'),
          _buildTextField('nama_pemohon', 'Nama Lengkap Pemohon'),
          _buildTextField('nik_pemohon', 'NIK', keyboardType: TextInputType.number),
          _buildTextField('tempat_lahir_pemohon', 'Tempat Lahir'),
          _buildTextField('tanggal_lahir_pemohon', 'Tanggal Lahir (YYYY-MM-DD)'),
          _buildTextField('jenis_kelamin_pemohon', 'Jenis Kelamin'),
          _buildTextField('agama_pemohon', 'Agama', isRequired: false),
          _buildTextField('kewarganegaraan_pemohon', 'Kewarganegaraan'),
          _buildTextField('pekerjaan_pemohon', 'Pekerjaan'),
          _buildTextField('alamat_pemohon', 'Alamat Lengkap'),
           _buildSectionHeader('Data Pihak Terkait (Opsional)'),
          _buildTextField('nama_terkait', 'Nama Terkait (Anak/Orang Tua)', isRequired: false),
          _buildTextField('nik_terkait', 'NIK Terkait', isRequired: false, keyboardType: TextInputType.number),
          _buildTextField('tempat_lahir_terkait', 'Tempat Lahir Terkait', isRequired: false),
          _buildTextField('tanggal_lahir_terkait', 'Tanggal Lahir Terkait', isRequired: false),
          _buildTextField('jenis_kelamin_terkait', 'Jenis Kelamin Terkait', isRequired: false),
          _buildTextField('agama_terkait', 'Agama Terkait', isRequired: false),
          _buildTextField('kewarganegaraan_terkait', 'Kewarganegaraan Terkait', isRequired: false),
          _buildTextField('pekerjaan_atau_sekolah_terkait', 'Pekerjaan/Sekolah Terkait', isRequired: false),
          _buildTextField('alamat_terkait', 'Alamat Terkait', isRequired: false),
          _buildSectionHeader('Keperluan'),
          _buildTextField('keperluan_surat', 'Digunakan untuk keperluan apa?', maxLines: 3),
          _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan_pemohon', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
           _buildSectionHeader('Lampiran Dokumen'),
          _buildFilePickerField('file_kk', 'File Kartu Keluarga'),
          _buildFilePickerField('file_ktp', 'File KTP'),
          _buildFilePickerField('file_pendukung_lain', 'File Pendukung Lainnya', isRequired: false),
        ];
      case 'sk_usaha':
        return [
          _buildSectionHeader('Data Pemohon'),
          _buildTextField('nama_pemohon', 'Nama Lengkap Pemohon'),
          _buildTextField('nik_pemohon', 'NIK', keyboardType: TextInputType.number),
          _buildTextField('jenis_kelamin', 'Jenis Kelamin'),
          _buildTextField('tempat_lahir', 'Tempat Lahir'),
          _buildTextField('tanggal_lahir', 'Tanggal Lahir (YYYY-MM-DD)'),
          _buildTextField('warganegara_agama', 'Warganegara / Agama'),
          _buildTextField('pekerjaan', 'Pekerjaan'),
          _buildTextField('alamat_pemohon', 'Alamat Lengkap Pemohon'),
          _buildSectionHeader('Data Usaha'),
          _buildTextField('nama_usaha', 'Nama Usaha'),
          _buildTextField('alamat_usaha', 'Alamat Usaha'),
          _buildSectionHeader('Catatan Tambahan'),
          _buildTextField('catatan_pemohon', 'Catatan untuk petugas', isRequired: false, maxLines: 4),
          _buildSectionHeader('Lampiran Dokumen'),
          _buildFilePickerField('file_kk', 'File Kartu Keluarga'),
          _buildFilePickerField('file_ktp', 'File KTP'),
        ];
      default:
        return [const Text('Jenis surat tidak valid.')];
    }
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
    );
  }

  Widget _buildTextField(String fieldKey, String label, {bool isRequired = true, int maxLines = 1, TextInputType keyboardType = TextInputType.text, TextEditingController? controller}) {
    final fieldController = controller ?? (_controllers[fieldKey] ??= TextEditingController());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: fieldController,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Masukkan $label...',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          suffix: isRequired ? null : Text('(Opsional)', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
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

  Widget _buildFilePickerField(String key, String label, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ${isRequired ? '' : '(Opsional)'}',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
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
                          _selectedFiles[key]?.name ?? 'Pilih file (PDF, JPG, PNG)...',
                          style: GoogleFonts.poppins(color: _selectedFiles[key] != null ? Colors.black87 : Colors.grey.shade600),
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
      fields.add(
        Card(
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
                    Text("Data Ahli Waris ${i + 1}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    if (i > 0)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => setState(() => _ahliWarisControllers.removeAt(i)),
                      ),
                  ],
                ),
                const Divider(),
                _buildTextField('ahli_waris_${i}_nama', 'Nama Lengkap', controller: _ahliWarisControllers[i]['nama']!),
                _buildTextField('ahli_waris_${i}_nik', 'NIK', controller: _ahliWarisControllers[i]['nik']!, keyboardType: TextInputType.number),
                _buildTextField('ahli_waris_${i}_hubungan', 'Hubungan Keluarga', controller: _ahliWarisControllers[i]['hubungan']!),
                _buildTextField('ahli_waris_${i}_alamat', 'Alamat', controller: _ahliWarisControllers[i]['alamat']!),
              ],
            ),
          ),
        )
      );
    }
    return fields;
  }
}