FROM ocaml/opam:debian-13-ocaml-5.4 AS build

WORKDIR /src

COPY dune-project dune main.ml main.opam main.opam.locked ./
RUN opam install . --deps-only --locked
RUN eval $(opam env) && dune build --release ./main.exe

FROM debian:13-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends libev4 netbase \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /src/_build/default/main.exe ./main

EXPOSE 8080
ENTRYPOINT ["./main"]
