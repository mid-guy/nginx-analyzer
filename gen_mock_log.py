import random
import datetime
import os

ips = ["192.168.1.10", "10.0.0.5", "172.16.0.8", "8.8.8.8", "1.1.1.1", "192.168.1.50"]
paths = ["/api/v1/users", "/", "/login", "/api/v1/products", "/favicon.ico", "/checkout"]
statuses = ["200", "200", "200", "200", "404", "500", "304", "403"]
agents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
    "curl/7.68.0",
    "PostmanRuntime/7.28.4"
]

NUM_LINES = 2_000_000
LINES_PER_FILE = 400_000  # ~47MB per file, safely under GitHub's 100MB limit
BASE_TIME = datetime.datetime(2026, 5, 5, 0, 0, 0)
BATCH_SIZE = 50_000
OUTPUT_DIR = "logs"

os.makedirs(OUTPUT_DIR, exist_ok=True)

file_index = 1
current_file_lines = 0
current_file = None

for i in range(NUM_LINES):
    if current_file_lines == 0:
        if current_file:
            current_file.close()
        path_out = os.path.join(OUTPUT_DIR, f"access_{file_index:03d}.log")
        current_file = open(path_out, "w")
        batch = []
        file_index += 1

    ip = random.choice(ips)
    path = random.choice(paths)
    status = random.choice(statuses)
    agent = random.choice(agents)
    offset = datetime.timedelta(seconds=random.randint(0, 86399))
    time_str = (BASE_TIME + offset).strftime("%d/%b/%Y:%H:%M:%S +0700")
    batch.append(f'{ip} - - [{time_str}] "GET {path} HTTP/1.1" {status} 1024 "-" "{agent}"\n')
    current_file_lines += 1

    if len(batch) == BATCH_SIZE:
        current_file.writelines(batch)
        batch.clear()

    if current_file_lines == LINES_PER_FILE:
        current_file.writelines(batch)
        batch.clear()
        current_file_lines = 0

if current_file:
    current_file.writelines(batch)
    current_file.close()

total_files = file_index - 1
print(f"Đã tạo xong {total_files} file log trong thư mục '{OUTPUT_DIR}/'")
print(f"  Mỗi file tối đa {LINES_PER_FILE:,} dòng (~47MB), tổng {NUM_LINES:,} dòng.")
