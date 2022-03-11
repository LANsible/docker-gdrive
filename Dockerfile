FROM golang:1.17.8-alpine3.15 as builder

# https://github.com/prasmussen/gdrive/releases
ENV VERSION=2.1.1

# Add unprivileged user
RUN echo "gdrive:x:1000:1000:gdrive:/:" > /etc_passwd
RUN echo "gdrive:x:1000:gdrive" > /etc_group

# Install build needs
RUN apk add --no-cache \
  git

# Get gdrive from Github
RUN git clone --depth 1 --branch "${VERSION}" https://github.com/prasmussen/gdrive.git /gdrive

# Setup go modules: https://github.com/prasmussen/gdrive/pull/585
COPY go.* /gdrive/

WORKDIR /gdrive

# Compile static gdrive
# setup go modules with `go mod init` and `go mod vendor`
RUN CGO_ENABLED=0 go build -ldflags='-s -w'

# 'Install' upx from image since upx isn't available for aarch64 from Alpine
COPY --from=lansible/upx /usr/bin/upx /usr/bin/upx
# Minify binaries and create config folder
RUN upx --brute gdrive && \
    upx -t gdrive


FROM scratch

# Copy the unprivileged user
COPY --from=builder /etc_passwd /etc/passwd
COPY --from=builder /etc_group /etc/group

# ca-certificates are required to resolve https// domains:
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Add static binary
COPY --from=builder /gdrive/gdrive /usr/bin/gdrive

USER gdrive
ENTRYPOINT ["/usr/bin/gdrive"]
