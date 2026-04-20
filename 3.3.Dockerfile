FROM ruby:3.3-alpine

LABEL maintainer="florian@floriandejonckheere.be"

ENV BUILD_DEPS="build-base git linux-headers yaml-dev zlib-dev openssl-dev curl"

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

ENV APP_HOME=/app

RUN apk add --no-cache $BUILD_DEPS

RUN gem update --system && gem install bundler

RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile polyphony.gemspec $APP_HOME/
ADD lib/polyphony/version.rb $APP_HOME/lib/polyphony/

RUN bundle install --jobs 4 --retry 5

ADD . $APP_HOME
