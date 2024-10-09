import evdev
from evdev import UInput, AbsInfo, ecodes as ec
import os
import sys
import traceback
import time
import asyncio

def create_virtual_joystick():
    capabilities = {
        ec.EV_KEY: [ec.BTN_A, ec.BTN_B, ec.BTN_X, ec.BTN_Y, ec.BTN_TL, ec.BTN_TR,
                   ec.BTN_SELECT, ec.BTN_START, ec.BTN_THUMBL, ec.BTN_THUMBR],
        ec.EV_ABS: [
            (ec.ABS_X, AbsInfo(value=0, min=-32768, max=32767, fuzz=0, flat=0, resolution=0)),
            (ec.ABS_Y, AbsInfo(value=0, min=-32768, max=32767, fuzz=0, flat=0, resolution=0)),
            (ec.ABS_RX, AbsInfo(value=0, min=-32768, max=32767, fuzz=0, flat=0, resolution=0)),
            (ec.ABS_RY, AbsInfo(value=0, min=-32768, max=32767, fuzz=0, flat=0, resolution=0)),
            (ec.ABS_Z, AbsInfo(value=0, min=0, max=255, fuzz=0, flat=0, resolution=0)),
            (ec.ABS_RZ, AbsInfo(value=0, min=0, max=255, fuzz=0, flat=0, resolution=0)),
            (ec.ABS_HAT0X, AbsInfo(value=0, min=-1, max=1, fuzz=0, flat=0, resolution=0)),
            (ec.ABS_HAT0Y, AbsInfo(value=0, min=-1, max=1, fuzz=0, flat=0, resolution=0)),
        ]
    }
    virtual_device = UInput(capabilities, name="Virtual Gamepad Proxy", vendor=0x045e, product=0x028e, version=0x110)

    print(f"Created virtual device: {virtual_device.device.path}")
    return virtual_device

async def proxy_events(source_device, virtual_device):
    try:
        async for event in source_device.async_read_loop():
            virtual_device.write(event.type, event.code, event.value)
            virtual_device.syn()
    except OSError:
        print("Device disconnected. Waiting for reconnection...")
        return False
    return True

def find_joystick_device():
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    for device in devices:
        if device.name.lower().find('microsoft') != -1:
            return device.path
    return None

async def main():
    virtual_device = None
    try:
        virtual_device = create_virtual_joystick()
        print("Virtual gamepad proxy created. Press Ctrl+C to exit.")

        while True:
            source_path = find_joystick_device()
            if not source_path:
                print("No joystick or gamepad device found. Retrying...")
                await asyncio.sleep(1)
                continue

            print(f"Using source device: {source_path}")
            source_device = evdev.InputDevice(source_path)
            print(f"Proxying events from: {source_path} ({source_device.name})")

            if await proxy_events(source_device, virtual_device):
                break  # Exit if proxy_events completes without error

            source_device.close()
            print("Waiting for device to reconnect...")
            await asyncio.sleep(1)  # Wait before retrying to avoid busy loop

    except KeyboardInterrupt:
        print("\nExiting...")
    except Exception as e:
        print(f"An error occurred: {e}")
        traceback.print_exc()
    finally:
        if virtual_device:
            virtual_device.close()

if __name__ == "__main__":
    asyncio.run(main())
