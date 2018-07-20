# Cloudfoundry logging Bosh release

This is a release to based on https://github.com/cloudfoundry-community/logsearch-for-cloudfoundry
to easily manage logging in Cloudfoundry deployments.

* Able to define logstash pipelines
* Not linked to ES
* Logstash 6.x and up (no legacy versions)
* Easy to manage and define logstash configuration files
* Includes Prometheus logstash exporter: https://github.com/BonnierNews/logstash_exporter


## Why?

This is a simple an small release, the core is just logstash, with the idea of
having something easy to manage and maintain decoupled from ES. Also, it is
focused on processing/filtering logs, not on store then in a ES cluster. It allows to
define logstash configuration pipelines in a flexible way (directly editing
logstash configuration files) and work with a simple endpoint which a 3rd party
service offered by somebody else (it can be ES offered by Elastic, BigQuery endpoint
by Google, etc.)


# Developing

First of all, when do a git commit, try to use good commit messages; the release
changes on each release will be taken from the commit messages!


Second, if first time, probably you will need to initialize the upstream git submodules
(for Prometheus logstash_exporter: https://github.com/BonnierNews/logstash_exporter):

```
git submodule init
git submodule update
```

When you make changes in the packages (or add new ones), please use
`./update-blobs.sh` to sync and upload the new blobs. This script reads the `spec` file 
of every package or looks for a `prepare` script (inside the folder of each package):

* If there is a `packages/<package>/prepare`, it executes it and goes to the next package.
* If the spec file of a package in `packages/<package>/spec` has a key `files` with this
format `- folder/src.tgz   # url`, for example:
```
files:
- ruby-2.3/ruby-2.3.7.tar.gz      # https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.7.tar.gz
- ruby-2.3/rubygems-2.7.7.tgz     # https://rubygems.org/rubygems/rubygems-2.7.7.tgz
```
It will take the url, download the file to `blobs/ruby-2.3/ruby-2.3.7.tar.gz` and
it will run `bosh add-blob` with the new src "ruby-2.3.7.tar.gz". Take into
account the script does not download a package if there is a file with the same
name in the destination folder, so it the package was not properly downloaded
(e.g. script execution interrupted), please delete the destination folder and try
again.

The idea is make it easy to update the version of the packages. Making a `packaging`
script flexible, not linked to version, updating a package is just a matter of 
updating its `spec` file and run `./update-blobs.sh` and you have a new version
ready!. Extract of a ruby `packaging` script (just and example):
```
# Grab the latest versions that are in the directory
RUBY_VERSION=`ls -r ruby-2.3/ruby-* | sed 's/ruby-2.3\/ruby-\(.*\)\.tar\.gz/\1/' | head -1`
RUBYGEMS_VERSION=`ls -r ruby-2.3/rubygems-* | sed 's/ruby-2.3\/rubygems-\(.*\)\.tgz/\1/' | head -1`

echo "Extracting ruby-${RUBY_VERSION} ..."
tar xvf ruby-2.3/ruby-${RUBY_VERSION}.tar.gz

echo "Building ruby-${RUBY_VERSION} ..."
pushd ruby-${RUBY_VERSION}
  LDFLAGS="-Wl,-rpath -Wl,${BOSH_INSTALL_TARGET}" ./configure --prefix=${BOSH_INSTALL_TARGET} --disable-install-doc --with-opt-dir=${BOSH_INSTALL_TARGET}
  make
  make install
popd
```

The script does not process any args and it is safe to run as many times as you need
(take into account if you create `prepare` scrips!).

## Creating Dev releases (for testing)

To create a dev release -for testing purposes-, just run:

```
# Update or sync blobs
./update-blobs.sh
# Create a dev release
bosh  create-release --force --tarball=/tmp/release.tgz
# Upload release to bosh director
bosh -e <bosh-env> upload-release /tmp/release.tgz
```

Then you can modify your manifest to include `latest` as a version (no `url` and `sha` 
fields are needed when the release is manually uploaded): 

```
releases:
  [...]
- name: cf-logging
  version: latest
```

Once you know that the dev version is working, you can generate and publish a final
version of the release (see  below), and remember to change the deployment manifest
to use a url of the new final manifest like this:

```
releases:
  [...]
- name: cf-logging
  url: https://github.com/SpringerPE/cf-logging-boshrelease/releases/download/v8/cf-logging-8.tgz
  version: 8
  sha1: 12c34892f5bc99491c310c8867b508f1bc12629c
```

or much better, use an operations file ;-)



