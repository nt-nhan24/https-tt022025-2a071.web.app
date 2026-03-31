import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, fontFamily: 'Roboto'),
      home: const AuthCheck(),
    );
  }
}

// --- ĐIỀU HƯỚNG TỰ ĐỘNG ---
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.hasData) return const DashboardPage();
        return const HomePage();
      },
    );
  }
}

// --- MÀN HÌNH DASHBOARD (TÍCH HỢP BIỂU ĐỒ THẬT) ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        children: [
          _buildSidebar(context, user),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  width: double.infinity, color: Colors.white,
                  child: const Center(child: Text("Chọn một miền để thực hiện tự đánh giá", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('competency_metadata').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final competencies = snapshot.data!.docs;
                      return GridView.builder(
                        padding: const EdgeInsets.all(35),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 30, mainAxisSpacing: 30, childAspectRatio: 0.8),
                        itemCount: competencies.length,
                        itemBuilder: (context, index) {
                          var data = competencies[index];
                          return _buildCompetencyCard(context, data.id, data['Name']);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetencyCard(BuildContext context, String compId, String compName) {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        int currentScore = 0;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          
          // FIX: Xử lý logic lấy điểm khi có dấu chấm (1.1 -> 1 -> 1)
          List<String> parts = compId.split('.');
          if (userData['scores'] != null) {
            var scoresMap = userData['scores'];
            if (parts.length > 1) {
              // Lấy theo kiểu map lồng nhau: scores['1']['1']
              currentScore = scoresMap[parts[0]]?[parts[1]] ?? 0;
            } else {
              currentScore = scoresMap[compId] ?? 0;
            }
          }
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => QuizPage(compId: compId, compName: compName))
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.black12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFF), 
                    borderRadius: BorderRadius.vertical(top: Radius.circular(25))
                  ),
                  child: Text("$compId. $compName", 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), 
                    maxLines: 2),
                ),
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Vẽ biểu đồ vành khăn dựa trên score thật
                        SizedBox(
                          width: 180, 
                          height: 180, 
                          child: CustomPaint(painter: DonutChartPainter(score: currentScore)),
                        ),
                        
                        // Lấy Text từ level_metadata
                        FutureBuilder<DocumentSnapshot>(
                          // Tìm document ID kiểu "1.1_7"
                          future: FirebaseFirestore.instance
                              .collection('level_metadata')
                              .doc("${compId}_$currentScore")
                              .get(),
                          builder: (context, snap) {
                            String group = "Chưa làm";
                            String rank = "Bậc $currentScore";
                            
                            if (snap.hasData && snap.data!.exists) {
                              group = snap.data!['group_name'] ?? "Cơ bản";
                              rank = snap.data!['rank_name'] ?? "Bậc $currentScore";
                            }
                            
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(group, 
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                                Text(rank, 
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                              ],
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSidebar(BuildContext context, User? user) {
    return Container(
      width: 350, decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.black12, width: 2))),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String name = "Đang tải...";
          Map<String, dynamic> userData = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            userData = snapshot.data!.data() as Map<String, dynamic>;
            name = userData['Name'] ?? "Người dùng";
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(40), width: double.infinity, color: Colors.blue[50], child: Text("Xin chào,\n$name", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue))),
              const Padding(padding: EdgeInsets.all(20), child: Chip(label: Text("THÔNG TIN CÁ NHÂN", style: TextStyle(fontWeight: FontWeight.bold)))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _infoRow("Lớp:", userData['Class']),
                _infoRow("Niên khóa:", userData['Semester']),
                _infoRow("Ngày sinh:", userData['DateofBirth']),
              ])),
              const Spacer(),
              Padding(padding: const EdgeInsets.all(25), child: Column(children: [
                _sidebarBtn("Đăng xuất", () => FirebaseAuth.instance.signOut() .then((value) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthPage()))), Colors.white, Colors.red),

              ])),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String l, dynamic v) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Text("$l ${v ?? '...'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)));
  Widget _sidebarBtn(String t, VoidCallback p, Color bg, Color txt) => SizedBox(width: double.infinity, height: 60, child: OutlinedButton(onPressed: p, style: OutlinedButton.styleFrom(backgroundColor: bg, side: BorderSide(color: txt), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text(t, style: TextStyle(color: txt, fontSize: 18, fontWeight: FontWeight.bold))));
}

// --- MÀN HÌNH LÀM BÀI (CHỈ HIỆN THEO MIỀN ĐÃ CHỌN) ---
class QuizPage extends StatefulWidget {
  final String compId;
  final String compName;
  const QuizPage({super.key, required this.compId, required this.compName});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  Map<String, String> userAnswers = {};
  bool _isSaving = false;

  Future<void> _submitQuiz(Map<int, List<QueryDocumentSnapshot>> levelGroups) async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    
    int finalRank = 0;
    var sortedLevels = levelGroups.keys.toList()..sort();

    for (int lv in sortedLevels) {
      bool allYes = true;
      for (var q in levelGroups[lv]!) {
        if (userAnswers[q.id] != "Có") { allYes = false; break; }
      }
      if (allYes) finalRank = lv; else break;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
        'scores.${widget.compId}': finalRank,
        'isChap${widget.compId.replaceAll('.', '_')}Done': true,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: Text("ĐÁNH GIÁ MIỀN ${widget.compId}"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('question').where('competency_id', isEqualTo: widget.compId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          docs.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
          Map<int, List<QueryDocumentSnapshot>> levelGroups = {};
          for (var doc in docs) {
            int lv = doc['level'] ?? 1;
            if (!levelGroups.containsKey(lv)) levelGroups[lv] = [];
            levelGroups[lv]!.add(doc);
          }
          var sortedLevels = levelGroups.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _header(widget.compId),
              const SizedBox(height: 20),
              ...sortedLevels.map((lv) => _row(widget.compId, lv, levelGroups[lv]!)).toList(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 150),
                child: SizedBox(
                  height: 70,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _submitQuiz(levelGroups),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("HOÀN TẤT & LƯU KẾT QUẢ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String id) => FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('competency_metadata').doc(id).get(),
    builder: (context, snap) {
      String n = "...", d = "";
      if (snap.hasData && snap.data!.exists) { n = snap.data!['Name']; d = snap.data!['Description']; }
      return Container(
        padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(id, style: const TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.blueAccent)), const SizedBox(width: 25), Expanded(child: Text(n, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)))]),
          if (d.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 15), child: Text(d, style: const TextStyle(fontSize: 20, color: Colors.black54, fontStyle: FontStyle.italic))),
        ]),
      );
    }
  );

  Widget _row(String id, int lv, List<QueryDocumentSnapshot> lDocs) => IntrinsicHeight(
    child: Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          width: 320, padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.grey[50], border: const Border(right: BorderSide(color: Colors.black, width: 1.5))),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('level_metadata').doc("${id}_$lv").get(),
            builder: (context, snap) {
              String r = "Bậc $lv", t = "Đang tải...";
              if (snap.hasData && snap.data!.exists) { r = snap.data!['rank_name']; t = snap.data!['title']; }
              return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(r, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                const SizedBox(height: 12),
                Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]);
            },
          ),
        ),
        Expanded(child: Column(children: lDocs.map((q) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Câu ${q.id}: ${q['Question']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            Row(children: [_radio(q.id, "Có"), _radio(q.id, "Không")]),
          ]),
        )).toList())),
      ]),
    ),
  );

  Widget _radio(String id, String l) => Expanded(child: RadioListTile<String>(title: Text(l, style: const TextStyle(fontSize: 20)), value: l, groupValue: userAnswers[id], onChanged: (v) => setState(() => userAnswers[id] = v!)));
}

