# test-editor-xtext-gradle

[![License](http://img.shields.io/badge/license-EPL-blue.svg?style=flat)](https://www.eclipse.org/legal/epl-v10.html)
[![Build Status](https://travis-ci.org/test-editor/test-editor-xtext-gradle.svg?branch=master)](https://travis-ci.org/test-editor/test-editor-xtext-gradle)

Gradle based project to build Xtext test-editor languages.

The resulting language jars provide rich editing and test generation facilities. They are wrapped into rest services served by [test-editor-backend](https://github.com/test-editor/test-editor-backend).

## Development

### Setup

``` shell
git clone https://github.com/test-editor/test-editor-xtext-gradle.git  # clone the sources
curl https://nixos.org/nix/install | sh                                # get nix package manager (if you happen to not have it installed)
cd test-editor-xtext-gradle                                            # switch into cloned repo
nix-shell                                                              # setup build environment (takes a bit on first invocation)
```

### Eclipse based development

- Make sure to have `Xtext SDK 2.15`, `Buildship 2.2.1` installed (e.g. use Eclipse DSL Edition 4.9.0)
- Generate eclipse project meta data:

```shell
./gradlew eclipse
```

- Import this project as gradle project.
- Make sure to disable errors on dependency cycles (which eclipse runs in because of limited dependency resolution capabilities).
  Preferences -> Java -> Compiler -> Building -> Build Path Problems -> Circular dependencies
  
### Build

    ./gradlew build
    
If the build process stops with failures generating the Xtext languages, it usually helps to rerun all gradle tasks.
 
    ./gradlew build --rerun-tasks
 
### Release process

In order to create a release switch to the `master` branch and execute

    ./gradlew release

and enter the new version. After the commit and tag is pushed Travis will automatically build and deploy the tagged version to Bintray.
