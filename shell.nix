with import <nixpkgs> {};

stdenv.mkDerivation {
    name = "test-editor-xtext-gradle";
    buildInputs = [
        jdk8
        travis
    ];
    shellHook = ''
        # do some gradle "finetuning"
        alias g="./gradlew"
        alias g.="../gradlew"
        export GRADLE_OPTS="$GRADLE_OPTS -Dorg.gradle.daemon=false"
    '';
}
