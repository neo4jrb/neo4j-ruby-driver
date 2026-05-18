# Driver image built and run by testkit's main.py from this directory.
#
# testkit.driver.py:_ensure_image() copies testkit's TLS fixtures into
# ./CAs/ and ./CustomCAs/ here at build time, then `docker build`s this
# Dockerfile with the testkit/ folder as the context. The container is
# then started by testkit with /testkit, /driver and /artifacts mounted
# and `python3 /testkit/driver/bootstrap.py` as entrypoint; bootstrap
# runs the phase scripts in order: build.py, unittests.py, backend.py,
# integration.py / stress.py.
#
# Switch runtime via BASE_IMAGE. Defaults to MRI; pass
#   --build-arg BASE_IMAGE=jruby:10.1.0.0-jdk21
# (or via TESTKIT_DRIVER_BUILD_ARG_BASE_IMAGE under testkit) for JRuby.
ARG BASE_IMAGE=ruby:3.4-slim
FROM ${BASE_IMAGE}

# Optional: bake NEO4J_DRIVER_FORCE_MRI=1 into the image so the
# Gemfile picks the MRI gemspec even when running on JRuby. testkit
# forwards env vars matching TESTKIT_DRIVER_BUILD_ARG_* as --build-arg,
# so set TESTKIT_DRIVER_BUILD_ARG_NEO4J_DRIVER_FORCE_MRI=1 in the
# workflow row that wants the MRI-on-JRuby flavour.
ARG NEO4J_DRIVER_FORCE_MRI=""

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    NEO4J_DRIVER_FORCE_MRI=$NEO4J_DRIVER_FORCE_MRI

# - python3 is the entrypoint: testkit starts the container with
#   `python3 /testkit/driver/bootstrap.py`, which then runs the phase
#   scripts in order (build.py, unittests.py, backend.py, …).
# - build-essential / libssl-dev / pkg-config support native-gem builds
#   on the slim images.
# JRuby's image already ships a JDK; the apt set below is a superset
# that works for both bases.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        python3 \
        build-essential \
        libssl-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

# testkit copies its TLS fixtures into ./CAs and ./CustomCAs at build
# time. update-ca-certificates is safe to run if either dir is empty.
COPY CAs/ /usr/local/share/ca-certificates/
COPY CustomCAs/ /usr/local/share/custom-ca-certificates/
RUN update-ca-certificates 2>/dev/null || true

# The driver source is mounted at /driver at run time, so the image
# itself is intentionally source-free. build.py runs `bundle install`
# from that mount on first phase entry; testkit caches the resulting
# image layers in CI.
WORKDIR /driver
EXPOSE 9876
