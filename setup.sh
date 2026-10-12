#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# CONFIGURATION (Update these!)
# ==========================================
GITHUB_USER="your_github_username"
GITHUB_REPO="your_repo_name"
GITHUB_BRANCH="main"
# If your repo is PRIVATE, generate a Personal Access Token and put it here:
GITHUB_TOKEN="" 

# Target app to apply permissions to
TARGET_APP="com.mbcfgkmhkdjx.cunpcbaavarqntr"

# Files to download
FILES=("pgtools.apk" "via.apk" "pgtoolsfly.apk" "nest.gpx" "Stardustconfig.txt")

# Local working directory
WORK_DIR="$HOME/cloud_setup"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit

# ==========================================
# 1. INSTALL DEPENDENCIES
# ==========================================
echo "[*] Updating Termux packages..."
pkg update -y && pkg upgrade -y
echo "[*] Installing required tools..."
pkg install curl wget sqlite -y

# ==========================================
# 2. DOWNLOAD FILES FROM GITHUB
# ==========================================
echo "[*] Downloading setup files..."
for FILE in "${FILES[@]}"; do
    URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/$FILE"
    echo "    -> Downloading $FILE..."
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -sL -H "Authorization: token $GITHUB_TOKEN" -o "$FILE" "$URL"
    else
        curl -sL -o "$FILE" "$URL"
    fi
done

# If you prefer to copy from /sdcard/Download instead of GitHub, uncomment the next line:
# cp /sdcard/Download/*.apk /sdcard/Download/*.gpx /sdcard/Download/*.txt "$WORK_DIR/"

# ==========================================
# 3. ROOT & SELINUX SETUP
# ==========================================
echo "[*] Requesting root and setting SELinux to Permissive..."
su -c "setenforce 0" || { echo "Root failed! Ensure Magisk is installed."; exit 1; }

# ==========================================
# 4. INSTALL APPS
# ==========================================
echo "[*] Installing APKs..."
for APK in "pgtools.apk" "via.apk" "pgtoolsfly.apk"; do
    if [ -f "$APK" ]; then
        echo "    -> Installing $APK..."
        su -c "pm install -r $WORK_DIR/$APK"
    else
        echo "    [!] Warning: $APK not found!"
    fi
done

# ==========================================
# 5. GRANT SPECIFIC PERMISSIONS (Root bypasses waiting)
# ==========================================
echo "[*] Granting permissions to $TARGET_APP..."
if su -c "pm list packages | grep -q $TARGET_APP"; then
    
    # --- Location Permissions ---
    su -c "pm grant $TARGET_APP android.permission.ACCESS_FINE_LOCATION" 2>/dev/null
    su -c "pm grant $TARGET_APP android.permission.ACCESS_COARSE_LOCATION" 2>/dev/null
    su -c "pm grant $TARGET_APP android.permission.ACCESS_BACKGROUND_LOCATION" 2>/dev/null
    
    # --- Notification Permission (Android 13+ only, safely skipped on 10/12) ---
    SDK_INT=$(su -c "getprop ro.build.version.sdk")
    if [ "$SDK_INT" -ge 33 ]; then
        su -c "pm grant $TARGET_APP android.permission.POST_NOTIFICATIONS" 2>/dev/null
        echo "    -> Notification permission granted (Android 13+)"
    else
        echo "    -> Notification permission skipped (Android 10/12 doesn't require runtime grant)"
    fi

    # --- AppOps Permissions (Background, Overlay, Mock Location) ---
    # RUN_IN_BACKGROUND allows background execution
    su -c "appops set $TARGET_APP RUN_IN_BACKGROUND allow" 2>/dev/null
    su -c "appops set $TARGET_APP RUN_ANY_IN_BACKGROUND allow" 2>/dev/null
    # SYSTEM_ALERT_WINDOW allows Display Over Other Apps
    su -c "appops set $TARGET_APP SYSTEM_ALERT_WINDOW allow" 2>/dev/null
    # Mock Location
    su -c "appops set $TARGET_APP android:mock_location allow" 2>/dev/null
    
    echo "[+] Permissions granted successfully to $TARGET_APP"
else
    echo "[!] Error: $TARGET_APP is not installed. Skipping permissions."
fi

# ==========================================
# 6. GRANT ROOT TO PG TOOLS (MAGISK)
# ==========================================
echo "[*] Attempting to grant root access to PGTools..."
PGTOOLS_PKG=$(su -c "pm list packages | grep -i 'pgtools' | cut -d ':' -f 2 | head -n 1")

if [ -n "$PGTOOLS_PKG" ]; then
    PGTOOLS_UID=$(su -c "dumpsys package $PGTOOLS_PKG | grep userId= | head -n 1 | awk -F= '{print $2}' | awk '{print $1}'")
    echo "    -> PGTools package: $PGTOOLS_PKG (UID: $PGTOOLS_UID)"
    
    # Check if Magisk is installed and has its DB
    if su -c "ls /data/adb/magisk.db" >/dev/null 2>&1; then
        echo "    -> Injecting root permission into Magisk database..."
        # policy=2 means ALLOW. 1 means DENY. 0 means PROMPT.
        su -c "sqlite3 /data/adb/magisk.db \"INSERT OR REPLACE INTO policies (uid, policy, until, logging, notification) VALUES ($PGTOOLS_UID, 2, 0, 1, 1);\""
        echo "[+] Root granted to PGTools automatically."
    else
        echo "    [!] Magisk database not found. Please grant root manually inside Magisk app."
    fi
else
    echo "    [!] PGTools package not found. Skipping root grant."
fi

echo "=========================================="
echo " SETUP COMPLETE!"
echo "=========================================="
