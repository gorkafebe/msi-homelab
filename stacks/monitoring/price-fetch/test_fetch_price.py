"""Tests for fetch_price.py (no network). Run: python3 -I -m unittest -v test_fetch_price"""

import os
import sys
import tempfile
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch_price as fp  # noqa: E402

SAMPLE = {
    "included": [
        {"type": "PVPC", "attributes": {"values": [
            {"value": 214.17, "datetime": "2026-11-05T00:00:00.000+01:00"},
            {"value": 244.88, "datetime": "2026-11-05T10:00:00.000+01:00"},
            {"value": 100.0, "datetime": "2026-11-05T11:00:00.000+01:00"},
            {"value": "bad", "datetime": "2026-11-05T12:00:00.000+01:00"},
        ]}},
        {"type": "Precio mercado spot", "attributes": {"values": [
            {"value": 221.18, "datetime": "2026-11-05T10:30:00.000+01:00"},
            {"value": 230.00, "datetime": "2026-11-05T10:45:00.000+01:00"},
        ]}},
        {"type": "Something else", "attributes": {"values": [{"value": 1, "datetime": "2026-11-05T10:00:00+01:00"}]}},
    ]
}


class ParseTest(unittest.TestCase):
    def test_parse_keeps_known_series_and_skips_bad_values(self):
        d = fp.parse(SAMPLE)
        self.assertEqual(set(d), {"pvpc", "spot"})
        self.assertEqual(len(d["pvpc"]), 3)

    def test_current_hour_uses_offsets(self):
        d = fp.parse(SAMPLE)
        now = datetime(2026, 11, 5, 9, 40, tzinfo=timezone.utc)  # 10:40 in Madrid (CET)
        start, price = fp.current(d["pvpc"], fp.SERIES["PVPC"][1], now)
        self.assertEqual(price, 244.88)
        self.assertEqual(start.utcoffset().total_seconds(), 3600)
        _, spot = fp.current(d["spot"], fp.SERIES["Precio mercado spot"][1], now)
        self.assertEqual(spot, 221.18)

    def test_no_current_value(self):
        d = fp.parse(SAMPLE)
        now = datetime(2026, 11, 6, 12, 0, tzinfo=timezone.utc)
        self.assertIsNone(fp.current(d["pvpc"], fp.SERIES["PVPC"][1], now))

    def test_render_converts_to_eur_per_kwh(self):
        d = fp.parse(SAMPLE)
        now = datetime(2026, 11, 5, 9, 40, tzinfo=timezone.utc)
        text = fp.render(d, now, 1793872000, True)
        self.assertIn('msi_electricity_price_eur_per_kwh{source="pvpc"} 0.24488', text)
        self.assertIn('msi_electricity_price_today_eur_per_kwh{source="pvpc",stat="max"} 0.24488', text)
        self.assertIn("msi_electricity_price_fetch_success 1", text)

    def test_render_without_data_reports_failure_only(self):
        text = fp.render({}, datetime.now(timezone.utc), 0, False)
        self.assertNotIn("msi_electricity_price_eur_per_kwh{", text)
        self.assertIn("msi_electricity_price_fetch_success 0", text)
        self.assertIn("msi_electricity_price_last_success_timestamp_seconds 0", text)

    def test_url_covers_three_days(self):
        url = fp.build_url(datetime(2026, 11, 5, 9, 0, tzinfo=timezone.utc))
        self.assertIn("start_date=2026-11-04T00:00", url)
        self.assertIn("end_date=2026-11-06T23:59", url)
        self.assertTrue(url.startswith("https://apidatos.ree.es/"))

    def test_write_atomic(self):
        with tempfile.TemporaryDirectory() as t:
            p = os.path.join(t, "x.prom")
            fp.write_atomic(p, "a 1\n")
            self.assertEqual(open(p, encoding="utf-8").read(), "a 1\n")
            self.assertFalse(os.path.exists(p + ".tmp"))


if __name__ == "__main__":
    unittest.main()
