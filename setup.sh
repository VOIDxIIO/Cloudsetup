#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
GITHUB_USER="VOIDxIIO"
GITHUB_REPO="Cloudsetup"
GITHUB_BRANCH="main"
GITHUB_TOKEN="" 

TARGET_APP="com.mbcfgkmhkdjx.cunpcbaavarqntr"
FILES=("pgtools.apk" "via.apk" "pgtoolsfly.apk" "nest.gpx" "Stardustconfig.txt")

# 1. DOWNLOAD TO TERMUX HOME
WORK_DIR="$HOME/cloud_setup"
rm -rf "$WORK_DIR" 
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit

# ==========================================
# 2. SAFE DEPENDENCY INSTALLATION
# ==========================================
echo "[*] Checking dependencies..."
export DEBIAN_FRONTEND=noninteractive
for cmd in curl wget sqlite; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "    -> Installing $cmd..."
        pkg install -y $cmd
    fi
done

# ==========================================
# 3. DOWNLOAD FILES FROM GITHUB
# ==========================================
echo "[*] Downloading setup files..."
for FILE in "${FILES[@]}"; do
    URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/$FILE?t=$(date +%s)"
    echo "    -> Downloading $FILE..."
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -sL -H "Authorization: token $GITHUB_TOKEN" -o "$FILE" "$URL"
    else
        curl -sL -o "$FILE" "$URL"
    fi
done

# ==========================================
# 4. ROOT & SELINUX SETUP (FIXED)
# ==========================================
echo "[*] Requesting root and setting SELinux to Permissive..."
if su -c "id" >/dev/null 2>&1; then
    echo "    -> Root access confirmed."
    # Ignore the error if SELinux is already disabled
    su -c "setenforce 0" >/dev/null 2>&1 || true
else
    echo "    [!] Root failed! Please open Magisk and grant root to Termux."
    exit 1
fi

# ==========================================
# 5. MOVE APKS TO SYSTEM-ACCESSIBLE LOCATION
# ==========================================
echo "[*] Moving APKs to /data/local/tmp/cloud_setup..."
su -c "rm -rf /data/local/tmp/cloud_setup"
su -c "mkdir -p /data/local/tmp/cloud_setup"
su -c "cp $WORK_DIR/*.apk /data/local/tmp/cloud_setup/"
su -c "chmod -R 755 /data/local/tmp/cloud_setup"

# ==========================================
# 6. COPY CONFIG FILES TO PUBLIC DOWNLOADS FOLDER
# ==========================================
echo "[*] Copying config files to /sdcard/Download/CloudSetup/..."
su -c "mkdir -p /sdcard/Download/CloudSetup"
su -c "cp $WORK_DIR/nest.gpx /sdcard/Download/CloudSetup/"
su -c "cp $WORK_DIR/Stardustconfig.txt /sdcard/Download/CloudSetup/"
echo "    -> Files saved to Internal Storage/Download/CloudSetup/"

# ==========================================
# 7. INSTALL APPS
# ==========================================
echo "[*] Installing APKs..."
for APK in "pgtools.apk" "via.apk" "pgtoolsfly.apk"; do
    if su -c "[ -f /data/local/tmp/cloud_setup/$APK ]"; then
        echo "    -> Installing $APK..."
        su -c "pm install -r /data/local/tmp/cloud_setup/$APK"
    fi
done

# ==========================================
# 8. GRANT SPECIFIC PERMISSIONS
# ==========================================
echo "[*] Granting permissions to $TARGET_APP..."
if su -c "pm list packages | grep -q $TARGET_APP"; then
    su -c "pm grant $TARGET_APP android.permission.ACCESS_FINE_LOCATION" 2>/dev/null
    su -c "pm grant $TARGET_APP android.permission.ACCESS_COARSE_LOCATION" 2>/dev/null
    su -c "pm grant $TARGET_APP android.permission.ACCESS_BACKGROUND_LOCATION" 2>/dev/null
    
    SDK_INT=$(su -c "getprop ro.build.version.sdk")
    if [ "$SDK_INT" -ge 33 ]; then
        su -c "pm grant $TARGET_APP android.permission.POST_NOTIFICATIONS" 2>/dev/null
    fi

    su -c "appops set $TARGET_APP RUN_IN_BACKGROUND allow" 2>/dev/null
    su -c "appops set $TARGET_APP RUN_ANY_IN_BACKGROUND allow" 2>/dev/null
    su -c "appops set $TARGET_APP SYSTEM_ALERT_WINDOW allow" 2>/dev/null
    su -c "appops set $TARGET_APP android:mock_location allow" 2>/dev/null
    
    echo "[+] Permissions granted successfully."
else
    echo "[!] Error: $TARGET_APP is not installed. Skipping permissions."
fi

# ==========================================
# 9. GRANT ROOT TO PG TOOLS (MAGISK)
# ==========================================
echo "[*] Granting root to PGTools..."
PGTOOLS_PKG=$(su -c "pm list packages | grep -i 'pgtools' | cut -d ':' -f 2 | head -n 1")

if [ -n "$PGTOOLS_PKG" ]; then
    PGTOOLS_UID=$(su -c "dumpsys package $PGTOOLS_PKG | grep userId= | head -n 1 | awk -F= '{print $2}' | awk '{print $1}'")
    if su -c "ls /data/adb/magisk.db" >/dev/null 2>&1; then
        su -c "sqlite3 /data/adb/magisk.db \"INSERT OR REPLACE INTO policies (uid, policy, until, logging, notification) VALUES ($PGTOOLS_UID, 2, 0, 1, 1);\""
        echo "[+] Root granted to PGTools automatically."
    else
        echo "[!] Magisk DB not found. Please grant root manually."
    fi
fi

echo "=========================================="
echo " SETUP COMPLETE!"
echo "=========================================="
