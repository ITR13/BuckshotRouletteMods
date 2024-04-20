import os
import shutil
import subprocess

def main():
    # Define source and destination paths relative to the current working directory
    destination_path = ".."

    # Get the absolute path of the current working directory
    current_directory = os.getcwd()

    # Construct the absolute paths for source and destination
    abs_destination_path = os.path.join(current_directory, destination_path)
    final_path = os.path.join(abs_destination_path, "mods-unpacked")

    # Compress the folder into a ZIP file
    shutil.make_archive(final_path, 'zip', current_directory, "mods-unpacked")

    # Run the executable
    executable_path = os.path.join(current_directory, "..", "..", "Buckshot Roulette.exe")
    subprocess.call(executable_path)

if __name__ == "__main__":
    main()
