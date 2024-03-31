wget https://github.com/kopia/kopia/releases/download/v0.16.1/kopia-0.16.1-linux-x64.tar.gz -O /tmp/kopia-0.16.1-linux-x64.tar.gz && \
cd /tmp && \
tar -xvf kopia-0.16.1-linux-x64.tar.gz && \
cp /tmp/kopia-0.16.1-linux-x64/kopia /usr/bin/kopia && \
cd -