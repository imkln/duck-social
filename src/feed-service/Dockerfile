FROM rust:1.98.1-slim AS build

WORKDIR /src

COPY Cargo.toml Cargo.lock ./
RUN cargo fetch

COPY main.rs .
RUN cargo build --release

FROM debian:13-slim

WORKDIR /app

COPY --from=build /src/target/release/feed-service .

EXPOSE 8080
ENTRYPOINT ["./feed-service"]
