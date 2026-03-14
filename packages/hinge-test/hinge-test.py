#!/usr/bin/env python3
"""
Hinge sensor test script for Lenovo Fold.
Tests different methods to detect hinge angle changes.
"""

import time
import logging
from pathlib import Path
import subprocess


class HingeTest:
    def __init__(self):
        self.hinge_device = Path("/sys/bus/iio/devices/iio:device4")
        self.logger = logging.getLogger(__name__)
        logging.basicConfig(
            level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
        )

        # Initialize hinge sensor
        self._init_hinge_sensor()

    def _init_hinge_sensor(self):
        """Initialize hinge sensor for readings."""
        try:
            # Enable all angle channels
            for i in range(3):
                enable_path = self.hinge_device / f"scan_elements/in_angl{i}_en"
                if enable_path.exists():
                    enable_path.write_text("1")
                    self.logger.info(f"Enabled angle channel {i}")

            # Try to enable buffer
            buffer_enable = self.hinge_device / "buffer/enable"
            if buffer_enable.exists():
                try:
                    buffer_enable.write_text("1")
                    self.logger.info("Enabled hinge sensor buffer")
                except OSError as e:
                    self.logger.warning(f"Could not enable buffer: {e}")

            # Check sampling frequency
            freq_path = self.hinge_device / "in_angl_sampling_frequency"
            if freq_path.exists():
                freq = freq_path.read_text().strip()
                self.logger.info(f"Hinge sampling frequency: {freq} Hz")

        except Exception as e:
            self.logger.error(f"Failed to initialize hinge sensor: {e}")

    def read_hinge_raw(self):
        """Read raw hinge values."""
        try:
            angles = {}
            labels = {}

            for i in range(3):
                # Read label
                label_path = self.hinge_device / f"in_angl{i}_label"
                if label_path.exists():
                    labels[i] = label_path.read_text().strip()

                # Read raw value
                raw_path = self.hinge_device / f"in_angl{i}_raw"
                if raw_path.exists():
                    angles[i] = int(raw_path.read_text().strip())

            # Read scale factor
            scale = 1.0
            scale_path = self.hinge_device / "in_angl_scale"
            if scale_path.exists():
                scale = float(scale_path.read_text().strip())

            return angles, labels, scale

        except Exception as e:
            self.logger.error(f"Failed to read hinge: {e}")
            return {}, {}, 1.0

    def read_hinge_degrees(self):
        """Read hinge values in degrees."""
        angles, labels, scale = self.read_hinge_raw()
        degrees = {}

        for i, raw_val in angles.items():
            # Convert from radians to degrees (scale is typically radians per unit)
            degrees[i] = raw_val * scale * 180.0 / 3.14159265359

        return degrees, labels

    def test_hinge_detection_methods(self):
        """Test different methods to detect hinge changes."""
        self.logger.info("=== Testing Hinge Detection Methods ===")

        # Method 1: Direct reading
        self.logger.info("Method 1: Direct sysfs reading")
        angles, labels, scale = self.read_hinge_raw()
        self.logger.info(f"Raw angles: {angles}")
        self.logger.info(f"Labels: {labels}")
        self.logger.info(f"Scale factor: {scale}")

        degrees, _ = self.read_hinge_degrees()
        self.logger.info(f"Angles in degrees: {degrees}")

        # Method 2: Check for /dev/iio:device4
        dev_path = Path("/dev/iio:device4")
        if dev_path.exists():
            self.logger.info(
                "Method 2: /dev/iio:device4 exists - could use iio library"
            )
        else:
            self.logger.info("Method 2: /dev/iio:device4 not available")

        # Method 3: Check HID sensors via input devices
        self.logger.info("Method 3: Checking input devices for HID sensors")
        try:
            result = subprocess.run(
                ["cat", "/proc/bus/input/devices"],
                capture_output=True,
                text=True,
                check=True,
            )
            if "hinge" in result.stdout.lower():
                self.logger.info("Found hinge-related input device")
            else:
                self.logger.info("No hinge input device found")
        except subprocess.CalledProcessError:
            self.logger.warning("Could not read input devices")

    def continuous_monitor(self, duration=30):
        """Continuously monitor hinge for changes."""
        self.logger.info(f"=== Monitoring hinge for {duration} seconds ===")
        self.logger.info("Try opening/closing the device now...")

        start_time = time.time()
        last_angles = None

        while time.time() - start_time < duration:
            degrees, labels = self.read_hinge_degrees()

            if degrees != last_angles:
                self.logger.info(f"Hinge change detected:")
                for i, angle in degrees.items():
                    label = labels.get(i, f"angle{i}")
                    self.logger.info(f"  {label}: {angle:.2f}°")
                last_angles = degrees.copy()

            time.sleep(0.5)

        self.logger.info("Monitoring complete")

    def analyze_sensor_files(self):
        """Analyze all available sensor files."""
        self.logger.info("=== Analyzing Hinge Sensor Files ===")

        if not self.hinge_device.exists():
            self.logger.error(f"Hinge device not found: {self.hinge_device}")
            return

        # List all files
        for item in sorted(self.hinge_device.rglob("*")):
            if item.is_file():
                rel_path = item.relative_to(self.hinge_device)
                try:
                    if item.stat().st_size < 1000:  # Only read small files
                        content = item.read_text().strip()
                        self.logger.info(f"{rel_path}: {content}")
                    else:
                        self.logger.info(f"{rel_path}: <large file>")
                except (OSError, UnicodeDecodeError):
                    self.logger.info(f"{rel_path}: <unreadable>")


def main():
    tester = HingeTest()

    # Run all tests
    tester.analyze_sensor_files()
    print()
    tester.test_hinge_detection_methods()
    print()
    tester.continuous_monitor(duration=20)


if __name__ == "__main__":
    main()
