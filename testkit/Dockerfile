# Install Maven 3.6, Java 11, Java 8 and Python3
FROM $RUBY

RUN apt-get --quiet --quiet update \
    && apt-get --quiet --quiet install -y bash python3 maven \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHON=python3

# Install our own CAs on the image.
# Assumes Linux Debian based image.
# JAVA_HOME needed by update-ca-certificates hook to update Java with changed system CAs.
COPY CAs/* /usr/local/share/ca-certificates/
RUN update-ca-certificates

RUN gem install ruby-maven
