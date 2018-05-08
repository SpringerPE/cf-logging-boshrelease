## Logstash BOSH Release

```
./add-blobs.sh

bosh create-release --name=logstash --force --timestamp-version --tarball=/tmp/logstash-boshrelease.tgz
bosh upload-release
bosh -n -d logstash deploy manifest/logstash.yml --var-file logstash.conf=manifest/logstash.conf --no-redact
```



To create a final release:

```
bosh create-release --name=logstash --version=1 --tarball=/tmp/logstash-boshrelease.tgz
bosh upload-release
```

