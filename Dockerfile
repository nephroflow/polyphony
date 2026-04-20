FROM ruby:4.0-alpine

LABEL maintainer="florian@floriandejonckheere.be"

ENV BUILD_DEPS="build-base git linux-headers yaml-dev zlib-dev openssl-dev curl"

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

ENV APP_HOME=/app

# Linux 5.0 has an incompatibility with io_uring backend
#ENV POLYPHONY_LIBEV=1

RUN apk add --no-cache $BUILD_DEPS

RUN gem update --system && gem install bundler

# Define glibc constant for zstd-ruby
#RUN bundle config build.zstd-ruby --with-cppflags=-DPATH_MAX=4096

RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile polyphony.gemspec $APP_HOME/
ADD lib/polyphony/version.rb $APP_HOME/lib/polyphony/

RUN bundle install --jobs 4 --retry 5

ADD . $APP_HOME
