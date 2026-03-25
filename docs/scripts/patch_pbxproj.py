#!/usr/bin/env python3
"""
patch_pbxproj.py — Fügt PBXResourcesBuildPhase in NevLate.xcodeproj ein.

Hintergrund: xcodegen v2.44.1 generiert für dieses macOS-Target keine
PBXResourcesBuildPhase. Deshalb werden Assets.xcassets, AppIcon.icns,
Localizable.xcstrings, PrivacyInfo.xcprivacy und InfoPlist.strings
nicht ins App-Bundle kopiert. Der Export schlägt dann fehl mit:
  "Missing required icon in ICNS format containing a 512pt x 512pt @2x image"

Dieses Script muss nach JEDEM `xcodegen generate` ausgeführt werden:
  python3 docs/scripts/patch_pbxproj.py

WARNUNG: `xcodegen generate` NICHT laufend lassen — überschreibt alle Patches!
Stattdessen xcodebuild direkt mit NevLate.xcodeproj verwenden.
"""

import os, sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PBXPROJ = os.path.join(PROJECT_ROOT, "NevLate.xcodeproj", "project.pbxproj")

with open(PBXPROJ, 'r') as f:
    content = f.read()

# Prüfen ob Patch bereits angewendet wurde
if "AA000001000000000000A001" in content:
    print("✅ Patch bereits angewendet — nichts zu tun.")
    sys.exit(0)

# UUIDs für neue Einträge (deterministisch)
resources = [
    ("AA000001000000000000A001", "AA000002000000000000A001", "Assets.xcassets",       "folder.assetcatalog",    "Meeting Reminder/Assets.xcassets"),
    ("AA000001000000000000A002", "AA000002000000000000A002", "AppIcon.icns",           "image.icns",             "Meeting Reminder/AppIcon.icns"),
    ("AA000001000000000000A003", "AA000002000000000000A003", "Localizable.xcstrings",  "text.json",              "Meeting Reminder/Localizable.xcstrings"),
    ("AA000001000000000000A004", "AA000002000000000000A004", "PrivacyInfo.xcprivacy",  "text.xml",               "Meeting Reminder/PrivacyInfo.xcprivacy"),
    ("AA000001000000000000A005", "AA000002000000000000A005", "InfoPlist.strings",      "text.plist.strings",     "Meeting Reminder/en.lproj/InfoPlist.strings"),
    ("AA000001000000000000A006", "AA000002000000000000A006", "InfoPlist.strings",      "text.plist.strings",     "Meeting Reminder/de.lproj/InfoPlist.strings"),
]
res_phase_uuid = "AA000003000000000000A000"

# 1. PBXFileReference-Einträge hinzufügen
file_ref_entries = ""
for fref_uuid, _, name, ftype, path in resources:
    file_ref_entries += f'\t\t{fref_uuid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{path}"; sourceTree = SOURCE_ROOT; }};\n'

if "/* End PBXFileReference section */" not in content:
    print("❌ PBXFileReference section nicht gefunden. pbxproj-Format unbekannt.")
    sys.exit(1)

content = content.replace(
    "/* End PBXFileReference section */",
    file_ref_entries + "/* End PBXFileReference section */"
)

# 2. PBXBuildFile-Einträge hinzufügen
build_file_entries = ""
for fref_uuid, bfile_uuid, name, _, _ in resources:
    build_file_entries += f'\t\t{bfile_uuid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fref_uuid} /* {name} */; }};\n'

content = content.replace(
    "/* End PBXBuildFile section */",
    build_file_entries + "/* End PBXBuildFile section */"
)

# 3. PBXResourcesBuildPhase section einfügen
files_list = "".join(
    f'\t\t\t\t{bfile_uuid} /* {name} in Resources */,\n'
    for _, bfile_uuid, name, _, _ in resources
)
res_phase = (
    "/* Begin PBXResourcesBuildPhase section */\n"
    f"\t\t{res_phase_uuid} /* Resources */ = {{\n"
    "\t\t\tisa = PBXResourcesBuildPhase;\n"
    "\t\t\tbuildActionMask = 2147483647;\n"
    "\t\t\tfiles = (\n"
    f"{files_list}"
    "\t\t\t);\n"
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    "\t\t};\n"
    "/* End PBXResourcesBuildPhase section */\n"
)

content = content.replace(
    "/* Begin PBXSourcesBuildPhase section */",
    res_phase + "/* Begin PBXSourcesBuildPhase section */"
)

# 4. Phase in NevLate-Target buildPhases eintragen
for pattern in [
    "\t\t\t\tbuildPhases = (\n\t\t\t\t\tC44F653D44DFC34567465F6E",
    "\t\t\tbuildPhases = (\n\t\t\t\tC44F653D44DFC34567465F6E",
    "buildPhases = (\n\t\t\t\tC44F653D44DFC34567465F6E",
]:
    if pattern in content:
        indent = "\t" * (pattern.count("\t") + 1)
        content = content.replace(
            pattern,
            pattern.replace(
                "buildPhases = (\n",
                f"buildPhases = (\n{indent}{res_phase_uuid} /* Resources */,\n"
            )
        )
        break

with open(PBXPROJ, 'w') as f:
    f.write(content)

print(f"✅ Patch angewendet: {PBXPROJ}")
print(f"   PBXResourcesBuildPhase: {res_phase_uuid}")
print(f"   {len(resources)} Ressourcen hinzugefügt")
