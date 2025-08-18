#!/usr/bin/env python3
"""
Automatic screen rotation service for Lenovo Fold with Hyprland.
Monitors accelerometer to detect device orientation and rotation.
"""

import argparse
import json
import subprocess
import sys
import time
import logging
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Tuple
import math

@dataclass
class SensorReading:
    """Represents accelerometer sensor readings."""
    x: float
    y: float
    z: float

@dataclass
class Orientation:
    """Represents device orientation."""
    transform: int
    name: str

# Orientation mappings for Hyprland transforms
ORIENTATIONS = {
    0: Orientation(0, "normal"),      # Portrait
    1: Orientation(1, "right"),       # Landscape (rotated right)
    2: Orientation(2, "inverted"),    # Portrait inverted
    3: Orientation(3, "left"),        # Landscape (rotated left)
}

class AutoRotate:
    """Main auto-rotation service class."""
    
    def __init__(self, args):
        self.accelerometer_device = Path(args.accelerometer)
        self.rotation_threshold = args.rotation_threshold
        self.debounce_time = args.debounce_time
        self.hyprland_instance = args.hyprland_instance
        self.poll_interval = args.poll_interval
        
        # State tracking
        self.current_orientation = 0
        self.last_rotation_time = 0
        
        # Setup logging
        logging.basicConfig(
            level=logging.DEBUG,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # Validate sensor devices
        self._validate_devices()
    
    def _validate_devices(self):
        """Validate that sensor devices exist and are accessible."""
        if not self.accelerometer_device.exists():
            raise FileNotFoundError(f"Accelerometer device not found: {self.accelerometer_device}")
        
        # Check for required accelerometer files
        accel_files = ["in_accel_x_raw", "in_accel_y_raw", "in_accel_z_raw"]
        for file in accel_files:
            accel_file = self.accelerometer_device / file
            if not accel_file.exists():
                raise FileNotFoundError(f"Accelerometer file not found: {accel_file}")
        
        
        self.logger.info("Sensor devices validated successfully")
    
    
    def _read_accelerometer(self) -> Optional[SensorReading]:
        """Read accelerometer values from sysfs."""
        try:
            x_raw = (self.accelerometer_device / "in_accel_x_raw").read_text().strip()
            y_raw = (self.accelerometer_device / "in_accel_y_raw").read_text().strip()
            z_raw = (self.accelerometer_device / "in_accel_z_raw").read_text().strip()
            
            return SensorReading(
                x=float(x_raw),
                y=float(y_raw),
                z=float(z_raw)
            )
        except (IOError, ValueError) as e:
            self.logger.error(f"Failed to read accelerometer: {e}")
            return None
    
    
    def _calculate_orientation(self, reading: SensorReading) -> int:
        """Calculate device orientation based on accelerometer readings."""
        # Normalize the readings
        magnitude = math.sqrt(reading.x**2 + reading.y**2 + reading.z**2)
        if magnitude == 0:
            return self.current_orientation
        
        x_norm = reading.x / magnitude
        y_norm = reading.y / magnitude
        
        # Calculate angle from vertical (Y-axis)
        angle = math.atan2(x_norm, -y_norm) * 180 / math.pi
        
        # Normalize angle to 0-360 range
        if angle < 0:
            angle += 360
        
        # Map angle to orientation with hysteresis
        if 315 <= angle or angle < 45:
            return 0  # Normal (portrait)
        elif 45 <= angle < 135:
            return 1  # Right (landscape)
        elif 135 <= angle < 225:
            return 2  # Inverted (portrait upside down)
        elif 225 <= angle < 315:
            return 3  # Left (landscape)
        
        return self.current_orientation
    
    
    def _get_current_monitor_info(self) -> Optional[dict]:
        """Get current monitor configuration from Hyprland."""
        try:
            result = subprocess.run(
                ["hyprctl", "--instance", str(self.hyprland_instance), "monitors", "-j"],
                capture_output=True,
                text=True,
                check=True
            )
            monitors = json.loads(result.stdout)
            return monitors[0] if monitors else None
        except (subprocess.CalledProcessError, json.JSONDecodeError, IndexError) as e:
            self.logger.error(f"Failed to get monitor info: {e}")
            return None
    
    def _apply_rotation(self, orientation: int):
        """Apply rotation to Hyprland display."""
        if orientation == self.current_orientation:
            return
        
        # Check debounce time
        current_time = time.time()
        if current_time - self.last_rotation_time < self.debounce_time:
            return
        
        monitor_info = self._get_current_monitor_info()
        if not monitor_info:
            self.logger.error("Could not get current monitor info")
            return
        
        monitor_name = monitor_info.get("name", "eDP-1")
        width = monitor_info.get("width", 2024)
        height = monitor_info.get("height", 2560)
        refresh_rate = monitor_info.get("refreshRate", 60)
        scale = monitor_info.get("scale", 1.0)
        
        # Apply the new transform
        orientation_info = ORIENTATIONS[orientation]
        monitor_config = f"{monitor_name},{width}x{height}@{refresh_rate},auto,{scale},transform,{orientation_info.transform}"
        
        try:
            # Apply monitor transform
            subprocess.run(
                ["hyprctl", "--instance", str(self.hyprland_instance), "keyword", "monitor", monitor_config],
                check=True,
                capture_output=True
            )
            
            # Set master layout orientation based on display orientation
            if orientation in [0, 2]:  # Portrait modes
                # Master on top, 50% height
                subprocess.run(
                    ["hyprctl", "--instance", str(self.hyprland_instance), "dispatch", "layoutmsg", "orientationtop"],
                    check=True,
                    capture_output=True
                )
                subprocess.run(
                    ["hyprctl", "--instance", str(self.hyprland_instance), "dispatch", "layoutmsg", "mfact", "exact", "0.5"],
                    check=True,
                    capture_output=True
                )
                layout_desc = "orientationtop, mfact 0.5"
            else:  # Landscape modes (1, 3)
                # Master on right, golden ratio
                subprocess.run(
                    ["hyprctl", "--instance", str(self.hyprland_instance), "dispatch", "layoutmsg", "orientationright"],
                    check=True,
                    capture_output=True
                )
                subprocess.run(
                    ["hyprctl", "--instance", str(self.hyprland_instance), "dispatch", "layoutmsg", "mfact", "exact", "0.618"],
                    check=True,
                    capture_output=True
                )
                layout_desc = "orientationright, mfact 0.618"
            
            self.current_orientation = orientation
            self.last_rotation_time = current_time
            self.logger.info(f"Rotated display to {orientation_info.name} (transform {orientation_info.transform}, layout: {layout_desc})")
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to apply rotation: {e}")
    
    def run(self):
        """Main service loop."""
        self.logger.info("Starting auto-rotation service")
        self.logger.info(f"Accelerometer: {self.accelerometer_device}")
        self.logger.info(f"Rotation threshold: {self.rotation_threshold}")
        self.logger.info(f"Poll interval: {self.poll_interval}s")
        
        try:
            while True:
                # Read sensor data
                accel_reading = self._read_accelerometer()
                if accel_reading is None:
                    time.sleep(self.poll_interval)
                    continue
                
                # Debug: Log accelerometer readings
                self.logger.debug(f"Accel: X={accel_reading.x}, Y={accel_reading.y}, Z={accel_reading.z}")
                
                # Check if significant movement detected
                if abs(accel_reading.x) < self.rotation_threshold and abs(accel_reading.y) < self.rotation_threshold:
                    self.logger.debug(f"Below threshold - X:{abs(accel_reading.x)} < {self.rotation_threshold}, Y:{abs(accel_reading.y)} < {self.rotation_threshold}")
                    time.sleep(self.poll_interval)
                    continue
                
                self.logger.debug(f"Above threshold - processing rotation")
                
                # Calculate and apply orientation
                new_orientation = self._calculate_orientation(accel_reading)
                self.logger.debug(f"Calculated orientation: {new_orientation} (current: {self.current_orientation})")
                self._apply_rotation(new_orientation)
                
                time.sleep(self.poll_interval)
                
        except KeyboardInterrupt:
            self.logger.info("Service stopped by user")
        except Exception as e:
            self.logger.error(f"Service error: {e}")
            sys.exit(1)

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Automatic screen rotation for Lenovo Fold")
    parser.add_argument("--accelerometer", default="/sys/bus/iio/devices/iio:device1",
                        help="Accelerometer device path")
    parser.add_argument("--rotation-threshold", type=int, default=500000,
                        help="Rotation detection threshold")
    parser.add_argument("--debounce-time", type=int, default=2,
                        help="Debounce time in seconds")
    parser.add_argument("--hyprland-instance", type=int, default=0,
                        help="Hyprland instance number")
    parser.add_argument("--poll-interval", type=float, default=0.5,
                        help="Sensor polling interval")
    
    args = parser.parse_args()
    
    service = AutoRotate(args)
    service.run()

if __name__ == "__main__":
    main()