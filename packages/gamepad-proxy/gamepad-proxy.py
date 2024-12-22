import asyncio
import traceback
import argparse

import evdev
from evdev import AbsInfo, UInput
from evdev import ecodes as ec

# Define gamepad capabilities for the virtual device
GAMEPAD_CAPABILITIES = {
    ec.EV_KEY: [
        ec.BTN_A, ec.BTN_B, ec.BTN_X, ec.BTN_Y,
        ec.BTN_TL, ec.BTN_TR, ec.BTN_SELECT, ec.BTN_START,
        ec.BTN_THUMBL, ec.BTN_THUMBR
    ],
    ec.EV_ABS: [
        (ec.ABS_X, AbsInfo(value=0, min=-32768, max=32767, fuzz=0, flat=0, resolution=0)),
        (ec.ABS_Y, AbsInfo(value=0, min=-32768, max=32767, fuzz=0, flat=0, resolution=0)),
        (ec.ABS_RX, AbsInfo(value=0, min=-32768, max=32767, fuzz=0, flat=0, resolution=0)),
        (ec.ABS_RY, AbsInfo(value=0, min=-32768, max=32767, fuzz=0, flat=0, resolution=0)),
        (ec.ABS_Z, AbsInfo(value=0, min=0, max=255, fuzz=0, flat=0, resolution=0)),  # LT
        (ec.ABS_RZ, AbsInfo(value=0, min=0, max=255, fuzz=0, flat=0, resolution=0)),  # RT
        (ec.ABS_HAT0X, AbsInfo(value=0, min=-1, max=1, fuzz=0, flat=0, resolution=0)),
        (ec.ABS_HAT0Y, AbsInfo(value=0, min=-1, max=1, fuzz=0, flat=0, resolution=0))
    ]
}

def find_joystick_device():
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    for device in devices:
        # Expand search to include more gamepad types
        if any(keyword in device.name.lower() for keyword in ['microsoft', 'xbox', 'controller', 'gamepad']):
            return device.path
    return None

async def proxy_gamepad(debug=False):
    # Create virtual gamepad
    virtual_gamepad = UInput(GAMEPAD_CAPABILITIES, name="Virtual Xbox Controller")
    print("Created virtual gamepad device")

    while True:
        device_path = find_joystick_device()
        if device_path:
            try:
                device = evdev.InputDevice(device_path)
                # Grab the device exclusively to prevent other applications from reading it
                device.grab()
                print(f"Connected to gamepad: {device.name}")
                
                async for event in device.async_read_loop():
                    if debug:
                        print(f"Event: type={event.type}, code={event.code}, value={event.value}")
                    virtual_gamepad.write(event.type, event.code, event.value)
                    virtual_gamepad.syn()
                    
            except (OSError, asyncio.CancelledError):
                try:
                    # Release the device when disconnected
                    device.ungrab()
                except:
                    pass
                print("Gamepad disconnected, waiting for new connection...")
                await asyncio.sleep(1)
                continue
        else:
            await asyncio.sleep(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Gamepad proxy with virtual device')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    args = parser.parse_args()

    try:
        asyncio.run(proxy_gamepad(debug=args.debug))
    except KeyboardInterrupt:
        print("\nExiting...")
    except Exception as e:
        print(f"Error: {e}")
        traceback.print_exc()