## Creating a new final release and publishing to GitHub releases:

Run: `./create-final-public-release.sh [version-number]`

Keep in mind you will need a Github token defined in a environment variable `GITHUB_TOKEN`.
Please get your token here: https://help.github.com/articles/creating-an-access-token-for-command-line-use/
and run `export GITHUB_TOKEN="xxxxxxxxxxxxxxxxx"`, after that you can use the script.

`version-number` is optional. If not provided it will create a new major version
(as integer), otherwise you can specify versions like "8.1", "8.1.2". There is a
regular expresion in the script to check if the format is correct. Bosh client
does not allow you to create 2 releases with the same version number. If for some
reason you need to recreate a release version, delete the file created in 
`releases/cf-logging-boshrelease` and update the index file in the same location,
you also need to remove the release (and tags) in Github.


# Usage in a deployment manifest


## Creating operarions file to define a new pipeline

Logstash pipeline configuration files are defined in `manifest/pipelines/<pipeline-name>` folder.
Thre is a script `manifest/pipelines/generate-pipeline-operations.sh`:

```
Usage:
   generate-pipeline-operations.sh [-m <generated-operations-manifest] <folder> [[config1] [config2] ...]

Generates a Bosh client operations file, next to <folder>, with the name
"<folder>.yml" including all snippets if no extra arguments are provided,
otherwise it will use the snippets given as arguments.

The output is an operations file ready to be used by bosh.

Why? Because this allows us to split the logstash configuration in different
files (snippets), making the logstash config easy to manage, and automatically
generates an operations file including these snippets.
```

So, if you generate/modify files in a pipeline folder, you can run:

```
./generate-pipeline-operations.sh <folder>
```

and it will generate an operations <folder>.yml with all the logstash files
inside such folder. You can filter which operations files you wan to include, for
example:

```
./generate_pipeline_operations.sh cf-platform
* Warning file 'cf-platform.yml' exists! Renaming to 'cf-platform.yml.old'
* Generating cf-platform.yml with snippets from cf-platform:
* Adding snippet 'cf-platform/filter-00-prefiltering.conf' ... ok
* Adding snippet 'cf-platform/filter-10-syslog_rfc5424_parsing.conf' ... ok
* Adding snippet 'cf-platform/filter-15-set_platform_index.conf' ... ok
* Adding snippet 'cf-platform/filter-50-platform_sd_parsing.conf' ... ok
* Adding snippet 'cf-platform/filter-51-platform_haproxy_parsing.conf' ... ok
* Adding snippet 'cf-platform/filter-52-platform_uaa_parsing.conf' ... ok
* Adding snippet 'cf-platform/filter-53-platform_vcap_and_json_parsing.conf' ... ok
* Adding snippet 'cf-platform/filter-90-set_syslog_level.conf' ... ok
* Adding snippet 'cf-platform/filter-91-rework_fields.conf' ... ok
* Adding snippet 'cf-platform/filter-99-cleanup.conf' ... ok
* Adding snippet 'cf-platform/input-10-syslog.conf' ... ok
* Adding snippet 'cf-platform/output-10-es.conf' ... ok
* Adding snippet 'cf-platform/output-99-debug.conf' ... ok
* Exit=0

```

Will read all the configuration files in `cf-platform` and create a bosh operations
file `cf_platform.yml`

Later on you can use the new operations file in a bosh deployment to include
the new settings with `bosh int logstash.yml -o manifest/pipelines/cf_platform.yml`



######## 

```
bosh int manifests/logstash.yml -o manifests/add-cloud-id.yml -o manifests/pipelines/add-test.yml -o manifests/add-settings.yml  --var-file pipeline=manifests/pipelines/test.conf --vars-file manifests/secrets.yml --vars-file manifests/settings.yml
```


```
bosh int manifests/logstash.yml -o manifests/add-cloud-id.yml -o manifests/pipelines/add-logstash.yml -o manifests/add-settings.yml  --var-file pipeline=manifests/pipelines/logstash.conf --vars-file manifests/secrets.yml --vars-file manifests/settings.yml
```




# Author

SpringerNature Platform Engineering, José Riguera López (jose.riguera@springer.com)

Copyright 2018 Springer Nature


# License

Apache 2.0 License
