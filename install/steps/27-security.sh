#!/usr/bin/env bash
set -euo pipefail
# Signing in (docs/security.md). Safe to run again; it keeps whatever the person chose.
#   /etc/pam.d/takumi-lock-finger  Takumi's own: the Lock's check by finger, used only while fingerprint unlock is on
#   /etc/pam.d/sudo                sudo's and polkit's own files, which have no folder for extras.
#   /etc/pam.d/polkit-1            `takumi security fingerprint on` puts four lines of Takumi's in front of their
#                                  "auth include system-auth" (a finger first, then the password) and `off` takes
#                                  them out. Here they are brought to their current form when they are there.
#   /etc/fwupd/fwupd.conf          with this computer's own Secure Boot keys (`takumi security secure-boot`),
#                                  DisableShimForSecureBoot=true, so firmware updates start fwupd's signed program.
#   /etc/pam.d/greetd              greetd's own, without a folder for extras: three lines of Takumi's at its end,
#                                  between marks, so the login keyring opens with the password you sign in with.
#   /etc/security/faillock.conf    pam's own, read by pam_faillock alone: deny and unlock_time set from
#                                  etc/security/faillock.conf (ten tries, then two minutes), the rest kept.
. "$TAKUMI_PATH/lib/security.sh"
sudo install -Dm644 "$TAKUMI_PATH/default/pam/takumi-lock-finger" /etc/pam.d/takumi-lock-finger
if security_finger_pam_is_on; then
  sudo bash -c '. "$1"; security_finger_pam on' _ "$TAKUMI_PATH/lib/security.sh"   # /etc/pam.d/sudo, /etc/pam.d/polkit-1
  echo "security: a finger answers sudo and polkit"
else
  echo "security: sudo and polkit ask for the password (takumi security fingerprint on adds a finger)"
fi
# The login keyring opens at the login screen (the Lock's file, default/pam/takumi-lock, is installed by 20-system.sh).
sudo bash -c '. "$1"; security_keyring_pam on' _ "$TAKUMI_PATH/lib/security.sh"   # /etc/pam.d/greetd
# Ten wrong passwords, then two minutes.
sudo bash -c '. "$1"; security_faillock "$2"' _ "$TAKUMI_PATH/lib/security.sh" "$TAKUMI_PATH/etc/security/faillock.conf"   # /etc/security/faillock.conf
if sudo test -f /var/lib/sbctl/keys/db/db.key; then   # /var/lib/sbctl/keys/db/db.key, only looked at
  sudo bash -c '. "$1"; security_fwupd_own_keys' _ "$TAKUMI_PATH/lib/security.sh"   # /etc/fwupd/fwupd.conf
  echo "security: Secure Boot with this computer's own keys"
fi
