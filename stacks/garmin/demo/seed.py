"""Write one year of INVENTED Garmin-like data into a demo InfluxDB 1.x.

Every value here comes from a random generator with a fixed seed: no real
person, watch or place is behind it. GPS points circle around latitude 0,
longitude 0 ("Null Island", in the Gulf of Guinea), which is obviously fake.

It writes the measurements, fields and tags that the Garmin dashboard
(stacks/garmin/dashboards/garmin-stats.json) actually queries, with the same
names the garmin-grafana fetcher uses, so every panel can be checked without
a Garmin account.

Standard library only. Talks only to the InfluxDB URL given (loopback).

    python3 -I seed.py --url http://127.0.0.1:18086 --days 365 --bootstrap

Environment (from .env): INFLUXDB_ADMIN_PASSWORD, INFLUXDB_WRITE_PASSWORD,
INFLUXDB_READ_PASSWORD. With --bootstrap it first creates (on an empty, demo
InfluxDB without users) the admin, the database and the writer/reader
accounts, exactly as the real module's InfluxDB does at its first start.
"""
import argparse
import base64
import math
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DB = "GarminStats"
TAGS = {"Device": "DemoWatch", "Database_Name": DB}
SEED = 20261126
DAY = 86400


# ----------------------------------------------------------------- InfluxDB
class Influx:
    def __init__(self, url, user=None, password=None):
        self.url = url.rstrip("/")
        self.auth = None
        if user:
            token = base64.b64encode(f"{user}:{password}".encode()).decode()
            self.auth = f"Basic {token}"

    def _request(self, path, params=None, data=None, method="GET"):
        query = "?" + urllib.parse.urlencode(params) if params else ""
        req = urllib.request.Request(self.url + path + query, data=data, method=method)
        if self.auth:
            req.add_header("Authorization", self.auth)
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.read()

    def query(self, q, method="POST"):
        if method == "POST":
            return self._request("/query", data=urllib.parse.urlencode({"q": q}).encode(), method="POST")
        return self._request("/query", params={"q": q})

    def write(self, lines):
        body = ("\n".join(lines) + "\n").encode()
        self._request("/write", params={"db": DB, "precision": "s"}, data=body, method="POST")


def ping(url, tries=60):
    for _ in range(tries):
        try:
            urllib.request.urlopen(url.rstrip("/") + "/ping", timeout=2)
            return True
        except (urllib.error.URLError, OSError):
            time.sleep(1)
    return False


def bootstrap(url, admin_pw, write_pw, read_pw):
    """Create admin, database and the two service accounts on an empty demo DB."""
    for name, value in (("admin", admin_pw), ("writer", write_pw), ("reader", read_pw)):
        if not value or "'" in value:
            raise SystemExit(f"missing or invalid password for {name} (run scripts/init-env.sh)")
    # With authentication on and no users yet, InfluxDB 1.x accepts exactly
    # one unauthenticated query: creating the first admin.
    Influx(url).query(f"CREATE USER admin WITH PASSWORD '{admin_pw}' WITH ALL PRIVILEGES")
    admin = Influx(url, "admin", admin_pw)
    for q in (
        f"CREATE DATABASE {DB}",
        f"CREATE USER garmin_writer WITH PASSWORD '{write_pw}'",
        f"GRANT WRITE ON {DB} TO garmin_writer",
        f"CREATE USER garmin_reader WITH PASSWORD '{read_pw}'",
        f"GRANT READ ON {DB} TO garmin_reader",
    ):
        admin.query(q)


# --------------------------------------------------------------- line format
def escape_tag(value):
    return str(value).replace("\\", "\\\\").replace(",", "\\,").replace("=", "\\=").replace(" ", "\\ ")


