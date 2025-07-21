import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- PENTING: GANTI DENGAN PATH ASLI PROJECT ANDA ---
import '/core/config/app_config.dart';
// import 'package:silades_kumantan/services/auth_service.dart';

class FormPermohonanLainnyaPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final int? draftId;

  const FormPermohonanLainnyaPage({
    super.key,
    this.initialData,
    this.draftId,
  });

  @override
  State<FormPermohonanLainnyaPage> createState() =>
      _FormPermohonanLainnyaPageState();
}

class _FormPermohonanLainnyaPageState
    extends State<FormPermohonanLainnyaPage> {
  final _formKey = GlobalKey<FormState>();
  int? _currentDraftId;

  // State untuk menyimpan data profil user
  Map<String, dynamic>? _userProfile;

  // Controllers untuk data permohonan
  final _judulController = TextEditingController();
  final _keperluanController = TextEditingController();
  final _rincianController = TextEditingController();

  // Controllers untuk data pemohon (jika bukan diri sendiri)
  final _namaLainController = TextEditingController();
  final _nikLainController = TextEditingController();

  final List<File> _lampiranFiles = [];
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _isForSomeoneElse = false;

  @override
  void initState() {
    super.initState();
    _currentDraftId = widget.draftId;

    if (widget.initialData != null) {
      _populateFormFromDraft(widget.initialData!);
    } else {
      _fetchProfileData();
    }
  }
  
  void _populateFormFromDraft(Map<String, dynamic> data) {
    _judulController.text = data['judul_permohonan'] ?? '';
    _keperluanController.text = data['keperluan'] ?? '';
    _rincianController.text = data['rincian_pemohon'] ?? '';
    setState(() {
      _isLoadingProfile = false;
    });
  }

  @override
  void dispose() {
    _judulController.dispose();
    _keperluanController.dispose();
    _rincianController.dispose();
    _namaLainController.dispose();
    _nikLainController.dispose();
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
        // Simpan data profil ke state
        setState(() {
          _userProfile = jsonDecode(response.body);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat data profil: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _lampiranFiles.addAll(result.paths.map((path) => File(path!)));
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _lampiranFiles.removeAt(index);
    });
  }

  Future<void> _submitPermohonan() async {
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

    var request = http.MultipartRequest('POST',
        Uri.parse('${AppConfig.apiBaseUrl}/masyarakat/permohonan-lainnya'));
    
    request.headers.addAll(
        {'Accept': 'application/json', 'Authorization': 'Bearer $token'});

    request.fields['judul_permohonan'] = _judulController.text;
    request.fields['keperluan'] = _keperluanController.text;
    request.fields['rincian_pemohon'] = _rincianController.text;
    
    if (_currentDraftId != null) {
      request.fields['draft_id'] = _currentDraftId.toString();
    }
    
    // Kirim data pemohon lain jika switch aktif
    // CATATAN: Pastikan backend Anda siap menerima field opsional ini
    if (_isForSomeoneElse) {
      request.fields['nama_pemohon_lain'] = _namaLainController.text;
      request.fields['nik_pemohon_lain'] = _nikLainController.text;
    }

    for (var file in _lampiranFiles) {
      request.files.add(await http.MultipartFile.fromPath('lampiran[]', file.path));
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

    final Map<String, String> fields = {
      'judul_permohonan': _judulController.text,
      'keperluan': _keperluanController.text,
      'rincian_pemohon': _rincianController.text,
    };

    final Uri uri;
    final String method;
    final String draftEndpoint = '/masyarakat/draft/permohonan-lainnya';

    if (_currentDraftId != null) {
      uri = Uri.parse('${AppConfig.apiBaseUrl}$draftEndpoint/$_currentDraftId');
      method = 'PUT';
    } else {
      uri = Uri.parse('${AppConfig.apiBaseUrl}$draftEndpoint');
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
        title: Text('Form Permohonan Khusus', style: GoogleFonts.poppins()),
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
                  _buildPemohonSection(),
                  const SizedBox(height: 16),
                  _buildDetailSection(),
                  const SizedBox(height: 16),
                  _buildLampiranSection(),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _submitPermohonan,
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
    );
  }

  Widget _buildPemohonSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
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
            
            // Tampilkan data user jika tidak mengajukan untuk orang lain
            if (!_isForSomeoneElse && _userProfile != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(_userProfile?['nama_lengkap'] ?? 'Nama tidak tersedia'),
                  subtitle: Text('NIK: ${_userProfile?['nik'] ?? 'NIK tidak tersedia'}'),
                ),
              ),

            SwitchListTile(
              title: const Text('Ajukan untuk orang lain'),
              value: _isForSomeoneElse,
              onChanged: (value) {
                setState(() {
                  _isForSomeoneElse = value;
                  if (!_isForSomeoneElse) {
                    _namaLainController.clear();
                    _nikLainController.clear();
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_isForSomeoneElse) ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: _namaLainController,
                label: 'Nama Lengkap Pemohon',
                hint: 'Masukkan nama lengkap',
                isRequired: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nikLainController,
                label: 'NIK Pemohon',
                hint: 'Masukkan NIK',
                keyboardType: TextInputType.number,
                isRequired: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detail Permohonan',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _judulController,
              label: 'Judul Permohonan',
              hint: 'Cth: Surat Keterangan Kehilangan KTP',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _keperluanController,
              label: 'Keperluan Surat',
              hint: 'Cth: Untuk mengurus pembukaan rekening',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _rincianController,
              label: 'Rincian Lengkap',
              hint: 'Jelaskan secara rinci...',
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLampiranSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lampiran',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Format: JPG, PNG, PDF. Maks: 2MB per file',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            if (_lampiranFiles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lampiranFiles.length,
                itemBuilder: (context, index) {
                  final file = _lampiranFiles[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(file.path.split('/').last,
                          overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeFile(index),
                      ),
                    ),
                  );
                },
              ),
            Center(
              child: OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Tambah File'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required String hint,
      bool isRequired = true,
      int maxLines = 1,
      TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
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
    );
  }
}
