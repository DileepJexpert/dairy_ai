#!/usr/bin/env python3
"""
Milterra Automated Courier Transit & Webhook Daemon
Simulates real-world DTDC / Delhivery courier lifecycle events:
  CONFIRMED -> PACKED -> DISPATCHED -> OUT_FOR_DELIVERY -> DELIVERED
Dispatches real HTTP webhooks to the Milterra backend.
"""

import argparse
import json
import random
import sys
import time
from datetime import datetime
import urllib.request
import urllib.error

MILESTONES = [
    {
        "status": "CONFIRMED",
        "title": "Order Verified & Allocated",
        "location": "Milterra Processing Corridors, Karnal",
        "remarks": "Order confirmed. Reserved from temperature-controlled storage and queued for packing.",
    },
    {
        "status": "PACKED",
        "title": "Sealed in Cold-Chain Container",
        "location": "Milterra Hub Packaging Unit, Karnal",
        "remarks": "Packed in certified tamper-evident insulated corrugated crate. Quality seal #TS-88402 applied.",
    },
    {
        "status": "DISPATCHED",
        "title": "Handed to DTDC Express Cargo",
        "location": "DTDC Logistics Hub, Karnal-Jaipur Line",
        "remarks": "Consignment scanned into linehaul container vehicle #RJ-14-GA-9021. Surface AWB allocated.",
    },
    {
        "status": "OUT_FOR_DELIVERY",
        "title": "Out for Delivery",
        "location": "Destination City Hub (Jaipur Sector 4)",
        "remarks": "Loaded onto last-mile delivery van. Delivery Executive: Rajesh Sharma (Ph: +91 98290 11223).",
    },
    {
        "status": "DELIVERED",
        "title": "Successfully Handed Over",
        "location": "Customer Delivery Address",
        "remarks": "Package delivered and verified via digital delivery PIN / consignee signature.",
    },
]


def send_webhook(api_base: str, order_id: str, carrier: str, awb: str, milestone: dict) -> bool:
    url = f"{api_base.rstrip('/')}/api/v1/marketplace/orders/webhooks/courier"
    payload = {
        "order_id": order_id,
        "carrier": carrier,
        "awb_number": awb,
        "status": milestone["status"],
        "location": milestone["location"],
        "remarks": milestone["remarks"],
        "timestamp": datetime.now().strftime("%d %b %Y, %I:%M %p"),
    }
    data_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data_bytes,
        headers={"Content-Type": "application/json", "User-Agent": "Milterra-Courier-Daemon/2.0"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            status_code = response.status
            resp_body = response.read().decode("utf-8")
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [OK {status_code}] Webhook accepted: Order {order_id} -> {milestone['status']}")
            return True
    except urllib.error.URLError as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] [OFFLINE] Backend at {url} unreachable ({e.reason}). Logged event locally: {milestone['status']}")
        return False
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] [ERROR] Webhook error: {e}")
        return False


def run_daemon(api_base: str, order_id: str, carrier: str, interval: int, once: bool):
    awb = f"DTDC-{abs(hash(order_id)) % 9000000 + 1000000}"
    print("=" * 70)
    print("  MILTERRA AUTOMATED LOGISTICS TRANSIT DAEMON")
    print(f"  Target Order  : {order_id}")
    print(f"  Logistics     : {carrier}")
    print(f"  AWB Airwaybill: {awb}")
    print(f"  Backend URL   : {api_base}")
    print(f"  Step Interval : {interval}s")
    print("=" * 70)

    for i, step in enumerate(MILESTONES):
        print(f"\n[Step {i+1}/{len(MILESTONES)}] Advancing order to \033[1m{step['status']}\033[0m")
        print(f"  Location : {step['location']}")
        print(f"  Remarks  : {step['remarks']}")

        send_webhook(api_base, order_id, carrier, awb, step)

        if once or i == len(MILESTONES) - 1:
            break

        print(f"  Sleeping {interval}s until next courier milestone...")
        time.sleep(interval)

    print(f"\n[DONE] Transit simulation completed for order: {order_id}")


def main():
    parser = argparse.ArgumentParser(description="Milterra Background Courier Transit Daemon")
    parser.add_argument("--api-url", default="http://127.0.0.1:8001", help="Milterra backend URL (default: http://127.0.0.1:8001)")
    parser.add_argument("--order-id", default="ORD-2026-8801", help="Target order ID (default: ORD-2026-8801)")
    parser.add_argument("--carrier", default="DTDC Express Surface", help="Carrier name (default: DTDC Express Surface)")
    parser.add_argument("--interval", type=int, default=12, help="Seconds between milestone updates (default: 12)")
    parser.add_argument("--once", action="store_true", help="Send only the first step and exit")

    args = parser.parse_args()
    try:
        run_daemon(args.api_url, args.order_id, args.carrier, args.interval, args.once)
    except KeyboardInterrupt:
        print("\n\033[93mTransit daemon stopped by user.\033[0m")


if __name__ == "__main__":
    main()
