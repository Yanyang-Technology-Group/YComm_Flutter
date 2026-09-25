#!/usr/bin/env python3
"""Keep feature code behind the adaptive UI boundary; run from repo root.

Widget tests verify which branch gets rendered. This guard finds direct
constructors in feature/shared widgets before a rarely visited screen can leak
Material controls. Theme configuration and adaptive implementations are excluded.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = (
    'Material Scaffold AppBar InkWell InkResponse Icon IconButton FilledButton '
    'ElevatedButton OutlinedButton TextButton FloatingActionButton Card ListTile '
    'AlertDialog Dialog SimpleDialog SimpleDialogOption PopupMenuButton '
    'TextField TextFormField DropdownButton DropdownButtonFormField Switch '
    'SwitchListTile Checkbox CheckboxListTile Radio RadioListTile Slider '
    'RefreshIndicator LinearProgressIndicator CircularProgressIndicator '
    'Chip ChoiceChip FilterChip Badge Tooltip SearchBar ExpansionTile '
    'SegmentedButton SelectableText CircleAvatar showDialog showModalBottomSheet '
    'showDatePicker showTimePicker showLicensePage MaterialPageRoute SnackBar'
).split()
constructor = re.compile(r'\b(' + '|'.join(FORBIDDEN) + r')(?:<[^>\n]+>)?(?:\.(?!styleFrom\b)\w+)?\(')
paths = sorted((ROOT / 'lib/features').rglob('*.dart')) + sorted((ROOT / 'lib/core/widgets').rglob('*.dart'))
errors = []
for path in paths:
    for line_no, line in enumerate(path.read_text().splitlines(), 1):
        if line.lstrip().startswith('//'):
            continue
        for match in constructor.finditer(line):
            errors.append(f'{path.relative_to(ROOT)}:{line_no}: use adaptive {match[1]}')

# Explicit mapping is mandatory even for icons currently below the fold.
mapped = set(re.findall(r'm\.Icons\.(\w+):', (ROOT / 'lib/core/design/apple_icons.dart').read_text()))
for path in (ROOT / 'lib').rglob('*.dart'):
    if path.name == 'apple_icons.dart':
        continue
    icons = set(re.findall(r'(?<!\w)Icons\.(\w+)', path.read_text()))
    for name in sorted(icons - mapped):
        errors.append(f'{path.relative_to(ROOT)}: missing Cupertino equivalent for Icons.{name}')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'Apple UI boundary passed: {len(paths)} feature/shared files; all Material icon symbols mapped.')
