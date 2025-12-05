# main.py
import sys
import datetime as dt

def main():
    now = dt.datetime.now(dt.timezone.utc)
    msg = f"[{now}] Hello from Cloud Run Job!"
    print(msg)
    sys.stdout.flush()

if __name__ == "__main__":
    main()
