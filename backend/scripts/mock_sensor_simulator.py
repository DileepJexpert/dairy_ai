#!/usr/bin/env python3
"""
Mock Sensor Simulator for DairyAI

Simulates ESP32 cattle collars sending sensor data via MQTT.
Supports two modes:
  1. MQTT mode (default) — publishes to MQTT broker like real hardware
  2. HTTP mode (--http) — posts directly to the REST API (no broker needed)

Usage:
  # MQTT mode (requires mosquitto running)
  python mock_sensor_simulator.py

  # HTTP mode (only needs the FastAPI server)
  python mock_sensor_simulator.py --http

  # Custom settings
  python mock_sensor_simulator.py --cattle 5 --interval 10 --duration 300

  # Simulate a sick cow (fever + high heart rate)
  python mock_sensor_simulator.py --scenario sick

  # Simulate low battery
  python mock_sensor_simulator.py --scenario low-battery

Scenarios:
  normal      — healthy cattle with normal vitals (default)
  sick        — one cow with fever (40-41.5C) and elevated heart rate
  low-battery — one collar running out of battery
  mixed       — combination of normal, sick, and low-battery cattle
"""

import argparse
import asyncio
import json
import logging
import math
import random
import sys
import time
import uuid
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("sensor_sim")

# ---------------------------------------------------------------------------
# Cattle profiles
# ---------------------------------------------------------------------------

DEFAULT_CATTLE_IDS = [
    "00000000-0000-0000-0000-000000000001",
    "00000000-0000-0000-0000-000000000002",
    "00000000-0000-0000-0000-000000000003",
]


class CattleProfile:
    """Simulates a single cattle's sensor collar."""

    def __init__(
        self,
        cattle_id: str,
        base_temp: float = 38.5,
        base_hr: int = 65,
        base_activity: float = 55.0,
        battery: int = 90,
        battery_drain: float = 0.0,
        sick: bool = False,
    ):
        self.cattle_id = cattle_id
        self.base_temp = base_temp
        self.base_hr = base_hr
        self.base_activity = base_activity
        self.battery = battery
        self.battery_drain = battery_drain
        self.sick = sick
        self._tick = 0

    def read(self) -> dict:
        """Generate one sensor reading with realistic variation."""
        self._tick += 1

        # Diurnal cycle: activity higher during day, lower at night
        hour = datetime.now().hour
        diurnal = math.sin((hour - 6) * math.pi / 12) * 10  # peaks at noon

        if self.sick:
            temp = round(self.base_temp + random.uniform(-0.2, 0.3), 1)
            hr = self.base_hr + random.randint(-3, 5)
            activity = max(5.0, self.base_activity + random.uniform(-5, 3))
        else:
            temp = round(self.base_temp + random.uniform(-0.3, 0.3), 1)
            hr = self.base_hr + random.randint(-5, 5)
            activity = round(
                max(0, min(100, self.base_activity + diurnal + random.uniform(-8, 8))),
                1,
            )

        # Battery drain
        if self.battery_drain > 0:
            self.battery = max(0, int(self.battery - self.battery_drain))

        return {
            "cattle_id": self.cattle_id,
            "temperature": max(35.0, min(42.0, temp)),
            "heart_rate": max(40, min(120, hr)),
            "activity_level": activity,
            "battery_pct": self.battery,
            "rssi": random.randint(-80, -30),
            "timestamp": int(time.time()),
            "firmware": "1.0.0-mock",
        }


