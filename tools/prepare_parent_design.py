from pathlib import Path
p=Path('lib/pally.dart')
p.write_text(p.read_text().replace('ParentTheme.dark.value?.55:.16','ParentTheme.dark.value ? 0.55 : 0.16'))
exec(compile(Path('tools/apply_parent_redesign.py').read_text(), 'tools/apply_parent_redesign.py', 'exec'))
