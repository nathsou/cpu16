import serial
import sys
import time
from tqdm import tqdm

SERIAL_PORT = '/dev/ttyUSB2'
BAUD_RATE = 921600
ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)

# Allow some time for the connection to establish
time.sleep(1)

def program_ram(file_path: str):
    try:
        with open(file_path, 'rb') as file:
            file_size = file.seek(0, 2)  # Move to the end of the file to get the file size
            file.seek(0)  # Move back to the beginning of the file

            with tqdm(total=file_size, unit='B', unit_scale=True, desc='Transferring') as pbar:
                while chunk := file.read(16):
                    ser.write(chunk)
                    pbar.update(len(chunk))

    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python prog.py <bin_file_path>")
        sys.exit(1)

    file_path = sys.argv[1]
    program_ram(file_path)

if __name__ == "__main__":
    main()
