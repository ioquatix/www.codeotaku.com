#!/usr/bin/env -S falcon host

Async.logger.enable(Async::HTTP::Protocol::HTTP2::Server)

load :rack, :lets_encrypt_tls, :supervisor

hostname = File.basename(__dir__)
rack hostname, :lets_encrypt_tls

supervisor
