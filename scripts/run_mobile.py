#!/usr/bin/env python3
"""Choose a mobile platform and run SpendWise using the installed Flutter SDK."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def choose(title, items, label):
    print('\n' + title)
    for index, item in enumerate(items, 1):
        print(f'  {index}. {label(item)}')
    print('  0. Cancel')
    while True:
        answer = input('Choose a number: ').strip()
        if answer == '0':
            raise SystemExit(0)
        if answer.isdigit() and 1 <= int(answer) <= len(items):
            return items[int(answer) - 1]
        print('Please enter one of the numbers above.')


def run_json(command):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    try:
        return json.loads(result.stdout)
    except ValueError as error:
        raise RuntimeError('The device tools returned an unexpected response. Run flutter doctor.') from error


def mobile_devices(flutter, platform):
    devices = run_json([flutter, 'devices', '--machine'])
    return [device for device in devices
            if device.get('isSupported', True)
            and (str(device.get('targetPlatform', '')).startswith('android')
                 if platform == 'android' else device.get('targetPlatform') == 'ios')]


def start_iphone():
    if sys.platform != 'darwin' or not shutil.which('xcrun'):
        print('Running iPhone apps requires a Mac with Xcode and an iOS simulator or connected iPhone.')
        return False
    inventory = run_json(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'])
    phones = [dict(device, runtime=runtime.rsplit('.', 1)[-1])
              for runtime, devices in inventory.get('devices', {}).items()
              for device in devices
              if device.get('isAvailable') and device.get('name', '').startswith('iPhone')]
    if not phones:
        print('No iPhone simulator is installed. Add an iOS runtime and simulator in Xcode first.')
        return False
    phone = choose('Choose an iPhone simulator', phones,
                   lambda item: f"{item['name']} ({item['runtime']})")
    if phone['state'] != 'Booted':
        subprocess.run(['xcrun', 'simctl', 'boot', phone['udid']], check=True)
    subprocess.run(['open', '-a', 'Simulator'], check=True)
    print('Waiting for the iPhone simulator to finish starting...', flush=True)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', phone['udid'], '-b'], check=True)
    return True


def main():
    parser = argparse.ArgumentParser(description='Run SpendWise on Android or iPhone.')
    parser.add_argument('--platform', choices=['android', 'ios'])
    args = parser.parse_args()
    flutter = shutil.which('flutter')
    if not flutter:
        print('Flutter was not found. Add your Flutter SDK bin folder to PATH and reopen the terminal.')
        return 1
    platform = args.platform or choose('Run SpendWise on', ['android', 'ios'],
                                       lambda item: 'Android' if item == 'android' else 'iPhone (iOS)')
    devices = mobile_devices(flutter, platform)
    if not devices and platform == 'ios':
        print('No running iPhone or iOS simulator was detected.')
        if not start_iphone():
            return 1
        devices = mobile_devices(flutter, platform)
    if not devices:
        if platform == 'android':
            print('\nNo Android device is available. Connect a phone with USB debugging enabled,')
            print('or start an Android emulator in Android Studio Device Manager, then run this again.')
            print('Use flutter devices to confirm detection and flutter doctor to check setup.')
        else:
            print('No supported iOS device was detected. Check flutter devices and flutter doctor.')
        return 1
    device = devices[0] if len(devices) == 1 else choose(
        'Choose a device', devices, lambda item: f"{item['name']} ({item['id']})")
    print(f"\nStarting SpendWise on {device['name']}...", flush=True)
    return subprocess.call([flutter, 'run', '-d', device['id']], cwd=ROOT)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (KeyboardInterrupt, EOFError):
        print('\nLaunch cancelled.')
        sys.exit(0)
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f'Could not launch SpendWise: {error}', file=sys.stderr)
        sys.exit(1)
