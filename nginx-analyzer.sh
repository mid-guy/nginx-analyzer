#!/usr/bin/env bash

# ==============================================================================
# Script   : nginx-analyzer.sh
# Mục đích : Phân tích file access.log của Nginx và xuất báo cáo thống kê.
#            Báo cáo gồm 4 mục: Top IP, Top Path, Top Status Code, Top User Agent.
#
# Cú pháp  : ./nginx-analyzer.sh <đường-dẫn-file-log>
# Ví dụ    : ./nginx-analyzer.sh /var/log/nginx/access.log
#
# Yêu cầu  : bash >= 4, awk, sort, uniq, head (có sẵn trên mọi hệ thống Unix/Linux)
#
# Định dạng log Nginx mặc định (combined):
#   $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent
#   "$http_referer" "$http_user_agent"
#
# Ví dụ một dòng log thực tế:
#   192.168.1.1 - - [01/May/2026:10:00:00 +0700] "GET /api/v1/users HTTP/1.1"
#   200 512 "-" "Mozilla/5.0 ..."
#   └─ cột 1   └─ cột 7 (path)                    └─ cột 9 (status)
# ==============================================================================

# --- Tùy chọn an toàn ---
# set -e  : Thoát ngay nếu bất kỳ lệnh nào trả về exit code khác 0.
#           Ngăn script tiếp tục chạy khi có lỗi không mong muốn.
# set -u  : Báo lỗi nếu dùng biến chưa được khai báo (phòng tránh lỗi typo).
# set -o pipefail : Pipeline thất bại nếu BẤT KỲ lệnh nào trong pipe thất bại,
#                   không chỉ lệnh cuối cùng. Quan trọng vì script dùng nhiều pipe.
set -euo pipefail

# ==============================================================================
# SPINNER
# ==============================================================================

spinner() {
    local pid=$1
    local label=$2
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        local frame="${frames:$((i % ${#frames})):1}"
        printf "\r  %s  %s..." "$frame" "$label"
        sleep 0.1
        ((i++)) || true
    done
    printf "\r  ✔  %-40s\n" "$label"
}

run_section() {
    local label=$1
    shift
    ("$@") &
    local pid=$!
    spinner "$pid" "$label"
    wait "$pid"
}

# ==============================================================================
# PHẦN 1: XỬ LÝ THAM SỐ ĐẦU VÀO
# ==============================================================================

# $1 là tham số dòng lệnh đầu tiên — đường dẫn tới file log.
# Dùng ${1:-} thay vì $1 để tránh lỗi "unbound variable" khi không có tham số
# (kết hợp với set -u ở trên).
LOG_FILE="${1:-}"

# Kiểm tra xem người dùng có truyền tham số vào không.
# -z kiểm tra chuỗi rỗng (zero-length).
if [[ -z "$LOG_FILE" ]]; then
    echo "Lỗi: Thiếu đường dẫn file log." >&2
    echo "Sử dụng: $0 <path-to-access.log>" >&2
    exit 1
fi

# Kiểm tra file tồn tại và là file thông thường (không phải thư mục hay symlink hỏng).
# -f trả về true nếu đường dẫn tồn tại và là regular file.
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Lỗi: Không tìm thấy file '$LOG_FILE'." >&2
    exit 1
fi

# ==============================================================================
# PHẦN 2: IN HEADER BÁO CÁO
# ==============================================================================

echo "========================================="
echo "📊 NGINX LOG ANALYZER REPORT"
echo "📁 File : $LOG_FILE"
echo "📅 Date : $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

# ==============================================================================
# PHẦN 3: TOP 5 IP ADDRESS
#
# Pipeline giải thích:
#   awk '{print $1}'     — In ra cột 1 của mỗi dòng (địa chỉ IP khách hàng).
#   sort                 — Sắp xếp danh sách IP để các IP giống nhau nằm liền nhau.
#                          uniq -c yêu cầu input phải được sort trước.
#   uniq -c              — Đếm số lần xuất hiện liên tiếp, thêm số đếm vào đầu dòng.
#                          Kết quả: "   4520 192.168.1.10"
#   sort -rn             — Sắp xếp ngược (r = reverse, n = numeric) theo số đếm,
#                          IP nhiều request nhất lên đầu.
#   head -n 5            — Chỉ lấy 5 dòng đầu tiên.
#   awk '{printf ...}'   — Định dạng output cho dễ đọc:
#                          $2 = địa chỉ IP, $1 = số lượng request.
# ==============================================================================

