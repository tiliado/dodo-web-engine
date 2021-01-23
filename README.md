Dodo Web Engine
===============

Embed QtWebEngine into an GTK 3 application.

* Development status: 💩 prototype 💩
* Maintainer: Jiří Janoušek
* License: [BSD-2-Clause](./LICENSE)
* Issues tracker: [Show issues][1] | [Create issue][2]

Components
----------

* The `dodo` protocol: [protocols/dodo-protocol.xml](./protocol/dodo-protocol.xml)
* Server implementation in Vala/GTK+ 3: [src/](./src)
* Client implementation in Python: [dodo/](./dodo)

Dependencies
------------

* Wayland Server library
* OpenGL library
* GTK+ 3 library
* Vala compiler
* GNU Make

Build from source
-----------------

`make all`

Run
---

`make run-server` - Starts a new server listening on `$XDG_RUNTIME_DIR/dodo/default`.

Copyright
---------

* Copyright 2020-2021 Jiří Janoušek <janousek.jiri@gmail.com>
* License: [BSD-2-Clause](./LICENSE)

[1]: https://github.com/tiliado/dodo-web-engine/issues
[2]: https://github.com/tiliado/dodo-web-engine/issues/new
