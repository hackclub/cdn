FROM rust:1.88.0 AS builder

WORKDIR /usr/src/app
COPY . .
RUN cargo build --release

FROM debian:trixie-slim AS runtime

RUN apt-get update && apt-get install -y ca-certificates

WORKDIR /app

COPY --from=builder /usr/src/app/target/release/cdn .

EXPOSE 3000
VOLUME /sled

CMD ["./cdn"]