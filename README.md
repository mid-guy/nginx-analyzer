# Nginx Log Analyser

Bash script phân tích file `access.log` của Nginx, xuất báo cáo thống kê nhanh trực tiếp trên server — không cần cài thêm runtime hay thư viện ngoài.

## Tính năng

| Mục | Mô tả |
|-----|-------|
| Top 5 IP Addresses | Các IP có số lượng request nhiều nhất |
| Top 5 Requested Paths | Các endpoint/URL được gọi nhiều nhất |
| Top 5 HTTP Status Codes | Phân phối mã trạng thái (200, 404, 500...) |
| Top 5 User Agents | Các loại client/browser phổ biến nhất |

## Yêu cầu

- Bash >= 4
- `awk`, `sort`, `uniq`, `head` — có sẵn trên mọi hệ thống Unix/Linux/macOS

## Cài đặt

```bash
git clone <repo-url>
cd nginx-log-analyser
chmod +x nginx-analyzer.sh
```

## Sử dụng

```bash
./nginx-analyzer.sh <đường-dẫn-file-log>
```

**Ví dụ:**

```bash
# Log mặc định của Nginx
./nginx-analyzer.sh /var/log/nginx/access.log

# Log của một virtual host cụ thể
./nginx-analyzer.sh /var/log/nginx/mysite.access.log
```

## Ví dụ Output

```
=========================================
📊 NGINX LOG ANALYZER REPORT
📁 File : /var/log/nginx/access.log
📅 Date : 2026-05-05 10:30:00
=========================================

🔥 Top 5 IP Addresses (nhiều request nhất):
   192.168.1.10       : 4520 requests
   10.0.0.5           : 3105 requests
   172.16.0.8         : 1250 requests
   192.168.1.50       : 890 requests
   8.8.8.8            : 420 requests

🌐 Top 5 Requested Paths (endpoint phổ biến nhất):
   /api/v1/users              : 5120 requests
   /                          : 3005 requests
   /api/v1/products           : 1540 requests
   /favicon.ico               : 890 requests
   /login                     : 650 requests

🛑 Top 5 HTTP Status Codes (phân phối mã trạng thái):
   HTTP 200    : 8500 requests
   HTTP 404    : 1200 requests
   HTTP 304    : 800 requests
   HTTP 500    : 45 requests
   HTTP 403    : 12 requests

🕵️  Top 5 User Agents (client phổ biến nhất):
      6500 reqs : Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...
      2100 reqs : Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36...
       800 reqs : curl/7.68.0
       150 reqs : python-requests/2.28.0
        30 reqs : Googlebot/2.1

=========================================
✅ Hoàn tất phân tích.
```

## Định dạng log được hỗ trợ

Script hoạt động với **Nginx Combined Log Format** — định dạng mặc định:

```
$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"
```

Ví dụ một dòng log thực tế:

```
192.168.1.1 - - [01/May/2026:10:00:00 +0700] "GET /api/v1/users HTTP/1.1" 200 512 "-" "Mozilla/5.0 ..."
│col 1│                                        │col 7│                     │c9│       │      col 6 (UA)     │
```

## Giải thích kỹ thuật

### Tại sao dùng `awk | sort | uniq -c | sort -rn | head`?

Đây là pipeline chuẩn để đếm và xếp hạng trên Unix:

```
awk '{print $N}'   →  trích cột cần phân tích
sort               →  gom các giá trị giống nhau liền kề (uniq -c yêu cầu điều này)
uniq -c            →  đếm số lần xuất hiện, thêm số đếm vào đầu dòng
sort -rn           →  sắp xếp ngược theo số (nhiều nhất lên đầu)
head -n 5          →  lấy 5 kết quả đầu
```

`awk` được viết bằng C, xử lý stream từng dòng nên tiêu thụ RAM rất thấp — phù hợp với file log hàng trăm MB mà không cần load toàn bộ vào bộ nhớ.

### Tại sao dùng `-F'"'` cho User Agent?

User Agent là chuỗi nhiều từ có khoảng trắng, không thể tách bằng `$N`. Dùng dấu ngoặc kép làm delimiter, User Agent luôn nằm ở field thứ 6 trong log combined format.

### Xử lý file log rất lớn (GB+)

Với file log hàng chục GB, lệnh `sort` sẽ tạo file tạm trên disk, làm nghẽn I/O. Các giải pháp scale lớn hơn:

- **Golang**: đọc file theo chunk với goroutines, dùng `map` để đếm trong RAM
- **Streaming**: đẩy log vào Kafka/Kinesis và xử lý bằng Flink/Spark
- **Log aggregation**: Loki + Grafana, ELK Stack, hoặc Datadog

Tuy nhiên, với mục đích **quick-triage trực tiếp trên node**, Bash pipeline này là lựa chọn nhanh và đáng tin cậy nhất.

## Cấu trúc project

```
nginx-log-analyser/
├── nginx-analyzer.sh   # Script chính
└── README.md           # Tài liệu này
```
