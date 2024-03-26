# Add Kopia's official GPG key:
apt-get update && \
apt-get install ca-certificates curl gnupg -y
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://kopia.io/signing-key | gpg --dearmor -o /etc/apt/keyrings/kopia-keyring.gpg
chmod a+r /etc/apt/keyrings/kopia-keyring.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable main" | \
  tee /etc/apt/sources.list.d/kopia.list

apt-get update && \
apt-get install kopia -y && \