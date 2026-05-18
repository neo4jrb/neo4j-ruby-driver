"""Install driver dependencies. Called by testkit's main.py."""

import subprocess


if __name__ == "__main__":
    # --jobs=1 serialises gem installs. On JRuby, bundler's default
    # parallel workers race when the gem under install has a post_install
    # hook (jar-dependencies on neo4j-ruby-driver-java) that itself needs
    # another gem in the same bundle (ruby-maven). One worker triggers the
    # hook before the other has finished extracting ruby-maven, leading to
    #   Errno::ENOENT: /usr/local/bundle/gems/ruby-maven-3.9.3/lib/
    #                  extensions/polyglot-ruby-0.7.1.jar
    # MRI doesn't have the hook so the flag is a no-op for it; serial install
    # is a few seconds slower than parallel but correct on both engines.
    subprocess.check_call(["bundle", "install", "--jobs=1"])
