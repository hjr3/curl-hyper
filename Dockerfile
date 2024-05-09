FROM rust:1 AS hyper-builder

RUN git clone --depth 1 --branch v1.3.1 https://github.com/hyperium/hyper.git /usr/src/hyper

WORKDIR /usr/src/hyper

RUN RUSTFLAGS="--cfg hyper_unstable_ffi" cargo rustc --release --features client,http1,http2,ffi --crate-type cdylib

FROM debian:bookworm-slim as curl-builder

RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends \
    build-essential make autoconf automake libtool git perl zip zlib1g-dev gawk ca-certificates libssl-dev curl && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/hyper/target/release && mkdir -p /usr/local/hyper/capi/include
COPY --from=hyper-builder /usr/src/hyper/target/release/libhyper.so /usr/local/hyper/target/release/
COPY --from=hyper-builder /usr/src/hyper/capi/include/hyper.h /usr/local/hyper/capi/include/

RUN git clone --depth 1 --branch curl-8_7_1 https://github.com/curl/curl.git /usr/src/curl

WORKDIR /usr/src/curl

RUN autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/usr/local/hyper/target/release" --with-openssl --with-hyper=/usr/local/hyper && \
    make && \
    make DESTDIR="/curl/" install

RUN curl https://curl.haxx.se/ca/cacert.pem -L -o /cacert.pem

FROM debian:bookworm-slim

RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends \
    openssl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=curl-builder /cacert.pem /cacert.pem
ENV CURL_CA_BUNDLE="/cacert.pem"

COPY --from=curl-builder /usr/local/hyper /usr/local/hyper
COPY --from=curl-builder /curl/usr/local/lib/libcurl.so.4.8.0 /usr/lib/
COPY --from=curl-builder /curl/usr/local/bin/curl /usr/bin/curl
COPY --from=curl-builder /curl/usr/local/include/curl /usr/include/curl

# explicitly set symlinks
RUN ln -s /usr/lib/libcurl.so.4.8.0 /usr/lib/libcurl.so.4
RUN ln -s /usr/lib/libcurl.so.4 /usr/lib/libcurl.so

RUN groupadd curl_group && \
    useradd --gid curl_group --shell /bin/bash --create-home curl_user

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER curl_user

CMD ["curl"]
ENTRYPOINT ["/entrypoint.sh"]
