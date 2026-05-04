import random
import datetime

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
BASE_TIME = datetime.datetime(2026, 5, 5, 0, 0, 0)
BATCH_SIZE = 50_000

with open("custom_access.log", "w") as f:
    batch = []
    for i in range(NUM_LINES):
        ip = random.choice(ips)
        path = random.choice(paths)
        status = random.choice(statuses)
        agent = random.choice(agents)
        offset = datetime.timedelta(seconds=random.randint(0, 86399))
        time_str = (BASE_TIME + offset).strftime("%d/%b/%Y:%H:%M:%S +0700")
        batch.append(f'{ip} - - [{time_str}] "GET {path} HTTP/1.1" {status} 1024 "-" "{agent}"\n')
        if len(batch) == BATCH_SIZE:
            f.writelines(batch)
            batch.clear()
    if batch:
        f.writelines(batch)

print("Đã tạo xong file custom_access.log")