def field(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return f"{value}i"
    if isinstance(value, float):
        return repr(round(value, 4))
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def line(measurement, ts, fields, extra_tags=None):
    tags = dict(TAGS)
    if extra_tags:
        tags.update(extra_tags)
    tag_part = ",".join(f"{escape_tag(k)}={escape_tag(v)}" for k, v in sorted(tags.items()))
    field_part = ",".join(f"{k}={field(v)}" for k, v in fields.items() if v is not None)
    return f"{measurement},{tag_part} {field_part} {int(ts)}"


# ---------------------------------------------------------------- generators
def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def generate(rng, start, end):
    """Yield line-protocol strings, roughly in time order, for [start, end)."""
    vo2 = 46.0
    weight = 72.0
    day = start - (start % DAY)
    while day < end:
        d = (day - start) // DAY
        season = math.sin(2 * math.pi * d / 365.0)
        bedtime = day - 3600 * (1.5 + rng.random())           # ~22:00-23:00 the evening before
        wake = day + 3600 * (6.2 + rng.random() * 1.3)         # ~06:10-07:30
        rest_hr = round(52 + 3 * season + rng.gauss(0, 1.5))
        active_day = rng.random() < 0.45
        steps_goal_factor = 1.3 if active_day else 0.8

        # --- sleep (stages every 2 min, HRV every 5 min) -------------------
        deep = light = rem = awake = 0
        t = int(bedtime)
        while t < wake:
            phase = ((t - bedtime) / 5400.0) % 1.0             # 90-minute cycles
            if rng.random() < 0.03:
                stage = 3                                      # awake
            elif phase < 0.25:
                stage = 0                                      # deep
            elif phase < 0.75:
                stage = 1                                      # light
            else:
                stage = 2                                      # REM
            deep += 120 * (stage == 0); light += 120 * (stage == 1)
            rem += 120 * (stage == 2); awake += 120 * (stage == 3)
            if t >= start:
                yield line("SleepIntraday", t, {"SleepStageLevel": float(stage)})
                yield line("SleepIntraday", t, {
                    "SleepMovementActivityLevel": round(abs(rng.gauss(0.2 if stage != 3 else 1.5, 0.3)), 2),
                    "heartRate": float(rest_hr - 2 + rng.randint(0, 6)),
                    "spo2Reading": float(clamp(round(rng.gauss(95, 1.2)), 88, 100)),
                })
                if (t // 120) % 3 == 0:
                    yield line("HRV_Intraday", t, {"hrvValue": float(clamp(round(rng.gauss(55 - 4 * season, 9)), 20, 120))})
            t += 120
        sleep_total = deep + light + rem
        if wake >= start:
            yield line("SleepSummary", wake, {
                "sleepTimeSeconds": sleep_total, "deepSleepSeconds": deep, "lightSleepSeconds": light,
                "remSleepSeconds": rem, "awakeSleepSeconds": awake,
                "averageSpO2Value": float(round(rng.gauss(95, 0.8), 1)),
                "avgSleepStress": float(round(abs(rng.gauss(14, 5)), 1)),
                "sleepScore": int(clamp(round(55 + sleep_total / 900 + rng.gauss(0, 5)), 30, 100)),
            })

        # --- intraday during the waking day --------------------------------
        total_steps = 0
        bb = clamp(int(60 + sleep_total / 900), 40, 100)
        high_stress = medium_stress = low_stress = rest_stress = 0
        hr_min, hr_max = 200, 0
        for minute in range(0, 1440, 2):
            t = day + minute * 60
            if t < start or t >= end:
                continue
            awake_now = wake <= t < day + 22 * 3600
            hour = minute / 60.0
            if awake_now:
                base = rest_hr + 18 + 8 * math.sin(math.pi * (hour - 6) / 16)
                if active_day and 18 <= hour < 19:
                    base += 45                                 # evening workout
                hr = clamp(round(rng.gauss(base, 5)), rest_hr - 3, 185)
            else:
                hr = clamp(round(rng.gauss(rest_hr + 2, 2)), rest_hr - 3, 80)
            hr_min, hr_max = min(hr_min, hr), max(hr_max, hr)
            yield line("HeartRateIntraday", t, {"HeartRate": float(hr)})
            if minute % 4 == 0:
                stress = clamp(round(rng.gauss(32 if awake_now else 12, 14)), 0, 100) if awake_now else -1
                if stress >= 0:
                    if stress > 75: high_stress += 240
                    elif stress > 50: medium_stress += 240
                    elif stress > 25: low_stress += 240
                    else: rest_stress += 240
                yield line("StressIntraday", t, {"stressLevel": float(stress)})
                bb = clamp(bb + (-0.35 if awake_now else 0.6) + rng.gauss(0, 0.2), 5, 100)
                yield line("BodyBatteryIntraday", t, {"BodyBatteryLevel": float(round(bb))})
            if minute % 10 == 0:
                yield line("BreathingRateIntraday", t, {"BreathingRate": float(round(rng.gauss(15 if awake_now else 13, 1.2), 1))})
            if minute % 15 == 0:
                if awake_now:
                    s = max(0, int(rng.gauss(320 * steps_goal_factor, 220)))
                    if active_day and 18 <= hour < 19:
                        s += 1800
                else:
                    s = 0
                total_steps += s
                yield line("StepsIntraday", t, {"StepsCount": s})

        # --- daily stats (written at the end of the day) -------------------
        t_daily = day + DAY - 60
        if start <= t_daily < end:
            active_kcal = int(total_steps * 0.045 + (450 if active_day else 0))
            yield line("DailyStats", t_daily, {
                "totalSteps": total_steps, "totalDistanceMeters": int(total_steps * 0.78),
                "activeKilocalories": active_kcal, "bmrKilocalories": 1690,
                "restingHeartRate": int(rest_hr), "minHeartRate": int(hr_min), "maxHeartRate": int(hr_max),
                "averageSpo2": float(round(rng.gauss(95.5, 0.8), 1)),
                "highStressDuration": high_stress, "mediumStressDuration": medium_stress,
                "lowStressDuration": low_stress, "restStressDuration": rest_stress,
                "uncategorizedStressDuration": int(rng.randint(600, 3600)),
                "sedentarySeconds": int(DAY - sleep_total - 3600 * (2.5 if active_day else 1.2)),
                "activeSeconds": int(3600 * (2.5 if active_day else 1.2)),
                "highlyActiveSeconds": int(3600 * (1.0 if active_day else 0.2)),
                "sleepingSeconds": sleep_total,
                "moderateIntensityMinutes": int(rng.randint(10, 40)),
                "vigorousIntensityMinutes": int(rng.randint(30, 60) if active_day else rng.randint(0, 10)),
                "bodyBatteryHighestValue": int(clamp(60 + sleep_total / 900, 40, 100)),
                "bodyBatteryLowestValue": int(clamp(bb, 5, 60)),
                "bodyBatteryChargedValue": int(rng.randint(30, 70)),
                "bodyBatteryDrainedValue": int(rng.randint(40, 80)),
            })

        # --- one workout on active days -------------------------------------
        a_start = int(day + 18 * 3600 + rng.randint(0, 600))
        if active_day and start <= a_start < end:
            kind = rng.choice(["running", "running", "cycling", "walking"])
            duration = rng.randint(1800, 3600)
            speed = {"running": 3.0, "cycling": 7.0, "walking": 1.4}[kind] * (0.9 + 0.2 * rng.random())
            selector = time.strftime("%Y%m%dT%H%M%SUTC-", time.gmtime(a_start)) + kind
            activity_id = 900000000 + d
            extra = {"ActivityID": activity_id, "ActivitySelector": selector}
            zones = [rng.randint(60, 300), rng.randint(300, 900), rng.randint(600, 1500), rng.randint(200, 800), rng.randint(0, 300)]
            avg_hr = rest_hr + 85 + rng.randint(-8, 8)
            yield line("ActivitySummary", a_start, {
                "Activity_ID": activity_id, "activityName": f"Demo {kind}", "activityType": kind,
                "distance": float(round(speed * duration, 1)), "elapsedDuration": float(duration),
                "averageSpeed": float(round(speed, 3)), "maxSpeed": float(round(speed * 1.35, 3)),
                "calories": float(round(duration / 60 * (11 if kind != "walking" else 5))),
                "bmrCalories": float(round(duration / 60 * 1.2)),
                "averageHR": float(avg_hr), "maxHR": float(avg_hr + rng.randint(12, 30)),
                "locationName": "Demo Park",
                **{f"hrTimeInZone_{i + 1}": float(z) for i, z in enumerate(zones)},
            }, extra)
            # A loop of about 400 m radius around (0, 0), one point every 10 s.
            radius_deg = 0.0036
            dist = 0.0
            for s in range(0, duration, 10):
                ang = 2 * math.pi * s / 600.0
                dist += speed * 10
                hr_s = avg_hr + 8 * math.sin(2 * math.pi * s / duration) + rng.gauss(0, 2)
                yield line("ActivityGPS", a_start + s, {
                    "ActivityName": kind, "Activity_ID": activity_id,
                    "Latitude": radius_deg * math.sin(ang), "Longitude": radius_deg * math.cos(ang),
                    "Altitude": float(round(10 + 3 * math.sin(ang * 2), 1)),
                    "Distance": float(round(dist, 1)), "DurationSeconds": float(s),
                    "HeartRate": float(round(hr_s)), "Speed": float(round(speed + rng.gauss(0, 0.15), 3)),
                    "Cadence": float(round((170 if kind == "running" else 85 if kind == "cycling" else 110) / 2 + rng.gauss(0, 2))),
                }, extra)

        # --- slow-changing metrics (daily estimates, weigh-in every 3 days) ---
        if start <= day + 43200 < end:
            vo2 = clamp(vo2 + rng.gauss(0.01, 0.12), 40, 55)
            base5k = 1500 - (vo2 - 40) * 25
            if d % 3 == 0:
                weight = clamp(weight + rng.gauss(-0.01, 0.2), 65, 80)
                yield line("BodyComposition", day + 43200, {"weight": float(round(weight * 1000))})
            yield line("VO2_Max", day + 43200, {"VO2_max_value": float(round(vo2, 1))})
            yield line("RacePredictions", day + 43200, {
                "time5K": int(base5k), "time10K": int(base5k * 2.09),
                "timeHalfMarathon": int(base5k * 4.65), "timeMarathon": int(base5k * 9.8),
            })
        day += DAY


def main(argv):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--url", default="http://127.0.0.1:18086")
    p.add_argument("--days", type=int, default=365)
    p.add_argument("--bootstrap", action="store_true", help="create admin, database and accounts first")
    p.add_argument("--batch", type=int, default=5000)
    args = p.parse_args(argv)

    if not ping(args.url):
        print(f"InfluxDB not reachable at {args.url}", file=sys.stderr)
        return 1
    admin_pw = os.environ.get("INFLUXDB_ADMIN_PASSWORD", "")
    write_pw = os.environ.get("INFLUXDB_WRITE_PASSWORD", "")
    read_pw = os.environ.get("INFLUXDB_READ_PASSWORD", "")
    if args.bootstrap:
        bootstrap(args.url, admin_pw, write_pw, read_pw)
        print("bootstrap: database GarminStats, accounts admin, garmin_writer, garmin_reader")

    rng = random.Random(SEED)
    end = int(time.time()) // 60 * 60
    start = end - args.days * DAY
    writer = Influx(args.url, "garmin_writer", write_pw)
    batch, total, t0 = [], 0, time.time()
    for ln in generate(rng, start, end):
        batch.append(ln)
        if len(batch) >= args.batch:
            writer.write(batch)
            total += len(batch)
            batch = []
    if batch:
        writer.write(batch)
        total += len(batch)
    print(f"wrote {total} points ({args.days} days of invented data) in {time.time() - t0:.0f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
