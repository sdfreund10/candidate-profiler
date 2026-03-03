# Build stage: install native deps and gems
FROM ruby:4-slim AS builder

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
ENV BUNDLE_FROZEN=true
RUN gem install --no-document bundler \
  && bundle config set --local frozen true \
  && bundle config set --local without "development test" \
  && bundle install

# Run stage: no build tools, copy installed gems from builder
FROM ruby:4-slim

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .


EXPOSE 80
ENV RACK_ENV=production

# rackup ignores Sinatra's :port; we must pass -p so Cloud Run's PORT is used
CMD ["sh", "-c", "bundle exec rackup -o 0.0.0.0 -p ${PORT:-8080}"]