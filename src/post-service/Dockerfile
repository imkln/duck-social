FROM ruby:4.0-slim AS build

WORKDIR /src

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

FROM ruby:4.0-slim

WORKDIR /app

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /src .

EXPOSE 8080
ENTRYPOINT ["ruby", "app.rb"]
