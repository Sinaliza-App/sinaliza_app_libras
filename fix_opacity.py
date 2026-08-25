import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex to find .withOpacity(value)
    # Be careful with parentheses
    new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)

    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('c:/Projetos/SINALIZA/sinaliza_app_libras/lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
