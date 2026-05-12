import json

# Fix .flutter-plugins-dependencies (JSON file)
with open('.flutter-plugins-dependencies', 'r') as f:
    content = f.read()

data = json.loads(content)

def fix_paths(obj):
    bs = '\\'
    if isinstance(obj, dict):
        for key in list(obj.keys()):
            if key == 'path' and isinstance(obj[key], str):
                p = obj[key]
                p = p.replace(bs, '/').replace('//', '/')
                obj[key] = p
            else:
                fix_paths(obj[key])
    elif isinstance(obj, list):
        for item in obj:
            fix_paths(item)

fix_paths(data)

with open('.flutter-plugins-dependencies', 'w') as f:
    json.dump(data, f, separators=(',', ':'))

# Verify
with open('.flutter-plugins-dependencies', 'r') as f:
    verify = json.load(f)
android_plugins = verify['plugins'].get('android', [])
for p in android_plugins[:5]:
    print('android:', p['name'], '->', p['path'])

# Fix .flutter-plugins (key=value properties file)
with open('.flutter-plugins', 'r') as f:
    lines = f.readlines()

fixed_lines = []
bs = '\\'
for line in lines:
    if '=' in line and not line.startswith('#'):
        key, _, val = line.partition('=')
        val_stripped = val.rstrip()
        val_fixed = val_stripped.replace(bs + bs, '/').replace('//', '/').replace(bs, '/')
        fixed_lines.append(key + '=' + val_fixed + '\n')
    else:
        fixed_lines.append(line)

with open('.flutter-plugins', 'w') as f:
    f.writelines(fixed_lines)

print()
print('.flutter-plugins first 5 entries:')
count = 0
for line in fixed_lines:
    if not line.startswith('#') and '=' in line:
        print(line.rstrip())
        count += 1
        if count >= 5:
            break
