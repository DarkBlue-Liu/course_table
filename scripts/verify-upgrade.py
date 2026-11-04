"""Run only against the disposable, rooted emulator-5556. APK paths are arguments."""
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import time

ADB = r'E:\Android\SDK\platform-tools\adb.exe'
SERIAL = 'emulator-5556'
PACKAGE = 'com.example.course_table'
OUT = Path('build/upgrade-verification')
REMOTE = f'/data/user/0/{PACKAGE}/databases/course_table.db'

def adb(*args, check=True):
    result = subprocess.run([ADB, '-s', SERIAL, *args], capture_output=True, text=True)
    if check and result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout + result.stderr

def snapshot(path):
    with sqlite3.connect(path) as db:
        return {table: db.execute(f'SELECT * FROM {table} ORDER BY id').fetchall()
                for table in ('semester', 'time_slot', 'course', 'course_schedule')}

baseline, target = sys.argv[1:]
assert 'ReleaseTest' in adb('emu', 'avd', 'name'), 'Requires disposable ReleaseTest AVD'
assert not adb('shell', 'pm', 'path', PACKAGE, check=False).strip(), 'Test AVD must not contain an existing installation'
assert 'Success' in adb('install', baseline)
assert 'versionCode=1 ' in adb('shell', 'dumpsys', 'package', PACKAGE)
adb('shell', 'am', 'start', '-n', f'{PACKAGE}/.MainActivity')
for _ in range(30):
    if 'No such file' not in adb('shell', 'ls', REMOTE, check=False):
        break
    time.sleep(1)
adb('shell', 'am', 'force-stop', PACKAGE)
adb('pull', REMOTE, str(OUT / 'seed.db'))
with sqlite3.connect(OUT / 'seed.db') as db:
    db.execute("INSERT INTO semester VALUES (1, '2026-08-31', 20, '2026-09-02', '2027-01-17', 1, '2026-11-04')")
    db.execute("INSERT INTO course (name,teacher,location,color,note,created_at) VALUES ('Upgrade retention','Teacher','Room',4283211775,'Keep this note','2026-11-04')")
    db.execute('INSERT INTO course_schedule (course_id,weekday,start_slot,end_slot,start_week,end_week,week_type) VALUES (1,3,1,2,1,20,0)')
    assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
adb('push', str(OUT / 'seed.db'), REMOTE)
# adb push replaces contents while retaining existing app file ownership.
adb('shell', 'am', 'start', '-n', f'{PACKAGE}/.MainActivity')
time.sleep(3)
adb('shell', 'am', 'force-stop', PACKAGE)
adb('pull', REMOTE, str(OUT / 'before.db'))
before = snapshot(OUT / 'before.db')
assert before['course'][0][1] == 'Upgrade retention'
assert 'Success' in adb('install', '-r', target)
assert 'versionCode=2 ' in adb('shell', 'dumpsys', 'package', PACKAGE)
adb('shell', 'am', 'start', '-n', f'{PACKAGE}/.MainActivity')
time.sleep(3)
adb('shell', 'am', 'force-stop', PACKAGE)
adb('pull', REMOTE, str(OUT / 'after.db'))
after = snapshot(OUT / 'after.db')
assert before == after, 'Database content changed during upgrade'
with sqlite3.connect(OUT / 'after.db') as db:
    assert db.execute('PRAGMA user_version').fetchone()[0] == 2
    assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
result = {'serial': SERIAL, 'package': PACKAGE, 'tables_equal': True,
          'rows': {key: len(value) for key, value in after.items()},
          'database_version': 2, 'target_sha256': hashlib.sha256(Path(target).read_bytes()).hexdigest(),
          'installed_package': adb('shell', 'dumpsys', 'package', PACKAGE)}
(OUT / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({key: value for key, value in result.items() if key != 'installed_package'}, indent=2))