// --- BIỂU ĐỒ VÀNH KHĂN ---
class DonutChartPainter extends CustomPainter {
  final int score;
  DonutChartPainter({required this.score});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 35.0;
    const gap = 0.08; 
    final pBg = Paint()..color = Colors.grey[200]!..style = PaintingStyle.stroke..strokeWidth = strokeWidth;
    final pFill = Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = strokeWidth;
    for (int i = 0; i < 8; i++) {
      double sA = (i * (2 * math.pi / 8)) - (math.pi / 2) + (gap / 2);
      double sW = (2 * math.pi / 8) - gap;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 20), sA, sW, false, (i < score) ? pFill : pBg);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
// --- MÀN HÌNH THIẾT LẬP HỒ SƠ ---
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _classController = TextEditingController();
  final _semesterController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // 1. Lấy dữ liệu và trim khoảng trắng
  final name = _nameController.text.trim();
  final dob = _dobController.text.trim();
  final semester = _semesterController.text.trim();
  final userClass = _classController.text.trim();

  // 2. Kiểm tra bỏ trống
  if (name.isEmpty || dob.isEmpty || semester.isEmpty || userClass.isEmpty) {
    _showErrorDialog("Vui lòng nhập đầy đủ tất cả các trường thông tin.");
    return;
  }

  // 3. Kiểm tra format Ngày sinh (DDMMYYYY - 8 chữ số)
  final dobRegExp = RegExp(r'^\d{8}$');
  if (!dobRegExp.hasMatch(dob)) {
    _showErrorDialog("Ngày sinh không đúng định dạng. Vui lòng nhập 8 chữ số (VD: 15052007).");
    return;
  }

  // 4. Kiểm tra format Niên khóa (YYYY-YYYY - VD: 2023-2026)
  final semesterRegExp = RegExp(r'^\d{4}-\d{4}$');
  if (!semesterRegExp.hasMatch(semester)) {
    _showErrorDialog("Niên khóa không đúng định dạng. Vui lòng nhập theo mẫu: 2023-2026.");
    return;
  }

  // 5. Nếu mọi thứ OK, bắt đầu lưu
  setState(() => _isLoading = true);
  try {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'Name': name,
      'DateofBirth': dob,
      'Semester': semester,
      'Class': userClass,
      'email': user.email,
      'isDone': false,
      'scores': {}, // Khởi tạo Map điểm trống để tránh lỗi null sau này
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const DashboardPage())
      );
    }
  } catch (e) {
    _showErrorDialog("Lỗi hệ thống: ${e.toString()}");
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

// Hàm phụ để hiển thị Popup thông báo lỗi cho nhanh
void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Thông báo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Đồng ý"),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 500, padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.black, width: 2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Thiết lập hồ sơ", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              _field(_nameController, "Họ và Tên", Icons.person),
              const SizedBox(height: 15),
              _field(_dobController, "Ngày sinh (DDMMYYYY)", Icons.calendar_today),
              const SizedBox(height: 15),
              _field(_classController, "Lớp (12-8)", Icons.class_),
              const SizedBox(height: 15),
              _field(_semesterController, "Niên khóa (2023-2026)", Icons.school),
              const SizedBox(height: 30),
              _isLoading ? const CircularProgressIndicator() : SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: _saveProfile, child: const Text("Hoàn tất"))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String h, IconData i) => TextField(controller: c, decoration: InputDecoration(prefixIcon: Icon(i), hintText: h, filled: true, fillColor: const Color(0xFFF2F2F2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)));
}

