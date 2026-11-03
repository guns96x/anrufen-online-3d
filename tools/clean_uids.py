import os, re

for root, _, files in os.walk(r"C:\Users\pavlo\anrufen-online-3d\client\scenes"):
    for f in files:
        if f.endswith(".tscn"):
            p = os.path.join(root, f)
            with open(p, "r", encoding="utf-8") as fp:
                content = fp.read()
            new_content = re.sub(r'\s+uid="[^"]+"', "", content)
            if new_content != content:
                with open(p, "w", encoding="utf-8") as fp:
                    fp.write(new_content)
                print("Cleaned UIDs in:", f)
