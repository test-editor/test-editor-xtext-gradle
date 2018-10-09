#!/bin/bash
# Execute only on tag builds where the tag starts with 'v'

if [[ -n "$TRAVIS_TAG" && "$TRAVIS_TAG" == v* ]]; then
    version="${TRAVIS_TAG//v}"
    echo "Publishing version: $version"
    ./gradlew bintrayUpload --stack-trace
fi