// --- MÀN HÌNH TRANG CHỦ ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // 2. Hàm xử lý mở link PDF
  Future<void> _launchPDFUrl() async {
    final Uri url = Uri.parse('https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/01/02-bgddt.pdf');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Không thể mở liên kết: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            vertical: 40, 
            horizontal: size.width * 0.05
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: size.width * 0.05,
            runSpacing: 40,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: isMobile ? size.width : 550),
                child: Column(
                  crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        
                      ],
                    ),
                    SizedBox(height: size.height * 0.06),
                    Text(
                      "TỰ ĐÁNH GIÁ\nNĂNG LỰC SỐ",
                      textAlign: isMobile ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        fontSize: size.width * 0.035 + 5,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      "Dựa trên Thông tư số 02/2025/TT-BGDĐT của Bộ Giáo dục và Đào tạo: Quy định Khung năng lực số cho người học",
                      textAlign: isMobile ? TextAlign.center : TextAlign.left,
                      style: TextStyle(fontSize: size.width * 0.01 + 12, color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 40),
                    Wrap(
                      spacing: 15,
                      runSpacing: 15,
                      alignment: WrapAlignment.center,
                      children: [
                        _actionButton(context, "Tự đánh giá", true, size * 0.8),
                        // Nút về Thông tư 02
                        _actionButton(context, "Về Thông tư 02", false, size * 0.8, onLinkTap: _launchPDFUrl),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                width: isMobile ? size.width * 0.8 : size.width * 0.35 + 100,
                height: isMobile ? size.width * 0.8 : size.width * 0.35 + 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(size.width * 0.03),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 15))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size.width * 0.03),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset('assets/metadata/KHUNG_NL_SO.png', fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cập nhật widget nút bấm để nhận thêm hàm mở link
  Widget _actionButton(BuildContext context, String text, bool isPrimary, Size size, {VoidCallback? onLinkTap}) {
    return ElevatedButton(
      onPressed: () {
        if (isPrimary) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
        } else {
          // Nếu có hàm mở link thì chạy hàm đó
          if (onLinkTap != null) onLinkTap();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        side: const BorderSide(color: Colors.black, width: 2),
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.02 + 15, 
          vertical: size.width * 0.01 + 10
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
      child: Text(text, style: TextStyle(fontSize: size.width * 0.01 + 10, fontWeight: FontWeight.bold)),
    );
  }
}

// --- MÀN HÌNH ĐĂNG NHẬP / ĐĂNG KÝ ---
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLogin = true;

  Future<void> _handleAuth() async {
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(), password: _passwordController.text.trim());
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardPage()));
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(), password: _passwordController.text.trim());
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileSetupPage()));
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // BÊN TRÁI: FORM ĐĂNG NHẬP (40% chiều rộng)
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(60),
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 2))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isLogin ? "Đăng nhập" : "Đăng ký", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 50),
                  _buildTextField(_emailController, "Email", false),
                  const SizedBox(height: 20),
                  _buildTextField(_passwordController, "Password", true),
                  const SizedBox(height: 40),
                  _buildAuthButton(isLogin ? "Đăng nhập" : "Đăng ký", _handleAuth, true),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text("hoặc", style: TextStyle(fontSize: 18))),
                  _buildAuthButton(isLogin ? "Đăng ký tài khoản mới" : "Quay lại Đăng nhập", () => setState(() => isLogin = !isLogin), false),
                  // const SizedBox(height: 20),
                  // _buildAuthButton("Đăng ký với Google", () {}, false, isGoogle: true),
                ],
              ),
            ),
          ),
          // BÊN PHẢI: TIÊU CHÍ (60% chiều rộng)
          Expanded(
            flex: 6,
            child: Container(
              color: const Color(0xFFF9F9F9),
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Các tiêu chí đánh giá năng lực số", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildCriterion(1, "KHAI THÁC DỮ LIỆU VÀ THÔNG TIN", "Xác định được nhu cầu thông tin, tìm kiếm, truy xuất..."),
                        _buildCriterion(2, "GIAO TIẾP VÀ HỢP TÁC", "Tương tác, chia sẻ thông tin thông qua công nghệ số..."),
                        _buildCriterion(3, "SÁNG TẠO NỘI DUNG SỐ", "Tạo lập và biên tập nội dung số, cải tiến nội dung..."),
                        _buildCriterion(4, "AN TOÀN", "Bảo vệ thiết bị, nội dung số, dữ liệu cá nhân..."),
                        _buildCriterion(5, "GIẢI QUYẾT VẤN ĐỀ", "Xác định nhu cầu và các giải pháp công nghệ phù hợp..."),
                        _buildCriterion(6, "ỨNG DỤNG TRÍ TUỆ NHÂN TẠO", "Có kiến thức và kỹ năng cho phép người học hiểu, đánh giá AI..."),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isObscure) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF2F2F2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black)),
      ),
    );
  }

  Widget _buildAuthButton(String text, VoidCallback onPress, bool isPrimary, {bool isGoogle = false}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPress,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.black : Colors.white,
          foregroundColor: isPrimary ? Colors.white : Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCriterion(int num, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$num.", style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(desc, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- MÀN HÌNH LÀM BÀI QUIZ (GIỮ NGUYÊN LOGIC NHÓM LEVEL) ---
class GeneralQuizPage extends StatefulWidget {
  const GeneralQuizPage({super.key});
  @override State<GeneralQuizPage> createState() => _GeneralQuizPageState();
}

class _GeneralQuizPageState extends State<GeneralQuizPage> {
  Map<String, String> userAnswers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TỰ ĐÁNH GIÁ NĂNG LỰC SỐ"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('question').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          docs.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
          Map<String, List<QueryDocumentSnapshot>> groupedData = {};
          for (var doc in docs) {
            String cId = doc['competency_id'].toString();
            if (!groupedData.containsKey(cId)) groupedData[cId] = [];
            groupedData[cId]!.add(doc);
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: groupedData.entries.map((e) => _buildCompBlock(e.key, e.value)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildCompBlock(String compId, List<QueryDocumentSnapshot> questions) {
    Map<int, List<QueryDocumentSnapshot>> levelGroups = {};
    for (var q in questions) {
      int lv = q['level'] ?? 1;
      if (!levelGroups.containsKey(lv)) levelGroups[lv] = [];
      levelGroups[lv]!.add(q);
    }
    var sortedLevels = levelGroups.keys.toList()..sort();
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2)),
      child: Column(
        children: [
          _compHeader(compId),
          const Divider(thickness: 2),
          ...sortedLevels.map((lv) => _levelRow(compId, lv, levelGroups[lv]!)).toList(),
        ],
      ),
    );
  }

  Widget _compHeader(String id) => FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('competency_metadata').doc(id).get(),
    builder: (context, snap) {
      String n = "...", d = "";
      if (snap.hasData && snap.data!.exists) { n = snap.data!['Name']; d = snap.data!['Description']; }
      return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(id, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(width: 20),
          Expanded(child: Text(n, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        ]),
        if (d.isNotEmpty) Text(d, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey)),
      ]));
    }
  );

  Widget _levelRow(String id, int lv, List<QueryDocumentSnapshot> lDocs) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        width: 280, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.grey[50], border: const Border(right: BorderSide(color: Colors.black12))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Bậc $lv", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          const SizedBox(height: 10),
          const Text("Dựa trên trình độ cơ bản...", textAlign: TextAlign.center),
        ]),
      ),
      Expanded(child: Column(children: lDocs.map((q) => ListTile(title: Text("Câu ${q.id}: ${q['Question']}"), subtitle: Row(children: [_radio(q.id, "Có"), _radio(q.id, "Không")]))).toList())),
    ]),
  );

  Widget _radio(String id, String l) => Expanded(child: RadioListTile<String>(title: Text(l), value: l, groupValue: userAnswers[id], onChanged: (v) => setState(() => userAnswers[id] = v!)));
}