def build_profiles(scenario: str, cattle_ids: list[str]) -> list[CattleProfile]:
    """Build cattle profiles based on scenario."""
    profiles = []

    if scenario == "normal":
        for cid in cattle_ids:
            profiles.append(CattleProfile(cattle_id=cid))

    elif scenario == "sick":
        # First cow is sick (fever + high HR)
        profiles.append(
            CattleProfile(
                cattle_id=cattle_ids[0],
                base_temp=40.5,
                base_hr=90,
                base_activity=20.0,
                sick=True,
            )
        )
        for cid in cattle_ids[1:]:
            profiles.append(CattleProfile(cattle_id=cid))

    elif scenario == "low-battery":
        profiles.append(
            CattleProfile(
                cattle_id=cattle_ids[0],
                battery=12,
                battery_drain=1.0,
            )
        )
        for cid in cattle_ids[1:]:
            profiles.append(CattleProfile(cattle_id=cid))

    elif scenario == "mixed":
        if len(cattle_ids) >= 1:
            profiles.append(
                CattleProfile(
                    cattle_id=cattle_ids[0],
                    base_temp=40.2,
                    base_hr=88,
                    base_activity=15.0,
                    sick=True,
                )
            )
        if len(cattle_ids) >= 2:
            profiles.append(
                CattleProfile(
                    cattle_id=cattle_ids[1],
                    battery=10,
                    battery_drain=0.5,
                )
            )
        for cid in cattle_ids[2:]:
            profiles.append(CattleProfile(cattle_id=cid))

    else:
        logger.error(f"Unknown scenario: {scenario}")
        sys.exit(1)

    return profiles


# ---------------------------------------------------------------------------
# MQTT publisher
# ---------------------------------------------------------------------------


async def run_mqtt(
    profiles: list[CattleProfile],
    broker_host: str,
    broker_port: int,
    interval: int,
    duration: int,
):
    """Publish sensor data over MQTT."""
    try:
        import paho.mqtt.client as mqtt
    except ImportError:
        logger.error("paho-mqtt not installed. Run: pip install paho-mqtt")
        sys.exit(1)

    client = mqtt.Client(client_id=f"mock-sim-{uuid.uuid4().hex[:6]}")

    connected = False

    def on_connect(c, userdata, flags, rc):
        nonlocal connected
        if rc == 0:
            connected = True
            logger.info(f"Connected to MQTT broker at {broker_host}:{broker_port}")
        else:
            logger.error(f"MQTT connection failed (rc={rc})")

    client.on_connect = on_connect
    try:
        client.connect(broker_host, broker_port, 60)
    except Exception as e:
        logger.error(f"Cannot connect to MQTT broker at {broker_host}:{broker_port}: {e}")
        logger.info("Is mosquitto running? Try: docker compose -f infra/docker-compose.yml up -d mosquitto")
        sys.exit(1)

    client.loop_start()
    await asyncio.sleep(1)

    if not connected:
        logger.error("Failed to connect to MQTT broker after 1s")
        client.loop_stop()
        sys.exit(1)

    start = time.time()
    readings_sent = 0

    logger.info(f"Simulating {len(profiles)} cattle, interval={interval}s, duration={duration}s")
    logger.info("-" * 60)

    try:
        while time.time() - start < duration:
            for profile in profiles:
                reading = profile.read()
                topic = f"dairy/cattle/{profile.cattle_id}/sensors"
                payload = json.dumps(reading)

                client.publish(topic, payload, qos=1)
                readings_sent += 1

                emoji = ""
                if reading["temperature"] > 39.5:
                    emoji = " [FEVER]"
                elif reading["heart_rate"] > 80:
                    emoji = " [HIGH HR]"
                elif reading["battery_pct"] < 15:
                    emoji = " [LOW BATT]"

                logger.info(
                    f"MQTT >> {profile.cattle_id[:8]}... | "
                    f"temp={reading['temperature']}C hr={reading['heart_rate']}bpm "
                    f"act={reading['activity_level']} batt={reading['battery_pct']}%{emoji}"
                )

            await asyncio.sleep(interval)
    except KeyboardInterrupt:
        pass
    finally:
        client.loop_stop()
        client.disconnect()
        elapsed = round(time.time() - start, 1)
        logger.info(f"\nDone. Sent {readings_sent} readings in {elapsed}s")


# ---------------------------------------------------------------------------
# HTTP publisher (no MQTT broker needed)
# ---------------------------------------------------------------------------


