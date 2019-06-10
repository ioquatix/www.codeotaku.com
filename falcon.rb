#!/usr/bin/env -S falcon host

load :rack, :lets_encrypt, :supervisor

rack 'www.codeotaku.com', :lets_encrypt

supervisor
