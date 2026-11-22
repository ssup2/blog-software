import sys, time, torch
dur = float(sys.argv[1])
a = torch.randn(2048, 2048, device="cuda"); b = torch.randn(2048, 2048, device="cuda")
start = time.time(); last = start; n = 0
while time.time() - start < dur:
    c = a @ b; torch.cuda.synchronize(); n += 1
    now = time.time()
    if now - last >= 5:
        print(f"{time.strftime('%H:%M:%S')} {n / (now - last):.0f} matmul/s", flush=True)
        last = now; n = 0
