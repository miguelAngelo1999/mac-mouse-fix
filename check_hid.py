#!/usr/bin/env python3
"""List HID devices that look like Logitech mice."""
import subprocess
result = subprocess.run(['ioreg', '-r', '-c', 'IOHIDDevice', '-l'], capture_output=True, text=True)
lines = result.stdout.split('\n')
current_device = []
devices = []
for line in lines:
    if '+-o IOHIDDevice' in line or '+-o AppleUserHIDDevice' in line:
        if current_device:
            devices.append('\n'.join(current_device))
        current_device = [line]
    else:
        current_device.append(line)
if current_device:
    devices.append('\n'.join(current_device))

for dev in devices:
    if '1133' in dev or '046d' in dev or '46d' in dev or 'Logitech' in dev.lower() or 'M720' in dev:
        # Extract key info
        for line in dev.split('\n'):
            if any(k in line for k in ['Product', 'VendorID', 'Transport', 'Manufacturer', 'PrimaryUsage']):
                print(line.strip())
        print('---')