async def run_http(
    profiles: list[CattleProfile],
    base_url: str,
    auth_token: str,
    interval: int,
    duration: int,
):
    """Post sensor data via HTTP REST API."""
    try:
        import httpx
    except ImportError:
        logger.error("httpx not installed. Run: pip install httpx")
        sys.exit(1)

    headers = {"Authorization": f"Bearer {auth_token}"} if auth_token else {}

    async with httpx.AsyncClient(base_url=base_url, headers=headers, timeout=10) as client:
        start = time.time()
        readings_sent = 0

        logger.info(f"HTTP mode → {base_url}")
        logger.info(f"Simulating {len(profiles)} cattle, interval={interval}s, duration={duration}s")
        logger.info("-" * 60)

        try:
            while time.time() - start < duration:
                for profile in profiles:
                    reading = profile.read()
                    url = f"/api/v1/cattle/{profile.cattle_id}/sensor-data"
                    body = {
                        "temperature": reading["temperature"],
                        "heart_rate": reading["heart_rate"],
                        "activity_level": reading["activity_level"],
                        "battery_pct": reading["battery_pct"],
                        "rssi": reading["rssi"],
                    }

                    try:
                        resp = await client.post(url, json=body)
                        status = resp.status_code
                        data = resp.json() if resp.status_code < 500 else {}
                        alerts = data.get("data", {}).get("alerts", [])

                        alert_str = ""
                        if alerts:
                            alert_types = [a["alert_type"] for a in alerts]
                            alert_str = f" ALERTS: {alert_types}"

                        logger.info(
                            f"HTTP >> {profile.cattle_id[:8]}... | "
                            f"status={status} | temp={reading['temperature']}C "
                            f"hr={reading['heart_rate']}bpm batt={reading['battery_pct']}%{alert_str}"
                        )
                        readings_sent += 1
                    except httpx.RequestError as e:
                        logger.warning(f"HTTP request failed: {e}")

                await asyncio.sleep(interval)
        except KeyboardInterrupt:
            pass
        finally:
            elapsed = round(time.time() - start, 1)
            logger.info(f"\nDone. Sent {readings_sent} readings in {elapsed}s")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="DairyAI Mock Sensor Simulator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--http", action="store_true",
        help="Use HTTP REST API instead of MQTT",
    )
    parser.add_argument(
        "--broker", default="localhost",
        help="MQTT broker host (default: localhost)",
    )
    parser.add_argument(
        "--broker-port", type=int, default=1883,
        help="MQTT broker port (default: 1883)",
    )
    parser.add_argument(
        "--base-url", default="http://localhost:8000",
        help="Backend API base URL for HTTP mode (default: http://localhost:8000)",
    )
    parser.add_argument(
        "--token", default="",
        help="Auth Bearer token for HTTP mode",
    )
    parser.add_argument(
        "--cattle", type=int, default=3,
        help="Number of cattle to simulate (default: 3)",
    )
    parser.add_argument(
        "--cattle-ids", nargs="+", default=None,
        help="Specific cattle UUIDs to use (space-separated)",
    )
    parser.add_argument(
        "--interval", type=int, default=30,
        help="Seconds between readings (default: 30)",
    )
    parser.add_argument(
        "--duration", type=int, default=600,
        help="Total simulation duration in seconds (default: 600 = 10 min)",
    )
    parser.add_argument(
        "--scenario", default="normal",
        choices=["normal", "sick", "low-battery", "mixed"],
        help="Simulation scenario (default: normal)",
    )

    args = parser.parse_args()

    # Build cattle IDs
    if args.cattle_ids:
        cattle_ids = args.cattle_ids
    else:
        cattle_ids = DEFAULT_CATTLE_IDS[: args.cattle]
        # Extend if more cattle requested
        while len(cattle_ids) < args.cattle:
            cattle_ids.append(str(uuid.uuid4()))

    profiles = build_profiles(args.scenario, cattle_ids)

    logger.info("=" * 60)
    logger.info("DairyAI Mock Sensor Simulator")
    logger.info(f"  Scenario : {args.scenario}")
    logger.info(f"  Cattle   : {len(profiles)}")
    logger.info(f"  Interval : {args.interval}s")
    logger.info(f"  Duration : {args.duration}s")
    logger.info(f"  Mode     : {'HTTP' if args.http else 'MQTT'}")
    logger.info("=" * 60)

    if args.http:
        asyncio.run(
            run_http(profiles, args.base_url, args.token, args.interval, args.duration)
        )
    else:
        asyncio.run(
            run_mqtt(profiles, args.broker, args.broker_port, args.interval, args.duration)
        )


if __name__ == "__main__":
    main()
