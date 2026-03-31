# 🚀 VN-Digital-Competency-Evaluator (TT02/2025)

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Status](https://img.shields.io/badge/Status-Live-success?style=for-the-badge)

Hệ thống tự đánh giá năng lực số dành cho người học tại Việt Nam, được phát triển bám sát theo **Thông tư số 02/2025/TT-BGDĐT** của Bộ Giáo dục và Đào tạo. Dự án hỗ trợ học sinh, sinh viên nhận diện trình độ số của bản thân thông qua 6 miền năng lực cốt lõi.

🔗 **Trải nghiệm trực tuyến:** [https://tt022025-2a071.web.app](https://tt022025-2a071.web.app)

---

## ✨ Tính năng chính

### 1. 🔐 Hệ thống xác thực & Hồ sơ
- Đăng ký/Đăng nhập bằng Email & Password.
- Tích hợp **Google Sign-In v7.x** (Singleton Pattern).
- Màn hình thiết lập hồ sơ (Họ tên, Ngày sinh, Niên khóa, Lớp) với hệ thống Validation chuẩn format.

### 2. 📊 Dashboard Trực quan
- Hiển thị kết quả dưới dạng **Biểu đồ vành khăn (Donut Chart)** chia 8 phần tương ứng với 8 Bậc trình độ.
- Tự động đồng bộ hóa dữ liệu từ Firestore để cập nhật trạng thái "Bậc" và "Nhóm trình độ" (Cơ bản - Trung cấp - Nâng cao - Chuyên sâu).

### 3. 📝 Logic Đánh giá Thông minh
- Tự động lọc bộ câu hỏi riêng biệt cho từng miền năng lực (1.1, 1.2, ...).
- **Scoring Logic:** Tính bậc dựa trên nguyên tắc "Bậc phá đảo" (Người dùng đạt Bậc $N$ khi và chỉ khi trả lời "Có" cho tất cả câu hỏi từ Bậc 1 đến Bậc $N$).
- Giao diện làm bài chia đôi (Side-by-side): Bên trái hiển thị mô tả Bậc trình độ từ metadata, bên phải là danh sách câu hỏi.

### 4. 🧠 Định hướng AI (Behavioral Analytics)
- Thu thập dữ liệu hành vi: Thời gian làm bài, số lần thay đổi đáp án.
- Cấu trúc Database nguyên tử (Atomic) sẵn sàng cho việc tích hợp **Gemini API** để phân tích tâm lý và xu hướng học tập trong tương lai.


## 🛠️ Công nghệ sử dụng

- **Framework:** Flutter Web (HTML Renderer).
- **Backend:** Firebase (Authentication, Cloud Firestore, Hosting).
- **UI/UX:** Custom Painter (vẽ biểu đồ), Responsive Layout (Wrap, Row/Column).
- **Database:** NoSQL (Firestore) với cấu trúc Map lồng nhau tối ưu hóa lượt đọc/ghi.

---

## 📁 Cấu trúc Database tiêu biểu (Firestore)

```json
users/{uid}
 {
   "Name": "Nguyễn Thanh Nhân",
   "scores": {
     "1.1": 7,
     "1.2": 0
   },
   "isChap1_1Done": true,
   "behavior_analytics": { ... }
 }
```

---

## 🚀 Cài đặt dự án

1. **Clone repository:**
   ```bash
   git clone [https://github.com/your-username/vn-digital-competency.git](https://github.com/your-username/vn-digital-competency.git)
   ```
2. **Cài đặt dependencies:**
   ```bash
   flutter pub get
   ```
3. **Cấu hình Firebase:** - Đảm bảo đã cài đặt FlutterFire CLI.
   - Chạy `flutterfire configure` để cập nhật `firebase_options.dart`.
4. **Build & Run:**
   ```bash
   flutter run -d chrome
   ```

---

## 👨‍💻 Tác giả

- **Nguyễn Thanh Nhân** - Sinh viên ngành Robotics & AI - Đại học HUTECH.
- **Dự án:** Nghiên cứu ứng dụng AI trong đánh giá năng lực số người học.
