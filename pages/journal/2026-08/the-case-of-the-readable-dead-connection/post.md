# The Case of the Readable Dead Connection: A Ruby Mystery

*Being an account of the curious case of a persistent HTTPS connection which appeared ready for use after it had already received its final message, as recorded by Dr. Claude Watson.*

---

## Chapter I: The Failure After Success

The telegram arrived at Baker Street bearing a familiar exception:

```text
Faraday::ConnectionFailed: EOFError
  protocol-http1/.../connection.rb:in `read_response_line`
  async-http/.../protocol/http1/client.rb:in `call`
```

“A remote service closes a persistent connection,” I observed. “The client reuses it, waits for the next response, and discovers the end of the stream. Surely we need only retry?”

Holmes looked up sharply. “What kind of request, Watson?”

“A <code class="language-ruby">POST</code>.”

That single word changed the case. If a connection fails while receiving a response, the client may not know whether the server processed the request. Retrying could repeat a payment, create a second record, or perform some other side effect twice.

The report, [Persistent connection issues for non-idempotent requests](https://github.com/socketry/async-http/issues/223), described around a thousand failures each day. The affected application could safely retry its particular operations, but a general-purpose HTTP client could not assume the same.

“Then our task,” Holmes said, “is not to invent confidence after an ambiguous failure. It is to avoid giving a new request to a connection we can already see is dead.”

## Chapter II: The Persistent Suspect

An HTTP connection is expensive to establish, especially when TCP setup and a TLS handshake are involved. A connection pool therefore keeps completed HTTP/1 connections and lends them to later requests.

Before reusing one, Async::HTTP asked a seemingly straightforward question:

```ruby
def viable?
  self.idle? && @stream&.readable?
end
```

The connection had to be idle, its stream had to exist, and that stream had to appear capable of future reads. Yet the failure remained. A connection passed this check, received a new request, and then produced <code class="language-ruby">EOFError</code> while the client waited for the response line.

“Our suspect presents valid papers,” I said.

“At one layer,” Holmes replied. “We have not yet asked who issued them.”

## Chapter III: The False Trail of Retrying

The investigation had an earlier clue. In [Overriding <code class="language-ruby">request.idempotent?</code> for individual requests](https://github.com/socketry/async-http/issues/221), the reporter had explored enabling Async::HTTP's automatic retry path.

The idea contained two separate hazards. First, declaring a request idempotent does not make its effects safe to repeat. Second, a request body may already have been consumed; retrying it without rewinding could send an empty or incomplete body.

Async::HTTP later gained the ability to rewind suitable bodies, but that did not make every <code class="language-ruby">POST</code> safe to replay. Retry policy could help after some failures, but it could not answer the question before us: why had the pool selected a connection whose peer had already shut it down?

Holmes drew a line through the word “retry.”

“A useful remedy in the right case,” he said, “but not the identity of our culprit.”

## Chapter IV: The Socket That Told the Truth

We descended through the layers. At the bottom was a TCP socket. Above it sat TLS, which decoded encrypted records into application data. Above TLS sat HTTP/1, expecting the beginning of a response.

```text
HTTP/1 response bytes
        ↓
TLS records
        ↓
TCP bytes and EOF
```

Operating systems report a socket as readable when a read can make progress. That may mean application bytes are waiting, but it may also mean the peer has closed the connection and the next read will return EOF.

Ruby's <code class="language-ruby">IO#wait_readable</code> correctly reports this descriptor-level readiness. The discussion around [Ruby feature #20215, <code class="language-ruby">IO#readable?</code>](https://bugs.ruby-lang.org/issues/20215), had already exposed the subtle difference between “data is available now,” “a read can observe EOF,” and “a future read might succeed.”

“Then the socket was not lying,” I said. “There really was something to process.”

“Precisely. Our error was to mistake readiness at the transport layer for viability at the protocol layer.”

## Chapter V: The Sealed TLS Message

The decisive complication was TLS. A graceful TLS shutdown is not merely a TCP EOF. The peer first sends an encrypted alert record called <code class="language-plain">close_notify</code>. The underlying socket becomes readable because the TLS record has arrived.

But after OpenSSL reads and decrypts that record, it yields no HTTP bytes. It marks the TLS stream as cleanly closed.

```text
TCP:  encrypted bytes are ready
TLS:  those bytes decode to close_notify
HTTP: no response bytes exist
```

From TCP's point of view, the socket was readable. From HTTP's point of view, the connection was finished. A check which stopped at the socket could not distinguish an encrypted application-data record from an encrypted shutdown alert.

“The connection is readable,” I concluded, “and dead.”

Holmes smiled. “Now the title of our case begins to make sense.”

## Chapter VI: A Peek Through the Layers

We needed to let TLS process one pending record without stealing application data from the eventual HTTP reader. A blocking read was unacceptable: a healthy idle connection usually has nothing to say. Peeking only at the raw socket would leave the TLS record undecoded.

The solution became [<code class="language-ruby">IO::Stream::Readable#peek_partial</code>](https://github.com/socketry/io-stream/pull/16), a layered, non-blocking peek:

```ruby
def peek_partial(size = @minimum_read_size)
  if @read_buffer.empty?
    return nil if @finished

    result = sysread_nonblock(size, @read_buffer)

    case result
    when :wait_readable, :wait_writable
      return nil
    when nil
      @finished = true
      return nil
    end
  end

  @read_buffer.byteslice(0, size)
end
```

The method makes at most one non-blocking read attempt through the layered stream. If no bytes can be read without waiting, it returns <code class="language-ruby">nil</code> and leaves the stream viable. If TLS decodes <code class="language-plain">close_notify</code>, the stream records EOF. If it decodes application data, those bytes remain in <code class="language-ruby">IO::Stream</code>'s read buffer for the real consumer.

This last property matters. <code class="language-ruby">peek_partial</code> may consume encrypted bytes from the socket, but it does not consume the decoded bytes from the application's perspective.

The tests covered four distinct states: an idle open TLS connection, a clean TLS shutdown, an abrupt disconnect, and pending application data that had to survive the probe.

## Chapter VII: The Protocol-Specific Verdict

With that primitive in place, [Async::HTTP could probe idle HTTP/1 connections before reuse](https://github.com/socketry/async-http/pull/230):

```ruby
def viable?
  return false unless self.idle?
  return false unless @stream

  # Process at most one pending read through the layered stream.
  return false if @stream.peek_partial(1)

  return @stream.readable?
rescue => error
  Console.debug(self, "Connection viability probe failed!", exception: error)
  return false
end
```

For an idle HTTP/1 connection, each possible result has a useful interpretation:

1. If the read would block, no shutdown is presently observable and the connection remains a candidate for reuse.
2. If the stream reaches EOF or decodes <code class="language-plain">close_notify</code>, the connection is discarded.
3. If the probe raises because the transport was reset or otherwise failed, the connection is discarded.
4. If application data appears while the HTTP/1 connection is meant to be idle, its state is unexpected and the connection is discarded; the peeked byte remains buffered.

HTTP/1 makes this probe safe because an idle connection has no concurrent response reader. HTTP/2 is different: a background reader owns transport reads and dispatches frames for many streams. A connection-pool check must not compete with it, so HTTP/2 retained its existing viability logic.

The regression test recreated the complete sequence: make one request, return its TLS connection to the pool, close it from the server, then issue a non-idempotent <code class="language-ruby">POST</code>. The stale connection was rejected and the request used a fresh one.

## Epilogue: Readiness Is Relative

[Async::HTTP v0.98.1](https://github.com/socketry/async-http/releases/tag/v0.98.1) carried the fix. The reporter's confirmation was pleasingly concise: “it does! w00t.”

The fix cannot abolish the race inherent in a network. A peer may close a connection immediately after any viability check. What it does is narrower and valuable: when shutdown is already observable, the pool no longer assigns that connection to a new HTTP/1 request.

The deeper lesson extends beyond TLS. Readiness belongs to a layer. A file descriptor can be ready while the protocol above it has no application data to offer. Whenever software wraps one stream in another—encryption, compression, framing, buffering—the question is not merely “can I read?” but “which layer can tell me what this read means?”

Holmes closed the casebook.

“The socket told us the truth from the beginning, Watson. We simply asked it a TLS question.”

*End of Account*

---

**Dr. Claude Watson**  
*221B Baker Street*  
*August 2026*
