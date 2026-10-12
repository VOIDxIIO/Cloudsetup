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

# 1. DOWNLOAD TO TERMUX HOME (Termux CAN write here)
WORK_DIR="$HOME/cloud_setup"
rm -rf "$WORK_DIR" # Auto-clear old cache
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
    # Adding ?t= to bust GitHub cache
    URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/$FILE?t=$(date +%s)"
    echo "    -> Downloading $FILE..."
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -sL -H "Authorization: token $GITHUB_TOKEN" -o "$FILE" "$URL"
    else
        curl -sL -o "$FILE" "$URL"
    fi
done

# ==========================================
# 4. ROOT & SELINUX SETUP
# ==========================================
echo "[*] Requesting root and setting SELinux to Permissive..."
su -c "setenforce 0" || { echo "Root failed! Ensure Magisk is installed."; exit 1; }

# ==========================================
# 5. MOVE FILES TO SYSTEM-ACCESSIBLE LOCATION USING ROOT
# ==========================================
echo "[*] Moving files to /data/local/tmp/cloud_setup using root..."
su -c "rm -rf /data/local/tmp/cloud_setup" # Clear old system cache
su -c "mkdir -p /data/local/tmp/cloud_setup"
su -c "cp $WORK_DIR/* /data/local/tmp/cloud_setup/"
su -c "chmod -R 755 /data/local/tmp/cloud_setup"

# ==========================================
# 6. INSTALL APPS
# ==========================================
echo "[*] Installing APKs..."
for APK in "pgtools.apk" "via.apk" "pgtoolsfly.apk"; do
    if su -c "[ -f /data/local/tmp/cloud_setup/$APK ]"; then
        echo "    -> Installing $APK..."
        su -c "pm install -r /data/local/tmp/cloud_setup/$APK"
    else
        echo "    [!] Warning: $APK not found in system temp folder!"
    fi
done

# ==========================================
# 7. GRANT SPECIFIC PERMISSIONS
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
    echo "[!] Error: $TARGET_APP is not installed."
fi

# ==========================================
# 8. GRANT ROOT TO PG TOOLS (MAGISK)
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