echo "🔥 Top 5 IP Addresses (nhiều request nhất):"
run_section "Đang phân tích IP..." \
    bash -c "awk '{print \$1}' \"$LOG_FILE\" | sort | uniq -c | sort -rn | head -n 5 | awk '{printf \"   %-18s : %s requests\n\", \$2, \$1}'"
echo ""

# ==============================================================================
# PHẦN 4: TOP 5 REQUESTED PATHS (ENDPOINT)
#
# Cột 7 trong log format mặc định chứa đường dẫn HTTP (path/endpoint).
# Ví dụ dòng log: ... "GET /api/v1/users HTTP/1.1" ...
#   → Sau khi tách theo khoảng trắng: cột 6 = "GET, cột 7 = /api/v1/users, cột 8 = HTTP/1.1"
#   (dấu ngoặc kép đầu dòng request được tính là một phần của cột 6)
#
# Pipeline tương tự phần 3, chỉ thay cột in ra từ $1 → $7.
# ==============================================================================

echo "🌐 Top 5 Requested Paths (endpoint phổ biến nhất):"
run_section "Đang phân tích Path..." \
    bash -c "awk '{print \$7}' \"$LOG_FILE\" | sort | uniq -c | sort -rn | head -n 5 | awk '{printf \"   %-30s : %s requests\n\", \$2, \$1}'"
echo ""

# ==============================================================================
# PHẦN 5: TOP 5 HTTP STATUS CODES
#
# Cột 9 chứa HTTP status code (200, 404, 500, v.v.).
# Ví dụ: ... "GET /api/v1/users HTTP/1.1" 200 512 ...
#                                          └── cột 9
#
# Cách đếm tương tự, kết quả cho biết phân phối trạng thái HTTP của server,
# giúp phát hiện nhanh tỉ lệ lỗi 4xx/5xx bất thường.
# ==============================================================================

echo "🛑 Top 5 HTTP Status Codes (phân phối mã trạng thái):"
run_section "Đang phân tích Status Code..." \
    bash -c "awk '{print \$9}' \"$LOG_FILE\" | sort | uniq -c | sort -rn | head -n 5 | awk '{printf \"   HTTP %-6s : %s requests\n\", \$2, \$1}'"
echo ""

# ==============================================================================
# PHẦN 6: TOP 5 USER AGENTS
#
# User Agent là chuỗi nằm trong cặp dấu ngoặc kép cuối cùng của mỗi dòng log.
# Không thể dùng tách theo khoảng trắng vì User Agent chứa nhiều từ có khoảng trắng.
#
# Giải pháp: dùng -F'"' để tách theo dấu ngoặc kép (") làm delimiter.
# Sau khi tách, các "cột" (field) sẽ là:
#   $1 = phần trước dấu " đầu tiên  (IP, thời gian, ...)
#   $2 = nội dung request            "GET /path HTTP/1.1"
#   $3 = khoảng giữa                 (status, bytes, ...)
#   $4 = referer                     "https://example.com"
#   $5 = khoảng giữa
#   $6 = user agent                  "Mozilla/5.0 ..."
#
# substr($0, index($0,$2)) trong lệnh awk cuối: giữ nguyên phần còn lại của dòng
# sau khi số đếm ($1) kết thúc, tránh cắt mất phần cuối của chuỗi user agent dài.
# ==============================================================================

echo "🕵️  Top 5 User Agents (client phổ biến nhất):"
run_section "Đang phân tích User Agent..." \
    bash -c "awk -F'\"' '{print \$6}' \"$LOG_FILE\" | sort | uniq -c | sort -rn | head -n 5 | awk '{printf \"   %7s reqs : %s\n\", \$1, substr(\$0, index(\$0,\$2))}'"
echo ""

# ==============================================================================
# PHẦN 7: KẾT THÚC
# ==============================================================================

echo "========================================="
echo "✅ Hoàn tất phân tích."
