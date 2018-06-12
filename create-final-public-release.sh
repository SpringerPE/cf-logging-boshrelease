#!/usr/bin/env bash
set -e

RELEASE="cf-logging"
DESCRIPTION="CF logging Bosh Release"
GITHUB_REPO="SpringerPE/cf-logging-boshrelease"
BUCKET="cf-logging-boshrelease"
BOSH=bosh
S3CMD=s3cmd
JQ=jq
CURL="curl -s"
SHA1="sha1sum -b"

# Create a personal github token to use this script
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Github TOKEN not defined!"
    echo "See https://help.github.com/articles/creating-an-access-token-for-command-line-use/"
    exit 1
fi
# You need s3cmd installed and with you credentials
if ! [ -x "$(command -v $S3CMD)" ]; then
    echo "$S3CMD command not found!"
    exit 1
fi
# You need bosh installed and with you credentials
if ! [ -x "$(command -v $BOSH)" ]; then
    echo "$BOSH command not found!";
    exit 1
fi
# You need jq installed
if ! [ -x "$(command -v $JQ)" ]; then
    echo "$JQ command not found!";
    exit 1
fi
# Checking if the bucket is there. If not, create it first (this just a check to
# be sure that s3cmd is properly setup and with the correct credentials
if ! $S3CMD ls | grep -q "s3://${BUCKET}"; then
    echo "Bucket 's3://${BUCKET}' not found! Please create it first!"
    exit 1
fi

# Creating the release
$BOSH create release --force --final --with-tarball --name $RELEASE

# Get the version of the release
VERSION=$(ls -r -v releases/$RELEASE/$RELEASE-*.yml | sed 's/.*\/.*-\(.*\)\.yml$/\1/' | head -1)

# Create a new tag and update the changes
echo "Commiting git changes ..."
git add .final_builds releases/$RELEASE/index.yml "releases/$RELEASE/$RELEASE-$VERSION.yml"
git commit -m "$RELEASE v$VERSION boshrelease"
git push --tags

# Create a release in Github
echo -n "Creating a new release in github ... "
description="$DESCRIPTION version $VERSION <br><br>sha1: $($SHA1 releases/$RELEASE/$RELEASE-$VERSION.tgz | cut -d' ' -f1)"
printf -v DATA '{"tag_name": "v%s","target_commitish": "master","name": "v%s","body": "%s","draft": false, "prerelease": false}' "$VERSION" "$VERSION" "$description"
releaseid=$($CURL -H "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/json" -XPOST --data "$DATA" "https://api.github.com/repos/$GITHUB_REPO/releases" | $JQ '.id')
if [ -z "$releaseid" ]; then
    echo "No release ID from github!"
    exit 1
elif [ "$releaseid" == "null" ]; then
    echo "Null release ID from github!"
    exit 1
fi
echo "$releaseid"
# Upload the release
echo -n "Uploading tarball ... "
$CURL -H "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/octet-stream" --data-binary @"releases/$RELEASE/$RELEASE-$VERSION.tgz" "https://uploads.github.com/repos/$GITHUB_REPO/releases/$releaseid/assets?name=$RELEASE-$VERSION.tgz" | $JQ -r '.browser_download_url'

# Delete the release
rm -f releases/$RELEASE/$RELEASE-$VERSION.tgz

# Update ACLs on bucket
echo "Assigning public ACL to new blobs in bucket ..."
$S3CMD setacl "s3://${BUCKET}" --acl-public --recursive
